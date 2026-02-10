# API Configuration - Web App & Mobile App

Both the **Auditra Web App** and **Mobile App** use the **same Django backend**.

## 🔗 Backend Connection

### Mobile App Configuration
**File:** `auditra/lib/services/api_service.dart`

```dart
static const String baseUrl = 'http://10.0.2.2:8000/api'; // Android emulator
// For physical device: Use your computer's IP (e.g., 'http://192.168.1.100:8000/api')
// For Chrome/web: Use 'http://localhost:8000/api'
```

### Web App Configuration
**Files:** `client-form.html` and `employee-form.html`

Default API URL:
```
http://localhost:8000/api
```

## 📍 Backend Endpoints

Both apps use the same endpoints:

### Authentication
- `POST /api/auth/register/` - Register new user
- `POST /api/auth/login/` - User login
- `GET /api/auth/profile/` - Get user profile
- `GET /api/auth/my-role/` - Get user role
- `POST /api/auth/assign-role/` - Assign role (admin only)
- `GET /api/auth/users/` - List all users (admin only)

### Attendance
- `POST /api/attendance/mark/` - Mark attendance
- `POST /api/attendance/checkout/` - Checkout
- `GET /api/attendance/today/` - Get today's attendance
- `GET /api/attendance/summary/` - Get attendance summary

### Projects
- `GET /api/projects/` - List projects
- `POST /api/projects/` - Create project
- `GET /api/projects/field-officers/` - Get field officers
- `POST /api/projects/{id}/assign-field-officer/` - Assign field officer

### Valuations
- `GET /api/valuations/` - List valuations
- `POST /api/valuations/` - Create valuation
- `PUT /api/valuations/{id}/` - Update valuation
- `POST /api/valuations/{id}/submit/` - Submit valuation

## 🚀 Starting the Backend

**Important:** The backend must be running for both apps to work!

```bash
cd backend
python manage.py runserver
```

The server will start at: `http://127.0.0.1:8000/`

## 🌐 URL Differences

### Mobile App
- **Android Emulator:** `http://10.0.2.2:8000/api` (special IP that maps to host)
- **Physical Device:** `http://YOUR_COMPUTER_IP:8000/api` (e.g., `http://192.168.1.100:8000/api`)
- **iOS Simulator:** `http://localhost:8000/api`

### Web App
- **Local Development:** `http://localhost:8000/api`
- **Same Computer:** `http://localhost:8000/api` or `http://127.0.0.1:8000/api`

## ⚙️ Changing the API URL

### In Mobile App
Edit `auditra/lib/services/api_service.dart`:
```dart
static const String baseUrl = 'http://YOUR_IP:8000/api';
```

### In Web App
The forms have an editable "API Base URL" field where users can change it before submitting.

## ✅ Same Database

Both apps register users in the **same database**. When a user registers through:
- **Web App** → User appears in mobile app (after admin assigns role)
- **Mobile App** → User appears in web app

All data is shared through the same Django backend and PostgreSQL database.

## 🔐 Authentication

Both apps use the same authentication system:
- JWT tokens stored in SharedPreferences (mobile) or localStorage (web, if implemented)
- Same login credentials work for both apps
- Role-based access control is consistent across both platforms




































