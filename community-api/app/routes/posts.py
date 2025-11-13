from fastapi import APIRouter, Depends, Query, status, Request
from typing import Optional
from uuid import UUID
import structlog

from app.core.auth import CurrentUser, get_current_user, get_current_user_optional
from app.core.database import Database, get_db
from app.core.rate_limit import limiter
from app.services.post_service import PostService
from app.models.post import (
    PostCreateRequest,
    PostCreateResponse,
    PostUpdateRequest,
    PostUpdateResponse,
    PostDeleteResponse,
    PostFeedResponse,
)
from app.utils.pagination import build_pagination_response

logger = structlog.get_logger()
router = APIRouter()

def get_post_service(db: Database = Depends(get_db)) -> PostService:
    return PostService(db)

# E8: POST /api/v1/communities/{community_id}/posts
@router.post(
    "/{community_id}/posts",
    response_model=PostCreateResponse,
    status_code=status.HTTP_201_CREATED
)
@limiter.limit("50/hour")
async def create_post(
    req: Request,
    community_id: UUID,
    request: PostCreateRequest,
    current_user: CurrentUser = Depends(get_current_user),
    service: PostService = Depends(get_post_service)
):
    """Create a new post in a community"""
    return await service.create_post(
        community_id=community_id,
        author_user_id=UUID(current_user.user_id),
        request=request
    )

# E9: PATCH /api/v1/communities/{community_id}/posts/{post_id}
@router.patch(
    "/{community_id}/posts/{post_id}",
    response_model=PostUpdateResponse
)
@limiter.limit("30/hour")
async def update_post(
    req: Request,
    community_id: UUID,
    post_id: UUID,
    request: PostUpdateRequest,
    current_user: CurrentUser = Depends(get_current_user),
    service: PostService = Depends(get_post_service)
):
    """Update own post"""
    return await service.update_post(
        post_id=post_id,
        updating_user_id=UUID(current_user.user_id),
        request=request
    )

# E10: DELETE /api/v1/communities/{community_id}/posts/{post_id}
@router.delete(
    "/{community_id}/posts/{post_id}",
    response_model=PostDeleteResponse
)
@limiter.limit("30/hour")
async def delete_post(
    req: Request,
    community_id: UUID,
    post_id: UUID,
    current_user: CurrentUser = Depends(get_current_user),
    service: PostService = Depends(get_post_service)
):
    """Delete own post (or organizer can delete any post)"""
    return await service.delete_post(
        post_id=post_id,
        deleting_user_id=UUID(current_user.user_id)
    )

# E11: GET /api/v1/communities/{community_id}/posts
@router.get(
    "/{community_id}/posts",
    response_model=PostFeedResponse
)
async def get_post_feed(
    community_id: UUID,
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: Optional[CurrentUser] = Depends(get_current_user_optional),
    service: PostService = Depends(get_post_service)
):
    """Get post feed for a community"""
    posts, total_count = await service.get_post_feed(
        community_id=community_id,
        requesting_user_id=UUID(current_user.user_id) if current_user else None,
        limit=limit,
        offset=offset
    )

    return build_pagination_response(
        items=posts,
        total_count=total_count,
        limit=limit,
        offset=offset
    )
