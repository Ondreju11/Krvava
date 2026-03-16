# Krvava hodina

Jednostránková registrační stránka pro akci **Krvavá hodina**. Je navržená jako čistý statický web, takže ji můžeš bez build procesu nasadit na GitHub Pages.

## Co je hotové

- minimalistická landing page v temném stylu s akcentem na Blood on the Clocktower
- formulář pro uložení `jméno + e-mail` do Supabase
- ochrana přes RLS, takže veřejný klient může pouze vkládat registrace
- placeholder kontakt, kam si doplníš vlastní Facebook URL

## Soubory

- `index.html`: obsah stránky
- `styles.css`: vzhled
- `app.js`: Supabase klient a odeslání formuláře
- `supabase.sql`: SQL pro vytvoření tabulky a policy

## Nastavení Supabase

1. V Supabase otevři SQL Editor.
2. Spusť obsah souboru `supabase.sql`.
3. Zkontroluj, že se vytvořila tabulka `public.event_registrations`.
4. Registrace pak uvidíš v Table Editoru.

Použitý frontend klíč je publishable key, což je pro veřejný frontend v pořádku. Bezpečnost stojí na RLS policy v databázi. Nepoužívej ve frontendu service role key.

## Co si ještě upravit

V `app.js` změň tyto konstanty:

```js
const CONTACT_URL = "#";
const CONTACT_LABEL = "Doplnit Facebook URL";
```

Jakmile doplníš reálný odkaz, tlačítko v kontaktu začne fungovat jako externí link.

## GitHub Pages

Protože je to čistý statický web, stačí repozitář pushnout na GitHub a zapnout Pages nad rootem nebo nad branchí, kde tyto soubory leží.

Pokud bude projekt běžet pod adresou typu `https://uzivatel.github.io/repozitar/`, tahle verze funguje bez dalších úprav, protože používá relativní cesty k assetům.

## Poznámka k veřejnému formuláři

Tahle verze je vhodná pro jednoduchou akční registraci. Pokud bys později chtěl omezit spam nebo mít potvrzovací e-maily, další logický krok je přidat CAPTCHA a případně Supabase Edge Function.
