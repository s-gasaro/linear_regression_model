"""
Prediction API for the marathon finish time model.
Serves the best-performing model (Random Forest) trained in Task 1.
"""

from pathlib import Path

import joblib
import pandas as pd
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, model_validator
from sklearn.ensemble import RandomForestRegressor
from sklearn.preprocessing import StandardScaler

# ---------------------------------------------------------------------------
# Model loading
# ---------------------------------------------------------------------------
BASE_DIR = Path(__file__).resolve().parent
MODEL_DIR = BASE_DIR.parent / "linear_regression"

model = joblib.load(MODEL_DIR / "best_model.pkl")
scaler = joblib.load(MODEL_DIR / "scaler.pkl")
FEATURES = joblib.load(MODEL_DIR / "feature_order.pkl")

app = FastAPI(
    title="Marathon Finish Time Prediction API",
    description="Predicts a runner's marathon finish time (in minutes) from their "
                "profile and first-half split times. Built for early talent "
                "identification in East African athletics.",
    version="1.0.0",
)

# ---------------------------------------------------------------------------
# CORS configuration
# Reasoning: origins are restricted to local development hosts used by the
# Flutter web preview and testing tools instead of a wildcard (*), so unknown
# websites cannot call the API from a browser. Only the two HTTP methods the
# API actually uses (POST for prediction/retraining, GET for docs and health)
# are allowed, and only the Content-Type header is needed since requests carry
# JSON or file uploads. Credentials are disabled because the API uses no
# cookies or authentication tokens. Note: the native Flutter mobile app is not
# affected by CORS, since CORS only applies to browsers.
# ---------------------------------------------------------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://localhost:8080",
        "http://127.0.0.1:8080",
    ],
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
    allow_credentials=False,
)


# ---------------------------------------------------------------------------
# Input schema: enforced data types and realistic range constraints
# Ranges are based on the Boston Marathon dataset (fastest elite splits to
# slowest recorded finishers).
# ---------------------------------------------------------------------------
class RunnerInput(BaseModel):
    age: int = Field(..., ge=18, le=85, description="Runner age in years")
    gender: str = Field(..., pattern="^[MF]$", description="M for male, F for female")
    k5: float = Field(..., ge=12, le=90, description="5K split time in minutes")
    k10: float = Field(..., ge=25, le=180, description="10K split time in minutes")
    k15: float = Field(..., ge=40, le=270, description="15K split time in minutes")
    k20: float = Field(..., ge=55, le=360, description="20K split time in minutes")
    half: float = Field(..., ge=58, le=380, description="Half-marathon split in minutes")

    @model_validator(mode="after")
    def splits_must_increase(self):
        splits = [self.k5, self.k10, self.k15, self.k20, self.half]
        if splits != sorted(splits):
            raise ValueError("Split times must increase: k5 < k10 < k15 < k20 < half")
        return self


class PredictionResponse(BaseModel):
    predicted_finish_minutes: float
    predicted_finish_formatted: str


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------
@app.get("/")
def health_check():
    return {"status": "ok", "docs": "/docs"}


@app.post("/predict", response_model=PredictionResponse)
def predict(runner: RunnerInput):
    """Predict the marathon finish time for one runner."""
    gender_encoded = 1 if runner.gender == "M" else 0
    row = pd.DataFrame(
        [[runner.age, gender_encoded, runner.k5, runner.k10,
          runner.k15, runner.k20, runner.half]],
        columns=FEATURES,
    )
    minutes = float(model.predict(scaler.transform(row))[0])
    hours, mins = divmod(round(minutes), 60)
    return PredictionResponse(
        predicted_finish_minutes=round(minutes, 1),
        predicted_finish_formatted=f"{hours}h{mins:02d}",
    )


@app.post("/retrain")
def retrain(file: UploadFile = File(...)):
    """
    Retrain the model when new data is uploaded.
    Expects a CSV with columns: Age, Gender_encoded, 5K_min, 10K_min,
    15K_min, 20K_min, Half_min, Finish_min. The uploaded data is combined
    with the original dataset, a new model and scaler are fitted, saved,
    and hot-swapped into the running API.
    """
    global model, scaler

    try:
        new_data = pd.read_csv(file.file)
    except Exception:
        raise HTTPException(status_code=400, detail="Uploaded file is not a valid CSV.")

    required_cols = FEATURES + ["Finish_min"]
    missing = [c for c in required_cols if c not in new_data.columns]
    if missing:
        raise HTTPException(status_code=400, detail=f"Missing columns: {missing}")

    original = pd.read_csv(MODEL_DIR / "data" / "boston_marathon_2015_2017.csv",
                           low_memory=False)
    original["Gender_encoded"] = (original["M/F"] == "M").astype(int)
    for col in ["5K", "10K", "15K", "20K", "Half", "Official Time"]:
        name = "Finish_min" if col == "Official Time" else f"{col}_min"
        original[name] = pd.to_timedelta(original[col], errors="coerce").dt.total_seconds() / 60

    combined = pd.concat(
        [original[required_cols].dropna(), new_data[required_cols].dropna()],
        ignore_index=True,
    )

    X, y = combined[FEATURES], combined["Finish_min"]
    new_scaler = StandardScaler().fit(X)
    new_model = RandomForestRegressor(n_estimators=100, max_depth=12,
                                      random_state=42, n_jobs=-1)
    new_model.fit(new_scaler.transform(X), y)

    joblib.dump(new_model, MODEL_DIR / "best_model.pkl", compress=3)
    joblib.dump(new_scaler, MODEL_DIR / "scaler.pkl")
    model, scaler = new_model, new_scaler

    return {
        "status": "retrained",
        "new_rows_received": len(new_data),
        "total_training_rows": len(combined),
    }