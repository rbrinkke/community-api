from typing import List, Optional
from uuid import UUID
import structlog

from app.core.database import Database
from app.utils.stored_procedures import execute_stored_procedure
from app.models.post import (
    PostCreateRequest,
    PostCreateResponse,
    PostUpdateRequest,
    PostUpdateResponse,
    PostDeleteResponse,
    PostListItem,
)

logger = structlog.get_logger()

class PostService:
    def __init__(self, db: Database):
        self.db = db

    async def create_post(
        self,
        community_id: UUID,
        author_user_id: UUID,
        request: PostCreateRequest
    ) -> PostCreateResponse:
        """Create a new post"""
        logger.info("creating_post", community_id=str(community_id))

        results = await execute_stored_procedure(
            self.db,
            "activity.sp_community_post_create",
            p_community_id=community_id,
            p_author_user_id=author_user_id,
            p_activity_id=request.activity_id,
            p_title=request.title,
            p_content=request.content,
            p_content_type=request.content_type
        )

        return PostCreateResponse(**results[0])

    async def update_post(
        self,
        post_id: UUID,
        updating_user_id: UUID,
        request: PostUpdateRequest
    ) -> PostUpdateResponse:
        """Update a post"""
        logger.info("updating_post", post_id=str(post_id))

        results = await execute_stored_procedure(
            self.db,
            "activity.sp_community_post_update",
            p_post_id=post_id,
            p_updating_user_id=updating_user_id,
            p_title=request.title,
            p_content=request.content
        )

        return PostUpdateResponse(**results[0])

    async def delete_post(
        self,
        post_id: UUID,
        deleting_user_id: UUID
    ) -> PostDeleteResponse:
        """Delete a post"""
        logger.info("deleting_post", post_id=str(post_id))

        results = await execute_stored_procedure(
            self.db,
            "activity.sp_community_post_delete",
            p_post_id=post_id,
            p_deleting_user_id=deleting_user_id
        )

        return PostDeleteResponse(**results[0])

    async def get_post_feed(
        self,
        community_id: UUID,
        requesting_user_id: Optional[UUID],
        limit: int = 20,
        offset: int = 0
    ) -> tuple[List[PostListItem], int]:
        """Get post feed for a community (returns posts list and total count)"""
        logger.info("getting_post_feed", community_id=str(community_id))

        results = await execute_stored_procedure(
            self.db,
            "activity.sp_community_post_get_feed",
            p_community_id=community_id,
            p_requesting_user_id=requesting_user_id,
            p_limit=limit,
            p_offset=offset
        )

        if not results:
            return [], 0

        total_count = results[0].get('total_count', 0) if results else 0
        posts = [PostListItem(**row) for row in results]

        return posts, total_count
