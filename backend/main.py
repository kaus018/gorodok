"""Backend приложения «ГородОК»: FastAPI + Firebase Admin SDK."""
import base64
import os
import time
from datetime import datetime
from pathlib import Path
from typing import Optional

import firebase_admin
from fastapi import Depends, FastAPI, Header, HTTPException, Query
from firebase_admin import auth, credentials, firestore
from pydantic import BaseModel, Field, model_validator

BASE_DIR = Path(__file__).resolve().parent

# Категории те же, что в мобильном приложении (NewReportScreen._cats)
CATEGORIES = ["Яма на дороге", "Освещение", "Мусор", "Благоустройство", "Другое"]
MAX_PHOTO_BYTES = 700_000  # запас до предела документа Firestore (1 МиБ)


# =========================
# FIREBASE INITIALIZATION
# =========================

if not firebase_admin._apps:
    credential_path = os.getenv(
        "GOOGLE_APPLICATION_CREDENTIALS",
        str(BASE_DIR / "serviceAccountKey.json"),
    )
    firebase_admin.initialize_app(credentials.Certificate(credential_path))

db = firestore.client()

app = FastAPI(
    title="ГородОК API",
    description="Backend для мобильного приложения ГородОК",
    version="1.1.0",
)


# =========================
# MODELS
# =========================

class Report(BaseModel):
    title: str = Field(min_length=1, max_length=150)
    description: str = Field(default="", max_length=3000)
    category: str
    photo: str = Field(min_length=1)  # фотография в формате base64
    address: str = Field(default="", max_length=300)
    lat: Optional[float] = Field(default=None, ge=-90, le=90)
    lng: Optional[float] = Field(default=None, ge=-180, le=180)
    date: str = Field(default="", max_length=30)  # дата для показа (с устройства)

    @model_validator(mode="after")
    def check_rules(self):
        if self.category not in CATEGORIES:
            raise ValueError("Недопустимая категория")
        try:
            raw = base64.b64decode(self.photo, validate=True)
        except ValueError:
            raise ValueError("Фотография должна быть в формате base64")
        if len(raw) > MAX_PHOTO_BYTES:
            raise ValueError("Фотография слишком большая")
        has_coords = self.lat is not None and self.lng is not None
        if not has_coords and not self.address.strip():
            raise ValueError("Укажите место: координаты или адрес")
        return self


# =========================
# AUTHENTICATION
# =========================

def get_current_user(authorization: Optional[str] = Header(default=None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Требуется вход в систему")

    token = authorization.split(" ", 1)[1]

    try:
        decoded = auth.verify_id_token(token)
    except Exception:
        raise HTTPException(status_code=401, detail="Недействительный или просроченный токен")

    return {"uid": decoded["uid"], "email": decoded.get("email", "")}


def to_items(documents) -> list:
    """Документы Firestore -> список словарей, новые обращения первыми."""
    items = []
    for doc in documents:
        item = doc.to_dict()
        item["id"] = doc.id
        items.append(item)
    items.sort(key=lambda x: x.get("ts", 0), reverse=True)
    return items


# =========================
# HEALTH CHECK
# =========================

@app.get("/")
def home():
    return {"message": "ГородОК Backend is running"}


# =========================
# GET ALL REPORTS
# =========================

@app.get("/reports")
def get_reports(
    category: Optional[str] = None,
    limit: int = Query(default=50, ge=1, le=200),
    user=Depends(get_current_user),
):
    query = db.collection("reports")
    if category:
        query = query.where("category", "==", category)
    return to_items(query.stream())[:limit]


# =========================
# GET MY REPORTS
# =========================

@app.get("/reports/mine")
def get_my_reports(user=Depends(get_current_user)):
    query = db.collection("reports").where("author", "==", user["email"])
    return to_items(query.stream())


# =========================
# CREATE REPORT
# =========================

@app.post("/reports", status_code=201)
def create_report(report: Report, user=Depends(get_current_user)):
    data = report.model_dump()

    # Автор и время определяются сервером, а не передаются клиентом.
    data["author"] = user["email"]
    data["ts"] = int(time.time() * 1000)  # миллисекунды, как в приложении
    if not data["date"]:
        data["date"] = datetime.now().strftime("%d.%m.%Y %H:%M")

    _, ref = db.collection("reports").add(data)
    return {"message": "Обращение успешно создано", "id": ref.id}


# =========================
# DELETE REPORT
# =========================

@app.delete("/reports/{report_id}")
def delete_report(report_id: str, user=Depends(get_current_user)):
    document = db.collection("reports").document(report_id)
    snapshot = document.get()

    if not snapshot.exists:
        raise HTTPException(status_code=404, detail="Обращение не найдено")

    if snapshot.to_dict().get("author") != user["email"]:
        raise HTTPException(status_code=403, detail="Нельзя удалить чужое обращение")

    document.delete()
    return {"message": "Обращение удалено"}


# =========================
# STATISTICS
# =========================

@app.get("/stats")
def stats(user=Depends(get_current_user)):
    counts = {name: 0 for name in CATEGORIES}
    for doc in db.collection("reports").stream():
        name = doc.to_dict().get("category", "Другое")
        counts[name] = counts.get(name, 0) + 1
    return counts
