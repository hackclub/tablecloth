# Tablecloth

Revokes Airtable PATs (Personal Access Tokens) via enterprise admin API.

## Setup

```bash
bundle install
cp .env.example .env
# Edit .env with your credentials
```

## Getting Credentials

1. **AIRTABLE_API_KEY**: Create a PAT at https://airtable.com/create/tokens with `enterprise.user:read` scope
2. **AIRTABLE_ENTERPRISE_ID**: Your enterprise ID (starts with `ent`)
3. **AIRTABLE_SESSION_COOKIE**: Copy the entire Cookie header from browser DevTools while logged in
4. **AIRTABLE_CSRF_TOKEN**: Decode `__Host-airtable-session` (base64) and extract `csrfSecret`
5. **API_TOKEN**: Secret token for authenticating requests to this service

## Running

```bash
bundle exec ruby app.rb
# or
bundle exec puma
```

## API

### POST /revoke

Revokes a PAT and returns the owner's email.

**Request:**
```json
{"token": "patXXX.secret"}
```

**Response:**
```json
{"success": true, "owner_email": "user@example.com"}
```

Requires `Authorization: Bearer <API_TOKEN>` header.
