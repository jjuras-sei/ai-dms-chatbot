from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import boto3
import json
import os
from datetime import datetime
import uuid
import re
import logging
import traceback
from time import time

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = FastAPI(title="Chatbot API")

# Add request logging middleware
@app.middleware("http")
async def log_requests(request: Request, call_next):
    request_id = str(uuid.uuid4())
    start_time = time()
    
    # Log request
    logger.info(f"Request {request_id}: {request.method} {request.url.path}")
    logger.info(f"Request {request_id}: Client: {request.client.host}")
    
    try:
        response = await call_next(request)
        duration = time() - start_time
        
        # Log response
        logger.info(f"Request {request_id}: Status: {response.status_code}, Duration: {duration:.3f}s")
        
        return response
    except Exception as e:
        duration = time() - start_time
        logger.error(f"Request {request_id}: Failed after {duration:.3f}s")
        logger.error(f"Request {request_id}: Exception: {str(e)}")
        logger.error(f"Request {request_id}: Traceback:\n{traceback.format_exc()}")
        raise

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# AWS clients
bedrock_runtime = boto3.client(
    service_name='bedrock-runtime',
    region_name=os.getenv('AWS_REGION', 'us-east-1')
)

dynamodb = boto3.client(
    service_name='dynamodb',
    region_name=os.getenv('AWS_REGION', 'us-east-1')
)

s3 = boto3.client(
    service_name='s3',
    region_name=os.getenv('AWS_REGION', 'us-east-1')
)

# Load system prompt and schema
def load_system_prompt():
    """Load the system prompt from file"""
    try:
        # Try current directory first, then parent directory
        if os.path.exists('system_prompt.txt'):
            with open('system_prompt.txt', 'r') as f:
                return f.read()
        elif os.path.exists('../system_prompt.txt'):
            with open('../system_prompt.txt', 'r') as f:
                return f.read()
        else:
            return "You are a helpful AI assistant that helps users query and analyze data."
    except Exception:
        return "You are a helpful AI assistant that helps users query and analyze data."

def load_schema():
    """Load the database schema from file"""
    try:
        # Try current directory first, then parent directory
        if os.path.exists('schema.json'):
            with open('schema.json', 'r') as f:
                return json.load(f)
        elif os.path.exists('../schema.json'):
            with open('../schema.json', 'r') as f:
                return json.load(f)
        else:
            return {}
    except Exception:
        return {}

SYSTEM_PROMPT = load_system_prompt()
DATABASE_SCHEMA = load_schema()
DYNAMODB_TABLE_NAME = os.getenv('DYNAMODB_TABLE_NAME', '')

# In-memory conversation storage (use DynamoDB for production)
conversations = {}

class Message(BaseModel):
    role: str
    content: str
    timestamp: Optional[str] = None
    data: Optional[dict] = None  # For query results
    query: Optional[dict] = None  # For DynamoDB query

class ChatRequest(BaseModel):
    conversation_id: Optional[str] = None
    message: str

class ChatResponse(BaseModel):
    conversation_id: str
    response: str
    history: List[Message]

class ConversationResponse(BaseModel):
    conversation_id: str
    history: List[Message]

@app.get("/")
async def root():
    return {"message": "Chatbot API with DynamoDB Query Workflow"}

@app.get("/health")
async def health():
    return {"status": "healthy"}

@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """
    Process a chat message using intelligent workflow:
    - LLM decides whether to query DB or respond directly
    - Uses conversation history for context
    """
    conversation_id = None
    user_message = None
    
    try:
        # Generate or use existing conversation ID
        conversation_id = request.conversation_id or str(uuid.uuid4())
        logger.info(f"Chat request - Conversation: {conversation_id}, Message: {request.message[:100]}...")
        
        # Initialize conversation history if new
        if conversation_id not in conversations:
            conversations[conversation_id] = []
            logger.info(f"New conversation started: {conversation_id}")
        
        # Add user message to history
        user_message = Message(
            role="user",
            content=request.message,
            timestamp=datetime.utcnow().isoformat()
        )
        conversations[conversation_id].append(user_message)
        
        model_id = os.getenv('BEDROCK_MODEL_ID', 'anthropic.claude-3-sonnet-20240229-v1:0')
        logger.info(f"Using Bedrock model: {model_id}")
        
        # Process with conversation history
        final_response, query_data = await process_with_history(
            model_id,
            conversation_id,
            conversations[conversation_id]
        )
        
        # Add assistant response to history with optional data
        assistant_msg = Message(
            role="assistant",
            content=final_response,
            timestamp=datetime.utcnow().isoformat(),
            data=query_data
        )
        conversations[conversation_id].append(assistant_msg)
        
        logger.info(f"Chat response generated successfully for conversation: {conversation_id}")
        
        return ChatResponse(
            conversation_id=conversation_id,
            response=final_response,
            history=conversations[conversation_id]
        )
    
    except Exception as e:
        # Log full exception details
        logger.error(f"Chat endpoint error - Conversation: {conversation_id}")
        logger.error(f"Exception type: {type(e).__name__}")
        logger.error(f"Exception message: {str(e)}")
        logger.error(f"Full traceback:\n{traceback.format_exc()}")
        
        # Return error to user in a friendly way
        error_message = f"I encountered an error while processing your request: {str(e)}"
        
        assistant_msg = Message(
            role="assistant",
            content=error_message,
            timestamp=datetime.utcnow().isoformat()
        )
        
        if conversation_id and conversation_id not in conversations:
            conversations[conversation_id] = [user_message] if user_message else []
        if conversation_id:
            conversations[conversation_id].append(assistant_msg)
        
        return ChatResponse(
            conversation_id=conversation_id or str(uuid.uuid4()),
            response=error_message,
            history=conversations.get(conversation_id, [])
        )

async def process_with_history(model_id: str, conversation_id: str, history: List[Message]) -> tuple[str, Optional[dict]]:
    """
    Process conversation with full history context
    Returns tuple of (response_text, query_data)
    """
    try:
        logger.info(f"Processing history for conversation: {conversation_id}")
        
        # Build prompt with conversation history
        prompt = build_conversation_prompt(history)
        
        # Get LLM response
        llm_response = await invoke_bedrock(model_id, prompt)
        logger.info(f"Received LLM response for conversation: {conversation_id}")
        
        # Parse the JSON response
        response_obj = extract_json_from_response(llm_response)
        
        # Handle based on response_type
        response_type = response_obj.get('response_type', 'NATURAL_LANGUAGE')
        content = response_obj.get('content')
        logger.info(f"Response type: {response_type} for conversation: {conversation_id}")
        
        if response_type == 'QUERY':
            # Store the generated query
            generated_query = content
            logger.info(f"Executing DynamoDB query for conversation: {conversation_id}")
            logger.debug(f"Query: {json.dumps(generated_query, indent=2)}")
            
            # Execute the DynamoDB query
            query_results = await execute_dynamodb_query(content)
            logger.info(f"Query executed, got {query_results.get('Count', 0)} results")
            
            # Add query results to conversation as system message
            system_message = Message(
                role="system",
                content=f"Query Results:\n{json.dumps(query_results, indent=2)}",
                timestamp=datetime.utcnow().isoformat()
            )
            conversations[conversation_id].append(system_message)
            
            # Call LLM again to analyze results
            logger.info(f"Requesting LLM analysis of query results for conversation: {conversation_id}")
            analysis_prompt = build_conversation_prompt(conversations[conversation_id])
            analysis_response = await invoke_bedrock(model_id, analysis_prompt)
            
            # Parse analysis response - always use content field only
            analysis_obj = extract_json_from_response(analysis_response)
            response_text = analysis_obj.get('content', '')
            
            # Log if content is empty
            if not response_text:
                logger.warning(f"Analysis response has empty content field for conversation: {conversation_id}")
            
            # Return response with query data and the original query
            # Store query in the results dict
            query_results['_generated_query'] = generated_query
            logger.info(f"Successfully processed query workflow for conversation: {conversation_id}")
            return response_text, query_results
        
        elif response_type == 'NATURAL_LANGUAGE':
            # Return the natural language response directly
            logger.info(f"Returning natural language response for conversation: {conversation_id}")
            return content, None
        
        else:
            # Unknown response type, return content as-is
            logger.warning(f"Unknown response type '{response_type}' for conversation: {conversation_id}")
            content_str = content if isinstance(content, str) else json.dumps(content)
            return content_str, None
            
    except Exception as e:
        logger.error(f"Error in process_with_history for conversation: {conversation_id}")
        logger.error(f"Exception type: {type(e).__name__}")
        logger.error(f"Exception message: {str(e)}")
        logger.error(f"Full traceback:\n{traceback.format_exc()}")
        raise

async def invoke_bedrock(model_id: str, messages: List[dict]) -> str:
    """
    Invoke AWS Bedrock with messages
    """
    response = bedrock_runtime.invoke_model(
        modelId=model_id,
        body=json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 2000,
            "messages": messages
        })
    )
    
    response_body = json.loads(response['body'].read())
    return response_body['content'][0]['text']

def build_conversation_prompt(history: List[Message]) -> List[dict]:
    """
    Build prompt with full conversation history
    """
    schema_text = json.dumps(DATABASE_SCHEMA, indent=2)
    
    # Add table name instruction if configured
    table_instruction = ""
    if DYNAMODB_TABLE_NAME:
        table_instruction = f"\n\n# Required Table Name\nYou MUST use the table name: {DYNAMODB_TABLE_NAME}"
    
    # Build the system context
    system_context = f"""{SYSTEM_PROMPT}

# Database Schema
{schema_text}{table_instruction}

# Instructions
Based on the conversation history below, respond with a JSON object indicating your next action.
Use conversation history to understand context and decide whether to query the database or provide a direct answer."""
    
    # Format messages for Bedrock - must alternate user/assistant
    messages = []
    
    # Start with system context + first user message combined
    first_user_content = system_context
    
    # Build conversation history with proper role alternation
    for msg in history:
        if msg.role == "user":
            # Append to existing user message or create new one
            if messages and messages[-1]["role"] == "user":
                # Merge with previous user message
                messages[-1]["content"] += f"\n\n{msg.content}"
            else:
                # Add as new user message
                if not messages:
                    # First message - include system context
                    messages.append({
                        "role": "user",
                        "content": f"{first_user_content}\n\n---\n\n{msg.content}"
                    })
                else:
                    messages.append({
                        "role": "user",
                        "content": msg.content
                    })
        elif msg.role == "system":
            # System messages get appended to the last message
            if messages and messages[-1]["role"] == "user":
                # Append to last user message
                messages[-1]["content"] += f"\n\n[SYSTEM INFO]\n{msg.content}"
            elif messages and messages[-1]["role"] == "assistant":
                # Need to start a new user message
                messages.append({
                    "role": "user",
                    "content": f"[SYSTEM INFO]\n{msg.content}"
                })
            else:
                # No previous message, start with system info
                messages.append({
                    "role": "user",
                    "content": f"{first_user_content}\n\n[SYSTEM INFO]\n{msg.content}"
                })
        elif msg.role == "assistant":
            # Add assistant message
            messages.append({
                "role": "assistant",
                "content": msg.content
            })
    
    # If we ended with an assistant message or no messages, we need to ensure there's a user message
    if not messages:
        messages.append({
            "role": "user",
            "content": first_user_content
        })
    elif messages[-1]["role"] == "assistant":
        # Bedrock expects conversation to end with user message in some cases
        # This is fine, the last user message is already there
        pass
    
    return messages

def extract_json_from_response(response: str) -> dict:
    """
    Extract JSON from LLM response, handling potential markdown formatting
    Always returns a dict with 'content' field
    """
    # Try to find JSON in markdown code blocks
    json_match = re.search(r'```(?:json)?\s*(\{.*?\})\s*```', response, re.DOTALL)
    if json_match:
        json_str = json_match.group(1)
    else:
        # Try to find raw JSON
        json_match = re.search(r'\{.*\}', response, re.DOTALL)
        if json_match:
            json_str = json_match.group(0)
        else:
            # If no JSON found, treat entire response as natural language
            logger.warning("No JSON found in LLM response, treating as natural language")
            return {
                "response_type": "NATURAL_LANGUAGE",
                "content": response.strip()
            }
    
    try:
        parsed = json.loads(json_str)
        # Ensure the parsed object has a content field
        if 'content' not in parsed:
            logger.warning("Parsed JSON missing 'content' field, using empty string")
            parsed['content'] = ""
        return parsed
    except json.JSONDecodeError as e:
        # If JSON parsing fails, return as natural language
        logger.error(f"JSON parsing failed: {str(e)}")
        return {
            "response_type": "NATURAL_LANGUAGE",
            "content": response.strip()
        }

async def execute_dynamodb_query(query: dict) -> dict:
    """
    Execute a DynamoDB query and return results
    """
    operation = query.get('operation', 'Query')
    table_name = query.get('table_name')
    
    try:
        if not table_name:
            raise ValueError("table_name is required in query")
        
        logger.info(f"Executing DynamoDB {operation} on table: {table_name}")
        
        # Build DynamoDB request parameters
        params = {
            'TableName': table_name
        }
        
        # Add optional parameters
        if 'key_condition_expression' in query:
            params['KeyConditionExpression'] = query['key_condition_expression']
        
        if 'expression_attribute_values' in query:
            params['ExpressionAttributeValues'] = query['expression_attribute_values']
        
        if 'filter_expression' in query:
            params['FilterExpression'] = query['filter_expression']
        
        if 'projection_expression' in query:
            params['ProjectionExpression'] = query['projection_expression']
        
        if 'index_name' in query:
            params['IndexName'] = query['index_name']
            logger.info(f"Using index: {query['index_name']}")
        
        if 'limit' in query:
            params['Limit'] = query['limit']
        
        if 'expression_attribute_names' in query:
            params['ExpressionAttributeNames'] = query['expression_attribute_names']
        
        # Execute appropriate operation
        if operation == 'Query':
            response = dynamodb.query(**params)
        elif operation == 'Scan':
            response = dynamodb.scan(**params)
        elif operation == 'GetItem':
            if 'Key' in query:
                params['Key'] = query['Key']
            response = dynamodb.get_item(**params)
        elif operation == 'BatchGetItem':
            if 'RequestItems' in query:
                response = dynamodb.batch_get_item(RequestItems=query['RequestItems'])
            else:
                raise ValueError("BatchGetItem requires RequestItems")
        else:
            raise ValueError(f"Unsupported operation: {operation}")
        
        logger.info(f"DynamoDB {operation} completed successfully. Count: {response.get('Count', 0)}, ScannedCount: {response.get('ScannedCount', 0)}")
        return response
    
    except Exception as e:
        logger.error(f"DynamoDB query execution failed")
        logger.error(f"Operation: {operation}, Table: {table_name}")
        logger.error(f"Exception type: {type(e).__name__}")
        logger.error(f"Exception message: {str(e)}")
        logger.error(f"Full traceback:\n{traceback.format_exc()}")
        
        # Return error with the original query included
        return {
            "Error": str(e),
            "Message": "Failed to execute DynamoDB query",
            "_generated_query": query  # Include the query that failed
        }

@app.get("/conversation/{conversation_id}", response_model=ConversationResponse)
async def get_conversation(conversation_id: str):
    """
    Retrieve conversation history
    """
    if conversation_id not in conversations:
        raise HTTPException(status_code=404, detail="Conversation not found")
    
    return ConversationResponse(
        conversation_id=conversation_id,
        history=conversations[conversation_id]
    )

@app.delete("/conversation/{conversation_id}")
async def delete_conversation(conversation_id: str):
    """
    Delete a conversation (start new)
    """
    if conversation_id in conversations:
        del conversations[conversation_id]
    return {"message": "Conversation deleted"}

@app.get("/schema")
async def get_schema():
    """
    Return the current database schema
    """
    return DATABASE_SCHEMA

@app.get("/reload-config")
async def reload_config():
    """
    Reload system prompt and schema from files
    """
    global SYSTEM_PROMPT, DATABASE_SCHEMA
    SYSTEM_PROMPT = load_system_prompt()
    DATABASE_SCHEMA = load_schema()
    return {
        "message": "Configuration reloaded",
        "schema_loaded": bool(DATABASE_SCHEMA)
    }

@app.post("/presigned-url")
async def get_presigned_url(request: dict):
    """
    Generate a presigned URL for an S3 object
    """
    s3_url = request.get('url')
    
    if not s3_url:
        logger.warning("Presigned URL request missing URL parameter")
        raise HTTPException(status_code=400, detail="URL is required")
    
    logger.info(f"Presigned URL request for: {s3_url}")
    
    # Parse S3 URL to extract bucket and key
    # Format: s3://bucket/key or https://bucket.s3.region.amazonaws.com/key
    try:
        if s3_url.startswith('s3://'):
            # s3://bucket/key format
            parts = s3_url[5:].split('/', 1)
            bucket = parts[0]
            key = parts[1] if len(parts) > 1 else ''
        elif 's3.amazonaws.com' in s3_url or 's3-' in s3_url:
            # https://bucket.s3.region.amazonaws.com/key or
            # https://s3.region.amazonaws.com/bucket/key
            from urllib.parse import urlparse
            parsed = urlparse(s3_url)
            
            if parsed.netloc.endswith('.s3.amazonaws.com') or '.s3-' in parsed.netloc or '.s3.' in parsed.netloc:
                # bucket.s3.region.amazonaws.com format
                bucket = parsed.netloc.split('.s3')[0]
                key = parsed.path.lstrip('/')
            else:
                # s3.region.amazonaws.com/bucket/key format
                path_parts = parsed.path.lstrip('/').split('/', 1)
                bucket = path_parts[0]
                key = path_parts[1] if len(path_parts) > 1 else ''
        else:
            logger.error(f"Invalid S3 URL format: {s3_url}")
            raise HTTPException(status_code=400, detail="Invalid S3 URL format")
        
        logger.info(f"Generating presigned URL for bucket: {bucket}, key: {key}")
        
        # Generate presigned URL (expires in 1 hour)
        presigned_url = s3.generate_presigned_url(
            'get_object',
            Params={'Bucket': bucket, 'Key': key},
            ExpiresIn=3600
        )
        
        logger.info(f"Successfully generated presigned URL for: s3://{bucket}/{key}")
        return {"presigned_url": presigned_url}
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to generate presigned URL for: {s3_url}")
        logger.error(f"Exception type: {type(e).__name__}")
        logger.error(f"Exception message: {str(e)}")
        logger.error(f"Full traceback:\n{traceback.format_exc()}")
        
        error_message = str(e)
        if 'AccessDenied' in error_message or 'Forbidden' in error_message:
            raise HTTPException(
                status_code=403,
                detail="Access denied: The application does not have permission to access this S3 object"
            )
        else:
            raise HTTPException(
                status_code=500,
                detail=f"Failed to generate presigned URL: {error_message}"
            )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
