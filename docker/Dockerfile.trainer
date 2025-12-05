FROM python:3.12-slim

WORKDIR /app

# Copy project files needed for installation
COPY pyproject.toml ./
COPY trainer/ ./trainer/

# Install dependencies
RUN pip install uv && uv pip install --system .

# Set Python path to include trainer directory
ENV PYTHONPATH=/app:/app/trainer

# Set working directory to trainer so imports work
WORKDIR /app/trainer

# Default command
CMD ["python", "main.py"]
