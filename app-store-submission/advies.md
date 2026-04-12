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

### Huidige screenshots (4 stuks)
Voldoende voor een eerste release (minimum is 3). Ze tonen:
1. Dashboard met hoog groen percentage (80%)
2. Alle bronnen breakdown (80%)
3. Dashboard met forecast (68%)
4. Alle bronnen breakdown (68%)

### Aanbevelingen voor betere screenshots
- **Overweeg framedscreenshots**: gebruik tools als Fastlane Frameit of Screenshots Pro om een iPhone-frame en titeltekst toe te voegen
- **Dark mode**: maak ook een dark mode screenshot om het bereik te tonen
- **iPad screenshots**: als je iPad ondersteunt, zijn aparte screenshots verplicht
- **Tip**: de screenshots met hoog groenpercentage (80%) zijn het meest aantrekkelijk - gebruik die als eerste

### Vereiste formaten
- iPhone 6.9" (iPhone 16 Pro Max): 1320 x 2868 px
- iPhone 6.7" (iPhone 15 Plus): 1290 x 2796 px
- iPhone 6.5" (iPhone 14 Plus): 1284 x 2778 px
- iPad Pro 13": 2064 x 2752 px (indien iPad wordt ondersteund)

Controleer de resolutie van je huidige screenshots en schaal indien nodig.

---

## Privacy Policy

Apple vereist een privacy policy URL. De app:
- Gebruikt **geen** persoonlijke gegevens
- Slaat **geen** data lokaal op
- Heeft **geen** accounts of login
- Maakt API calls naar NED.nl (publieke energiedata) en OpenAI (voor tekstgeneratie)

Je hebt twee opties:
1. **Eenvoudige privacy policy pagina** op energiemix.gentle-innovations.nl/privacy
2. **Gratis generator** zoals privacypolicies.com of iubenda.com

De privacy policy moet minimaal vermelden:
- Welke data wordt verzameld (geen persoonlijke data)
- Welke third-party services worden gebruikt (NED API, OpenAI)
- Contactgegevens

---

## Checklist voor Submission

### Vooraf
- [ ] Kies definitieve app-naam
- [ ] Maak Apple Developer account aan ($99/jaar) als dat nog niet bestaat
- [ ] Maak privacy policy pagina aan
- [ ] Maak support URL aan (kan dezelfde website zijn)
- [ ] Controleer dat bundle ID `nl.gentleinnovations.energiemix` correct is in Apple Developer portal

### App Store Connect
- [ ] Maak nieuwe app aan in App Store Connect
- [ ] Vul alle teksten in (zie `app-store-teksten.md`)
- [ ] Upload screenshots per device-formaat
- [ ] Stel prijsstelling in (gratis)
- [ ] Selecteer content rating (4+, geen aanstootgevend materiaal)
- [ ] Vul export compliance in (gebruikt geen encryptie buiten standaard HTTPS)
- [ ] Voeg review notes toe (zie `review-notes.md`)

### Xcode / Build
- [ ] Zet versienummer op 1.0.0 in Xcode
- [ ] Zet build number op 1
- [ ] Controleer dat app-icoon (1024x1024) correct is ingesteld
- [ ] Update display name naar gekozen naam
- [ ] Doe een clean build: `Product > Clean Build Folder`
- [ ] Archiveer: `Product > Archive`
- [ ] Upload via Xcode Organizer naar App Store Connect

### Na upload
- [ ] Wacht op processing (kan 15-30 minuten duren)
- [ ] Controleer dat build verschijnt in App Store Connect
- [ ] Submit for Review
- [ ] Review duurt meestal 24-48 uur
