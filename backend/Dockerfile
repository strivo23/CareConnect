FROM python:3.12-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    gcc \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install python dependencies
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt gunicorn daphne whitenoise

# Copy project files
COPY . /app/

# Collect static files
RUN python manage.py collectstatic --noinput || true

EXPOSE 8000

# Default entry command
CMD ["daphne", "-b", "0.0.0.0", "-p", "8000", "careconnect.asgi:application"]
