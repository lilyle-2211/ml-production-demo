"""
Configuration validation using Pydantic.
"""
from pathlib import Path
from typing import List

import yaml
from pydantic import BaseModel, ConfigDict, Field, field_validator


class BigQueryConfig(BaseModel):
    """BigQuery data source configuration."""

    project_id: str = Field(description="GCP project ID")
    table_name: str = Field(description="Full BigQuery table name with backticks")


class GCSConfig(BaseModel):
    """GCS storage configuration."""

    bucket_name: str = Field(description="GCS bucket name for model storage")
    model_path: str = Field(description="Path to model in GCS bucket")


class DataConfig(BaseModel):
    """Data splitting configuration."""

    test_frac: float = Field(gt=0, lt=1, description="Test set fraction")
    val_frac: float = Field(gt=0, lt=1, description="Validation set fraction")
    random_state: int = Field(ge=0, description="Random state for reproducibility")

    @field_validator("test_frac", "val_frac")
    @classmethod
    def validate_fraction(cls, v: float) -> float:
        """Ensure fractions are reasonable."""
        if v > 0.5:
            raise ValueError("Fraction should not exceed 0.5")
        return v


class HyperparameterRange(BaseModel):
    """Hyperparameter search range."""

    min: float = Field(description="Minimum value")
    max: float = Field(description="Maximum value")
    log: bool = Field(default=False, description="Use log scale")
    type: str = Field(default="float", description="Parameter type: float or int")


class ModelConfig(BaseModel):
    """Model training configuration."""

    n_trials: int = Field(gt=0, description="Number of Optuna trials")
    num_boost_round: int = Field(gt=0, description="Maximum boosting rounds")
    early_stopping_rounds: int = Field(gt=0, description="Early stopping rounds")
    fixed_params: dict = Field(default_factory=dict, description="Fixed XGBoost parameters")
    hyperparameter_ranges: dict[str, HyperparameterRange] = Field(
        default_factory=dict, description="Hyperparameter search ranges"
    )

    model_config = ConfigDict(extra="allow")


class FeaturesConfig(BaseModel):
    """Feature definitions."""

    numeric: List[str] = Field(min_length=1, description="Numeric feature columns")
    categorical: List[str] = Field(description="Categorical feature columns")

    @property
    def all_features(self) -> List[str]:
        """Get all feature columns."""
        return self.numeric + self.categorical


class Config(BaseModel):
    """Main configuration."""

    model_config = ConfigDict(arbitrary_types_allowed=True)

    bigquery: BigQueryConfig
    gcs: GCSConfig
    data: DataConfig
    model: ModelConfig
    features: FeaturesConfig

    @field_validator("data")
    @classmethod
    def validate_data_splits(cls, v: DataConfig) -> DataConfig:
        """Ensure train/val/test splits sum to less than 1."""
        total = v.test_frac + v.val_frac
        if total >= 1.0:
            raise ValueError(
                f"test_frac ({v.test_frac}) + val_frac ({v.val_frac}) "
                f"must be less than 1.0, got {total}"
            )
        return v


def load_config(config_path: str = "config.yaml") -> Config:
    """
    Load and validate configuration from YAML file.

    Args:
        config_path: Path to the YAML configuration file

    Returns:
        Validated Config object

    Raises:
        FileNotFoundError: If config file doesn't exist
        ValidationError: If config is invalid
    """
    config_file = Path(config_path)

    if not config_file.exists():
        raise FileNotFoundError(f"Configuration file not found: {config_path}")

    with open(config_file, "r") as f:
        config_dict = yaml.safe_load(f)

    return Config(**config_dict)
