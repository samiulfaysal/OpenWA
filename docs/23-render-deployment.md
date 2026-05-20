# OpenWA Deployment Guide: Render.com

## Critical Issue: "Couldn't link device" on Render

### Root Causes & Fixes Applied

Your "Couldn't link device" error after successful QR scan is caused by **7 critical issues**:

#### 1. **Missing Error Handlers** ✅ FIXED
- **Problem**: whatsapp-web.js client had no handlers for `error`, `auth_failure_reason`, or `change_state` events
- **Impact**: Browser crashes after QR scan were silently ignored, leaving session corrupted
- **Fix**: Added comprehensive error handlers to [whatsapp-web-js.adapter.ts](../src/engine/adapters/whatsapp-web-js.adapter.ts)
  - `client.on('error', ...)` - Catches unhandled Chromium errors
  - `client.on('auth_failure', ...)` - Logs detailed authentication failures  
  - `client.on('change_state', ...)` - Tracks state transitions for debugging

#### 2. **Unstable --single-process Flag** ✅ FIXED
- **Problem**: Puppeteer flag `--single-process` causes browser crashes under memory pressure
- **Impact**: Render's 350MB memory limit = immediate instability after QR scan
- **Fix**: Removed `--single-process` from puppeteer args
  - Single-process mode is for testing only
  - Multi-process is required for stability in production

#### 3. **Insufficient Memory Allocation** ✅ FIXED
- **Problem**: Node.js limited to 350MB (`--max-old-space-size=350`)
- **Impact**: Chromium (~200MB) + Node (~200MB) = -50MB (out of memory)
- **Fix**: Increased to 512MB (`--max-old-space-size=512`)
  - Chromium needs ~200MB
  - Node.js needs ~200MB  
  - 112MB buffer for garbage collection

#### 4. **Duplicate Puppeteer Arguments** ✅ FIXED
- **Problem**: Puppeteer args were built but then duplicated/spread again
- **Fix**: Consolidated args into single array in [whatsapp-web-js.adapter.ts](../src/engine/adapters/whatsapp-web-js.adapter.ts)

#### 5. **Session Data Path Issues** ✅ FIXED
- **Problem**: Relative path `./data/sessions` fails if process CWD changes
- **Impact**: LocalAuth can't persist session data between restarts
- **Fix**: 
  - Changed to absolute path `/app/data/sessions` in Dockerfile and env config
  - Added detailed logging around session path usage

#### 6. **Missing Initialization Error Handling** ✅ FIXED
- **Problem**: Engine initialization errors weren't properly caught or logged
- **Impact**: Failed initialization silently marked session as "DISCONNECTED" instead of "FAILED"
- **Fix**: Wrapped `initializeEngine()` in try-catch with proper status updates

#### 7. **Missing Chromium Optimization for Render** ✅ FIXED
- **Problem**: No environment variables to disable GPU or optimize for containerized environment
- **Fix**: Added Render-specific env vars in Dockerfile:
  ```dockerfile
  ENV DISABLE_GPU=true
  ENV NODE_OPTIONS=--use-strict-object-caches
  ```

---

## Step-by-Step Render Deployment

### Prerequisites
- Render account (free tier OK)
- GitHub repository connected to Render

### 1. Create New Web Service

1. Go to [render.com/dashboard](https://render.com/dashboard)
2. Click **"New +"** → **"Web Service"**
3. Select your GitHub repository (`samiulfaysal/OpenWA`)
4. Choose deployment settings:
   - **Name**: `openwa-backend` (or your choice)
   - **Environment**: `Docker`
   - **Branch**: `main`
   - **Root Directory**: Leave empty (uses root)
   - **Auto-Deploy**: Enable to auto-deploy on git push

### 2. Configure Environment Variables

Add these to Render dashboard under **Environment**:

```env
# CRITICAL: Use absolute path for Render
SESSION_DATA_PATH=/app/data/sessions

# Database (recommended: use Render PostgreSQL database)
DATABASE_TYPE=postgres
DATABASE_HOST=<your-render-postgres-host>
DATABASE_PORT=5432
DATABASE_NAME=<your-db-name>
DATABASE_USERNAME=<your-db-user>
DATABASE_PASSWORD=<your-db-password>
DATABASE_SYNCHRONIZE=false
DATABASE_LOGGING=false

# Engine
ENGINE_TYPE=whatsapp-web.js
PUPPETEER_HEADLESS=true
PUPPETEER_ARGS=--no-sandbox,--disable-setuid-sandbox,--disable-dev-shm-usage,--disable-gpu

# Chromium
PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

# Node optimization
NODE_ENV=production

# API
API_PORT=2785
LOG_LEVEL=info
```

### 3. Configure Instance Settings

- **Plan**: Free tier OK (has 0.5GB RAM)
- **Disk**: Free tier includes 1GB ephemeral disk
- **Advanced**:
  - Health Check Path: `/api/health`
  - Health Check Interval: 30 seconds
  - Timeout: 10 seconds

### 4. Deploy

Click **"Deploy"** and watch logs:

```bash
# Good signs:
✓ Chromium installed
✓ Node dependencies installed
✓ Application started
✓ Health check passing

# Bad signs to fix:
✗ Cannot find chromium → Check Dockerfile
✗ Out of memory → Memory limit too low
✗ Permission denied /app/data → Check directory permissions
```

---

## Monitoring After Deployment

### Check Logs

1. Go to Render dashboard → Your service
2. Click **"Logs"** tab
3. Look for these log patterns:

**Good initialization:**
```
[Engine] Initializing WhatsApp client for session: default
[Engine] Client created, setting up event handlers
[Engine] Starting client initialization
[Engine] QR code generated successfully
[Engine] Client authenticated with WhatsApp
[Engine] WhatsApp client ready: 1234567890
```

**Bad initialization (NEEDS FIX):**
```
[Engine] WhatsApp client error: session_closed
[Engine] Authentication failed: unknown reason
[Engine] Client disconnected: Browser crashed
```

### Test QR Scan

1. GET `/api/sessions` → Create a session:
   ```bash
   curl -X POST http://your-render-app.onrender.com/api/sessions \
     -H "Content-Type: application/json" \
     -d '{"name":"test-session"}'
   ```

2. POST `/api/sessions/{sessionId}/start` to start session
3. GET `/api/sessions/{sessionId}/qr` to get QR code
4. Scan QR with WhatsApp on phone
5. Check logs for "WhatsApp client ready"

---

## Troubleshooting

### Issue: "Couldn't link device" appears after QR scan

**Check logs for:**
```
WhatsApp client error: ...
Authentication failed: ...
Browser crashed: ...
```

**Solutions in order:**
1. Ensure `SESSION_DATA_PATH=/app/data/sessions` is set
2. Increase memory: Edit Render plan or modify Dockerfile to 768MB
3. Check free disk space in Render console
4. Restart service via Render dashboard
5. Delete session and try new QR scan

### Issue: "Out of memory" errors in logs

**Fix:**
- Edit [Dockerfile](../Dockerfile) line with `--max-old-space-size`
- Try: 768MB for reliability, 512MB minimum
- Redeploy

### Issue: Session doesn't persist across restarts

**Check:**
1. `SESSION_DATA_PATH` uses absolute path `/app/data/sessions`
2. Directory permissions: Should be writable by Node process
3. Render ephemeral disk isn't shared → Use PostgreSQL for session metadata
4. Session data files are actually being written (check via logs)

### Issue: Chromium not found error

**Fix:** Ensure Dockerfile Stage 2 includes:
```dockerfile
RUN apt-get update && apt-get install -y chromium ...
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
```

---

## Performance Optimization

### For Free Tier (0.5GB RAM)
- Use PostgreSQL database (external service)
- Limit concurrent sessions to 1-2
- Monitor memory usage regularly
- Consider 768MB if budget allows

### For Pro Tier (2GB+ RAM)
- Can support 5-10 concurrent sessions
- Increase heap to 768MB-1GB
- Consider adding Redis for caching

---

## Important Notes

⚠️ **Ephemeral Filesystem**: Render's free tier uses ephemeral disk that resets on redeploy
- Session data directory `/app/data/sessions` will be cleared on deploy
- User MUST re-scan QR code after deployment
- For persistence: Implement external storage (S3, database blob storage)

⚠️ **Memory Limits**: Free tier has strict 0.5GB limit
- Monitor logs for memory pressure warnings
- If seeing "Allowed memory exceeded", upgrade plan

✅ **Best Practices**:
- Always use absolute paths for persistent data
- Add comprehensive error logging (already done)
- Monitor health endpoint regularly
- Implement automatic session cleanup for failed sessions

---

## Related Documentation

- [System Architecture](./03-system-architecture.md#render-deployment)
- [DevOps Infrastructure](./10-devops-infrastructure.md)
- [API Specification](./06-api-specification.md#sessions)
