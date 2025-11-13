from fastapi import HTTPException
from typing import Dict
from datetime import datetime

# Error code to HTTP status mapping
ERROR_STATUS_MAP: Dict[str, int] = {
    'USER_NOT_FOUND': 404,
    'COMMUNITY_NOT_FOUND': 404,
    'POST_NOT_FOUND': 404,
    'COMMENT_NOT_FOUND': 404,
    'ACTIVITY_NOT_FOUND': 404,
    'ORGANIZATION_NOT_FOUND': 404,
    'INSUFFICIENT_PERMISSIONS': 403,
    'NOT_MEMBER': 403,
    'NOT_COMMUNITY_ORGANIZER': 403,
    'NOT_ACTIVITY_ORGANIZER': 403,
    'ORGANIZER_CANNOT_LEAVE': 403,
    'COMMUNITY_NOT_OPEN': 403,
    'SLUG_EXISTS': 409,
    'ALREADY_MEMBER': 400,
    'COMMUNITY_FULL': 409,
    'LINK_ALREADY_EXISTS': 409,
    'COMMUNITY_NOT_ACTIVE': 400,
    'POST_NOT_PUBLISHED': 400,
    'COMMENT_DELETED': 400,
    'PARENT_COMMENT_NOT_FOUND': 400,
    'INVALID_COMMUNITY_TYPE': 400,
    'INVALID_TARGET_TYPE': 400,
    'TARGET_NOT_FOUND': 404,
    'NOT_ORGANIZATION_MEMBER': 403,
}

# Error code to human-readable message mapping
ERROR_MESSAGES: Dict[str, str] = {
    'USER_NOT_FOUND': 'User not found',
    'COMMUNITY_NOT_FOUND': 'Community not found',
    'POST_NOT_FOUND': 'Post not found',
    'COMMENT_NOT_FOUND': 'Comment not found',
    'ACTIVITY_NOT_FOUND': 'Activity not found',
    'ORGANIZATION_NOT_FOUND': 'Organization not found',
    'INSUFFICIENT_PERMISSIONS': 'Insufficient permissions',
    'NOT_MEMBER': 'Not a community member',
    'NOT_COMMUNITY_ORGANIZER': 'Not a community organizer',
    'NOT_ACTIVITY_ORGANIZER': 'Not an activity organizer',
    'ORGANIZER_CANNOT_LEAVE': 'Organizer cannot leave community',
    'COMMUNITY_NOT_OPEN': 'Community is not open',
    'SLUG_EXISTS': 'Community slug already exists',
    'ALREADY_MEMBER': 'Already a member',
    'COMMUNITY_FULL': 'Community is full',
    'LINK_ALREADY_EXISTS': 'Activity already linked to community',
    'COMMUNITY_NOT_ACTIVE': 'Community is not active',
    'POST_NOT_PUBLISHED': 'Post is not published',
    'COMMENT_DELETED': 'Comment has been deleted',
    'PARENT_COMMENT_NOT_FOUND': 'Parent comment not found',
    'INVALID_COMMUNITY_TYPE': 'Invalid community type',
    'INVALID_TARGET_TYPE': 'Invalid target type',
    'TARGET_NOT_FOUND': 'Target not found',
    'NOT_ORGANIZATION_MEMBER': 'Not an organization member',
}

def parse_db_error(error_message: str) -> str:
    """Extract error code from database exception message"""
    # PostgreSQL RAISE EXCEPTION format: "ERROR_CODE"
    if isinstance(error_message, str):
        for error_code in ERROR_STATUS_MAP.keys():
            if error_code in error_message:
                return error_code
    return "UNKNOWN_ERROR"

def raise_http_exception(error_code: str):
    """Raise HTTPException with proper status code and message"""
    status_code = ERROR_STATUS_MAP.get(error_code, 500)
    message = ERROR_MESSAGES.get(error_code, "An unexpected error occurred")

    raise HTTPException(
        status_code=status_code,
        detail={
            "detail": message,
            "error_code": error_code,
            "timestamp": datetime.utcnow().isoformat()
        }
    )
