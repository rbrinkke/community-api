from typing import List, Optional
from uuid import UUID
import structlog

from app.core.database import Database
from app.utils.stored_procedures import execute_stored_procedure
from app.models.comment import (
    CommentCreateRequest,
    CommentCreateResponse,
    CommentUpdateRequest,
    CommentUpdateResponse,
    CommentDeleteResponse,
    CommentListItem,
)

logger = structlog.get_logger()

class CommentService:
    def __init__(self, db: Database):
        self.db = db

    async def create_comment(
        self,
        post_id: UUID,
        author_user_id: UUID,
        request: CommentCreateRequest
    ) -> CommentCreateResponse:
        """Create a new comment"""
        logger.info("creating_comment", post_id=str(post_id))

        results = await execute_stored_procedure(
            self.db,
            "activity.sp_community_comment_create",
            p_post_id=post_id,
            p_author_user_id=author_user_id,
            p_parent_comment_id=request.parent_comment_id,
            p_content=request.content
        )

        return CommentCreateResponse(**results[0])

    async def update_comment(
        self,
        comment_id: UUID,
        updating_user_id: UUID,
        request: CommentUpdateRequest
    ) -> CommentUpdateResponse:
        """Update a comment"""
        logger.info("updating_comment", comment_id=str(comment_id))

        results = await execute_stored_procedure(
            self.db,
            "activity.sp_community_comment_update",
            p_comment_id=comment_id,
            p_updating_user_id=updating_user_id,
            p_content=request.content
        )

        return CommentUpdateResponse(**results[0])

    async def delete_comment(
        self,
        comment_id: UUID,
        deleting_user_id: UUID
    ) -> CommentDeleteResponse:
        """Delete a comment"""
        logger.info("deleting_comment", comment_id=str(comment_id))

        results = await execute_stored_procedure(
            self.db,
            "activity.sp_community_comment_delete",
            p_comment_id=comment_id,
            p_deleting_user_id=deleting_user_id
        )

        return CommentDeleteResponse(**results[0])

    async def get_comments(
        self,
        post_id: UUID,
        parent_comment_id: Optional[UUID],
        limit: int = 50,
        offset: int = 0
    ) -> tuple[List[CommentListItem], int]:
        """Get comments for a post (returns comments list and total count)"""
        logger.info("getting_comments", post_id=str(post_id))

        results = await execute_stored_procedure(
            self.db,
            "activity.sp_community_post_get_comments",
            p_post_id=post_id,
            p_parent_comment_id=parent_comment_id,
            p_limit=limit,
            p_offset=offset
        )

        if not results:
            return [], 0

        total_count = results[0].get('total_count', 0) if results else 0
        comments = [CommentListItem(**row) for row in results]

        return comments, total_count
