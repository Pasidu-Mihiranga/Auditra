# How to Start Auditra Application

## Quick Start (All-in-One)

Double-click `start_all.bat` to:
- Open the web app in your browser
- Start the backend server

## Manual Start

### Option 1: Start Backend Only

**Windows:**
```bash
# Double-click start_backend.bat
# OR run in terminal:
cd backend
python manage.py runserver
```

**Linux/Mac:**
```bash
cd backend
python3 manage.py runserver
```

### Option 2: Open Web App Only

**Windows:**
```bash
# Double-click start_web_app.bat
# OR run in terminal:
start "" "auditra web app\index.html"
```

**Linux:**
```bash
xdg-open "auditra web app/index.html"
```

**Mac:**
```bash
open "auditra web app/index.html"
```

## Prerequisites

1. **Python 3.8+** installed
2. **PostgreSQL** installed and running
3. **Database created** (`auditra_db`)
4. **Dependencies installed:**
   ```bash
   cd backend
   pip install -r requirements.txt
   ```

5. **Environment variables** configured in `backend/.env`:
   ```
   DB_NAME=auditra_db
   DB_USER=postgres
   DB_PASSWORD=your_password
   DB_HOST=localhost
   DB_PORT=5432
   ```

6. **Migrations run:**
   ```bash
   cd backend
   python manage.py makemigrations
   python manage.py migrate
   ```

## URLs

- **Web App:** `file:///path/to/auditra web app/index.html` (opens in browser)
- **Backend API:** `http://localhost:8000/api/`
- **Admin Panel:** `http://localhost:8000/admin/`

## Troubleshooting

### Backend won't start:
- Check if port 8000 is already in use
- Verify PostgreSQL is running
- Check database credentials in `.env` file
- Run migrations: `python manage.py migrate`

### Web app can't connect to backend:
- Ensure backend is running at `http://localhost:8000`
- Check browser console for CORS errors
- Verify API URL in form JavaScript files

### Database errors:
- Ensure PostgreSQL is running
- Check database exists: `psql -U postgres -l`
- Create database if needed: `CREATE DATABASE auditra_db;`

