import os
from datetime import datetime
from typing import Optional

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlmodel import Field, Session, SQLModel, create_engine, select

os.makedirs("/app/data", exist_ok=True)
DATABASE_URL = "sqlite:////app/data/clipboard.db"
engine = create_engine(DATABASE_URL)


class ClipboardItem(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    content: str
    content_type: str = "text"
    created_at: str = Field(default_factory=lambda: datetime.now().isoformat())
    pinned: bool = False


class ClipboardCreate(BaseModel):
    content: str
    content_type: str = "text"


app = FastAPI(title="Clipboard History")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def on_startup():
    SQLModel.metadata.create_all(engine)


@app.get("/history", response_model=list[ClipboardItem])
def get_history(limit: int = 100, search: str = ""):
    with Session(engine) as session:
        stmt = select(ClipboardItem).order_by(ClipboardItem.id.desc()).limit(limit)
        items = session.exec(stmt).all()
        if search:
            items = [i for i in items if search.lower() in i.content.lower()]
        pinned = [i for i in items if i.pinned]
        unpinned = [i for i in items if not i.pinned]
        return pinned + unpinned


@app.post("/clipboard", response_model=ClipboardItem)
def add_item(payload: ClipboardCreate):
    content = payload.content.strip()
    if not content:
        raise HTTPException(status_code=400, detail="Empty content")
    with Session(engine) as session:
        last = session.exec(
            select(ClipboardItem).order_by(ClipboardItem.id.desc()).limit(1)
        ).first()
        if last and last.content == content:
            return last
        item = ClipboardItem(content=content, content_type=payload.content_type)
        session.add(item)
        session.commit()
        session.refresh(item)
        return item


@app.delete("/clipboard/{item_id}")
def delete_item(item_id: int):
    with Session(engine) as session:
        item = session.get(ClipboardItem, item_id)
        if not item:
            raise HTTPException(status_code=404, detail="Not found")
        session.delete(item)
        session.commit()
    return {"ok": True}


@app.patch("/clipboard/{item_id}/pin")
def toggle_pin(item_id: int):
    with Session(engine) as session:
        item = session.get(ClipboardItem, item_id)
        if not item:
            raise HTTPException(status_code=404, detail="Not found")
        item.pinned = not item.pinned
        session.commit()
        session.refresh(item)
    return item


@app.delete("/history")
def clear_history():
    with Session(engine) as session:
        items = session.exec(
            select(ClipboardItem).where(ClipboardItem.pinned == False)
        ).all()
        for item in items:
            session.delete(item)
        session.commit()
    return {"ok": True}


@app.get("/health")
def health():
    return {"status": "ok"}
