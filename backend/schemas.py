# schemas.py
from pydantic import BaseModel
from uuid import UUID
import datetime
from typing import List

class MeterOut(BaseModel):
    id: UUID
    name: str
    total_units: float
    current_month_units: float   # NEW field

    class Config:
        orm_mode = True

class EntryOut(BaseModel):
    id: UUID
    date: datetime.date
    time: datetime.datetime      # NEW: full timestamp
    reading: float
    posted_by: str

class MonthlyData(BaseModel):
    start_reading: float
    entries: List[EntryOut]

class HomeSummary(BaseModel):        # NEW schema
    meters: List[MeterOut]
    home_total: float
    home_current_month: float