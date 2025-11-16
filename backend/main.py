from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import boto3
import json
import os
from datetime import datetime
import uuid

app = FastAPI(title="Chatbot API")

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# AWS Bedrock client
bedrock_runtime = boto3.client(
    service_name='bedrock-runtime',
    region_name=os.getenv('AWS_REGION', 'us-east-1')
)

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
    return {"message": "Chatbot API is running"}

@app.get("/health")
async def health():
    return {"status": "healthy"}

@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """
    Process a chat message and return a response from AWS Bedrock
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
        
        # Build the prompt with conversation history
        prompt = build_prompt(conversations[conversation_id])
        
        # Call AWS Bedrock
        model_id = os.getenv('BEDROCK_MODEL_ID', 'anthropic.claude-3-sonnet-20240229-v1:0')
        
        response = bedrock_runtime.invoke_model(
            modelId=model_id,
            body=json.dumps({
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": 1000,
                "messages": format_messages_for_bedrock(conversations[conversation_id])
            })
        )
        
        # Parse response
        response_body = json.loads(response['body'].read())
        assistant_message = response_body['content'][0]['text']
        
        # Add assistant response to history
        assistant_msg = Message(
            role="assistant",
            content=assistant_message,
            timestamp=datetime.utcnow().isoformat()
        )
        conversations[conversation_id].append(assistant_msg)
        
        return ChatResponse(
            conversation_id=conversation_id,
            response=assistant_message,
            history=conversations[conversation_id]
        )
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

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

def build_prompt(history: List[Message]) -> str:
    """
    Build a prompt string from conversation history
    """
    prompt = ""
    for msg in history:
        if msg.role == "user":
            prompt += f"Human: {msg.content}\n\n"
        else:
            prompt += f"Assistant: {msg.content}\n\n"
    return prompt

def format_messages_for_bedrock(history: List[Message]) -> List[dict]:
    """
    Format messages for Bedrock API
    """
    messages = []
    for msg in history:
        messages.append({
            "role": msg.role,
            "content": msg.content
        })
    return messages

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
