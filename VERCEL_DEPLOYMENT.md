# React Admin Portal — Vercel Production Deployment Guide

This guide details the steps to deploy the **CareConnect React Admin Portal** on Vercel.

---

## 1. Project Specifications

| Property | Value |
|---|---|
| **Framework** | Vite (React 19) |
| **Root Directory** | `admin-portal` |
| **Build Command** | `npm run build` |
| **Output Directory** | `dist` |
| **Node Version** | `20.x` |

---

## 2. Environment Variables

| Variable | Scope | Description | Example Value |
|---|---|---|---|
| `VITE_API_BASE_URL` | Public (Browser) | Base API endpoint of your Render backend. | `https://careconnect-backend.onrender.com/api` |

> [!CAUTION]
> **Security Notice:** Do NOT expose backend secrets (`DATABASE_PASSWORD`, `SECRET_KEY`, `SMTP_PASSWORD`) in Vercel environment variables. Frontend environment variables prefixed with `VITE_` are publicly accessible in browser bundles.

---

## 3. Step-by-Step Vercel Deployment

1. Sign in to **[vercel.com](https://vercel.com)** using your GitHub account.
2. Click **`Add New...`** -> select **`Project`**.
3. Select the GitHub repository: **`strivo23/CareConnect`**.
4. Configure Deployment Settings:
   - **Framework Preset:** Vite
   - **Root Directory:** Edit -> select `admin-portal`
   - **Build Command:** `npm run build`
   - **Output Directory:** `dist`
5. Expand **`Environment Variables`**:
   - Key: `VITE_API_BASE_URL`
   - Value: `https://your-render-backend.onrender.com/api`
6. Click **`Deploy`**!

---

## 4. SPA Client Routing (`vercel.json`)

Single Page Application (SPA) client-side routing is automatically configured via `admin-portal/vercel.json`:

```json
{
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
```

This guarantees that direct page navigation (e.g. `/login`, `/dashboard`, `/forgot-password`, `/society`) returns `index.html` with HTTP 200 instead of HTTP 404.
