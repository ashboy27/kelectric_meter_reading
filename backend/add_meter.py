from models import Meter
from database import engine
from sqlmodel import Session
from uuid import uuid4

meters = [
    Meter(id=uuid4(), name="First Floor Meter", is_primary=False, household_token="hardcoded_home_id_123"),
    Meter(id=uuid4(), name="Second Floor Meter", is_primary=True, household_token="hardcoded_home_id_123")
]

with Session(engine) as session:
    session.add_all(meters)
    session.commit()

print("✅ Two meters added successfully!")
