# Render Backend Production Environment Variables Guide

This document lists all environment variables required to deploy the **CareConnect Django DRF Backend** on Render.

> [!IMPORTANT]
> **Security Notice:** Do NOT commit real secret values to repository source code. Configure these environment variables directly inside the Render Dashboard (**`careconnect-backend` -> Environment**).

---

## 1. Django Core Configuration

| Environment Variable | Recommended Production Value | Description |
|---|---|---|
| `SECRET_KEY` | `generateValue: true` or random 64-char string | Cryptographic key for Django session and JWT signing. |
| `DEBUG` | `False` | Disables debug mode and diagnostic tracebacks. |
| `ALLOWED_HOSTS` | `careconnect-backend.onrender.com,your-custom-domain.com` | Comma-separated list of allowed host domains. |
| `CORS_ALLOW_ALL_ORIGINS` | `False` | Set to `False` in production to restrict cross-origin access. |
| `CORS_ALLOWED_ORIGINS` | `https://your-admin-portal.vercel.app` | Comma-separated allowed frontend origins. |
| `CSRF_TRUSTED_ORIGINS` | `https://your-admin-portal.vercel.app` | Comma-separated trusted origins for CSRF POST requests. |

---

## 2. PostgreSQL Database

| Environment Variable | Recommended Production Value | Description |
|---|---|---|
| `DATABASE_URL` | `postgres://user:password@hostname:5432/dbname` | Full PostgreSQL connection string (auto-linked by Render). |
| `DB_NAME` | `careconnect_db` | Fallback database name if `DATABASE_URL` is not used. |
| `DB_USER` | `careconnect_user` | Fallback database user. |
| `DB_PASSWORD` | `<your-db-password>` | Fallback database password. |
| `DB_HOST` | `careconnect-db` | Fallback database hostname. |
| `DB_PORT` | `5432` | Database port. |

---

## 3. Redis & Celery Configuration

| Environment Variable | Recommended Production Value | Description |
|---|---|---|
| `REDIS_URL` | `redis://hostname:6379/0` | Connection string for Redis instance. |
| `CELERY_BROKER_URL` | `redis://hostname:6379/0` | Message broker URL for Celery background tasks. |
| `CELERY_RESULT_BACKEND` | `redis://hostname:6379/0` | Result backend for Celery task status. |
| `CHANNEL_LAYER_BACKEND` | `channels_redis.core.RedisChannelLayer` | Django Channels WebSocket layer backend. |

---

## 4. SMTP Email Configuration (Password Reset OTP & Notifications)

| Environment Variable | Recommended Production Value | Description |
|---|---|---|
| `EMAIL_BACKEND` | `django.core.mail.backends.smtp.EmailBackend` | Django email backend implementation. |
| `EMAIL_HOST` | `smtp.gmail.com` | SMTP email server hostname. |
| `EMAIL_PORT` | `587` | SMTP port (587 for TLS, 465 for SSL). |
| `EMAIL_USE_TLS` | `True` | Enables TLS encryption. |
| `EMAIL_HOST_USER` | `noreply@yourdomain.com` | Registered SMTP sender email address. |
| `EMAIL_HOST_PASSWORD` | `<your-app-password>` | SMTP authentication or App Password. |
| `DEFAULT_FROM_EMAIL` | `CareConnect <noreply@yourdomain.com>` | Default sender display header. |

---

## 5. SMS Gateway & Firebase FCM Push Notifications (Optional)

| Environment Variable | Recommended Production Value | Description |
|---|---|---|
| `TEXTBEE_API_KEY` | `<your-textbee-api-key>` | TextBee SMS gateway API key. |
| `TEXTBEE_DEVICE_ID` | `<your-textbee-device-id>` | TextBee gateway device identifier. |
| `FIREBASE_SERVICE_ACCOUNT_PATH` | `/app/serviceAccountKey.json` | Path to Firebase Admin SDK service account key. |

---

## 6. Media Storage Recommendation

> [!NOTE]
> Render free web services utilize ephemeral local disk storage. For persistent media uploads (resident ID documents, voice notes, avatar photos), set up an S3-compatible cloud storage bucket (e.g. AWS S3 / Cloudflare R2 / DigitalOcean Spaces) in production.
