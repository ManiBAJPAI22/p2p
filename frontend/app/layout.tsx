import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'P2P Lending Platform',
  description: 'Decentralized peer-to-peer lending with Aave integration',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
