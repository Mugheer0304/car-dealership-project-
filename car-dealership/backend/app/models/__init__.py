from datetime import datetime
from sqlalchemy import String, Integer, Float, DateTime, Text, func
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base


class Car(Base):
    __tablename__ = "cars"

    id:           Mapped[int]      = mapped_column(Integer, primary_key=True, index=True)
    make:         Mapped[str]      = mapped_column(String(50), nullable=False, index=True)
    model:        Mapped[str]      = mapped_column(String(50), nullable=False, index=True)
    year:         Mapped[int]      = mapped_column(Integer, nullable=False, index=True)
    trim:         Mapped[str]      = mapped_column(String(100), nullable=True)
    price:        Mapped[float]    = mapped_column(Float, nullable=False)
    mileage:      Mapped[int]      = mapped_column(Integer, nullable=False, default=0)
    color:        Mapped[str]      = mapped_column(String(50), nullable=True)
    fuel_type:    Mapped[str]      = mapped_column(String(30), nullable=True)
    transmission: Mapped[str]      = mapped_column(String(30), nullable=True)
    condition:    Mapped[str]      = mapped_column(String(10), nullable=False, default="used")
    vin:          Mapped[str]      = mapped_column(String(17), unique=True, nullable=True)
    image_url:    Mapped[str]      = mapped_column(String(500), nullable=True)
    description:  Mapped[str]      = mapped_column(Text, nullable=True)
    available:    Mapped[bool]     = mapped_column(default=True)
    created_at:   Mapped[datetime] = mapped_column(DateTime, server_default=func.now())


class Inquiry(Base):
    __tablename__ = "inquiries"

    id:         Mapped[int]      = mapped_column(Integer, primary_key=True, index=True)
    name:       Mapped[str]      = mapped_column(String(100), nullable=False)
    email:      Mapped[str]      = mapped_column(String(200), nullable=False, index=True)
    phone:      Mapped[str]      = mapped_column(String(30), nullable=True)
    message:    Mapped[str]      = mapped_column(Text, nullable=False)
    car_id:     Mapped[int]      = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
