# main.py  (replace or merge into your existing file)

from fastapi import FastAPI, Depends, Body, Query, Path
from fastapi.middleware.cors import CORSMiddleware
import crud, schemas
from database import init_db, SessionLocal
from sqlmodel import Session
from typing import List
import datetime

from pydantic import BaseModel

class StartReadingIn(BaseModel):
    year: int
    month: int
    reading: float

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
def on_startup():
    init_db()

@app.get("/home/{home_id}/meters", response_model=List[schemas.MeterOut])
def read_meters(home_id: str):
    return crud.get_meters(home_id)

@app.get("/home/{home_id}/summary", response_model=schemas.HomeSummary)  # NEW

def read_summary(home_id: str):
    return crud.get_summary(home_id)

@app.get("/home/{home_id}/meters/{meter_id}/data", response_model=schemas.MonthlyData)
def read_monthly(meter_id: str, year: int, month: int):
    return crud.get_monthly_data(meter_id, year, month)

@app.post("/home/{home_id}/meters/{meter_id}/startReading")
def post_start(
    meter_id: str,
    payload: StartReadingIn,          # <-- read from JSON body
):
    crud.set_start_reading(
        meter_id,
        payload.year,
        payload.month,
        payload.reading
    )
    return {"status": "ok"}

@app.post("/home/{home_id}/meters/{meter_id}/entries")
def post_entry(
    meter_id: str,
    date: datetime.date = Body(..., embed=True),
    reading: float = Body(..., embed=True),
    name: str = Body(..., embed=True),             # NEW
):
    level = crud.add_reading(meter_id, date, reading, name)
    return {"status": "ok", "level": level}


@app.get("/ping-db")
def ping_db(name: str = Depends(lambda: None), db: Session = Depends(lambda: SessionLocal())):
    try:
        db.execute("SELECT 1")
        return {"status": "connected"}
    except Exception as e:
        return {"status": "error", "detail": str(e)}
    
@app.get("/home/{home_id}/meters/{meter_id}/hasStart")
def has_start(
    meter_id: str = Path(...),
    year: int = Query(..., ge=2000),
    month: int = Query(..., ge=1, le=12)
):
    ok = crud.has_start_reading(meter_id, year, month)
    return {"has_start": ok}


@app.delete("/home/{home_id}/meters/{meter_id}/entries/{entry_id}")
def delete_entry(
    meter_id: str,
    entry_id: str = Path(..., description="ID of the entry to delete")
):
    crud.delete_entry(entry_id)
    return {"status": "deleted"}