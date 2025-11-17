interface Message {
  role: 'user' | 'assistant';
  content: string;
  timestamp?: string;
  data?: any;
  query?: any;
}

interface ChatMessageProps {
  message: Message;
  onViewData?: (data: any) => void;
  onViewQuery?: (query: any) => void;
  onViewError?: (error: any) => void;
}

export default function ChatMessage({ message, onViewData, onViewQuery, onViewError }: ChatMessageProps) {
  const isUser = message.role === 'user';
  const hasData = message.data && message.data.Items && message.data.Items.length > 0;
  const hasQuery = message.data && message.data._generated_query;
  const hasError = message.data && message.data.query_error;

  return (
    <div className={`flex items-start space-x-3 ${isUser ? 'flex-row-reverse space-x-reverse' : ''}`}>
      <div className="flex-shrink-0">
        <div
          className={`w-10 h-10 rounded-full flex items-center justify-center shadow-md transition-transform duration-300 hover:scale-110 ${
            isUser ? 'bg-wu-black' : 'bg-wu-gradient'
          }`}
        >
          {isUser ? (
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
                d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
              />
            </svg>
          ) : (
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
          )}
        </div>
      </div>
      <div className="flex-1 max-w-3xl">
        <div
          className={`rounded-2xl p-4 shadow-md transition-all duration-300 hover:shadow-lg ${
            isUser
              ? 'bg-white text-wu-gray border border-gray-200'
              : 'bg-white text-wu-black border-2 border-wu-gold'
          }`}
        >
          <p className="whitespace-pre-wrap break-words leading-relaxed font-medium">{message.content}</p>
          
          {(hasData || hasQuery || hasError) && (
            <div className="flex flex-wrap gap-2 mt-3">
              {hasQuery && onViewQuery && (
                <button
                  onClick={() => onViewQuery(message.data._generated_query)}
                  className="px-3 py-1.5 bg-gray-100 text-gray-700 text-sm font-medium rounded-md shadow-sm hover:shadow-md transition-all duration-200 hover:scale-105 flex items-center space-x-1.5 border border-gray-300"
                >
                  <svg
                    className="w-4 h-4"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"
                    />
                  </svg>
                  <span>View Query</span>
                </button>
              )}
              {hasError && onViewError && (
                <button
                  onClick={() => onViewError(message.data.query_error)}
                  className="px-3 py-1.5 bg-red-100 text-red-700 text-sm font-medium rounded-md shadow-sm hover:shadow-md transition-all duration-200 hover:scale-105 flex items-center space-x-1.5 border border-red-300"
                >
                  <svg
                    className="w-4 h-4"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                    />
                  </svg>
                  <span>View Error</span>
                </button>
              )}
              {hasData && onViewData && (
                <button
                  onClick={() => onViewData(message.data)}
                  className="px-3 py-1.5 bg-wu-gradient text-wu-black text-sm font-semibold rounded-md shadow-sm hover:shadow-md transition-all duration-200 hover:scale-105 flex items-center space-x-1.5"
                >
                  <svg
                    className="w-4 h-4"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M3 10h18M3 14h18m-9-4v8m-7 0h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"
                    />
                  </svg>
                  <span>View Data ({message.data.Items.length})</span>
                </button>
              )}
            </div>
          )}
          
          {message.timestamp && (
            <div className="flex items-center mt-2 pt-2 border-t border-opacity-20 border-current">
              <svg
                className={`w-3 h-3 mr-1 ${isUser ? 'text-wu-black opacity-70' : 'text-gray-400'}`}
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
              <p className={`text-xs ${isUser ? 'text-wu-black opacity-70' : 'text-gray-400'}`}>
                {new Date(message.timestamp).toLocaleTimeString([], { 
                  hour: '2-digit', 
                  minute: '2-digit' 
                })}
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
