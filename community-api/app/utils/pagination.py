from typing import List, TypeVar, Generic
from pydantic import BaseModel

T = TypeVar('T')

class PaginationMeta(BaseModel):
    limit: int
    offset: int
    total_count: int

class PaginatedResponse(BaseModel, Generic[T]):
    items: List[T]
    pagination: PaginationMeta

def build_pagination_response(
    items: List[T],
    total_count: int,
    limit: int,
    offset: int
) -> PaginatedResponse[T]:
    """Build paginated response"""
    return PaginatedResponse(
        items=items,
        pagination=PaginationMeta(
            limit=limit,
            offset=offset,
            total_count=total_count
        )
    )
