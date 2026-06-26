FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN useradd -u 10001 -r -m -d /home/appuser -s /usr/sbin/nologin appuser \
 && chmod +x /app/run.sh \
 && chown -R appuser:appuser /app /home/appuser

USER appuser

EXPOSE 5500

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD curl -fsS http://127.0.0.1:5500/health || exit 1

ENTRYPOINT ["/app/run.sh"]
