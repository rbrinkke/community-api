from fastapi import APIRouter, Depends, Query, status, Request
from typing import Optional
from uuid import UUID
import structlog

from app.core.auth import CurrentUser, get_current_user
from app.core.database import Database, get_db
from app.core.rate_limit import limiter
from app.services.comment_service import CommentService
from app.models.comment import (
    CommentCreateRequest,
    CommentCreateResponse,
    CommentUpdateRequest,
    CommentUpdateResponse,
    CommentDeleteResponse,
    CommentListResponse,
)
from app.utils.pagination import build_pagination_response

logger = structlog.get_logger()
router = APIRouter()

def get_comment_service(db: Database = Depends(get_db)) -> CommentService:
    return CommentService(db)

# E12: POST /api/v1/communities/{community_id}/posts/{post_id}/comments
@router.post(
    "/{community_id}/posts/{post_id}/comments",
    response_model=CommentCreateResponse,
    status_code=status.HTTP_201_CREATED
)
@limiter.limit("100/hour")
async def create_comment(
    request: Request,
    community_id: UUID,
    post_id: UUID,
    body: CommentCreateRequest,
    current_user: CurrentUser = Depends(get_current_user),
    service: CommentService = Depends(get_comment_service)
):
    """Create a comment on a post"""
    return await service.create_comment(
        post_id=post_id,
        author_user_id=UUID(current_user.user_id),
        request=body
    )

# E13: PATCH /api/v1/communities/{community_id}/posts/{post_id}/comments/{comment_id}
@router.patch(
    "/{community_id}/posts/{post_id}/comments/{comment_id}",
    response_model=CommentUpdateResponse
)
@limiter.limit("50/hour")
async def update_comment(
    request: Request,
    community_id: UUID,
    post_id: UUID,
    comment_id: UUID,
    body: CommentUpdateRequest,
    current_user: CurrentUser = Depends(get_current_user),
    service: CommentService = Depends(get_comment_service)
):
    """Update own comment"""
    return await service.update_comment(
        comment_id=comment_id,
        updating_user_id=UUID(current_user.user_id),
        request=body
    )

# E14: DELETE /api/v1/communities/{community_id}/posts/{post_id}/comments/{comment_id}
@router.delete(
    "/{community_id}/posts/{post_id}/comments/{comment_id}",
    response_model=CommentDeleteResponse
)
@limiter.limit("50/hour")
async def delete_comment(
    request: Request,
    community_id: UUID,
    post_id: UUID,
    comment_id: UUID,
    current_user: CurrentUser = Depends(get_current_user),
    service: CommentService = Depends(get_comment_service)
):
    """Delete own comment (or organizer can delete any comment)"""
    return await service.delete_comment(
        comment_id=comment_id,
        deleting_user_id=UUID(current_user.user_id)
    )

# E15: GET /api/v1/communities/{community_id}/posts/{post_id}/comments
@router.get(
    "/{community_id}/posts/{post_id}/comments",
    response_model=CommentListResponse
)
async def get_comments(
    community_id: UUID,
    post_id: UUID,
    parent_comment_id: Optional[UUID] = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    service: CommentService = Depends(get_comment_service)
):
    """Get comments for a post (threaded)"""
    comments, total_count = await service.get_comments(
        post_id=post_id,
        parent_comment_id=parent_comment_id,
        limit=limit,
        offset=offset
    )

    return build_pagination_response(
        items=comments,
        total_count=total_count,
        limit=limit,
        offset=offset
    )
