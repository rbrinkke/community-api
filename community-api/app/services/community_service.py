from typing import List, Optional
from uuid import UUID
import structlog

from app.core.database import Database
from app.utils.stored_procedures import execute_stored_procedure
from app.models.community import (
    CommunityCreateRequest,
    CommunityCreateResponse,
    CommunityUpdateRequest,
    CommunityUpdateResponse,
    CommunityDetailResponse,
    CommunityListItem,
    MembershipCreateResponse,
    MembershipLeaveResponse,
    MemberListItem,
)

logger = structlog.get_logger()

class CommunityService:
    def __init__(self, db: Database):
        self.db = db

    async def create_community(
        self,
        creator_user_id: UUID,
        request: CommunityCreateRequest
    ) -> CommunityCreateResponse:
        """Create a new community"""
        logger.info("creating_community", slug=request.slug)

        results = await execute_stored_procedure(
            self.db,
            "activity.sp_community_create",
            p_creator_user_id=creator_user_id,
            p_organization_id=request.organization_id,
            p_name=request.name,
            p_slug=request.slug,
            p_description=request.description,
            p_community_type=request.community_type,
            p_cover_image_url=str(request.cover_image_url) if request.cover_image_url else None,
            p_icon_url=str(request.icon_url) if request.icon_url else None,
            p_max_members=request.max_members,
            p_tags=request.tags
        )

        return CommunityCreateResponse(**results[0])

    async def get_community(
        self,
        community_id: UUID,
        requesting_user_id: Optional[UUID]
    ) -> Optional[CommunityDetailResponse]:
        """Get community by ID"""
        logger.info("getting_community", community_id=str(community_id))

        results = await execute_stored_procedure(
            self.db,
            "activity.sp_community_get_by_id",
            p_community_id=community_id,
            p_requesting_user_id=requesting_user_id
        )

        if not results:
            return None

        return CommunityDetailResponse(**results[0])

    async def update_community(
        self,
        community_id: UUID,
        updating_user_id: UUID,
        request: CommunityUpdateRequest
    ) -> CommunityUpdateResponse:
        """Update community"""
        logger.info("updating_community", community_id=str(community_id))

        results = await execute_stored_procedure(
            self.db,
            "activity.sp_community_update",
            p_community_id=community_id,
            p_updating_user_id=updating_user_id,
            p_name=request.name,
            p_description=request.description,
            p_cover_image_url=str(request.cover_image_url) if request.cover_image_url else None,
            p_icon_url=str(request.icon_url) if request.icon_url else None,
            p_max_members=request.max_members,
            p_tags=request.tags
        )

        return CommunityUpdateResponse(**results[0])

    async def join_community(
        self,
        community_id: UUID,
        user_id: UUID
    ) -> MembershipCreateResponse:
        """Join a community"""
        logger.info("joining_community", community_id=str(community_id), user_id=str(user_id))

        results = await execute_stored_procedure(
            self.db,
            "activity.sp_community_join",
            p_community_id=community_id,
            p_user_id=user_id
        )

        return MembershipCreateResponse(**results[0])

    async def leave_community(
        self,
        community_id: UUID,
        user_id: UUID
    ) -> MembershipLeaveResponse:
        """Leave a community"""
        logger.info("leaving_community", community_id=str(community_id), user_id=str(user_id))

        results = await execute_stored_procedure(
            self.db,
            "activity.sp_community_leave",
            p_community_id=community_id,
            p_user_id=user_id
        )

        return MembershipLeaveResponse(**results[0])

    async def get_members(
        self,
        community_id: UUID,
        requesting_user_id: UUID,
        limit: int = 50,
        offset: int = 0
    ) -> tuple[List[MemberListItem], int]:
        """Get community members (returns members list and total count)"""
        logger.info("getting_members", community_id=str(community_id))

        results = await execute_stored_procedure(
            self.db,
            "activity.sp_community_get_members",
            p_community_id=community_id,
            p_requesting_user_id=requesting_user_id,
            p_limit=limit,
            p_offset=offset
        )

        if not results:
            return [], 0

        total_count = results[0].get('total_count', 0)
        members = [MemberListItem(**row) for row in results]

        return members, total_count

    async def search_communities(
        self,
        search_text: Optional[str],
        organization_id: Optional[UUID],
        tags: Optional[List[str]],
        requesting_user_id: Optional[UUID],
        limit: int = 20,
        offset: int = 0
    ) -> tuple[List[CommunityListItem], int]:
        """Search communities (returns communities list and total count)"""
        logger.info("searching_communities", search_text=search_text)

        results = await execute_stored_procedure(
            self.db,
            "activity.sp_community_search",
            p_search_text=search_text,
            p_organization_id=organization_id,
            p_tags=tags,
            p_requesting_user_id=requesting_user_id,
            p_limit=limit,
            p_offset=offset
        )

        if not results:
            return [], 0

        total_count = results[0].get('total_count', 0) if results else 0
        communities = [CommunityListItem(**row) for row in results]

        return communities, total_count
