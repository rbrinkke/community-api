from pydantic import BaseModel, Field
from typing import Optional, List
from uuid import UUID
from datetime import datetime
from app.models.common import PaginationMeta

# Request: Create comment
class CommentCreateRequest(BaseModel):
    parent_comment_id: Optional[UUID] = None
    content: str = Field(..., min_length=1, max_length=2000)

# Response: Comment created
class CommentCreateResponse(BaseModel):
    comment_id: UUID
    post_id: UUID
    parent_comment_id: Optional[UUID]
    author_user_id: UUID
    created_at: datetime

# Request: Update comment
class CommentUpdateRequest(BaseModel):
    content: str = Field(..., min_length=1, max_length=2000)

# Response: Comment updated
class CommentUpdateResponse(BaseModel):
    comment_id: UUID
    updated_at: datetime

# Response: Comment deleted
class CommentDeleteResponse(BaseModel):
    comment_id: UUID
    deleted_at: datetime

# Response: Comment list item
class CommentListItem(BaseModel):
    comment_id: UUID
    parent_comment_id: Optional[UUID]
    author_user_id: UUID
    author_username: str
    author_first_name: Optional[str]
    author_main_photo_url: Optional[str]
    content: str
    reaction_count: int
    is_deleted: bool
    created_at: datetime
    updated_at: datetime

# Response: Comment list
class CommentListResponse(BaseModel):
    comments: List[CommentListItem]
    pagination: PaginationMeta
