# Quick Start Guide - Auditra

## 🚀 Fastest Way to Start

### PowerShell (Recommended for Windows)

**Option 1: Start Everything (Backend + Web App)**
```powershell
.\start_all.ps1
```

**Option 2: Start Backend Only**
```powershell
.\start_backend.ps1
```

**Option 3: Open Web App Only**
```powershell
.\start_web_app.ps1
```

### Command Prompt (CMD)

**Option 1: Start Everything**
```cmd
start_all.bat
```

**Option 2: Start Backend Only**
```cmd
start_backend.bat
```

**Option 3: Open Web App Only**
```cmd
start_web_app.bat
```

## 📝 Manual Commands

### Start Backend Server (Port 8000)

**PowerShell:**
```powershell
cd backend
python manage.py runserver
```

**CMD:**
```cmd
cd backend
python manage.py runserver
```

### Open Web App in Browser

**PowerShell:**
```powershell
Start-Process "auditra web app\index.html"
```

**CMD:**
```cmd
start "" "auditra web app\index.html"
```

## 🌐 URLs

- **Backend API:** http://localhost:8000/api/
- **Admin Panel:** http://localhost:8000/admin/
- **Web App:** Opens automatically in your default browser

## ⚙️ Prerequisites

1. **Python 3.8+** installed
2. **PostgreSQL** running
3. **Database created:** `auditra_db`
4. **Dependencies installed:**
   ```powershell
   cd backend
   pip install -r requirements.txt
   ```

5. **Migrations run:**
   ```powershell
   cd backend
   python manage.py migrate
   ```

## 🔧 Troubleshooting

### PowerShell Execution Policy Error
If you get an execution policy error, run:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Port 8000 Already in Use
If port 8000 is busy, use a different port:
```powershell
python manage.py runserver 8001
```

### Backend Won't Start
- Check PostgreSQL is running
- Verify database credentials in `backend/.env`
- Run migrations: `python manage.py migrate`

### Web App Can't Connect
- Ensure backend is running at http://localhost:8000
- Check browser console (F12) for errors
- Verify API URL in form files

