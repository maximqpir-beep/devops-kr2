FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN groupadd --system app \
    && useradd --system --gid app --home-dir /app --no-create-home app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY --chown=app:app app.py ./

USER app

EXPOSE 8002

CMD ["gunicorn", "--bind", "0.0.0.0:8002", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
