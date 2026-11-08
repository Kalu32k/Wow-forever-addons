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
