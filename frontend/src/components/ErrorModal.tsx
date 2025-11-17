'use client';

interface ErrorModalProps {
  isOpen: boolean;
  onClose: () => void;
  error: any;
}

export default function ErrorModal({ isOpen, onClose, error }: ErrorModalProps) {
  if (!isOpen || !error) return null;

  return (
    <div 
      className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4"
      onClick={onClose}
    >
      <div 
        className="bg-white rounded-lg shadow-2xl max-w-4xl w-full max-h-[90vh] flex flex-col"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-200 bg-red-50">
          <div>
            <h2 className="text-2xl font-bold text-red-900">Query Error Details</h2>
            <p className="text-sm text-red-700 mt-1">
              Full error information for debugging
            </p>
          </div>
          <button
            onClick={onClose}
            className="text-red-700 hover:bg-red-100 rounded-full p-2 transition-colors"
          >
            <svg
              className="w-6 h-6"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M6 18L18 6M6 6l12 12"
              />
            </svg>
          </button>
        </div>

        {/* Error Content */}
        <div className="flex-1 overflow-auto p-6 space-y-4">
          {/* Exception Type */}
          <div className="p-4 bg-red-50 border-l-4 border-red-400 rounded">
            <h3 className="font-semibold text-red-900 mb-2">Exception Type:</h3>
            <p className="text-sm text-red-800 font-mono">{error.exception_type || 'N/A'}</p>
          </div>

          {/* Exception Message */}
          <div className="p-4 bg-orange-50 border-l-4 border-orange-400 rounded">
            <h3 className="font-semibold text-orange-900 mb-2">Exception Message:</h3>
            <p className="text-sm text-orange-800">{error.exception_message || 'N/A'}</p>
          </div>

          {/* Query Details */}
          <div className="p-4 bg-blue-50 border-l-4 border-blue-400 rounded">
            <h3 className="font-semibold text-blue-900 mb-2">Query Details:</h3>
            <ul className="text-sm text-blue-800 space-y-1">
              <li><strong>Operation:</strong> {error.operation || 'N/A'}</li>
              <li><strong>Table:</strong> {error.table_name || 'N/A'}</li>
            </ul>
          </div>

          {/* Full Traceback */}
          <div className="p-4 bg-gray-50 border-l-4 border-gray-400 rounded">
            <h3 className="font-semibold text-gray-900 mb-2">Full Traceback:</h3>
            <pre className="text-xs text-gray-800 overflow-x-auto whitespace-pre-wrap font-mono bg-white p-3 rounded border border-gray-200">
              {error.traceback || 'No traceback available'}
            </pre>
          </div>
        </div>

        {/* Footer */}
        <div className="flex items-center justify-end p-6 border-t border-gray-200 bg-gray-50">
          <button
            onClick={onClose}
            className="px-6 py-2 bg-red-600 text-white font-semibold rounded-lg shadow-md hover:bg-red-700 hover:shadow-lg transition-all duration-200 hover:scale-105"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
}
