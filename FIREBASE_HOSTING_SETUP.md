# Firebase Hosting Setup for Auditra Web App

Complete guide to host your Auditra web app on Firebase Hosting.

## Prerequisites

1. **Node.js installed** (for Firebase CLI)
   - Check: `node --version`
   - Download: https://nodejs.org/

2. **Google Account** (for Firebase)

## Step 1: Install Firebase CLI

```bash
npm install -g firebase-tools
```

Verify installation:
```bash
firebase --version
```

## Step 2: Login to Firebase

```bash
firebase login
```

This will open your browser to authenticate with Google.

## Step 3: Initialize Firebase in Your Project

```bash
cd "auditra web app"
firebase init hosting
```

**Follow the prompts:**

1. **Select Firebase features:** Choose `Hosting`
2. **Select a default Firebase project:** 
   - Choose `Create a new project` (or select existing)
   - Enter project name: `auditra-web` (or your preferred name)
3. **What do you want to use as your public directory?** 
   - Enter: `.` (current directory)
4. **Configure as a single-page app?** 
   - Enter: `No` (unless you want SPA routing)
5. **Set up automatic builds and deploys with GitHub?** 
   - Enter: `No` (for now)
6. **File index.html already exists. Overwrite?** 
   - Enter: `No`

## Step 4: Configure Firebase Hosting

Firebase will create `firebase.json`. Verify it looks like this:

```json
{
  "hosting": {
    "public": ".",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
```

## Step 5: Update API URL (Important!)

Before deploying, update your API endpoints in the HTML files:

**In `client-form.html` and `employee-form.html`:**

Find the API URL field and update the default value, or add this script:

```javascript
// Update API URL for production
const API_BASE_URL = 'https://your-backend-domain.com/api';
// Or keep localhost for development
// const API_BASE_URL = 'http://localhost:8000/api';
```

## Step 6: Deploy to Firebase

```bash
firebase deploy --only hosting
```

**First deployment will ask:**
- "Firebase Hosting requires a site. Would you like to create one now?"
- Enter: `Yes`

## Step 7: Access Your Site

After deployment, Firebase will provide a URL like:
```
https://auditra-web.web.app
https://auditra-web.firebaseapp.com
```

## Step 8: Custom Domain (Optional)

1. Go to Firebase Console: https://console.firebase.google.com
2. Select your project
3. Go to **Hosting** → **Add custom domain**
4. Enter your domain name
5. Follow DNS configuration instructions

## Configuration Files

### firebase.json (Auto-generated)
```json
{
  "hosting": {
    "public": ".",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ],
    "headers": [
      {
        "source": "**/*.@(jpg|jpeg|gif|png|svg|webp|js|css)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "max-age=31536000"
          }
        ]
      }
    ]
  }
}
```

### .firebaserc (Auto-generated)
```json
{
  "projects": {
    "default": "auditra-web"
  }
}

```

## Updating Your Site

To update your site after making changes:

```bash
cd "auditra web app"
firebase deploy --only hosting
```

## Environment-Specific Deployments

### Development
```bash
firebase use default
firebase deploy --only hosting
```

### Production
```bash
firebase use production
firebase deploy --only hosting
```

## Firebase Hosting Features

✅ **Free SSL/HTTPS** - Automatic HTTPS certificates
✅ **Global CDN** - Fast content delivery worldwide
✅ **Custom Domains** - Use your own domain
✅ **Rollback** - Easy to revert to previous versions
✅ **Preview Channels** - Test before production
✅ **Free Tier** - 10 GB storage, 360 MB/day transfer

## Troubleshooting

### Error: "Firebase CLI not found"
```bash
npm install -g firebase-tools
```

### Error: "Permission denied"
```bash
firebase login --reauth
```

### Error: "Project not found"
```bash
firebase use --add
# Select or create project
```

### CORS Issues
Make sure your Django backend allows Firebase domain:
```python
# backend/auditra_backend/settings.py
CORS_ALLOWED_ORIGINS = [
    "https://auditra-web.web.app",
    "https://auditra-web.firebaseapp.com",
    "http://localhost:8000",  # For local development
]
```

## Quick Deploy Script

Create `deploy.sh`:

```bash
#!/bin/bash
echo "🚀 Deploying to Firebase..."

cd "auditra web app"
firebase deploy --only hosting

echo "✅ Deployment complete!"
echo "🌐 Your site: https://auditra-web.web.app"
```

Make executable:
```bash
chmod +x deploy.sh
./deploy.sh
```

## Next Steps

1. ✅ Deploy to Firebase
2. ✅ Update backend CORS settings
3. ✅ Test all forms and functionality
4. ✅ Set up custom domain (optional)
5. ✅ Configure environment variables if needed

## Firebase Console

Access your Firebase project:
https://console.firebase.google.com

View hosting:
https://console.firebase.google.com/project/YOUR_PROJECT/hosting

