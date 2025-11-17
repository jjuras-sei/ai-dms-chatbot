import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'AI DMS Chatbot',
  description: 'Conversational AI chatbot powered by AWS Bedrock',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
