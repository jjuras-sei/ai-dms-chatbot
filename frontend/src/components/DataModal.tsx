'use client';

import { useState } from 'react';
import axios from 'axios';

interface DataModalProps {
  isOpen: boolean;
  onClose: () => void;
  data: any;
}

export default function DataModal({ isOpen, onClose, data }: DataModalProps) {
  const [loadingUrl, setLoadingUrl] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  if (!isOpen || !data || !data.Items) return null;

  // Extract column names from first item
  const items = data.Items;
  const columns = items.length > 0 ? Object.keys(items[0]) : [];

  const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000';

  // Helper to check if value is an S3 URL
  const isS3Url = (value: string): boolean => {
    return value.startsWith('s3://') || 
           value.includes('s3.amazonaws.com') || 
           value.includes('.s3-') ||
           value.includes('.s3.');
  };

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

  // Handle S3 URL click
  const handleS3Click = async (s3Url: string) => {
    setLoadingUrl(s3Url);
    setError(null);

    try {
      const response = await axios.post(`${apiUrl}/presigned-url`, {
        url: s3Url
      });

      // Open presigned URL in new tab
      window.open(response.data.presigned_url, '_blank');
    } catch (err: any) {
      const errorMessage = err.response?.data?.detail || 'Failed to access file';
      setError(errorMessage);
      setTimeout(() => setError(null), 5000); // Clear error after 5 seconds
    } finally {
      setLoadingUrl(null);
    }
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
          {error && (
            <div className="mb-4 p-4 bg-red-50 border-l-4 border-red-400 rounded">
              <div className="flex">
                <div className="flex-shrink-0">
                  <svg className="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
                    <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" />
                  </svg>
                </div>
                <div className="ml-3">
                  <p className="text-sm text-red-700">{error}</p>
                </div>
              </div>
            </div>
          )}
          
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
                    {columns.map((column) => {
                      const value = extractValue(item[column]);
                      const isS3Link = isS3Url(value);
                      
                      return (
                        <td
                          key={column}
                          className="px-4 py-3 text-sm text-gray-900 border-r border-gray-200 last:border-r-0"
                        >
                          {isS3Link ? (
                            <button
                              onClick={() => handleS3Click(value)}
                              disabled={loadingUrl === value}
                              className="text-blue-600 hover:text-blue-800 underline flex items-center space-x-1 disabled:opacity-50 disabled:cursor-not-allowed"
                              title={value}
                            >
                              {loadingUrl === value ? (
                                <>
                                  <svg className="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                                  </svg>
                                  <span>Loading...</span>
                                </>
                              ) : (
                                <>
                                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                                  </svg>
                                  <span className="truncate max-w-xs">{value}</span>
                                </>
                              )}
                            </button>
                          ) : (
                            <div className="max-w-xs truncate" title={value}>
                              {value}
                            </div>
                          )}
                        </td>
                      );
                    })}
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
