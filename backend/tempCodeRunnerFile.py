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
        print(entries)
        print("ashar")
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
