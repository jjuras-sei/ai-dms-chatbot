'use client';

import { useState, useRef, useEffect } from 'react';
import ChatMessage from '../components/ChatMessage';
import DataModal from '../components/DataModal';
import QueryModal from '../components/QueryModal';
import axios from 'axios';

interface Message {
  role: 'user' | 'assistant';
  content: string;
  timestamp?: string;
  data?: any;
}

export default function Home() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [conversationId, setConversationId] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [modalData, setModalData] = useState<any>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [queryData, setQueryData] = useState<any>(null);
  const [isQueryModalOpen, setIsQueryModalOpen] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000';
  const contentMessage = process.env.NEXT_PUBLIC_CONTENT_MESSAGE || 'Powered by AWS Bedrock';
  const welcomeMessage = process.env.NEXT_PUBLIC_WELCOME_MESSAGE || 'Start a conversation and ask me anything';

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!input.trim() || isLoading) return;

    const userMessage: Message = {
      role: 'user',
      content: input,
      timestamp: new Date().toISOString()
    };

    setMessages(prev => [...prev, userMessage]);
    setInput('');
    setIsLoading(true);

    try {
      const response = await axios.post(`${apiUrl}/chat`, {
        conversation_id: conversationId,
        message: input
      });

      setConversationId(response.data.conversation_id);
      
      // Get the latest assistant message from history (includes data)
      const history = response.data.history;
      const latestAssistant = history[history.length - 1];
      
      const assistantMessage: Message = {
        role: 'assistant',
        content: latestAssistant.content,
        timestamp: latestAssistant.timestamp,
        data: latestAssistant.data
      };

      setMessages(prev => [...prev, assistantMessage]);
    } catch (error) {
      console.error('Error sending message:', error);
      const errorMessage: Message = {
        role: 'assistant',
        content: 'Sorry, there was an error processing your request. Please try again.',
        timestamp: new Date().toISOString()
      };
      setMessages(prev => [...prev, errorMessage]);
    } finally {
      setIsLoading(false);
    }
  };

  const handleNewConversation = () => {
    setMessages([]);
    setConversationId(null);
    setInput('');
  };

  const handleViewData = (data: any) => {
    setModalData(data);
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setModalData(null);
  };

  const handleViewQuery = (query: any) => {
    setQueryData(query);
    setIsQueryModalOpen(true);
  };

  const handleCloseQueryModal = () => {
    setIsQueryModalOpen(false);
    setQueryData(null);
  };

  return (
    <main className="flex min-h-screen flex-col bg-wu-light-gray">
      <div className="w-full h-screen flex flex-col">
        {/* Header with Western Union Styling */}
        <div className="bg-wu-gradient shadow-lg">
          <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-4 flex justify-between items-center">
            <div className="flex items-center space-x-3">
              <div className="w-10 h-10 bg-wu-black rounded-lg flex items-center justify-center">
                <svg
                  className="w-6 h-6 text-wu-yellow"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-5l-5 5v-5z"
                  />
                </svg>
              </div>
              <div>
                <h1 className="text-2xl font-bold text-wu-black">AI DMS Chatbot</h1>
                <p className="text-xs text-wu-gray">{contentMessage}</p>
              </div>
            </div>
            {conversationId && (
              <button
                onClick={handleNewConversation}
                className="bg-wu-black text-wu-yellow px-5 py-2.5 rounded-lg font-semibold hover:bg-wu-dark-gray transition-all duration-300 transform hover:scale-105 shadow-md hover:shadow-lg"
              >
                New Question
              </button>
            )}
          </div>
        </div>

        {/* Messages Area with reduced side margins */}
        <div className="flex-1 overflow-y-auto">
          <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
            {messages.length === 0 ? (
              <div className="flex items-center justify-center h-full animate-fade-in">
                <div className="text-center">
                  <div className="inline-block p-6 bg-white rounded-2xl shadow-lg mb-6 animate-bounce-subtle">
                    <svg
                      className="mx-auto h-16 w-16 text-wu-yellow"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={1.5}
                        d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
                      />
                    </svg>
                  </div>
                  <h3 className="text-2xl font-bold text-wu-black mb-2">Welcome!</h3>
                  <p className="text-wu-gray text-lg">{welcomeMessage}</p>
                </div>
              </div>
            ) : (
              <div className="space-y-4">
                {messages.map((message, index) => (
                  <div key={index} className="animate-slide-up">
                    <ChatMessage 
                      message={message} 
                      onViewData={handleViewData}
                      onViewQuery={handleViewQuery}
                    />
                  </div>
                ))}
                {isLoading && (
                  <div className="flex items-start space-x-3 animate-slide-up">
                    <div className="flex-shrink-0">
                      <div className="w-10 h-10 rounded-full bg-wu-gradient flex items-center justify-center shadow-md">
                        <svg
                          className="w-6 h-6 text-wu-black"
                          fill="none"
                          viewBox="0 0 24 24"
                          stroke="currentColor"
                        >
                          <path
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            strokeWidth={2}
                            d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
                          />
                        </svg>
                      </div>
                    </div>
                    <div className="bg-white rounded-2xl p-4 shadow-md">
                      <div className="flex space-x-2">
                        <div className="w-2.5 h-2.5 bg-wu-yellow rounded-full animate-bounce"></div>
                        <div className="w-2.5 h-2.5 bg-wu-yellow rounded-full animate-bounce" style={{ animationDelay: '0.2s' }}></div>
                        <div className="w-2.5 h-2.5 bg-wu-yellow rounded-full animate-bounce" style={{ animationDelay: '0.4s' }}></div>
                      </div>
                    </div>
                  </div>
                )}
                <div ref={messagesEndRef} />
              </div>
            )}
          </div>
        </div>

        {/* Input Area with Western Union Styling */}
        <div className="border-t border-gray-200 bg-white shadow-lg">
          <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
            <form onSubmit={handleSubmit} className="flex space-x-3">
              <div className="flex-1 relative">
                <input
                  type="text"
                  value={input}
                  onChange={(e) => setInput(e.target.value)}
                  placeholder="Type your message..."
                  className="w-full border-2 border-gray-200 rounded-xl px-5 py-3.5 focus:outline-none focus:border-wu-yellow focus:ring-2 focus:ring-wu-yellow focus:ring-opacity-50 transition-all duration-300 text-wu-gray placeholder-gray-400 shadow-sm"
                  disabled={isLoading}
                />
                {input && (
                  <div className="absolute right-3 top-1/2 transform -translate-y-1/2">
                    <div className="w-2 h-2 bg-wu-yellow rounded-full animate-pulse"></div>
                  </div>
                )}
              </div>
              <button
                type="submit"
                disabled={isLoading || !input.trim()}
                className="bg-wu-gradient text-wu-black px-8 py-3.5 rounded-xl font-bold hover:shadow-lg disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-300 transform hover:scale-105 disabled:hover:scale-100 shadow-md"
              >
                <div className="flex items-center space-x-2">
                  <span>Send</span>
                  <svg
                    className="w-5 h-5"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M14 5l7 7m0 0l-7 7m7-7H3"
                    />
                  </svg>
                </div>
              </button>
            </form>
          </div>
        </div>
      </div>

      {/* Data Modal */}
      <DataModal 
        isOpen={isModalOpen}
        onClose={handleCloseModal}
        data={modalData}
      />

      {/* Query Modal */}
      <QueryModal 
        isOpen={isQueryModalOpen}
        onClose={handleCloseQueryModal}
        query={queryData}
      />
    </main>
  );
}
