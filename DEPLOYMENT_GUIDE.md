# CareConnect Production Deployment & Hosting Guide

This guide details step-by-step procedures to deploy the **CareConnect Django DRF Backend** and **React Admin Portal** to production cloud hosts.

---

## Architecture Overview

- **Backend:** Django 6.0 REST Framework, Channels (WebSockets), Daphne / Gunicorn, PostgreSQL 16, Redis 7, Celery Worker & Beat.
- **Frontend Admin Portal:** React 19, Vite, MUI, Chart.js, Nginx SPA Web Server.

---

## Option 1: Docker Compose Single-Server Hosting (Recommended for VPS / AWS EC2 / DigitalOcean)

### Prerequisites
- Linux server (Ubuntu 22.04 LTS / 24.04 LTS recommended)
- Docker 24+ & Docker Compose v2+ installed

### Step-by-Step Instructions

1. **Clone repository onto host server:**
   ```bash
   git clone <repository_url>
   cd CareConnect
   ```

2. **Configure environment variables:**
   ```bash
   cp backend/.env.production.example backend/.env.production
   nano backend/.env.production
   ```
   Set `SECRET_KEY`, `ALLOWED_HOSTS`, `CORS_ALLOWED_ORIGINS`, and `POSTGRES_PASSWORD`.

3. **Build & launch the container stack:**
   ```bash
   docker compose -f docker-compose.prod.yml up -d --build
   ```

4. **Run database migrations inside the backend container:**
   ```bash
   docker compose -f docker-compose.prod.yml exec backend python manage.py migrate
   ```

5. **Create initial Superuser / Admin account:**
   ```bash
   docker compose -f docker-compose.prod.yml exec backend python manage.py createsuperuser
   ```

6. **Verify status:**
   - Admin Portal: `http://your-server-ip/`
   - Backend API: `http://your-server-ip:8000/api/`

---

## Option 2: Render / Railway Cloud PaaS Hosting

### Backend Deployment (Render / Railway)
1. Create a **PostgreSQL Database** on Render/Railway.
2. Create a **Redis instance** on Render/Railway.
3. Deploy a **Web Service** connected to the `backend/` directory.
   - **Build Command:** `pip install -r requirements.txt && python manage.py collectstatic --noinput && python manage.py migrate`
   - **Start Command:** `daphne -b 0.0.0.0 -p $PORT careconnect.asgi:application`
   - **Environment Variables:**
     - `DEBUG=False`
     - `SECRET_KEY=<your_generated_secret_key>`
     - `DATABASE_URL=<your_postgres_database_url>`
     - `REDIS_URL=<your_redis_url>`
     - `CORS_ALLOW_ALL_ORIGINS=True`

4. Deploy **Background Worker Service** (Celery):
   - **Start Command:** `celery -A careconnect worker -l info`

5. Deploy **Background Scheduler Service** (Celery Beat):
   - **Start Command:** `celery -A careconnect beat -l info`

---

### React Admin Portal Deployment (Vercel / Netlify)

#### Deploying on Vercel
1. Connect your repository to Vercel.
2. Set Root Directory to `admin-portal`.
3. Add Environment Variable:
   - `VITE_API_BASE_URL=https://your-backend-api.onrender.com/api`
4. Deploy! (`vercel.json` will handle SPA rewrites automatically).

#### Deploying on Netlify
1. Connect repository to Netlify.
2. Set Base directory to `admin-portal`.
3. Set Build command to `npm run build` and Publish directory to `admin-portal/dist`.
4. Add Environment Variable:
   - `VITE_API_BASE_URL=https://your-backend-api.onrender.com/api`
5. Deploy! (`_redirects` handles SPA client-side routing automatically).

---

## Useful Maintenance Commands

- **Check Backend Logs:**
  ```bash
  docker compose -f docker-compose.prod.yml logs -f backend
  ```
- **Check Celery Logs:**
  ```bash
  docker compose -f docker-compose.prod.yml logs -f celery_worker
  ```
- **Restart Services:**
  ```bash
  docker compose -f docker-compose.prod.yml restart
  ```
