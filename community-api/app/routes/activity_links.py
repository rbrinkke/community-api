from fastapi import APIRouter, Depends, status, Request
from uuid import UUID
import structlog

from app.core.auth import CurrentUser, get_current_user
from app.core.database import Database, get_db
from app.core.rate_limit import limiter
from app.services.reaction_service import ReactionService
from app.models.reaction import (
    CommunityActivityLinkRequest,
    CommunityActivityLinkResponse,
)

logger = structlog.get_logger()
router = APIRouter()

def get_reaction_service(db: Database = Depends(get_db)) -> ReactionService:
    return ReactionService(db)

# E20: POST /api/v1/communities/{community_id}/activities
@router.post(
    "/{community_id}/activities",
    response_model=CommunityActivityLinkResponse,
    status_code=status.HTTP_201_CREATED
)
@limiter.limit("20/hour")
async def link_activity_to_community(
    req: Request,
    community_id: UUID,
    request: CommunityActivityLinkRequest,
    current_user: CurrentUser = Depends(get_current_user),
    service: ReactionService = Depends(get_reaction_service)
):
    """Link an activity to a community (both organizers required)"""
    return await service.link_activity_to_community(
        community_id=community_id,
        linking_user_id=UUID(current_user.user_id),
        request=request
    )
