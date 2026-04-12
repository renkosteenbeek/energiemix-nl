# Apple Review Notes

## What this app does

Stroompeil shows the real-time energy mix of the Dutch electricity grid. It displays what percentage of electricity is currently generated from sustainable sources (wind, solar) versus fossil fuels (natural gas, coal). Data comes from the Dutch National Energy Dashboard (NED - api.ned.nl), an official government-backed data source.

## How to test

The app requires no login or account. Simply open the app to see the current energy mix. You can:

1. View the current green percentage at the top
2. Scroll down to see all energy sources with their contribution
3. Use the timeline to browse different hours of the day
4. Read the AI-generated interpretation ("duiding") section

## API dependencies

The app fetches data from a backend server at energiemix.gentle-innovations.nl, which in turn connects to:
- **NED API** (api.ned.nl) - Dutch energy data (requires API key, server-side)
- **OpenAI API** - for generating the short text interpretation (optional, falls back to template-based text)

Both APIs are accessed server-side only. The app itself makes no direct third-party API calls.

## No login required

The app does not collect any personal data, has no user accounts, and requires no sign-in.

## Content

All UI text is in Dutch. The app targets Dutch-speaking users interested in the sustainability of their electricity supply.
