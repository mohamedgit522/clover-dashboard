# Stage 1 - Builder
FROM python:3.11-slim AS builder

WORKDIR /app

COPY app/requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

# Stage 2 - Runtime
FROM python:3.11-slim

WORKDIR /app

# Create non-root user
RUN useradd -m appuser

COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY app/ .

RUN chown -R appuser:appuser /app
USER appuser

EXPOSE 8080

CMD ["python", "app.py"]