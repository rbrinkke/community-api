#!/usr/bin/env python3
"""Generate JWT token using python-jose (same as API uses)"""
import sys
import json
from jose import jwt
from datetime import datetime, timedelta

if len(sys.argv) < 3:
    print("Usage: generate_jwt_python.py <user_id> <email> [secret_key]")
    sys.exit(1)

user_id = sys.argv[1]
email = sys.argv[2]
secret_key = sys.argv[3] if len(sys.argv) > 3 else "dev-secret-key-change-in-production"

# Create payload
payload = {
    "sub": user_id,
    "email": email,
    "subscription_level": "free",
    "ghost_mode": False,
    "org_id": None,
    "exp": datetime.utcnow() + timedelta(minutes=15)
}

# Generate token
token = jwt.encode(payload, secret_key, algorithm="HS256")
print(token)
