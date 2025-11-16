from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import boto3
import json
import os
from datetime import datetime
import uuid
import re

app = FastAPI(title="Chatbot API")

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

# Load system prompt and schema
def load_system_prompt():
    """Load the system prompt from file"""
    try:
        with open('system_prompt.txt', 'r') as f:
            return f.read()
    except FileNotFoundError:
        return "You are a helpful AI assistant that helps users query and analyze data."

def load_schema():
    """Load the database schema from file"""
    try:
        with open('schema.json', 'r') as f:
            return json.load(f)
    except FileNotFoundError:
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
    Process a chat message using DynamoDB query workflow:
    1. Generate DynamoDB query from user question
    2. Execute query
    3. Analyze results and respond
    """
    try:
        # Generate or use existing conversation ID
        conversation_id = request.conversation_id or str(uuid.uuid4())
        
        # Initialize conversation history if new
        if conversation_id not in conversations:
            conversations[conversation_id] = []
        
        # Add user message to history
        user_message = Message(
            role="user",
            content=request.message,
            timestamp=datetime.utcnow().isoformat()
        )
        conversations[conversation_id].append(user_message)
        
        model_id = os.getenv('BEDROCK_MODEL_ID', 'anthropic.claude-3-sonnet-20240229-v1:0')
        
        # Step 1: Generate DynamoDB query
        query_generation_prompt = build_query_generation_prompt(request.message)
        query_json = await invoke_bedrock(model_id, query_generation_prompt)
        
        # Parse the query from response
        dynamodb_query = extract_json_from_response(query_json)
        
        # Step 2: Execute DynamoDB query
        query_results = await execute_dynamodb_query(dynamodb_query)
        
        # Step 3: Analyze results
        analysis_prompt = build_analysis_prompt(
            request.message, 
            dynamodb_query,
            query_results
        )
        final_response = await invoke_bedrock(model_id, analysis_prompt)
        
        # Add assistant response to history
        assistant_msg = Message(
            role="assistant",
            content=final_response,
            timestamp=datetime.utcnow().isoformat()
        )
        conversations[conversation_id].append(assistant_msg)
        
        return ChatResponse(
            conversation_id=conversation_id,
            response=final_response,
            history=conversations[conversation_id]
        )
    
    except Exception as e:
        # Return error to user in a friendly way
        error_message = f"I encountered an error while processing your request: {str(e)}"
        
        assistant_msg = Message(
            role="assistant",
            content=error_message,
            timestamp=datetime.utcnow().isoformat()
        )
        
        if conversation_id not in conversations:
            conversations[conversation_id] = [user_message]
        conversations[conversation_id].append(assistant_msg)
        
        return ChatResponse(
            conversation_id=conversation_id,
            response=error_message,
            history=conversations[conversation_id]
        )

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

def build_query_generation_prompt(user_question: str) -> List[dict]:
    """
    Build prompt for query generation step
    """
    schema_text = json.dumps(DATABASE_SCHEMA, indent=2)
    
    # Add table name instruction if configured
    table_instruction = ""
    if DYNAMODB_TABLE_NAME:
        table_instruction = f"\n\n# Required Table Name\nYou MUST use the table name: {DYNAMODB_TABLE_NAME}"
    
    return [
        {
            "role": "user",
            "content": f"""{SYSTEM_PROMPT}

# Database Schema
{schema_text}{table_instruction}

# User Question
{user_question}

# Your Task
Generate a DynamoDB query that will retrieve data to answer the user's question. Respond ONLY with the JSON query object, no explanations or markdown formatting."""
        }
    ]

def build_analysis_prompt(user_question: str, query: dict, results: dict) -> List[dict]:
    """
    Build prompt for analysis step
    """
    return [
        {
            "role": "user",
            "content": f"""{SYSTEM_PROMPT}

# User's Original Question
{user_question}

# DynamoDB Query That Was Executed
{json.dumps(query, indent=2)}

# Query Results
{json.dumps(results, indent=2)}

# Your Task
Analyze the query results and provide a clear, helpful answer to the user's original question. Present the information in a user-friendly format."""
        }
    ]

def extract_json_from_response(response: str) -> dict:
    """
    Extract JSON from LLM response, handling potential markdown formatting
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
            json_str = response
    
    return json.loads(json_str)

async def execute_dynamodb_query(query: dict) -> dict:
    """
    Execute a DynamoDB query and return results
    """
    operation = query.get('operation', 'Query')
    table_name = query.get('table_name')
    
    if not table_name:
        raise ValueError("table_name is required in query")
    
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
    
    if 'limit' in query:
        params['Limit'] = query['limit']
    
    if 'expression_attribute_names' in query:
        params['ExpressionAttributeNames'] = query['expression_attribute_names']
    
    # Execute appropriate operation
    try:
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
        
        return response
    
    except Exception as e:
        return {
            "Error": str(e),
            "Message": "Failed to execute DynamoDB query"
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

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
