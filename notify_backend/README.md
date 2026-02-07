# Notify backend (Render)

Minimalny backend do wysylki FCM do tematu `all`.

## Zmienne srodowiskowe

- `ADMIN_TOKEN` - token wymagany w naglowku `X-Admin-Token`
- `FIREBASE_SERVICE_ACCOUNT` - JSON konta uslugi (jedna linia)
- `FIREBASE_SERVICE_ACCOUNT_B64` - JSON w base64 (alternatywa)

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
