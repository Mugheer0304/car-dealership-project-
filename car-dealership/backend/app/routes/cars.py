import hashlib
import json
from typing import Optional
from fastapi import APIRouter, Depends, Query, Request, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from pydantic import BaseModel

from app.database import get_db
from app.models import Car
from app.cache import cache_get, cache_set

router = APIRouter()


class CarOut(BaseModel):
    id: int
    make: str
    model: str
    year: int
    trim: Optional[str]
    price: float
    mileage: int
    color: Optional[str]
    fuel_type: Optional[str]
    transmission: Optional[str]
    condition: str
    image_url: Optional[str]
    description: Optional[str]

    class Config:
        from_attributes = True


@router.get("", response_model=dict)
async def list_cars(
    request: Request,
    make: Optional[str]      = Query(None),
    model: Optional[str]     = Query(None),
    year: Optional[int]      = Query(None),
    price_max: Optional[float] = Query(None, alias="priceMax"),
    condition: Optional[str] = Query(None),
    limit: int               = Query(12, le=100),
    offset: int              = Query(0),
    db: AsyncSession         = Depends(get_db),
):
    # Build a deterministic cache key from query params
    cache_key = "cars:" + hashlib.md5(
        f"{make}|{model}|{year}|{price_max}|{condition}|{limit}|{offset}".encode()
    ).hexdigest()

    redis = request.app.state.redis
    cached = await cache_get(redis, cache_key)
    if cached:
        return cached

    # DB query with optional filters
    filters = [Car.available == True]
    if make:      filters.append(Car.make.ilike(f"%{make}%"))
    if model:     filters.append(Car.model.ilike(f"%{model}%"))
    if year:      filters.append(Car.year == year)
    if price_max: filters.append(Car.price <= price_max)
    if condition: filters.append(Car.condition == condition)

    result = await db.execute(
        select(Car).where(and_(*filters)).order_by(Car.created_at.desc()).limit(limit).offset(offset)
    )
    cars = result.scalars().all()

    payload = {"cars": [CarOut.model_validate(c).model_dump() for c in cars], "total": len(cars)}
    await cache_set(redis, cache_key, payload, ttl=300)
    return payload


@router.get("/{car_id}", response_model=CarOut)
async def get_car(car_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Car).where(Car.id == car_id, Car.available == True))
    car = result.scalar_one_or_none()
    if not car:
        raise HTTPException(status_code=404, detail="Car not found")
    return car
