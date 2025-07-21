# crud.py
from sqlmodel import Session, select
from fastapi import HTTPException
import datetime
import models, schemas
from database import engine


def get_meters(household_token: str) -> list[schemas.MeterOut]:
    """
    Return a list of MeterOut for all meters in the given household,
    including computed `current_month_units`.
    """
    today = datetime.date.today()
    first_of_month = datetime.date(today.year, today.month, 1)

    with Session(engine) as sess:
        meters = sess.exec(
            select(models.Meter).where(models.Meter.household_token == household_token)
        ).all()

        result: list[schemas.MeterOut] = []
        for m in meters:
            # 1) total_units: most recent ever
            latest_value = (
                sess.exec(
                    select(models.Reading.reading_value)
                    .where(models.Reading.meter_id == m.id)
                    .order_by(models.Reading.reading_time.desc())
                    .limit(1)
                ).first()
                or 0.0
            )

            # 2) Determine start_val for this month
            sr = sess.exec(
                select(models.StartReading).where(
                    models.StartReading.meter_id == m.id,
                    models.StartReading.year == today.year,
                    models.StartReading.month == today.month,
                )
            ).one_or_none()

            if sr:
                start_val = sr.reading_value
            else:
                # Fallback to last reading before this month
                start_val = (
                    sess.exec(
                        select(models.Reading.reading_value)
                        .where(
                            models.Reading.meter_id == m.id,
                            models.Reading.reading_date < first_of_month,
                        )
                        .order_by(models.Reading.reading_time.desc())
                        .limit(1)
                    ).first()
                    or 0.0
                )

            # 3) Determine end_of_month: latest reading this month
            end_val = (
                sess.exec(
                    select(models.Reading.reading_value)
                    .where(
                        models.Reading.meter_id == m.id,
                        models.Reading.reading_date >= first_of_month,
                    )
                    .order_by(models.Reading.reading_time.desc())
                    .limit(1)
                ).first()
                or start_val
            )

            current_month_units = end_val - start_val

            result.append(
                schemas.MeterOut(
                    id=m.id,
                    name=m.name,
                    total_units=latest_value,
                    current_month_units=current_month_units,
                )
            )
        return result


def get_summary(household_token: str) -> schemas.HomeSummary:
    """
    Return aggregated summary for a household.
    """
    meters = get_meters(household_token)
    home_total = sum(m.total_units for m in meters)
    home_current = sum(m.current_month_units for m in meters)
    return schemas.HomeSummary(
        meters=meters, home_total=home_total, home_current_month=home_current
    )


def get_monthly_data(meter_id: str, year: int, month: int) -> schemas.MonthlyData:
    """
    Return the start reading and list of entries for a given meter/year/month.
    Each entry includes date, full timestamp, reading, and poster name.
    """
    with Session(engine) as sess:
        # 1) Fetch or default start reading
        sr = sess.exec(
            select(models.StartReading).where(
                models.StartReading.meter_id == meter_id,
                models.StartReading.year == year,
                models.StartReading.month == month,
            )
        ).one_or_none()
        start_val = sr.reading_value if sr else 0.0

        # 2) Date bounds
        first_day = datetime.date(year, month, 1)
        if month == 12:
            next_month = datetime.date(year + 1, 1, 1)
        else:
            next_month = datetime.date(year, month + 1, 1)

        # 3) Fetch readings in range
        entries = sess.exec(
            select(models.Reading)
            .where(
                models.Reading.meter_id == meter_id,
                models.Reading.reading_date >= first_day,
                models.Reading.reading_date < next_month,
            )
            .order_by(models.Reading.reading_time.desc())
        ).all()

        return schemas.MonthlyData(
            start_reading=start_val,
            entries=[
                schemas.EntryOut(
                    id=e.id,  
                    date=e.reading_time.date(),
                    time=e.reading_time,
                    reading=e.reading_value,
                    posted_by=e.posted_by,
                )
                for e in entries
            ],
        )


def set_start_reading(meter_id: str, year: int, month: int, reading: float):
    """
    Explicitly set or reset the start reading for a meter/month.
    """
    with Session(engine) as sess:
        # Delete existing if any
        existing = sess.exec(
            select(models.StartReading).where(
                models.StartReading.meter_id == meter_id,
                models.StartReading.year == year,
                models.StartReading.month == month,
            )
        ).all()
        for sr in existing:
            sess.delete(sr)
        sess.commit()

        # Add new
        sr = models.StartReading(
            meter_id=meter_id, year=year, month=month, reading_value=reading
        )
        sess.add(sr)
        sess.commit()


def add_reading(
    meter_id: str,
    reading_date: datetime.date,
    reading_val: float,
    posted_by: str,
    reading_time: datetime.datetime
) -> int:
    with Session(engine) as sess:
        m = sess.get(models.Meter, meter_id)
        if not m:
            raise HTTPException(status_code=404, detail="Meter not found")

        y, mo = reading_date.year, reading_date.month

        # Ensure start_reading exists
        sr = sess.exec(
            select(models.StartReading).where(
                models.StartReading.meter_id == meter_id,
                models.StartReading.year == y,
                models.StartReading.month == mo,
            )
        ).one_or_none()

        if not sr:
            raise HTTPException(
                status_code=400,
                detail="Cannot add entry: start reading not set for this month.",
            )

        # Ensure date matches selected month/year
        if y != sr.year or mo != sr.month:
            raise HTTPException(
                status_code=400,
                detail=f"Entry date {reading_date} must be within {sr.year}-{sr.month}.",
            )

        start_val = sr.reading_value

        # Get previous most entry for this month
        # prev_entry = sess.exec(
        #     select(models.Reading)
        #     .where(
        #         models.Reading.meter_id == meter_id,
        #         models.Reading.reading_date >= datetime.date(y, mo, 1),
        #         models.Reading.reading_date <= reading_date,
        #     )
        #     .order_by(
        #         models.Reading.reading_date.desc(), models.Reading.reading_time.desc()
        #     )
        # ).first()

        # prev_val = prev_entry.reading_value if prev_entry else start_val

        # # Enforce that new reading is not less than previous
        # if reading_val < prev_val:
        #     raise HTTPException(
        #         status_code=400,
        #         detail=f"New reading ({reading_val}) cannot be less than previous ({prev_val}).",
        #     )

        # Enforce freeze on primary meter
        new_total = reading_val - start_val

        level = 0
        if new_total > 200:
            level = 4
        elif new_total > 190:
            level = 3
        elif new_total > 180:
            level = 2
        elif new_total > 170:
            level = 1

        # Insert reading
        r = models.Reading(
            meter_id=m.id,
            reading_date=reading_date,
            reading_value=reading_val,
            posted_by=posted_by,
            reading_time=reading_time,
        )
        sess.add(r)
        sess.commit()
        return level


def has_start_reading(meter_id: str, year: int, month: int) -> bool:
    with Session(engine) as sess:
        exists = sess.exec(
            select(models.StartReading).where(
                models.StartReading.meter_id == meter_id,
                models.StartReading.year == year,
                models.StartReading.month == month,
            )
        ).first()
        return exists is not None

def delete_entry(entry_id: str):
    with Session(engine) as sess:
        entry = sess.get(models.Reading, entry_id)
        if not entry:
            raise HTTPException(status_code=404, detail="Entry not found")
        sess.delete(entry)
        sess.commit()
