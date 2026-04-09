# energiemix.nl

Live dashboard voor de Nederlandse energiemix met data van [NED.nl](https://ned.nl) en AI-duiding via OpenAI.

Toont per uur welke bronnen (zon, wind, gas, kolen, kern, biomassa, etc.) het Nederlandse elektriciteitsnet voeden, met automatische context en inzichten.

## Stack

- Next.js 16 (App Router)
- React 19
- TypeScript
- Tailwind CSS 4
- OpenAI API voor duiding
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
OPENAI_API_KEY=your_openai_api_key
```

## Build

```bash
npm run build
npm start
```
