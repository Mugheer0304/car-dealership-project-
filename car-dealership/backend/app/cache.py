import os
import json
import redis.asyncio as aioredis

REDIS_HOST = os.environ.get("REDIS_HOST", "localhost")
REDIS_PORT = int(os.environ.get("REDIS_PORT", "6379"))
REDIS_PASSWORD = os.environ.get("REDIS_PASSWORD", "")
REDIS_TLS = os.environ.get("REDIS_TLS", "true").lower() == "true"

CAR_LIST_TTL = 300   # 5 minutes


async def get_redis_pool():
    return await aioredis.from_url(
        f"rediss://{REDIS_HOST}:{REDIS_PORT}" if REDIS_TLS else f"redis://{REDIS_HOST}:{REDIS_PORT}",
        password=REDIS_PASSWORD or None,
        decode_responses=True,
        max_connections=20,
    )


async def cache_get(redis, key: str):
    value = await redis.get(key)
    return json.loads(value) if value else None


async def cache_set(redis, key: str, value, ttl: int = CAR_LIST_TTL):
    await redis.setex(key, ttl, json.dumps(value))
