# WoW Forever addons

## ProfessionProfit

Listar de **mest lönsamma sakerna du kan tillverka** med de recept din karaktär
faktiskt har lärt sig, baserat på priser från **Forever Guide**s AH-skanning.

### Installation
1. Kopiera mappen `ProfessionProfit` till `World of Warcraft/<klient>/Interface/AddOns/`.
2. Starta spelet. Om addonet står som "out of date", kryssa i *Load out of date AddOns*.

### Användning
1. **Öppna varje yrkesfönster en gång** (Tailoring, Alchemy, ...). Addonet sparar då
   vilka recept karaktären kan. Gör om det när du lär dig nya recept.
2. **Skanna AH med Forever Guide** som vanligt.
3. Skriv **`/pp`** så visas listan, sorterad med högst profit först.
   Håll musen över en rad för att se reagenser och kostnader. Shift-klicka för att
   söka på föremålet i AH:t (eller länka det i chatten).

Profit = AH-pris × antal per tillverkning × 0,95 (AH:ts 5 %-avgift) − reagenskostnad.
Reagenser räknas med det billigaste av AH-pris och försäljarpris. Försäljarpriser lär
sig addonet själv när du öppnar en försäljare (t.ex. tråd och flaskor).
Recept där någon reagens saknar pris, och föremål utan AH-pris (soulbound), visas inte.

### Kommandon
| Kommando | Vad det gör |
|---|---|
| `/pp` | Visa/dölj listan |
| `/pp min 1g50s` | Visa bara recept med minst så här mycket profit |
| `/pp status` | Visar om Forever Guides priser hittats och vilka recept som sparats |
| `/pp fgdump` | Felsökning: visar hur Forever Guides data ser ut |
| `/pp reset` | Glöm sparade recept för karaktären |

### Hur Forever Guide-kopplingen fungerar
Forever Guide har inget dokumenterat API för andra addons. ProfessionProfit letar därför
själv upp det. Först söker det efter en prisfunktion, t.ex. `GetAuctionPrice(itemID)`.
Annars söker det efter tabellen där Forever Guide sparar sina skannade priser
(`[itemID] = pris`), och tabellen för din realm och faktion väljs i första hand.
Alla AH-priser kommer **bara från Forever Guide**. Inga andra AH-addons används.

Om `/pp status` säger att inga priser hittades fast du har skannat:
kör `/pp fgdump`, gör `/reload` och skicka innehållet under `fgdump` i
`WTF/Account/<konto>/SavedVariables/ProfessionProfit.lua`. Då kan kopplingen
anpassas exakt efter Forever Guide.

## RollTracker

Visar **vad alla i gruppen valde – Need, Greed eller Pass** (och Disenchant/Transmog
om spelet har det) på varje sak som droppas. Fungerar **med och utan ElvUI**.

### Installation
Kopiera mappen `RollTracker` till `Interface/AddOns/`.

### Vad du ser
- **Ett fönster** som öppnas av sig självt när något ska rollas. Där står varje drop
  med vilka som valt vad, roll-siffror, vem som vann och vilka som **inte valt än**.
  Namnen visas i klassfärg. Fönstret kan flyttas och ändras i storlek.
- **En rad med siffror ovanför själva roll-fönstret**, t.ex. `Need: 1  Greed: 2  Pass: 1  Väntar: 1`.
  Håll musen över raden för att se namnen. Det fungerar både på Blizzards roll-fönster
  och på ElvUI:s.

Med ElvUI används ElvUI:s utseende (ram, typsnitt, knappar). Utan ElvUI används vanliga
Blizzard-ramar.

### Hur det fungerar
Spelet skriver alla val i loot-chatten ("X has selected Greed for: [föremål]").
RollTracker läser de raderna med spelets egna översatta texter, så det fungerar på
alla språk och oavsett vilket UI som visar roll-fönstren.

### Kommandon
| Kommando | Vad det gör |
|---|---|
| `/rt` | Visa/dölj fönstret |
| `/rt auto` | Slå på/av att fönstret öppnas automatiskt vid roll |
| `/rt clear` | Rensa historiken |
