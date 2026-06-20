from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, EmailStr
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import insert
from typing import Optional
from app.database import get_db
from app.models import Inquiry

router = APIRouter()


class InquiryIn(BaseModel):
    name:    str
    email:   EmailStr
    phone:   Optional[str] = None
    message: str
    car_id:  Optional[int] = None


@router.post("", status_code=201)
async def create_inquiry(body: InquiryIn, db: AsyncSession = Depends(get_db)):
    if len(body.message) < 5:
        raise HTTPException(status_code=422, detail="Message too short")

    await db.execute(
        insert(Inquiry).values(
            name=body.name,
            email=body.email,
            phone=body.phone,
            message=body.message,
            car_id=body.car_id,
        )
    )
    await db.commit()
    return {"status": "received", "message": "We'll be in touch soon!"}
