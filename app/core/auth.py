from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from typing import Optional, Dict
import structlog
from app.config import settings

logger = structlog.get_logger()
security = HTTPBearer()

class CurrentUser:
    """Container for current user from JWT token"""
    def __init__(
        self,
        user_id: str,
        email: str,
        subscription_level: str = "free",
        ghost_mode: bool = False,
        org_id: Optional[str] = None
    ):
        self.user_id = user_id
        self.email = email
        self.subscription_level = subscription_level
        self.ghost_mode = ghost_mode
        self.org_id = org_id

def decode_token(token: str) -> Dict:
    """Decode and validate JWT token"""
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM]
        )
        return payload
    except JWTError as e:
        logger.error("jwt_decode_error", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> CurrentUser:
    """Extract current user from JWT token (required)"""
    payload = decode_token(credentials.credentials)

    return CurrentUser(
        user_id=payload.get("sub"),
        email=payload.get("email"),
        subscription_level=payload.get("subscription_level", "free"),
        ghost_mode=payload.get("ghost_mode", False),
        org_id=payload.get("org_id")
    )

async def get_current_user_optional(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(
        HTTPBearer(auto_error=False)
    )
) -> Optional[CurrentUser]:
    """Extract current user from JWT token (optional)"""
    if not credentials:
        return None

    try:
        payload = decode_token(credentials.credentials)
        return CurrentUser(
            user_id=payload.get("sub"),
            email=payload.get("email"),
            subscription_level=payload.get("subscription_level", "free"),
            ghost_mode=payload.get("ghost_mode", False),
            org_id=payload.get("org_id")
        )
    except HTTPException:
        return None
