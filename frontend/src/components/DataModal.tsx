'use client';

interface DataModalProps {
  isOpen: boolean;
  onClose: () => void;
  data: any;
}

export default function DataModal({ isOpen, onClose, data }: DataModalProps) {
  if (!isOpen || !data || !data.Items) return null;

  // Extract column names from first item
  const items = data.Items;
  const columns = items.length > 0 ? Object.keys(items[0]) : [];

  // Helper to extract value from DynamoDB format
  const extractValue = (obj: any): string => {
    if (!obj) return '';
    if (obj.S) return obj.S;
    if (obj.N) return obj.N;
    if (obj.BOOL !== undefined) return obj.BOOL.toString();
    if (obj.L) return JSON.stringify(obj.L);
    if (obj.M) return JSON.stringify(obj.M);
    if (obj.SS) return obj.SS.join(', ');
    if (obj.NS) return obj.NS.join(', ');
    return JSON.stringify(obj);
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg shadow-2xl max-w-6xl w-full max-h-[90vh] flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-200 bg-wu-gradient">
          <div>
            <h2 className="text-2xl font-bold text-wu-black">Query Results</h2>
            <p className="text-sm text-wu-black opacity-75 mt-1">
              {items.length} {items.length === 1 ? 'item' : 'items'} found
            </p>
          </div>
          <button
            onClick={onClose}
            className="text-wu-black hover:bg-wu-black hover:text-wu-yellow rounded-full p-2 transition-colors"
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

        {/* Table Container */}
        <div className="flex-1 overflow-auto p-6">
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200 border border-gray-300">
              <thead className="bg-gray-100 sticky top-0">
                <tr>
                  {columns.map((column) => (
                    <th
                      key={column}
                      className="px-4 py-3 text-left text-xs font-bold text-wu-black uppercase tracking-wider border-r border-gray-300 last:border-r-0"
                    >
                      {column}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {items.map((item: any, idx: number) => (
                  <tr key={idx} className="hover:bg-gray-50 transition-colors">
                    {columns.map((column) => (
                      <td
                        key={column}
                        className="px-4 py-3 text-sm text-gray-900 border-r border-gray-200 last:border-r-0"
                      >
                        <div className="max-w-xs truncate" title={extractValue(item[column])}>
                          {extractValue(item[column])}
                        </div>
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between p-6 border-t border-gray-200 bg-gray-50">
          <div className="text-sm text-gray-600">
            {data.Count && <span>Count: {data.Count}</span>}
            {data.ScannedCount && <span className="ml-4">Scanned: {data.ScannedCount}</span>}
          </div>
          <button
            onClick={onClose}
            className="px-6 py-2 bg-wu-black text-wu-yellow font-semibold rounded-lg shadow-md hover:shadow-lg transition-all duration-200 hover:scale-105"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
}
