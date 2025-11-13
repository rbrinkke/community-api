from pydantic import BaseModel, Field, field_validator, HttpUrl
from typing import Optional, List, Literal
from uuid import UUID
from datetime import datetime
from app.models.common import PaginationMeta

# Request: Create community
class CommunityCreateRequest(BaseModel):
    organization_id: Optional[UUID] = None
    name: str = Field(..., min_length=1, max_length=255)
    slug: str = Field(..., min_length=1, max_length=100, pattern=r'^[a-z0-9-]+$')
    description: Optional[str] = Field(None, max_length=5000)
    community_type: Literal['open'] = 'open'  # Phase 1 restriction
    cover_image_url: Optional[HttpUrl] = None
    icon_url: Optional[HttpUrl] = None
    max_members: Optional[int] = Field(None, gt=0)
    tags: Optional[List[str]] = Field(None, max_length=20)

    @field_validator('tags')
    @classmethod
    def validate_tags(cls, v):
        if v:
            for tag in v:
                if len(tag) > 100:
                    raise ValueError('Each tag must be max 100 characters')
        return v

# Response: Community created
class CommunityCreateResponse(BaseModel):
    community_id: UUID
    slug: str
    created_at: datetime
    member_count: int

# Request: Update community
class CommunityUpdateRequest(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = Field(None, max_length=5000)
    cover_image_url: Optional[HttpUrl] = None
    icon_url: Optional[HttpUrl] = None
    max_members: Optional[int] = Field(None, gt=0)
    tags: Optional[List[str]] = None  # None = no change, [] = clear all

# Response: Community updated
class CommunityUpdateResponse(BaseModel):
    community_id: UUID
    updated_at: datetime

# Response: Community details
class CommunityDetailResponse(BaseModel):
    community_id: UUID
    organization_id: Optional[UUID]
    creator_user_id: UUID
    name: str
    slug: str
    description: Optional[str]
    community_type: str
    status: str
    member_count: int
    max_members: Optional[int]
    is_featured: bool
    cover_image_url: Optional[str]
    icon_url: Optional[str]
    created_at: datetime
    updated_at: datetime
    is_member: bool
    user_role: Optional[str]
    user_status: Optional[str]
    tags: List[str]

# Response: Community list item (for search)
class CommunityListItem(BaseModel):
    community_id: UUID
    organization_id: Optional[UUID]
    name: str
    slug: str
    description: Optional[str]
    community_type: str
    member_count: int
    max_members: Optional[int]
    is_featured: bool
    cover_image_url: Optional[str]
    icon_url: Optional[str]
    created_at: datetime
    is_member: bool
    tags: List[str]

# Response: Community search results
class CommunitySearchResponse(BaseModel):
    communities: List[CommunityListItem]
    pagination: PaginationMeta

# Response: Join community
class MembershipCreateResponse(BaseModel):
    community_id: UUID
    user_id: UUID
    role: str
    status: str
    joined_at: datetime

# Response: Leave community
class MembershipLeaveResponse(BaseModel):
    community_id: UUID
    user_id: UUID
    left_at: datetime

# Response: Member list item
class MemberListItem(BaseModel):
    user_id: UUID
    username: str
    first_name: Optional[str]
    last_name: Optional[str]
    main_photo_url: Optional[str]
    role: str
    status: str
    joined_at: datetime
    is_verified: bool

# Response: Member list
class MemberListResponse(BaseModel):
    members: List[MemberListItem]
    pagination: PaginationMeta
