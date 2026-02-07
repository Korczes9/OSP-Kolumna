# Notify backend (Render)

Minimalny backend do wysylki FCM do tematu `all` + worker do monitoringu Discord.

## Zmienne srodowiskowe

- `ADMIN_TOKEN` - token wymagany w naglowku `X-Admin-Token`
- `FIREBASE_SERVICE_ACCOUNT` - JSON konta uslugi (jedna linia)
- `FIREBASE_SERVICE_ACCOUNT_B64` - JSON w base64 (alternatywa)

## Zmienne srodowiskowe (worker Discord)

- `DISCORD_BOT_TOKEN` - token bota Discord
- `DISCORD_CHANNEL_ID` - ID kanalu do monitoringu
- `DISCORD_POLL_INTERVAL_SECONDS` - interwal sprawdzania (domyslnie 1)
- `DISCORD_MESSAGE_LIMIT` - limit wiadomosci na request (domyslnie 10)
- `DISCORD_ALARM_KEYWORD` - slowo kluczowe alarmu (domyslnie KOLUMNA)
- `DISCORD_ALARM_COOLDOWN_MINUTES` - wyciszenie alarmu w minutach (domyslnie 4)
- `DISCORD_STATE_DOC` - dokument stanu w Firestore (domyslnie config/discord_monitor)

## Endpoints

- `GET /health`
- `POST /notify`

Przyklad payload:

```
{
  "type": "ALARM",
  "title": "ALARM!",
  "body": "Pozar",
  "data": {
    "kategoria": "Pozar"
  }
}
```

## Worker Discord

Worker odpytuje Discord, wykrywa slowo kluczowe i zapisuje dokument do kolekcji `powiadomienia`.
Cloud Function wysyla FCM po utworzeniu dokumentu.

Start lokalny:

```
npm run worker
```

Wymagania:

- Node.js 18+

Przyklad zmiennych lokalnych:

Zobacz [notify_backend/.env.example](../notify_backend/.env.example).

## Render (deployment)

W katalogu glownym projektu jest plik [render.yaml](../render.yaml) z gotowa konfiguracja worker'a.

Kroki:

1. Utworz nowy serwis w Render z blueprint (Render -> New -> Blueprint -> wybierz repozytorium).
2. Ustaw zmienne srodowiskowe wymagane przez worker (sekcja powyzej).
3. Wdróż serwis i sprawdz logi startowe.

Wymagane sekrety w Render:

- `DISCORD_BOT_TOKEN`
- `DISCORD_CHANNEL_ID`
- `FIREBASE_SERVICE_ACCOUNT` lub `FIREBASE_SERVICE_ACCOUNT_B64`
