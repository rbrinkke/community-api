import asyncpg
from typing import List, Dict, Any
import structlog
from app.core.database import Database
from app.core.errors import parse_db_error, raise_http_exception

logger = structlog.get_logger()

async def execute_stored_procedure(
    db: Database,
    procedure_name: str,
    **kwargs
) -> List[Dict[str, Any]]:
    """
    Execute a stored procedure and return results

    Args:
        db: Database instance
        procedure_name: Full procedure name (e.g., 'activity.sp_community_create')
        **kwargs: Procedure parameters

    Returns:
        List of result rows as dictionaries

    Raises:
        HTTPException: With appropriate status code and error details
    """
    # Build parameter list
    params = []
    param_placeholders = []
    for i, (key, value) in enumerate(kwargs.items(), start=1):
        params.append(value)
        param_placeholders.append(f'${i}')

    # Build query
    query = f"SELECT * FROM {procedure_name}({', '.join(param_placeholders)})"

    logger.debug(
        "executing_stored_procedure",
        procedure=procedure_name,
        params={k: str(v)[:50] for k, v in kwargs.items()}
    )

    try:
        async with db.get_connection() as conn:
            rows = await conn.fetch(query, *params)

            # Convert to list of dicts
            results = [dict(row) for row in rows]

            logger.debug(
                "stored_procedure_success",
                procedure=procedure_name,
                row_count=len(results)
            )

            return results

    except asyncpg.exceptions.RaiseError as e:
        # Database raised custom error
        error_code = parse_db_error(str(e))
        logger.warning(
            "stored_procedure_error",
            procedure=procedure_name,
            error_code=error_code,
            error_message=str(e)
        )
        raise_http_exception(error_code)

    except asyncpg.exceptions.PostgresError as e:
        # Other database error
        logger.error(
            "database_error",
            procedure=procedure_name,
            error=str(e),
            code=e.sqlstate
        )
        raise_http_exception("DATABASE_ERROR")

    except Exception as e:
        # Unexpected error
        logger.error(
            "unexpected_error",
            procedure=procedure_name,
            error=str(e),
            error_type=type(e).__name__
        )
        raise_http_exception("INTERNAL_ERROR")
