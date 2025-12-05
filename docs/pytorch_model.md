# ChurnClassifier Neural Network Explained

## **Architecture Overview**

This is a **3-layer feedforward neural network** (also called Multi-Layer Perceptron) for binary classification:

```
Input (10 features) → [32 neurons] → [16 neurons] → [1 neuron] → Output (probability)
```

---

## **Line-by-Line Breakdown**

### **1. Class Definition**
```python
class ChurnClassifier(nn.Module):
```
- Inherits from `nn.Module` (PyTorch's base class for all neural networks)
- This gives you access to `.parameters()`, `.train()`, `.eval()`, etc.

---

### **2. Initialization (`__init__`)**
```python
def __init__(self, input_dim: int):
    super().__init__()
```
- `input_dim`: Number of input features (in your case: 10 features from config.yaml)
- `super().__init__()`: Calls parent class constructor to initialize PyTorch module properly

#### **Layer 1: Input → Hidden Layer 1**
```python
self.fc1 = nn.Linear(input_dim, 32)
```
- **`fc1`** = "Fully Connected layer 1"
- **`nn.Linear(input_dim, 32)`**: Creates a linear transformation: `y = Wx + b`
  - `W`: Weight matrix of shape `[input_dim, 32]` (e.g., 10×32 = 320 parameters)
  - `b`: Bias vector of shape `[32]` (32 parameters)
  - **Total**: 320 + 32 = **352 parameters**
- **Purpose**: Transforms 10 input features into 32 hidden features

#### **Layer 2: Hidden Layer 1 → Hidden Layer 2**
```python
self.fc2 = nn.Linear(32, 16)
```
- Takes 32 neurons from previous layer
- Outputs 16 neurons
- **Parameters**: (32 × 16) + 16 = **528 parameters**
- **Purpose**: Further compresses information, learns more abstract patterns

#### **Layer 3: Hidden Layer 2 → Output**
```python
self.fc3 = nn.Linear(16, 1)
```
- Takes 16 neurons from previous layer
- Outputs **1 neuron** (binary classification: churn probability)
- **Parameters**: (16 × 1) + 1 = **17 parameters**
- **Purpose**: Final decision layer

**Total Model Parameters**: 352 + 528 + 17 = **897 parameters**

---

### **3. Forward Pass (`forward`)**
```python
def forward(self, x):
```
- Defines how data flows through the network
- `x`: Input tensor of shape `[batch_size, input_dim]` (e.g., `[256, 10]`)

#### **Step 1: First Hidden Layer + Activation**
```python
x = torch.relu(self.fc1(x))
```
- **`self.fc1(x)`**: Linear transformation → shape `[256, 32]`
- **`torch.relu()`**: ReLU activation function
  - ReLU(x) = max(0, x)
  - Introduces **non-linearity** (without this, stacked linear layers = one linear layer)
  - Helps network learn complex patterns
  - Sets negative values to 0, keeps positive values unchanged

#### **Step 2: Second Hidden Layer + Activation**
```python
x = torch.relu(self.fc2(x))
```
- **`self.fc2(x)`**: Linear transformation → shape `[256, 16]`
- **`torch.relu()`**: Another ReLU activation
- Network is now learning higher-level abstractions

#### **Step 3: Output Layer + Sigmoid**
```python
x = torch.sigmoid(self.fc3(x))
```
- **`self.fc3(x)`**: Linear transformation → shape `[256, 1]` (raw logits)
- **`torch.sigmoid()`**: Sigmoid activation
  - Formula: σ(x) = 1 / (1 + e^(-x))
  - Squashes any value into range **[0, 1]**
  - Interprets as **probability of churn**
  - Output: 0.0 = definitely won't churn, 1.0 = definitely will churn

#### **Step 4: Return**
```python
return x
```
- Returns tensor of shape `[256, 1]` with churn probabilities for each sample

---

## **Visual Representation**

```
Input: [f_0, f_1, ..., f_9]  (10 features)
         ↓
    [32 neurons] ← fc1 + ReLU
         ↓
    [16 neurons] ← fc2 + ReLU
         ↓
    [1 neuron]   ← fc3 + Sigmoid
         ↓
Output: 0.73 (73% probability of churn)
```

---

## **Why This Architecture?**

1. **Funnel Shape (10 → 32 → 16 → 1)**:
   - First expands to capture patterns (32 neurons)
   - Then compresses to essential features (16 neurons)
   - Finally reduces to single prediction

2. **ReLU Activation**:
   - Fast to compute
   - Avoids vanishing gradients
   - Introduces non-linearity for complex patterns

3. **Sigmoid Output**:
   - Required for binary classification
   - Works with BCELoss (Binary Cross Entropy)
   - Gives interpretable probabilities

4. **Simple & Lightweight**:
   - Only 897 parameters (vs XGBoost which can have millions)
   - Fast training and inference
   - Good baseline for 100M rows

---

## **Example Prediction**

```python
# Input: One customer with 10 features
input = torch.FloatTensor([[0.5, 1.2, -0.3, ..., 2.1]])  # [1, 10]

# Forward pass:
hidden1 = relu(fc1(input))    # [1, 32]
hidden2 = relu(fc2(hidden1))  # [1, 16]
output = sigmoid(fc3(hidden2)) # [1, 1] → 0.73

# Interpretation: 73% chance this customer will churn
```

---

## **Training Process**

### **Loss Function: Binary Cross Entropy (BCE)**
```python
criterion = nn.BCELoss()
```
- Measures difference between predicted probability and actual label
- Formula: `-[y * log(ŷ) + (1-y) * log(1-ŷ)]`
- Penalizes confident wrong predictions more heavily

### **Optimizer: Adam**
```python
optimizer = torch.optim.Adam(model.parameters(), lr=0.001)
```
- Adaptive learning rate optimizer
- Adjusts learning rate per parameter
- Learning rate: 0.001 (controls step size during gradient descent)

### **Training Loop**
```python
for epoch in range(50):
    for X_batch, y_batch in train_loader:  # Process 256 samples at a time
        optimizer.zero_grad()               # Reset gradients
        outputs = model(X_batch)            # Forward pass
        loss = criterion(outputs, y_batch)  # Calculate loss
        loss.backward()                     # Backpropagation
        optimizer.step()                    # Update weights
```

---

## **Model Performance**

From the latest training run:

- **Test ROC AUC**: 0.7611 (76.11% - ability to rank positive/negative samples)
- **Test PR AUC**: 0.4939 (49.39% - precision-recall trade-off)
- **Training Time**: ~50 epochs
- **Data Size**: 190,979 records (138k train, 18k val, 34k test)


---

## **Full Code**

See [`pytorch_trainer.py`](./pytorch_trainer.py) for the complete implementation.
