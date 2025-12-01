"""Simple PyTorch neural network for churn prediction."""
import sys
from pathlib import Path

import torch
import torch.nn as nn
from sklearn.preprocessing import StandardScaler
from torch.utils.data import DataLoader, TensorDataset

# Add parent directory to path to import from trainer
sys.path.append(str(Path(__file__).parent.parent / "trainer"))

from data_loader import load_data_from_bigquery  # noqa: E402
from data_preprocessing import time_ordered_split  # noqa: E402
from validation import load_config  # noqa: E402


class ChurnClassifier(nn.Module):
    """Simple neural network for churn classification."""

    def __init__(self, input_dim: int):
        super().__init__()
        self.fc1 = nn.Linear(input_dim, 32)
        self.fc2 = nn.Linear(32, 16)
        self.fc3 = nn.Linear(16, 1)

    def forward(self, x):
        x = torch.relu(self.fc1(x))
        x = torch.relu(self.fc2(x))
        x = torch.sigmoid(self.fc3(x))
        return x


def train_model(model, X_train, y_train, X_val, y_val, epochs=50, device="cpu"):
    """Train the model."""
    # Scale features
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_val_scaled = scaler.transform(X_val)

    # Convert to tensors
    X_train_t = torch.FloatTensor(X_train_scaled)
    y_train_t = torch.FloatTensor(y_train.to_numpy()).reshape(-1, 1)
    X_val_t = torch.FloatTensor(X_val_scaled).to(device)
    y_val_t = torch.FloatTensor(y_val.to_numpy()).reshape(-1, 1).to(device)

    # Create data loaders
    train_dataset = TensorDataset(X_train_t, y_train_t)
    train_loader = DataLoader(train_dataset, batch_size=256, shuffle=True)

    # Setup training
    criterion = nn.BCELoss()
    optimizer = torch.optim.Adam(model.parameters(), lr=0.001)

    # Training loop
    for epoch in range(epochs):
        model.train()
        for X_batch, y_batch in train_loader:
            X_batch, y_batch = X_batch.to(device), y_batch.to(device)

            optimizer.zero_grad()
            outputs = model(X_batch)
            loss = criterion(outputs, y_batch)
            loss.backward()
            optimizer.step()

        # Validation
        if (epoch + 1) % 10 == 0:
            model.eval()
            with torch.no_grad():
                val_outputs = model(X_val_t)
                val_loss = criterion(val_outputs, y_val_t)
                print(f"Epoch {epoch+1}/{epochs} - Val Loss: {val_loss:.4f}")

    return model, scaler


def main():
    """Run simple PyTorch churn prediction."""
    # Load configuration from trainer/config.yaml
    config_path = Path(__file__).parent.parent / "trainer" / "config.yaml"
    config = load_config(str(config_path))

    # Load data from BigQuery
    print("Loading data from BigQuery...")
    df = load_data_from_bigquery(config)

    # Split data
    print("Splitting data...")
    feature_cols = config.features.all_features
    X_train, y_train, X_val, y_val, X_test, y_test = time_ordered_split(
        df, config.data.test_frac, config.data.val_frac, feature_cols, label_col="is_churn"
    )
    print(f"Train: {len(X_train)}, Val: {len(X_val)}, Test: {len(X_test)}")

    # Train model
    print("Training model...")
    model = ChurnClassifier(input_dim=X_train.shape[1])
    model, scaler = train_model(model, X_train, y_train, X_val, y_val, epochs=50)

    # Evaluate on test set
    print("\nEvaluating on test set...")
    from sklearn.metrics import average_precision_score, roc_auc_score

    X_test_scaled = scaler.transform(X_test)
    X_test_t = torch.FloatTensor(X_test_scaled)

    model.eval()
    with torch.no_grad():
        test_pred = model(X_test_t).numpy().flatten()

    # Calculate AUC metrics
    y_test_np = y_test.to_numpy()
    roc_auc = roc_auc_score(y_test_np, test_pred)
    pr_auc = average_precision_score(y_test_np, test_pred)

    print(f"Test ROC AUC: {roc_auc:.4f}")
    print(f"Test PR AUC:  {pr_auc:.4f}")

    # Save model with metrics
    torch.save(
        {
            "model_state_dict": model.state_dict(),
            "scaler": scaler,
            "input_dim": X_train.shape[1],
            "metrics": {"roc_auc": float(roc_auc), "pr_auc": float(pr_auc)},
        },
        "churn_model.pt",
    )
    print("Model saved to churn_model.pt")

    return model, {"roc_auc": roc_auc, "pr_auc": pr_auc}


if __name__ == "__main__":
    model, metrics = main()
