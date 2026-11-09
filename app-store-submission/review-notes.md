# Apple Review Notes

## What this app does

Stroompeil shows the real-time energy mix of the Dutch electricity grid. It displays what percentage of electricity is currently generated from sustainable sources (wind, solar, biomass) versus other sources (natural gas, coal, nuclear). Data comes from the Dutch National Energy Dashboard (NED, api.ned.nl), the data platform of the Dutch grid operators.

The app is written natively in Swift and SwiftUI. It includes home screen widgets (small and medium) and Lock Screen widgets.

## How to test

The app requires no login or account. Open the app to see the current energy mix. You can:

1. View the current green percentage on the large card at the top. Tap the "i" button to read about the app; the back of the card links to the privacy policy and support page.
2. Tap a bar in the "Dagritme" timeline, or drag horizontally across it, to see another hour. The arrows move one day back or forward, "NU" returns to the current hour.
3. Switch the timeline between "Dag", "Maand" and "Jaar" (or pinch on the chart) to zoom out to a month or a whole year, back to 2021. Tap a day to see its mix; tap "Dag" to see the hours of that day.
4. Read the short interpretation ("Duiding") of the selected hour or day.
5. Scroll down and tap "Alle bronnen" for a breakdown of all energy sources.
6. Pull down to refresh.
7. Add the Stroompeil widget to the home screen or Lock Screen.

## Server dependency

The app fetches data from our backend at energiemix.gentle-innovations.nl, which connects server-side to:
- **NED API** (api.ned.nl) for Dutch energy data
- **Anthropic API** (Claude) for the short text interpretation (falls back to a rule-based text)

The app itself makes no third-party API calls and contains no API keys.

## Privacy

The app does not collect personal data, has no accounts, no analytics and no advertising. It keeps a temporary cache of the downloaded energy data on the device so it opens quickly and can show the last known values offline.

## Content

All UI text is in Dutch. The app targets Dutch-speaking users interested in the sustainability of their electricity supply.
