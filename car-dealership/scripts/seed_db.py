#!/usr/bin/env python3
"""
seed_db.py – Populate the car dealership DB with realistic sample inventory.

Usage:
  DB_HOST=... DB_USER=... DB_PASSWORD=... DB_NAME=... python scripts/seed_db.py

Or inside the cluster:
  kubectl run seed --image=<backend-image> --rm -it --restart=Never \
    --env-from secret/backend-db-secret -- python scripts/seed_db.py
"""

import asyncio
import os
import sys
from pathlib import Path

# Add backend to path
sys.path.insert(0, str(Path(__file__).parent.parent / 'backend'))

from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

DB_URL = (
    f"postgresql+asyncpg://"
    f"{os.environ['DB_USER']}:{os.environ['DB_PASSWORD']}"
    f"@{os.environ['DB_HOST']}:{os.environ.get('DB_PORT','5432')}"
    f"/{os.environ['DB_NAME']}"
)

CARS = [
    dict(make="Toyota",    model="Camry",     year=2023, trim="XSE",         price=31500,  mileage=8200,  color="Midnight Black",  fuel_type="Gasoline",   transmission="Automatic", condition="used",  vin="4T1BF1FK5EU123456"),
    dict(make="Honda",     model="Civic",     year=2024, trim="Sport",        price=27990,  mileage=0,     color="Sonic Gray Pearl", fuel_type="Gasoline",   transmission="CVT",       condition="new",   vin="2HGFE2F59RH100001"),
    dict(make="Ford",      model="F-150",     year=2022, trim="XLT 4x4",      price=45800,  mileage=22000, color="Oxford White",    fuel_type="Gasoline",   transmission="Automatic", condition="used",  vin="1FTFW1E53NFA12345"),
    dict(make="Tesla",     model="Model 3",   year=2023, trim="Long Range",   price=48990,  mileage=5100,  color="Pearl White",     fuel_type="Electric",   transmission="Single",    condition="used",  vin="5YJ3E1EA8PF345678"),
    dict(make="BMW",       model="3 Series",  year=2023, trim="330i xDrive",  price=53000,  mileage=12000, color="Alpine White",    fuel_type="Gasoline",   transmission="Automatic", condition="used",  vin="WBA5R7C55LFH23456"),
    dict(make="Chevrolet", model="Tahoe",     year=2022, trim="LT",           price=58900,  mileage=31000, color="Iridescent Pearl", fuel_type="Gasoline",  transmission="Automatic", condition="used",  vin="1GNSCBKC5NR234567"),
    dict(make="Mercedes",  model="C-Class",   year=2024, trim="C 300",        price=51500,  mileage=0,     color="Obsidian Black",  fuel_type="Gasoline",   transmission="9G-Tronic", condition="new",   vin="W1KWF8EB5RG000123"),
    dict(make="Toyota",    model="RAV4",      year=2023, trim="Hybrid XSE",   price=38500,  mileage=14200, color="Cavalry Blue",    fuel_type="Hybrid",     transmission="CVT",       condition="used",  vin="4T3RWRFV3PU012345"),
    dict(make="Audi",      model="Q5",        year=2023, trim="Premium Plus", price=57200,  mileage=9800,  color="Glacier White",   fuel_type="Gasoline",   transmission="Automatic", condition="used",  vin="WA1BNAFY3P2045678"),
    dict(make="Honda",     model="CR-V",      year=2024, trim="Hybrid EX-L",  price=39900,  mileage=0,     color="Sonic Gray Pearl", fuel_type="Hybrid",    transmission="CVT",       condition="new",   vin="7FARW2H83RE000456"),
    dict(make="Ford",      model="Mustang",   year=2023, trim="GT Premium",   price=52000,  mileage=3200,  color="Race Red",        fuel_type="Gasoline",   transmission="Manual",    condition="used",  vin="1FA6P8CF7P5100789"),
    dict(make="Tesla",     model="Model Y",   year=2024, trim="Performance",  price=58990,  mileage=0,     color="Midnight Silver", fuel_type="Electric",   transmission="Single",    condition="new",   vin="7SAYGDEF1RF123456"),
    dict(make="Jeep",      model="Wrangler",  year=2022, trim="Rubicon 4xe",  price=62000,  mileage=18500, color="Hydro Blue",      fuel_type="Plug-in",    transmission="Automatic", condition="used",  vin="1C4JJXR65NW234567"),
    dict(make="Toyota",    model="Highlander",year=2023, trim="Limited",      price=49800,  mileage=10200, color="Midnight Black",  fuel_type="Gasoline",   transmission="Automatic", condition="used",  vin="5TDHZRBH6NS012345"),
    dict(make="Chevrolet", model="Corvette",  year=2023, trim="Stingray Z51", price=79000,  mileage=1200,  color="Amplify Orange",  fuel_type="Gasoline",   transmission="DCT",       condition="used",  vin="1G1YB2D41P5100012"),
    dict(make="BMW",       model="X5",        year=2024, trim="xDrive40i",    price=73500,  mileage=0,     color="Carbon Black",    fuel_type="Gasoline",   transmission="Automatic", condition="new",   vin="5UXKR6C51P9K00456"),
    dict(make="Ford",      model="Explorer",  year=2023, trim="ST",           price=55200,  mileage=16700, color="Atlas Blue",      fuel_type="Gasoline",   transmission="Automatic", condition="used",  vin="1FM5K8GC8PGB23456"),
    dict(make="Honda",     model="Accord",    year=2024, trim="Touring",      price=37900,  mileage=0,     color="Lunar Silver",    fuel_type="Hybrid",     transmission="CVT",       condition="new",   vin="1HGCY2F89RA012345"),
    dict(make="Audi",      model="A4",        year=2023, trim="Premium",      price=42000,  mileage=20100, color="Florett Silver",  fuel_type="Gasoline",   transmission="S-Tronic",  condition="used",  vin="WAUEAAF40PN012345"),
    dict(make="Toyota",    model="4Runner",   year=2023, trim="TRD Pro",      price=57600,  mileage=7900,  color="Cavalry Blue",    fuel_type="Gasoline",   transmission="Automatic", condition="used",  vin="JTEEU5JR8P5012345"),
]

async def seed():
    engine = create_async_engine(DB_URL, echo=False)
    Session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    # Late import so DB_URL is resolved first
    from app.database import Base
    from app.models import Car

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with Session() as session:
        for car_data in CARS:
            session.add(Car(**car_data))
        await session.commit()
        print(f"✅ Seeded {len(CARS)} cars into the database.")

    await engine.dispose()


if __name__ == '__main__':
    asyncio.run(seed())
