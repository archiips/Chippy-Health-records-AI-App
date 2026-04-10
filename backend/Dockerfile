FROM python:3.11-slim

WORKDIR /app

# System deps for PyMuPDF (MuPDF native libs)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libmupdf-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies first (cached layer if pyproject.toml unchanged)
COPY pyproject.toml .
RUN pip install --no-cache-dir .

# Copy source
COPY . .

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
