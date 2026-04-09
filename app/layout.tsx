import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Energiemix Nederland",
  description: "Hoe duurzaam is de Nederlandse stroom op dit moment?",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
  themeColor: "#FAFAF7",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="nl" className="h-full antialiased">
      <body className="min-h-full" style={{ background: "#FAFAF7", color: "#0B0B0A" }}>
        {children}
      </body>
    </html>
  );
}
