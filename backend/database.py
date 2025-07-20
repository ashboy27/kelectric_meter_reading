from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlmodel import SQLModel
import os
from dotenv import load_dotenv

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    raise ValueError("DATABASE_URL is not set!")

if '?' in DATABASE_URL:
    DATABASE_URL = DATABASE_URL.split('?')[0]

engine = create_engine(
    DATABASE_URL,
    connect_args={
        "sslmode": "require",
        "sslrootcert": "/etc/ssl/certs/ca-certificates.crt",
    },
    pool_pre_ping=True,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def init_db():
    SQLModel.metadata.create_all(bind=engine)
