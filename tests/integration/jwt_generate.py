#!/usr/bin/env python3
"""Generate JWT token - wrapper for docker exec"""
import subprocess
import sys

if len(sys.argv) < 3:
    print("Usage: jwt_generate.py <user_id> <email>", file=sys.stderr)
    sys.exit(1)

user_id = sys.argv[1]
email = sys.argv[2]
subscription = sys.argv[3] if len(sys.argv) > 3 else "free"
ghost_mode = sys.argv[4].lower() if len(sys.argv) > 4 else "false"
org_id = sys.argv[5] if len(sys.argv) > 5 else "null"
expiry_min = sys.argv[6] if len(sys.argv) > 6 else "15"

# Convert bash boolean to Python boolean
ghost_mode_py = "True" if ghost_mode == "true" else "False"

python_code = f"""
from jose import jwt
from datetime import datetime, timedelta
import os

payload = {{
    'sub': '{user_id}',
    'email': '{email}',
    'subscription_level': '{subscription}',
    'ghost_mode': {ghost_mode_py},
    'org_id': None if '{org_id}' == 'null' else '{org_id}',
    'exp': datetime.utcnow() + timedelta(minutes={expiry_min})
}}

secret_key = os.getenv('JWT_SECRET_KEY', 'dev-secret-key-change-in-production')
token = jwt.encode(payload, secret_key, algorithm='HS256')
print(token, end='')
"""

try:
    result = subprocess.run(
        ['docker', 'compose', 'exec', '-T', 'community-api', 'python3', '-c', python_code],
        capture_output=True,
        text=True,
        check=True
    )
    print(result.stdout, end='')
except subprocess.CalledProcessError as e:
    print(f"Error: {e.stderr}", file=sys.stderr)
    sys.exit(1)
