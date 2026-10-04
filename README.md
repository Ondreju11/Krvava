# Krvava hodina

Jednostránková registrační stránka pro akci **Krvavá hodina**. Je navržená jako čistý statický web, takže ji můžeš bez build procesu nasadit na GitHub Pages.

## Co je hotové

- minimalistická landing page v temném stylu s akcentem na Blood on the Clocktower
- formulář pro uložení `jméno + e-mail` do Supabase
- po naplnění kapacity 15 lidí se další zájemci přihlašují jako náhradníci
- ochrana přes RLS, takže veřejný klient může pouze vkládat registrace
- placeholder kontakt, kam si doplníš vlastní Facebook URL

## Soubory

- `index.html`: obsah stránky
- `full.html`: stará adresa stránky „plno“, přesměruje na `index.html`
- `styles.css`: vzhled
- `app.js`: Supabase klient a odeslání formuláře
- `supabase.sql`: SQL pro vytvoření tabulky a policy

## Nastavení Supabase

Aktuální termín je **20. 10. 2026 od 18:15**, kapacita **15 lidí**.
Registrace používají nový identifikátor `krvava-hodina-2026-10-20`.
Staré registrace zůstávají v databázi pod původním identifikátorem a nepočítají
se do nové kapacity. Stejný e-mail se může přihlásit na nový termín.

1. V Supabase otevři SQL Editor.
2. Spusť obsah souboru `supabase.sql`.
3. Zkontroluj, že se vytvořila tabulka `public.event_registrations`.
4. Registrace pak uvidíš v Table Editoru.

Skript je možné spustit i nad stávající databází; aktualizuje funkce a pravidla
v jedné transakci, nemaže registrace. Spusť jej před zveřejněním nové verze webu.
Původní termín poté již nepřijímá registrace.

Po aktualizaci ověř v SQL Editoru:

```sql
select public.get_event_registration_status('krvava-hodina-2026-10-20');
```

Výsledek má mít limit 15 a počet registrací jen pro říjnový termín.

## Náhradníci

Po obsazení 15 míst formulář zůstává, jen se z něj stane přihláška náhradníka.
Uživatel uvidí, že je přihlášený jako náhradník (a kolikátý v pořadí) a že mu
dáme e-mailem vědět, až se uvolní místo.

- Sloupec `status` v `event_registrations`: `registered` = má místo,
  `waitlist` = náhradník. Stav určuje databáze, ne prohlížeč.
- `created_at` nastavuje databáze ve chvíli zápisu, takže odpovídá skutečnému
  pořadí přihlášení.
- Pořadí uvidíš ve view `event_registration_order` (sloupec `poradi` se počítá
  zvlášť pro přihlášené a pro náhradníky):

```sql
select status, poradi, full_name, email, created_at
from public.event_registration_order
where event_slug = 'krvava-hodina-2026-10-20';
```

Když se někdo odhlásí, smaž jeho řádek a prvního náhradníka posuň mezi
přihlášené. Pak mu pošli e-mail:

```sql
update public.event_registrations
set status = 'registered'
where id = '<id prvního náhradníka>';
```

E-maily se zatím posílají ručně. Automatické upozornění by šlo doplnit přes
Supabase Edge Function.

Použitý frontend klíč je publishable key, což je pro veřejný frontend v pořádku. Bezpečnost stojí na RLS policy v databázi. Nepoužívej ve frontendu service role key.

## Co si ještě upravit

V `app.js` změň tyto konstanty:

```js
const CONTACT_URL = "#";
const CONTACT_LABEL = "Doplnit Facebook URL";
```

Jakmile doplníš reálný odkaz, tlačítko v kontaktu začne fungovat jako externí link.

## GitHub Pages

Cílová adresa je `https://akce.psynaffuk.cz/krvava/`. Produkční soubory
`index.html`, `full.html`, `styles.css` a `app.js` jsou také v repozitáři
`Ondreju11/Psyna_kalendar` ve složce `public/krvava`. Nasazují se společně
s kalendářem jeho stávajícím workflow. DNS ani nastavení domény se nemění.
Při dalších úpravách aktualizuj i tuto produkční kopii.

Protože je to čistý statický web, stačí repozitář pushnout na GitHub a zapnout Pages nad rootem nebo nad branchí, kde tyto soubory leží.

Pokud bude projekt běžet pod adresou typu `https://uzivatel.github.io/repozitar/`, tahle verze funguje bez dalších úprav, protože používá relativní cesty k assetům.

## Poznámka k veřejnému formuláři

Tahle verze je vhodná pro jednoduchou akční registraci. Pokud bys později chtěl omezit spam nebo mít potvrzovací e-maily, další logický krok je přidat CAPTCHA a případně Supabase Edge Function.
