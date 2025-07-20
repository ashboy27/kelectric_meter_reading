# models.py
from sqlmodel import SQLModel, Field, Relationship
from typing import List, Optional
from uuid import UUID, uuid4
import datetime
from datetime import datetime
import pytz
from datetime import datetime, date

PK_TZ = pytz.timezone("Asia/Karachi")

def pk_now():
    return datetime.now(PK_TZ)

class Meter(SQLModel, table=True):
    id: UUID = Field(default=None, primary_key=True)
    name: str
    is_frozen: bool = Field(default=False)
    is_primary: bool = Field(default=False)
    household_token: str

    start_readings: List["StartReading"] = Relationship(back_populates="meter")
    readings:       List["Reading"]      = Relationship(back_populates="meter")

class StartReading(SQLModel, table=True):
    id: UUID = Field(default_factory=uuid4, primary_key=True)
    meter_id: UUID = Field(foreign_key="meter.id")
    year: int
    month: int
    reading_value: float

    meter: Meter = Relationship(back_populates="start_readings")

class Reading(SQLModel, table=True):
    __tablename__ = "readings"
    id: UUID = Field(default_factory=uuid4, primary_key=True)
    meter_id: UUID = Field(foreign_key="meter.id")
    
    reading_date: date
    reading_time: datetime = Field(default_factory=pk_now)
    reading_value: float
    posted_by: str = Field(default="")
    meter: Meter = Relationship(back_populates="readings")
