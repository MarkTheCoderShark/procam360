# FieldVision Deployment Guide

## Prerequisites

- Node.js 18+
- Railway account
- Supabase account
- Apple Developer account

## 1. Supabase Setup

### Create Project
1. Go to [supabase.com](https://supabase.com) and create a new project
2. Note your project region (choose closest to your users)

### Get Credentials
From Project Settings > API:
- `SUPABASE_URL` - Project URL
- `SUPABASE_ANON_KEY` - anon/public key
- `SUPABASE_SERVICE_KEY` - service_role key (keep secret!)

From Project Settings > Database:
- `DATABASE_URL` - Connection string (use pooling mode for production)
- Add `?pgbouncer=true` to the URL for connection pooling

### Storage Setup
1. Go to Storage in your Supabase dashboard
2. Create a new bucket named `media`
3. Set bucket to **public** (for photo access)
4. Enable RLS policies as needed

## 2. Railway Deployment

### Deploy Backend
```bash
cd backend

# Install Railway CLI
npm install -g @railway/cli

# Login and init
railway login
railway init

# Link to project
railway link

# Deploy
railway up
```

### Environment Variables
Set these in Railway dashboard (Settings > Variables):

```
DATABASE_URL=postgresql://...?pgbouncer=true
DIRECT_URL=postgresql://...
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_KEY=eyJ...
JWT_SECRET=your-secure-random-string
JWT_REFRESH_SECRET=another-secure-random-string
PORT=3000
NODE_ENV=production
```

### Database Migration
```bash
# Run in Railway shell or locally with prod DATABASE_URL
npx prisma migrate deploy
```

### Get Your Production URL
After deployment, Railway provides a URL like:
`https://fieldvision-backend-production.up.railway.app`

Update `FieldVision/Core/Constants.swift`:
```swift
case .production:
    return "https://your-railway-url.up.railway.app"
```

## 3. App Store Connect Setup

### Create App
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Create new app with bundle ID `com.mark.procam360`

### Subscription Setup
1. Go to App > Subscriptions
2. Create subscription group: "FieldVision Pro"
3. Add products:

| Product ID | Type | Price |
|------------|------|-------|
| `com.fieldvision.pro.monthly` | Auto-Renewable | $9.99/month |
| `com.fieldvision.pro.annual` | Auto-Renewable | $99.99/year |

4. Add localization for each product

### StoreKit Configuration (Development)
For testing in Simulator:
1. In Xcode, go to Product > Scheme > Edit Scheme
2. Add StoreKit Configuration file
3. Create products matching the IDs above

## 4. iOS App Configuration

### Update Constants
Edit `FieldVision/Core/Constants.swift`:
- Set production API URL after Railway deployment

### Xcode Settings
1. Select the FieldVision target
2. Signing & Capabilities:
   - Set your Team
   - Enable "In-App Purchase" capability
3. Build Settings:
   - Set `PRODUCT_BUNDLE_IDENTIFIER` to match App Store Connect

### Archive and Upload
```bash
# In Xcode:
# 1. Set scheme to "Any iOS Device"
# 2. Product > Archive
# 3. Distribute App > App Store Connect
```

## 5. Post-Deployment Checklist

- [ ] Backend health check passes (`GET /health`)
- [ ] Database migrations applied
- [ ] Supabase storage bucket accessible
- [ ] iOS app connects to production API
- [ ] Subscriptions load in PaywallView
- [ ] Test purchase flow with sandbox account
- [ ] Push notifications configured (APNs)

## Environment Variables Reference

| Variable | Description | Required |
|----------|-------------|----------|
| `DATABASE_URL` | Postgres connection (pooled) | Yes |
| `DIRECT_URL` | Postgres direct connection (migrations) | Yes |
| `SUPABASE_URL` | Supabase project URL | Yes |
| `SUPABASE_ANON_KEY` | Supabase public key | Yes |
| `SUPABASE_SERVICE_KEY` | Supabase service key | Yes |
| `JWT_SECRET` | Access token signing | Yes |
| `JWT_REFRESH_SECRET` | Refresh token signing | Yes |
| `PORT` | Server port (default: 3000) | No |
| `NODE_ENV` | Environment (production) | Yes |

## Troubleshooting

### Database Connection Issues
- Ensure `?pgbouncer=true` is in DATABASE_URL
- Check Railway logs for connection errors
- Verify Supabase password hasn't changed

### Storage Upload Failures
- Check Supabase Storage bucket exists and is public
- Verify SUPABASE_SERVICE_KEY is set correctly
- Check file size limits in Supabase dashboard

### Subscription Not Loading
- Verify product IDs match App Store Connect exactly
- Check StoreKit entitlements in Xcode
- Ensure app is signed with correct Team

### API Timeouts
- Check Railway instance isn't sleeping (free tier)
- Verify DATABASE_URL uses connection pooling
- Check Supabase region latency
