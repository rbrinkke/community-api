# Community API - Comprehensive Integration Test Suite

Complete test suite die **100% bewijs** levert dat alle API endpoints correct werken door database verificatie.

## 🎯 Overzicht

Deze test suite test:
- ✅ Alle 20 API endpoints
- ✅ Database state verificatie
- ✅ Data integriteit (counts, relationships)
- ✅ Error cases en validaties
- ✅ Edge cases en soft deletes

## 📋 Prerequisites

Zorg dat de volgende tools geïnstalleerd zijn:
```bash
# Check prerequisites
curl --version
jq --version
psql --version
openssl version
```

Zorg dat de API draait:
```bash
docker compose up -d
curl http://localhost:8003/health
```

## 🚀 Quick Start

### Volledige test suite uitvoeren
```bash
cd tests/integration
./run_tests.sh
```

### Met verbose output
```bash
./run_tests.sh --verbose
```

### Met debug informatie
```bash
./run_tests.sh --debug
```

## 🔧 Configuratie

Pas configuratie aan in `test_config.sh` of via environment variables:

```bash
# API configuratie
export API_BASE_URL="http://localhost:8003"

# Database configuratie
export DB_HOST="localhost"
export DB_PORT="5441"
export DB_NAME="activitydb"
export DB_USER="postgres"
export DB_PASSWORD="postgres_secure_password_change_in_prod"

# JWT configuratie (MOET matchen met API)
export JWT_SECRET_KEY="dev-secret-key-change-in-production"
```

## 📚 Gebruik

### Basis gebruik
```bash
# Volledige test suite
./run_tests.sh

# Alleen setup draaien
./run_tests.sh --setup

# Alleen cleanup draaien
./run_tests.sh --cleanup

# Tests zonder cleanup (data blijft in DB)
./run_tests.sh --no-cleanup
```

### Test categorieën
```bash
# Alleen community tests
./run_tests.sh --category communities

# Alleen posts tests
./run_tests.sh --category posts

# Alleen comments tests
./run_tests.sh --category comments

# Alleen reactions tests
./run_tests.sh --category reactions

# Alleen data integrity tests
./run_tests.sh --category integrity
```

## 📁 Bestandsstructuur

```
tests/integration/
├── README.md                  # Deze file
├── run_tests.sh              # Main entry point
├── test_config.sh            # Configuratie en constanten
├── test_utils.sh             # Utility functies (JWT, API calls, DB queries)
├── test_setup.sh             # Test data lifecycle management
├── test_suite.sh             # Test cases (TO BE IMPLEMENTED)
├── test_reporter.sh          # Report generatie (TO BE IMPLEMENTED)
└── results/                  # Test results (gegenereerd)
    ├── test_results.json     # Machine-readable results
    ├── test_report.html      # Human-readable report
    └── test.log              # Detailed log
```

## 🧪 Test Categorieën

### Communities (25 tests)
- Create, update, get, search communities
- Join, leave communities
- Get members, manage permissions
- Error cases: duplicate slug, not found, permissions
- Edge cases: tags, pagination, full community

### Posts (20 tests)
- Create, update, delete posts
- Get post feed with pagination
- Error cases: not member, not author
- Edge cases: soft delete, pinned posts

### Comments (20 tests)
- Create, update, delete comments
- Threaded comments (parent_comment_id)
- Error cases: post not found, deleted comments
- Edge cases: pagination, nested threads

### Reactions (15 tests)
- React to posts and comments
- Update reaction type
- Remove reactions
- Idempotent operations
- Count verification

### Activity Links (5 tests)
- Link activities to communities
- Permission verification (dual organizer)
- Error cases: not organizer, already linked

### Data Integrity (15 tests)
- Member count accuracy
- Comment count accuracy
- Reaction count accuracy
- Timestamp verification
- Soft delete verification
- FK relationship integrity

## 🔍 Hoe het werkt

### Test Flow
```
1. Setup Environment
   └─ Create 3 test users (organizer, member, outsider)
   └─ Create test organization
   └─ Create test activities
   └─ Verify in database

2. Run Tests
   └─ Generate JWT tokens
   └─ Call API endpoints
   └─ Verify HTTP responses
   └─ Query database to verify data
   └─ Check counts and relationships

3. Cleanup
   └─ Delete all test data
   └─ Verify cleanup complete

4. Generate Reports
   └─ Terminal output (colored)
   └─ JSON results file
   └─ HTML report (detailed)
```

### JWT Token Generatie

De test suite genereert JWT tokens met pure bash + openssl:
- Geen externe Python/Node dependencies
- Tokens zijn 15 minuten geldig
- Automatische payload constructie met jq

### Database Verificatie

Elke test verifieert data in database:
```bash
# Voorbeeld: test_create_community
1. API Call: POST /communities
2. Verify: HTTP 201 status
3. Verify: Response has community_id
4. DB Query: SELECT * FROM communities WHERE community_id=...
5. Verify: Community exists in database
6. Verify: Creator is organizer in community_members
7. Verify: member_count = 1
```

## 📊 Output Formaten

### Terminal Output
```
🧪 Community API Test Suite
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[SETUP] Creating test environment...
  ✓ Created 3 test users
  ✓ Created test organization
  ✓ Created test activities
  ✓ Environment ready

[COMMUNITIES] Running 25 tests...
  ✓ test_create_community (1.2s)
  ✓ test_join_community (0.9s)
  ✗ test_duplicate_slug (0.6s)
    Expected: 409 SLUG_EXISTS
    Got: 500 INTERNAL_ERROR

[SUMMARY]
Total: 82 | Passed: 80 (97.6%) | Failed: 2 | Duration: 45.3s
```

### JSON Output
```json
{
  "test_suite": "Community API Integration Tests",
  "start_time": "2025-11-13T14:00:00+01:00",
  "summary": {
    "total": 82,
    "passed": 80,
    "failed": 2,
    "duration_seconds": 45
  },
  "tests": [...]
}
```

### HTML Report
Gedetailleerd rapport met:
- Summary dashboard
- Test results per categorie
- Database verificatie logs
- Failed test details
- Timing informatie

## 🔨 Implementatie Status

### ✅ Compleet
- `test_config.sh` - Configuratie en constanten
- `test_utils.sh` - Utility functies (JWT, API, DB, assertions)
- `test_setup.sh` - Test data lifecycle
- `run_tests.sh` - Main entry point

### 🚧 Te Implementeren
- `test_suite.sh` - 80-100 test cases
- `test_reporter.sh` - HTML report generatie

## 🎓 Test Cases Toevoegen

Voeg nieuwe tests toe aan `test_suite.sh`:

```bash
test_create_community() {
    start_test "test_create_community"

    # Generate JWT token
    local token=$(generate_jwt "$TEST_USER_1_ID" "$TEST_USER_1_EMAIL")

    # Make API call
    local response=$(api_call POST "/communities" \
        -H "Authorization: Bearer $token" \
        -d '{"name":"Test","slug":"test-123","community_type":"open"}')

    # Verify API response
    assert_status_code "201" "$response"
    local community_id=$(echo "$response" | jq -r '.body.community_id')
    assert_not_null "$community_id"

    # Verify in database
    local db_result=$(db_query_json "SELECT * FROM activity.communities WHERE community_id='$community_id'")
    assert_not_null "$db_result"

    # Verify membership
    assert_equals "1" "$(db_query_value "SELECT member_count FROM activity.communities WHERE community_id='$community_id'")"

    log_success "Test passed"
}
```

## 🐛 Troubleshooting

### API niet bereikbaar
```bash
# Check of container draait
docker ps | grep community-api

# Check logs
docker compose logs community-api

# Herstart API
docker compose restart community-api
```

### Database connectie fails
```bash
# Test database connectie
PGPASSWORD="postgres_secure_password_change_in_prod" psql -h localhost -p 5441 -U postgres -d activitydb -c "SELECT 1"

# Check of postgres container draait
docker ps | grep postgres
```

### JWT validatie faalt
```bash
# Verify JWT_SECRET_KEY matches API
echo $JWT_SECRET_KEY

# Check API logs voor JWT errors
docker compose logs community-api | grep JWT
```

## 📝 Volgende Stappen

1. **Implementeer test_suite.sh**
   - Schrijf 80-100 test cases
   - Gebruik test_utils functies
   - Volg test flow pattern

2. **Implementeer test_reporter.sh**
   - Generate HTML report
   - Parse JSON results
   - Create dashboard

3. **CI/CD Integratie**
   - Add to GitHub Actions
   - Automated testing on PR
   - Test result badges

## 🤝 Contributing

Bij het toevoegen van tests:
1. Gebruik consistent naming: `test_<category>_<action>`
2. Volg assert pattern: API → DB verificatie
3. Log duidelijke error messages
4. Update test count in documentatie

## 📞 Support

Voor vragen of problemen:
- Check logs in `tests/integration/results/test.log`
- Run met `--debug` voor gedetailleerde output
- Verify prerequisites met `./run_tests.sh --help`
