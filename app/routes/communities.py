from fastapi import APIRouter, Depends, Query, HTTPException, status, Request
from typing import Optional, List
from uuid import UUID
import structlog

from app.core.auth import CurrentUser, get_current_user, get_current_user_optional
from app.core.database import Database, get_db
from app.core.rate_limit import limiter
from app.services.community_service import CommunityService
from app.models.community import (
    CommunityCreateRequest,
    CommunityCreateResponse,
    CommunityUpdateRequest,
    CommunityUpdateResponse,
    CommunityDetailResponse,
    CommunitySearchResponse,
    MembershipCreateResponse,
    MembershipLeaveResponse,
    MemberListResponse,
)
from app.utils.pagination import build_pagination_response
from app.models.common import PaginationMeta

logger = structlog.get_logger()
router = APIRouter()

def get_community_service(db: Database = Depends(get_db)) -> CommunityService:
    return CommunityService(db)

# E1: POST /api/v1/communities
@router.post(
    "",
    response_model=CommunityCreateResponse,
    status_code=status.HTTP_201_CREATED
)
@limiter.limit("10/hour")
async def create_community(
    request: Request,
    body: CommunityCreateRequest,
    current_user: CurrentUser = Depends(get_current_user),
    service: CommunityService = Depends(get_community_service)
):
    """Create a new community"""
    return await service.create_community(
        creator_user_id=UUID(current_user.user_id),
        request=body
    )

# E7: GET /api/v1/communities/search (MUST come before /{community_id})
@router.get(
    "/search",
    response_model=CommunitySearchResponse
)
async def search_communities(
    q: Optional[str] = Query(None),
    organization_id: Optional[UUID] = Query(None),
    tags: Optional[str] = Query(None),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: Optional[CurrentUser] = Depends(get_current_user_optional),
    service: CommunityService = Depends(get_community_service)
):
    """Search communities"""
    # Parse comma-separated tags
    tags_array = tags.split(',') if tags else None

    communities, total_count = await service.search_communities(
        search_text=q,
        organization_id=organization_id,
        tags=tags_array,
        requesting_user_id=UUID(current_user.user_id) if current_user else None,
        limit=limit,
        offset=offset
    )

    return CommunitySearchResponse(
        communities=communities,
        pagination=PaginationMeta(
            limit=limit,
            offset=offset,
            total_count=total_count
        )
    )

# E2: GET /api/v1/communities/{community_id}
@router.get(
    "/{community_id}",
    response_model=CommunityDetailResponse
)
async def get_community(
    community_id: UUID,
    current_user: Optional[CurrentUser] = Depends(get_current_user_optional),
    service: CommunityService = Depends(get_community_service)
):
    """Get community details"""
    requesting_user_id = UUID(current_user.user_id) if current_user else None

    community = await service.get_community(
        community_id=community_id,
        requesting_user_id=requesting_user_id
    )

    if not community:
        raise HTTPException(status_code=404, detail="Community not found")

    return community

# E3: PATCH /api/v1/communities/{community_id}
@router.patch(
    "/{community_id}",
    response_model=CommunityUpdateResponse
)
@limiter.limit("20/hour")
async def update_community(
    request: Request,
    community_id: UUID,
    body: CommunityUpdateRequest,
    current_user: CurrentUser = Depends(get_current_user),
    service: CommunityService = Depends(get_community_service)
):
    """Update community details"""
    return await service.update_community(
        community_id=community_id,
        updating_user_id=UUID(current_user.user_id),
        request=body
    )

# E4: POST /api/v1/communities/{community_id}/join
@router.post(
    "/{community_id}/join",
    response_model=MembershipCreateResponse,
    status_code=status.HTTP_201_CREATED
)
@limiter.limit("30/hour")
async def join_community(
    request: Request,
    community_id: UUID,
    current_user: CurrentUser = Depends(get_current_user),
    service: CommunityService = Depends(get_community_service)
):
    """Join a community"""
    return await service.join_community(
        community_id=community_id,
        user_id=UUID(current_user.user_id)
    )

# E5: POST /api/v1/communities/{community_id}/leave
@router.post(
    "/{community_id}/leave",
    response_model=MembershipLeaveResponse
)
@limiter.limit("20/hour")
async def leave_community(
    request: Request,
    community_id: UUID,
    current_user: CurrentUser = Depends(get_current_user),
    service: CommunityService = Depends(get_community_service)
):
    """Leave a community"""
    return await service.leave_community(
        community_id=community_id,
        user_id=UUID(current_user.user_id)
    )

# E6: GET /api/v1/communities/{community_id}/members
@router.get(
    "/{community_id}/members",
    response_model=MemberListResponse
)
async def get_members(
    community_id: UUID,
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: CurrentUser = Depends(get_current_user),
    service: CommunityService = Depends(get_community_service)
):
    """Get community members"""
    members, total_count = await service.get_members(
        community_id=community_id,
        requesting_user_id=UUID(current_user.user_id),
        limit=limit,
        offset=offset
    )

    return build_pagination_response(
        items=members,
        total_count=total_count,
        limit=limit,
        offset=offset
    )
