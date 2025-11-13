import asyncpg
from contextlib import asynccontextmanager
from typing import AsyncGenerator, Optional
import structlog
from app.config import settings

logger = structlog.get_logger()

class Database:
    def __init__(self):
        self.pool: Optional[asyncpg.Pool] = None

    async def connect(self):
        """Create connection pool"""
        logger.info("connecting_to_database", url=settings.DATABASE_URL.split('@')[1] if '@' in settings.DATABASE_URL else "localhost")
        self.pool = await asyncpg.create_pool(
            settings.DATABASE_URL,
            min_size=settings.DB_POOL_MIN_SIZE,
            max_size=settings.DB_POOL_MAX_SIZE,
            command_timeout=60
        )
        logger.info("database_connected")

    async def disconnect(self):
        """Close connection pool"""
        if self.pool:
            await self.pool.close()
            logger.info("database_disconnected")

    @asynccontextmanager
    async def get_connection(self) -> AsyncGenerator[asyncpg.Connection, None]:
        """Get connection from pool"""
        if not self.pool:
            raise RuntimeError("Database pool not initialized")

        async with self.pool.acquire() as connection:
            yield connection

db = Database()

async def get_db() -> Database:
    """Dependency for getting database instance"""
    return db
