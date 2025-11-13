from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class PaginationMeta(BaseModel):
    limit: int
    offset: int
    total_count: int

class ErrorResponse(BaseModel):
    detail: str
    error_code: Optional[str] = None
    timestamp: datetime
