from pydantic import BaseModel, Field
from typing import Optional, List, Literal
from uuid import UUID
from datetime import datetime
from app.models.common import PaginationMeta

# Request: Create post
class PostCreateRequest(BaseModel):
    activity_id: Optional[UUID] = None
    title: Optional[str] = Field(None, max_length=500)
    content: str = Field(..., min_length=1, max_length=10000)
    content_type: Literal['post', 'photo', 'video', 'poll', 'event_announcement'] = 'post'

# Response: Post created
class PostCreateResponse(BaseModel):
    post_id: UUID
    community_id: UUID
    author_user_id: UUID
    created_at: datetime
    status: str

# Request: Update post
class PostUpdateRequest(BaseModel):
    title: Optional[str] = Field(None, max_length=500)
    content: Optional[str] = Field(None, min_length=1, max_length=10000)

# Response: Post updated
class PostUpdateResponse(BaseModel):
    post_id: UUID
    updated_at: datetime

# Response: Post deleted
class PostDeleteResponse(BaseModel):
    post_id: UUID
    deleted_at: datetime

# Response: Post list item
class PostListItem(BaseModel):
    post_id: UUID
    author_user_id: UUID
    author_username: str
    author_first_name: Optional[str]
    author_main_photo_url: Optional[str]
    activity_id: Optional[UUID]
    title: Optional[str]
    content: str
    content_type: str
    view_count: int
    comment_count: int
    reaction_count: int
    is_pinned: bool
    created_at: datetime
    updated_at: datetime

# Response: Post feed
class PostFeedResponse(BaseModel):
    posts: List[PostListItem]
    pagination: PaginationMeta
