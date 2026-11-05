FROM python:3.12-slim-bookworm AS builder

WORKDIR /app

RUN python -m venv /opt/venv

COPY requirements.txt .

RUN /opt/venv/bin/pip install \
    --no-cache-dir \
    -r requirements.txt


FROM python:3.12-slim-bookworm

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TMPDIR=/tmp

WORKDIR /app

COPY --from=builder /opt/venv /opt/venv
COPY app.py .

RUN groupadd --system --gid 1001 appuser && \
    useradd --system --uid 1001 --gid 1001 appuser

USER 1001:1001

EXPOSE 5000

CMD ["gunicorn", "--no-control-socket", "--bind", "0.0.0.0:5000", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
