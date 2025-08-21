FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    MPLBACKEND=Agg

RUN apt-get update && apt-get install -y --no-install-recommends \
      libfreetype6 \
      libpng16-16 \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir matplotlib

WORKDIR /app

COPY output.py .

CMD ["python", "output.py"]
