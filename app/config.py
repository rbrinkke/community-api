from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    # Environment
    ENVIRONMENT: str = "development"
    DEBUG: bool = False

    # API
    API_V1_PREFIX: str = "/api/v1"
    PROJECT_NAME: str = "Activity Platform - Community API"

    # API Documentation (Swagger UI / OpenAPI)
    ENABLE_DOCS: bool = True
    API_VERSION: str = "1.0.0"

    # Database
    DATABASE_URL: str
    DB_POOL_MIN_SIZE: int = 10
    DB_POOL_MAX_SIZE: int = 20

    # Redis
    REDIS_URL: str

    # JWT (shared with auth-api)
    JWT_SECRET_KEY: str
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 15

    # Logging
    LOG_LEVEL: str = "INFO"

    # Rate Limiting
    RATE_LIMIT_ENABLED: bool = True

    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()
