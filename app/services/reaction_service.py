from uuid import UUID
import structlog

from app.core.database import Database
from app.utils.stored_procedures import execute_stored_procedure
from app.models.reaction import (
    ReactionCreateRequest,
    ReactionCreateResponse,
    ReactionDeleteResponse,
    CommunityActivityLinkRequest,
    CommunityActivityLinkResponse,
)

logger = structlog.get_logger()

class ReactionService:
    def __init__(self, db: Database):
        self.db = db

    async def create_reaction(
        self,
        user_id: UUID,
        target_type: str,
        target_id: UUID,
        request: ReactionCreateRequest
    ) -> ReactionCreateResponse:
        """Create or update a reaction"""
        logger.info("creating_reaction", target_type=target_type, target_id=str(target_id))

        results = await execute_stored_procedure(
            self.db,
            "activity.sp_community_reaction_create",
            p_user_id=user_id,
            p_target_type=target_type,
            p_target_id=target_id,
            p_reaction_type=request.reaction_type
        )

        return ReactionCreateResponse(**results[0])

    async def delete_reaction(
        self,
        user_id: UUID,
        target_type: str,
        target_id: UUID
    ) -> ReactionDeleteResponse:
        """Delete a reaction"""
        logger.info("deleting_reaction", target_type=target_type, target_id=str(target_id))

        results = await execute_stored_procedure(
            self.db,
            "activity.sp_community_reaction_delete",
            p_user_id=user_id,
            p_target_type=target_type,
            p_target_id=target_id
        )

        return ReactionDeleteResponse(**results[0])

    async def link_activity_to_community(
        self,
        community_id: UUID,
        linking_user_id: UUID,
        request: CommunityActivityLinkRequest
    ) -> CommunityActivityLinkResponse:
        """Link an activity to a community"""
        logger.info("linking_activity", community_id=str(community_id), activity_id=str(request.activity_id))

        results = await execute_stored_procedure(
            self.db,
            "activity.sp_community_link_activity",
            p_community_id=community_id,
            p_activity_id=request.activity_id,
            p_linking_user_id=linking_user_id
        )

        return CommunityActivityLinkResponse(**results[0])
