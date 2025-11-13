from fastapi import APIRouter, Depends, status
from uuid import UUID
import structlog

from app.core.auth import CurrentUser, get_current_user
from app.core.database import Database, get_db
from app.services.reaction_service import ReactionService
from app.models.reaction import (
    ReactionCreateRequest,
    ReactionCreateResponse,
    ReactionDeleteResponse,
)

logger = structlog.get_logger()
router = APIRouter()

def get_reaction_service(db: Database = Depends(get_db)) -> ReactionService:
    return ReactionService(db)

# E16: POST /api/v1/communities/{community_id}/posts/{post_id}/reactions
@router.post(
    "/{community_id}/posts/{post_id}/reactions",
    response_model=ReactionCreateResponse,
    status_code=status.HTTP_201_CREATED
)
async def create_post_reaction(
    community_id: UUID,
    post_id: UUID,
    request: ReactionCreateRequest,
    current_user: CurrentUser = Depends(get_current_user),
    service: ReactionService = Depends(get_reaction_service)
):
    """React to a post (create or update reaction)"""
    return await service.create_reaction(
        user_id=UUID(current_user.user_id),
        target_type='post',
        target_id=post_id,
        request=request
    )

# E17: DELETE /api/v1/communities/{community_id}/posts/{post_id}/reactions
@router.delete(
    "/{community_id}/posts/{post_id}/reactions",
    response_model=ReactionDeleteResponse
)
async def delete_post_reaction(
    community_id: UUID,
    post_id: UUID,
    current_user: CurrentUser = Depends(get_current_user),
    service: ReactionService = Depends(get_reaction_service)
):
    """Remove reaction from a post"""
    return await service.delete_reaction(
        user_id=UUID(current_user.user_id),
        target_type='post',
        target_id=post_id
    )

# E18: POST /api/v1/communities/{community_id}/posts/{post_id}/comments/{comment_id}/reactions
@router.post(
    "/{community_id}/posts/{post_id}/comments/{comment_id}/reactions",
    response_model=ReactionCreateResponse,
    status_code=status.HTTP_201_CREATED
)
async def create_comment_reaction(
    community_id: UUID,
    post_id: UUID,
    comment_id: UUID,
    request: ReactionCreateRequest,
    current_user: CurrentUser = Depends(get_current_user),
    service: ReactionService = Depends(get_reaction_service)
):
    """React to a comment"""
    return await service.create_reaction(
        user_id=UUID(current_user.user_id),
        target_type='comment',
        target_id=comment_id,
        request=request
    )

# E19: DELETE /api/v1/communities/{community_id}/posts/{post_id}/comments/{comment_id}/reactions
@router.delete(
    "/{community_id}/posts/{post_id}/comments/{comment_id}/reactions",
    response_model=ReactionDeleteResponse
)
async def delete_comment_reaction(
    community_id: UUID,
    post_id: UUID,
    comment_id: UUID,
    current_user: CurrentUser = Depends(get_current_user),
    service: ReactionService = Depends(get_reaction_service)
):
    """Remove reaction from a comment"""
    return await service.delete_reaction(
        user_id=UUID(current_user.user_id),
        target_type='comment',
        target_id=comment_id
    )
