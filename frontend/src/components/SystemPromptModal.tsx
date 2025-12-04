import { useEffect, useState } from 'react';

interface SystemPromptModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export default function SystemPromptModal({ isOpen, onClose }: SystemPromptModalProps) {
  const [systemPrompt, setSystemPrompt] = useState('');
  const [originalPrompt, setOriginalPrompt] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000';

  useEffect(() => {
    if (isOpen) {
      fetchSystemPrompt();
    }
  }, [isOpen]);

  const fetchSystemPrompt = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const response = await fetch(`${apiUrl}/system-prompt`);
      if (!response.ok) {
        throw new Error('Failed to fetch system prompt');
      }
      const data = await response.json();
      setSystemPrompt(data.system_prompt);
      setOriginalPrompt(data.system_prompt);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load system prompt');
    } finally {
      setIsLoading(false);
    }
  };

  const handleSave = async () => {
    setIsSaving(true);
    setError(null);
    setSuccessMessage(null);
    try {
      const response = await fetch(`${apiUrl}/system-prompt`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          system_prompt: systemPrompt,
        }),
      });

      if (!response.ok) {
        throw new Error('Failed to update system prompt');
      }

      setOriginalPrompt(systemPrompt);
      setSuccessMessage('System prompt updated successfully!');
      setTimeout(() => {
        setSuccessMessage(null);
      }, 3000);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to save system prompt');
    } finally {
      setIsSaving(false);
    }
  };

  const handleReset = () => {
    setSystemPrompt(originalPrompt);
    setError(null);
    setSuccessMessage(null);
  };

  const hasChanges = systemPrompt !== originalPrompt;

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-2xl max-w-4xl w-full max-h-[90vh] flex flex-col shadow-2xl">
        {/* Header */}
        <div className="bg-wu-gradient p-6 rounded-t-2xl flex justify-between items-center">
          <h2 className="text-2xl font-bold text-wu-black">System Prompt Editor</h2>
          <button
            onClick={onClose}
            className="text-wu-black hover:text-wu-gray transition-colors"
            aria-label="Close modal"
          >
            <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-6">
          {isLoading ? (
            <div className="flex items-center justify-center h-64">
              <div className="flex space-x-2">
                <div className="w-3 h-3 bg-wu-yellow rounded-full animate-bounce"></div>
                <div className="w-3 h-3 bg-wu-yellow rounded-full animate-bounce" style={{ animationDelay: '0.2s' }}></div>
                <div className="w-3 h-3 bg-wu-yellow rounded-full animate-bounce" style={{ animationDelay: '0.4s' }}></div>
              </div>
            </div>
          ) : (
            <>
              {error && (
                <div className="mb-4 p-4 bg-red-50 border border-red-200 rounded-lg">
                  <div className="flex items-center">
                    <svg className="w-5 h-5 text-red-500 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    <span className="text-red-700 font-medium">{error}</span>
                  </div>
                </div>
              )}

              {successMessage && (
                <div className="mb-4 p-4 bg-green-50 border border-green-200 rounded-lg">
                  <div className="flex items-center">
                    <svg className="w-5 h-5 text-green-500 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    <span className="text-green-700 font-medium">{successMessage}</span>
                  </div>
                </div>
              )}

              <div className="mb-4">
                <label htmlFor="systemPrompt" className="block text-sm font-semibold text-wu-black mb-2">
                  System Prompt
                </label>
                <textarea
                  id="systemPrompt"
                  value={systemPrompt}
                  onChange={(e) => setSystemPrompt(e.target.value)}
                  className="w-full h-96 p-4 border-2 border-gray-200 rounded-lg focus:outline-none focus:border-wu-yellow focus:ring-2 focus:ring-wu-yellow focus:ring-opacity-50 transition-all duration-300 font-mono text-sm"
                  placeholder="Enter system prompt..."
                  disabled={isSaving}
                />
              </div>

              <div className="text-sm text-wu-gray mb-4">
                <p className="mb-2">
                  <strong>Note:</strong> Changes to the system prompt will affect how the AI responds to user queries.
                  The system prompt is loaded at startup and after updates.
                </p>
                <p>
                  Character count: {systemPrompt.length}
                </p>
              </div>
            </>
          )}
        </div>

        {/* Footer */}
        <div className="border-t border-gray-200 p-6 bg-gray-50 rounded-b-2xl">
          <div className="flex justify-between items-center">
            <div>
              {hasChanges && !isSaving && (
                <button
                  onClick={handleReset}
                  className="px-4 py-2 text-wu-gray hover:text-wu-black transition-colors font-medium"
                >
                  Reset Changes
                </button>
              )}
            </div>
            <div className="flex space-x-3">
              <button
                onClick={onClose}
                className="px-6 py-2.5 border-2 border-gray-300 text-wu-gray rounded-lg font-semibold hover:border-wu-black hover:text-wu-black transition-all duration-300"
                disabled={isSaving}
              >
                Close
              </button>
              <button
                onClick={handleSave}
                disabled={!hasChanges || isSaving}
                className="bg-wu-gradient text-wu-black px-6 py-2.5 rounded-lg font-semibold hover:shadow-lg disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-300 transform hover:scale-105 disabled:hover:scale-100"
              >
                {isSaving ? (
                  <span className="flex items-center">
                    <svg className="animate-spin -ml-1 mr-2 h-4 w-4 text-wu-black" fill="none" viewBox="0 0 24 24">
                      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                    </svg>
                    Saving...
                  </span>
                ) : (
                  'Save Changes'
                )}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
