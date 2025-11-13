from pydantic import BaseModel
from typing import Literal
from uuid import UUID
from datetime import datetime

# Request: Create/update reaction
class ReactionCreateRequest(BaseModel):
    reaction_type: Literal['like', 'love', 'celebrate', 'support', 'insightful']

# Response: Reaction created/updated
class ReactionCreateResponse(BaseModel):
    reaction_id: UUID
    target_type: str
    target_id: UUID
    reaction_type: str
    created_at: datetime

# Response: Reaction deleted
class ReactionDeleteResponse(BaseModel):
    deleted: bool

# Request: Link activity to community
class CommunityActivityLinkRequest(BaseModel):
    activity_id: UUID

# Response: Activity linked
class CommunityActivityLinkResponse(BaseModel):
    community_id: UUID
    activity_id: UUID
    created_at: datetime
