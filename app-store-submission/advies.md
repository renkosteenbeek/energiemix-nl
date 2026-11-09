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

Het widget-screenshot is gemaakt met de simulator op Nederlands (`AppleLanguages nl-NL`), zodat de systeemteksten op het beginscherm Nederlands zijn. Een beginscherm dat je na het plaatsen van widgets herstart, verliest die widgets; maak het screenshot dus zonder herstart.

---

## Privacy

De app verzamelt geen persoonlijke gegevens, heeft geen accounts, geen analytics en geen advertenties. Wel bewaren app en widget een tijdelijke cache van de energiedata op het toestel (geen persoonlijke gegevens). De privacypagina is daarop aangepast.

- App Privacy in App Store Connect: "Data Not Collected"
- Privacy manifest (`PrivacyInfo.xcprivacy`) zit in app en widget: geen tracking, geen verzamelde data, geen required-reason API's

---

## Eisen voor iOS 27 (stand november 2026)

- **SDK**: sinds april 2026 moet elke upload met Xcode 26 of nieuwer en de iOS 26 SDK gebouwd zijn. Stroompeil bouwt met Xcode 27.2 en de iOS 27.2 SDK, dus dat is gedekt.
- **Minimale iOS-versie**: uploads moeten iOS 13 of hoger targeten, vanaf april 2027 iOS 15 of hoger (in combinatie met de iOS 27 SDK). De app target iOS 17.
- **Leeftijdsclassificatie**: sinds september 2026 bevat de vragenlijst in App Store Connect ook vragen over social media (berichten tussen gebruikers, door gebruikers gemaakte content, profielen). Zonder ingevulde vragenlijst kun je geen nieuwe versie indienen. Antwoorden voor Stroompeil: overal "Nee" of "Geen" (geen gebruikerscontent, geen communicatie tussen gebruikers, geen webbrowser, geen gokken, geen wedstrijden, geen medische of gezondheidsinformatie). Uitkomst: **4+**.
- **App-icoon**: een Icon Composer-bestand (`.icon`) met Liquid Glass-lagen is aanbevolen, niet verplicht. De asset catalog bevat een licht, donker en getint icoon, zodat het icoon in alle weergaven van het beginscherm klopt.
- **Screenshots**: 6,9" (1320 x 2868) zonder alfakanaal. De set in `screenshots/` voldoet daaraan.

Bronnen:
- [SDK minimum requirements](https://developer.apple.com/news/upcoming-requirements/) (Apple)
- [App Store uploads must now target iOS 13 or later, and iOS 15 from April 2027](https://www.macobserver.com/news/app-store-ios-13-minimum-target/) (MacObserver)
- [Age rating questionnaire now includes social media questions](https://developer.apple.com/news/?id=tlur8uvi) (Apple)
- [Overview of Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels) en [Manage Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/manage-accessibility-nutrition-labels) (App Store Connect Help)
- [WWDC26-sessie 8012 over app-iconen](https://developer.apple.com/videos/play/wwdc2026/8012/) (Apple)

---

## Toegankelijkheid (Accessibility Nutrition Labels)

Apple vraagt per functie of alle veelvoorkomende taken ermee te doen zijn. Claim een functie alleen als dat echt zo is; Apple kan een claim laten verwijderen. Voor Stroompeil zijn de veelvoorkomende taken: het huidige percentage lezen, een ander uur of een andere dag kiezen, uitzoomen naar maand en jaar, de duiding lezen en de bronnen bekijken.

| Functie | Claimen | Waarom |
|---|---|---|
| VoiceOver | Ja | Hero, tijdlijn (verstelbaar met omhoog/omlaag vegen, acties Uitzoomen/Inzoomen), duiding en bronnen hebben Nederlandse labels; de UI-tests sturen de app via diezelfde labels aan. |
| Larger Text | Ja | Alle tekst schaalt mee met Dynamic Type. Kleine labels (schaalkeuze, sectiekoppen, assen in de grafiek) hebben een bovengrens van Accessibility 2 of zijn decoratief en verborgen voor VoiceOver; de inhoud staat dan ook in de preview-regel en de hero. Gecontroleerd tot de grootste maat. |
| Dark Interface | Ja | Volledige donkere modus, ook in de widgets. |
| Differentiate Without Color Alone | Ja | Elk percentage staat ook als getal naast de kleur; de bronnen hebben naam en percentage naast hun kleurstip. |
| Sufficient Contrast | Ja | Gewone tekst haalt minimaal 4,5:1. Met Verhoog contrast krijgen de hero en de widgets donkerdere kaarten en dekkender tekst. |
| Reduced Motion | Ja | Met Verminder beweging vallen de zoomovergang en het omdraaien van de kaart terug op een korte fade. |
| Voice Control | Nee | De knoppen hebben namen, maar het kiezen van een uur op de tijdlijn gaat via slepen en is met Voice Control niet goed te doen. |
| Captions / Audio Descriptions | n.v.t. | De app heeft geen video of audio. |

---

## Checklist voor Submission

### Server
- [ ] Controleer vlak voor indienen dat https://energiemix.gentle-innovations.nl/api/health, `/privacy` en `/support` een 200 geven. Zonder werkende API toont de app alleen een foutmelding en wordt hij afgewezen.

### Xcode / Build
- [ ] Versie en buildnummer in `ios/project.yml` (`MARKETING_VERSION` 1.0, `CURRENT_PROJECT_VERSION` 2). Elk geüpload build moet een hoger buildnummer hebben dan het vorige.
- [ ] `cd ios && xcodegen generate` (het Xcode-project staat niet in git), open `Stroompeil.xcodeproj`
- [ ] Bundle ID's ongewijzigd: `nl.gentleinnovations.stroompeil` en `nl.gentleinnovations.stroompeil.widget`
- [ ] Product > Archive met het schema Stroompeil, daarna uploaden via Organizer

### App Store Connect
- [ ] Teksten invullen (zie `app-store-teksten.md`)
- [ ] Screenshots uploaden (6,9")
- [ ] App Privacy: Data Not Collected
- [ ] Leeftijdsclassificatie: vragenlijst invullen inclusief de social-mediavragen (alles "Nee"/"Geen"), uitkomst 4+
- [ ] Accessibility Nutrition Labels invullen volgens de tabel hierboven
- [ ] Export compliance: de Info.plist bevat `ITSAppUsesNonExemptEncryption = NO`, dus deze vraag wordt niet meer gesteld
- [ ] Review notes toevoegen (zie `review-notes.md`)

### Na upload
- [ ] Wachten op processing (15-30 minuten)
- [ ] Build selecteren en Submit for Review
- [ ] Review duurt meestal 24-48 uur
