# App Store Submission Advies

## Naam Aanbeveling

### Aanbevolen: Stroompeil

"Stroom" (elektriciteit) + "peil" (niveau/gauge). Zoals een waterpeil, maar dan voor stroom. De naam is:
- Kort en memorabel (10 tekens)
- Herkenbaar Nederlands
- Professioneel en serieus
- Niet bezet op de App Store
- Past goed onder een app-icoon op het homescreen
- "Op peil" heeft ook de bijbetekenis van "op standaard"

### Alternatieven

| Naam | Stijl | Reden |
|------|-------|-------|
| WattNu | Speels | "Watt nu?" klinkt als "Wat nu?" - uitnodigend, catchy |
| Groenmeter | Beschrijvend | Zoals thermometer/barometer - direct duidelijk |
| Netgroen | Kort | "Net" (elektriciteitsnet) + "groen" - ook leesbaar als "net groen" (precies groen) |

### Concurrentie-analyse

Er is **geen directe concurrent** in dit niche op de Nederlandse App Store. Wat er wel is:
- **Electricity Maps** - wereldwijd, niet NL-specifiek
- **Buurtnet** (Netbeheer NL) - netcongestie, niet energiemix
- **Spot/GridPulse** - stroomprijzen, niet bronnen
- **Echt Groene Stroom** - beoordeelt leveranciers, niet real-time data

Dit betekent: de eerste die dit niche pakt heeft een sterke positie.

---

## App Store Categorie

- **Primair: Hulpprogramma's (Utilities)** - waar vergelijkbare apps staan
- **Secundair: Onderwijs (Education)** - de app leert je over de energiemix

---

## Screenshot Strategie

### Screenshots (native app, 6,9", 1320 x 2868)
Gegenereerd met de UI-test `AppStoreScreenshots` op de iPhone 18 Pro Max-simulator (zie CLAUDE.md). De test zoekt het groenste uur van de afgelopen week op, zodat de eerste indruk sterk is.

1. `01-dashboard-light.png` - hoog groen percentage
2. `02-alle-bronnen.png` - alle bronnen met donut
3. `03-nu-met-verwachting.png` - het huidige uur met verwachting
4. `04-over-stroompeil.png` - achterkant van de kaart
5. `05-widgets-beginscherm.png` - widgets op het beginscherm
6. `06-dashboard-dark.png` - donkere modus
7. `07-jaaroverzicht.png` - jaaroverzicht met de groenste dag geselecteerd

Alleen iPhone: de app is iPhone-only, dus iPad-screenshots zijn niet nodig. Apple schaalt de 6,9"-set automatisch voor kleinere iPhones.

Let op: de simulator staat in het Engels, dus systeemteksten op het widget-screenshot (zoals "Search") zijn Engels. Zet de simulator op Nederlands als je dat screenshot opnieuw maakt.

---

## Privacy

De app verzamelt geen persoonlijke gegevens, heeft geen accounts, geen analytics en geen advertenties. Wel bewaren app en widget een tijdelijke cache van de energiedata op het toestel (geen persoonlijke gegevens). De privacypagina is daarop aangepast.

- App Privacy in App Store Connect: "Data Not Collected"
- Privacy manifest (`PrivacyInfo.xcprivacy`) zit in app en widget: geen tracking, geen verzamelde data, geen required-reason API's

---

## Checklist voor Submission

### Server
- [ ] Controleer vlak voor indienen dat https://energiemix.gentle-innovations.nl/api/health, `/privacy` en `/support` een 200 geven. Zonder werkende API toont de app alleen een foutmelding en wordt hij afgewezen.

### Xcode / Build
- [ ] Versie en buildnummer in `ios/project.yml` (`MARKETING_VERSION` 1.0, `CURRENT_PROJECT_VERSION` 2). Elk geüpload build moet een hoger buildnummer hebben dan het vorige.
- [ ] `cd ios && xcodegen generate`, open `Stroompeil.xcodeproj`
- [ ] Bundle ID's ongewijzigd: `nl.gentleinnovations.stroompeil` en `nl.gentleinnovations.stroompeil.widget`
- [ ] Product > Archive met het schema Stroompeil, daarna uploaden via Organizer

### App Store Connect
- [ ] Teksten invullen (zie `app-store-teksten.md`)
- [ ] Screenshots uploaden (6,9")
- [ ] App Privacy: Data Not Collected
- [ ] Leeftijdsclassificatie 4+
- [ ] Export compliance: de Info.plist bevat `ITSAppUsesNonExemptEncryption = NO`, dus deze vraag wordt niet meer gesteld
- [ ] Review notes toevoegen (zie `review-notes.md`)

### Na upload
- [ ] Wachten op processing (15-30 minuten)
- [ ] Build selecteren en Submit for Review
- [ ] Review duurt meestal 24-48 uur
