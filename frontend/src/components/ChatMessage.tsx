interface Message {
  role: 'user' | 'assistant';
  content: string;
  timestamp?: string;
  data?: any;
}

interface ChatMessageProps {
  message: Message;
  onViewData?: (data: any) => void;
}

export default function ChatMessage({ message, onViewData }: ChatMessageProps) {
  const isUser = message.role === 'user';
  const hasData = message.data && message.data.Items && message.data.Items.length > 0;

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
          
          {hasData && onViewData && (
            <button
              onClick={() => onViewData(message.data)}
              className="mt-3 px-4 py-2 bg-wu-gradient text-wu-black font-semibold rounded-lg shadow-md hover:shadow-lg transition-all duration-200 hover:scale-105 flex items-center space-x-2"
            >
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
                  d="M3 10h18M3 14h18m-9-4v8m-7 0h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"
                />
              </svg>
              <span>View Data ({message.data.Items.length} items)</span>
            </button>
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
