# Hosting Guide for Auditra Web App

This guide covers multiple hosting options for your Auditra web application.

## Option 1: Static Hosting (Recommended for Simple HTML App)

### GitHub Pages (Free)

1. **Create a GitHub repository:**
   ```bash
   cd "auditra web app"
   git init
   git add .
   git commit -m "Initial commit"
   git remote add origin https://github.com/YOUR_USERNAME/auditra-web.git
   git push -u origin main
   ```

2. **Enable GitHub Pages:**
   - Go to repository Settings → Pages
   - Select branch: `main`
   - Select folder: `/ (root)`
   - Save

3. **Access your site:**
   - URL: `https://YOUR_USERNAME.github.io/auditra-web/`

### Netlify (Free, Easy)

1. **Install Netlify CLI:**
   ```bash
   npm install -g netlify-cli
   ```

2. **Deploy:**
   ```bash
   cd "auditra web app"
   netlify deploy
   # Follow prompts
   netlify deploy --prod  # For production
   ```

3. **Or use Netlify Drop:**
   - Go to https://app.netlify.com/drop
   - Drag and drop your `auditra web app` folder
   - Get instant URL

### Vercel (Free, Fast)

1. **Install Vercel CLI:**
   ```bash
   npm install -g vercel
   ```

2. **Deploy:**
   ```bash
   cd "auditra web app"
   vercel
   # Follow prompts
   vercel --prod  # For production
   ```

## Option 2: Simple HTTP Server (Local/Development)

### Python HTTP Server

```bash
cd "auditra web app"
python3 -m http.server 8000
# Access at: http://localhost:8000
```

### Node.js HTTP Server

```bash
# Install globally
npm install -g http-server

# Run
cd "auditra web app"
http-server -p 8000
# Access at: http://localhost:8000
```

### PHP Built-in Server

```bash
cd "auditra web app"
php -S localhost:8000
# Access at: http://localhost:8000
```

## Option 3: Flutter Web Build (If you want Flutter web version)

### Build Flutter Web App

```bash
cd auditra
flutter build web
```

This creates a `build/web` folder with optimized web files.

### Host Flutter Web Build

1. **Copy build files:**
   ```bash
   cp -r auditra/build/web/* "auditra web app/flutter-build/"
   ```

2. **Serve the Flutter build:**
   ```bash
   cd "auditra web app/flutter-build"
   python3 -m http.server 8000
   ```

## Option 4: Production Server (Nginx/Apache)

### Nginx Configuration

Create `/etc/nginx/sites-available/auditra`:

```nginx
server {
    listen 80;
    server_name your-domain.com;
    root /path/to/auditra/web/app;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # API proxy (if backend on same server)
    location /api/ {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

Enable:
```bash
sudo ln -s /etc/nginx/sites-available/auditra /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### Apache Configuration

Create `/etc/apache2/sites-available/auditra.conf`:

```apache
<VirtualHost *:80>
    ServerName your-domain.com
    DocumentRoot /path/to/auditra/web/app

    <Directory /path/to/auditra/web/app>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    # API proxy
    ProxyPass /api http://localhost:8000/api
    ProxyPassReverse /api http://localhost:8000/api
</VirtualHost>
```

Enable:
```bash
sudo a2ensite auditra
sudo systemctl reload apache2
```

## Option 5: Cloud Hosting Services

### AWS S3 + CloudFront

1. **Upload to S3:**
   ```bash
   aws s3 sync "auditra web app" s3://your-bucket-name --delete
   ```

2. **Enable static website hosting in S3**

3. **Create CloudFront distribution** for CDN

### Google Cloud Storage

1. **Upload files:**
   ```bash
   gsutil -m cp -r "auditra web app/*" gs://your-bucket-name/
   ```

2. **Make bucket public**

3. **Enable website configuration**

### Azure Static Web Apps

1. **Install Azure CLI:**
   ```bash
   az login
   ```

2. **Create static web app:**
   ```bash
   az staticwebapp create \
     --name auditra-web \
     --resource-group your-resource-group \
     --source "auditra web app"
   ```

## Important Configuration

### Update API URL

Before hosting, update the API endpoint in your HTML/JS files:

**For production:**
```javascript
const API_BASE_URL = 'https://your-backend-domain.com/api';
```

**For development:**
```javascript
const API_BASE_URL = 'http://localhost:8000/api';
```

### CORS Configuration

Make sure your Django backend allows requests from your web domain:

```python
# backend/auditra_backend/settings.py
CORS_ALLOWED_ORIGINS = [
    "https://your-web-domain.com",
    "http://localhost:8000",  # For development
]
```

### Environment Variables

If using build tools, create `.env` file:

```env
API_BASE_URL=https://your-backend-domain.com/api
```

## Quick Deploy Script

Create `deploy.sh`:

```bash
#!/bin/bash
echo "🚀 Deploying Auditra Web App..."

# Option 1: Netlify
# netlify deploy --prod --dir="auditra web app"

# Option 2: Vercel
# vercel --prod --cwd="auditra web app"

# Option 3: GitHub Pages
cd "auditra web app"
git add .
git commit -m "Deploy update"
git push origin main

echo "✅ Deployment complete!"
```

Make executable:
```bash
chmod +x deploy.sh
./deploy.sh
```

## Recommended Setup

**For Quick Testing:**
- Use Netlify Drop or Vercel (drag & drop)

**For Production:**
- Use Netlify, Vercel, or GitHub Pages (all free)
- Add custom domain if needed
- Enable HTTPS (automatic with these services)

**For Enterprise:**
- AWS S3 + CloudFront
- Azure Static Web Apps
- Google Cloud Storage

## Next Steps

1. Choose your hosting option
2. Update API URLs in your web app
3. Configure CORS on backend
4. Deploy!
5. Test all functionality

Need help? Check the specific hosting service documentation.

