
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

from typing_extensions import Optional
import pytz

# Define Pakistan timezone
pk_tz = pytz.timezone('Asia/Karachi')



from typing import Optional
import datetime
from fastapi import Body, HTTPException

# assume pk_tz is defined earlier (your PK timezone, e.g. pytz.timezone("Asia/Karachi"))
# from your code it looked like you have pk_tz variable already

@app.post("/home/{home_id}/meters/{meter_id}/entries")
def post_entry(
    meter_id: str,
    date: datetime.date = Body(..., embed=True),
    reading: float = Body(..., embed=True),
    name: str = Body(..., embed=True),
    posting_date: Optional[datetime.date] = Body(None, embed=True)
):  
    import datetime
    # Current time in Pakistan
    now_in_pk = datetime.datetime.now(pk_tz)
    reading_time = datetime.datetime.combine(
    posting_date if posting_date else now_in_pk.date(),
    now_in_pk.time()
    )
    print(reading_time)
    level = crud.add_reading(meter_id, date, reading, name, reading_time)
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



from fastapi import FastAPI, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse
from excel_service import ExcelExportService
import io
import crud
import models
from database import engine
from sqlalchemy.orm import Session


@app.get("/home/{home_id}/meters/{meter_id}/export-excel")
async def export_meter_excel(
    home_id: str,
    meter_id: str,
    meter_name:str,
    year: int = datetime.datetime.now().year
):
    """Export meter readings to Excel for a specific year"""
    try:
        # All the heavy lifting is done in crud.py
        excel_buffer = crud.create_excel_export(meter_id, year)
        
        # Create filename
        filename = f"{meter_name}_{year}_readings.xlsx"
        
        return StreamingResponse(
            io.BytesIO(excel_buffer.read()),
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            headers={
                "Content-Disposition": f"attachment; filename={filename}",
                "Content-Type": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            }
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Excel export failed: {str(e)}")