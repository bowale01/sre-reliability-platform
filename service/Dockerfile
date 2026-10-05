# ---- Build a small, non-root, production-ready image ----
FROM python:3.12-slim AS base

# Prevent Python from writing .pyc files and buffering stdout/stderr.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Install dependencies first for better layer caching.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code.
COPY app ./app

# Run as a non-root user.
RUN useradd --create-home --uid 10001 appuser
USER appuser

EXPOSE 8080

# ddtrace-run auto-instruments FastAPI/uvicorn for Datadog APM.
# If DD_AGENT_HOST is unset, ddtrace simply no-ops on trace submission.
CMD ["ddtrace-run", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
