# Migratie naar Centrale Database

**Datum:** 2025-11-13
**Status:** ✅ Compleet

## Wijzigingen

### 1. Docker Compose Configuratie

**Voor:**
- Eigen PostgreSQL container (postgres:15)
- Eigen Redis container
- Port 8000

**Na:**
- ✅ Gebruikt centrale `activity-postgres-db` container
- ✅ Gebruikt gedeelde `auth-redis` container
- ✅ Gebruikt `activity_default` netwerk
- ✅ Port 8003 (om conflicten te voorkomen)

### 2. Database Configuratie

**Database URL:**
```
postgresql://postgres:postgres_secure_password_change_in_prod@activity-postgres-db:5432/activitydb
```

**Belangrijke punten:**
- Host: `activity-postgres-db` (centrale database container)
- Database: `activitydb` (met alle 40 tabellen)
- Schema: `activity` (automatisch via migraties)
- User: `postgres`
- Password: `postgres_secure_password_change_in_prod`

### 3. Redis Configuratie

**Redis URL:**
```
redis://auth-redis:6379/0
```

Gebruikt dezelfde Redis instance als auth-api en moderation-api voor:
- Rate limiting
- Caching
- Session management

### 4. Netwerk Configuratie

Gebruikt `activity_default` external network:
- Alle activity services in zelfde netwerk
- Direct communicatie tussen services
- Geen port mapping conflicts

### 5. Container Naam

Container naam: `community-api`
- Makkelijk te identificeren
- Consistent met andere services
- Gebruikt in logs en monitoring

## Database Schema

De community-api gebruikt tabellen uit het centrale schema:

**Community Tabellen:**
- `communities` (17 kolommen) - Community data
- `community_members` (6 kolommen) - Community membership
- `community_activities` (4 kolommen) - Activity-community relations
- `community_tags` (4 kolommen) - Community categorization

**Content Tabellen:**
- `posts` (17 kolommen) - Community posts
- `comments` (10 kolommen) - Post comments
- `reactions` (6 kolommen) - Post/comment reactions

**User Tabellen:**
- `users` (34 kolommen) - User info
- `user_settings` (14 kolommen) - User preferences

## Deployment

### Starten

```bash
cd /mnt/d/activity/community-api/community-api
docker compose build
docker compose up -d
```

### Logs Checken

```bash
docker compose logs -f community-api
```

### Health Check

```bash
curl http://localhost:8003/health
```

### Stoppen

```bash
docker compose down
```

## Belangrijke Opmerkingen

1. **Geen eigen database meer** - Alle data in centrale database
2. **Gedeelde Redis** - Rate limiting gedeeld met andere APIs
3. **Schema migraties** - Gebruik database/stored_procedures.sql voor schema wijzigingen
4. **Port 8003** - Om conflict met auth-api (8000) en moderation-api (8002) te voorkomen
5. **External network** - Moet `activity_default` netwerk bestaan

## Port Overzicht

| Service | Port | Functie |
|---------|------|---------|
| auth-api | 8000 | Authenticatie & gebruikers |
| moderation-api | 8002 | Content moderatie |
| community-api | 8003 | Communities & posts |

## Verificatie

Checklist na deployment:
- [ ] Container start zonder errors
- [ ] Database connectie succesvol
- [ ] Redis connectie succesvol
- [ ] Health endpoint reageert
- [ ] Auth-API communicatie werkt
- [ ] Community endpoints werken

## Rollback

Als er problemen zijn:
```bash
cd /mnt/d/activity/community-api/community-api
docker compose down
# Fix issues
docker compose up -d
```

---

**Status:** ✅ Klaar voor gebruik met centrale database
