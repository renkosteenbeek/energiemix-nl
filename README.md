# energiemix.nl

Live dashboard voor de Nederlandse energiemix met data van [NED.nl](https://ned.nl) en AI-duiding via Claude (Anthropic).

Toont per uur welke bronnen (zon, wind, gas, kolen, kern, biomassa, etc.) het Nederlandse elektriciteitsnet voeden, met automatische context en inzichten.

## Stack

- Next.js 16 (App Router)
- React 19
- TypeScript
- Tailwind CSS 4
- Anthropic API (Claude Haiku) voor duiding
- NED API voor energiemix data

## Development

```bash
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

## Environment variables

Maak een `.env.local` aan met:

```
NED_API_KEY=your_ned_api_key
ANTHROPIC_API_KEY=your_anthropic_api_key
```

## Build

```bash
npm run build
npm start
```

## iOS-app

De iOS-app (Stroompeil) is een native SwiftUI-app met widgets in `ios/`. Het Xcode-project wordt gegenereerd met [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
cd ios
xcodegen generate
open Stroompeil.xcodeproj
```

De app gebruikt de API-routes van deze server; de NED- en Anthropic-sleutels blijven server-side.
