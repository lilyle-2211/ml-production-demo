"""Pydantic models for API request/response schemas."""
from pydantic import BaseModel, Field


class PredictionInput(BaseModel):
    """Input schema for single prediction."""

    f_0: float
    f_1: float
    f_2: float
    f_3: float
    f_4: float
    months_since_signup: int
    calendar_month: int = Field(ge=1, le=12)
    signup_month: int = Field(ge=1, le=12)
    is_first_month: int = Field(ge=0, le=1)


class PredictionOutput(BaseModel):
    """Output schema for prediction response."""

    churn_probability: float
    churn_prediction: int
    model_version: str
