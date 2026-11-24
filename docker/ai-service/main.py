import os
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="iCloudEMS Student Feedback Sentiment API")

POSITIVE = {"good", "great", "helpful", "fast", "excellent", "smooth", "clear", "love"}
NEGATIVE = {"slow", "bad", "crash", "error", "broken", "delay", "poor", "hate", "down"}

class FeedbackRequest(BaseModel):
    text: str

@app.get("/health")
def health():
    return {"status": "ok", "model": os.getenv("MODEL_NAME", "distilbert-sentiment-lite")}

@app.post("/predict")
def predict(req: FeedbackRequest):
    words = set(req.text.lower().split())
    pos = len(words & POSITIVE)
    neg = len(words & NEGATIVE)
    if pos > neg:
        label, score = "POSITIVE", round(min(0.99, 0.70 + 0.1 * pos), 2)
    elif neg > pos:
        label, score = "NEGATIVE", round(min(0.99, 0.70 + 0.1 * neg), 2)
    else:
        label, score = "NEUTRAL", 0.50
    return {"label": label, "confidence": score, "text": req.text}
