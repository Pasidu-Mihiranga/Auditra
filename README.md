# Auditra - Full Stack Flutter & Django Application

A complete authentication system with Flutter mobile app and Django backend using PostgreSQL.

## 🚀 Features

- ✅ User Registration
- ✅ User Login with JWT Authentication
- ✅ User Profile Management
- ✅ Role-Based Access Control (Admin, Coordinator, Field Officer, etc.)
- ✅ Attendance Management System
  - Check-in/Check-out
  - Overtime tracking
  - Attendance summaries and charts
  - Auto-checkout at 5 PM
- ✅ Project Management
  - Coordinators can create projects
  - Assign projects to field officers
  - Document attachments
- ✅ Valuation System
  - Field officers can create valuations for assigned projects
  - Multiple categories: Land, Building, Vehicle, Other
  - Photo attachments
  - Live location capture (for Land and Building)
  - Draft and submit functionality
- ✅ Beautiful Material Design UI
- ✅ Persistent Session Management
- ✅ PostgreSQL Database
- ✅ RESTful API with Django REST Framework

## 📁 Project Structure

```
Auditra/
├── auditra/              # Flutter mobile app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/
│   │   │   ├── login_screen.dart
│   │   │   ├── register_screen.dart
│   │   │   └── home_screen.dart
│   │   └── services/
│   │       └── api_service.dart
│   └── pubspec.yaml
│
├── backend/              # Django backend
│   ├── auditra_backend/
│   │   ├── settings.py
│   │   └── urls.py
│   ├── authentication/   # User authentication & roles
│   │   ├── views.py
│   │   ├── serializers.py
│   │   └── urls.py
│   ├── attendance/       # Attendance management
│   │   ├── models.py
│   │   ├── views.py
│   │   └── urls.py
│   ├── projects/        # Project management
│   │   ├── models.py
│   │   ├── views.py
│   │   └── urls.py
│   ├── valuations/      # Valuation system
│   │   ├── models.py
│   │   ├── views.py
│   │   └── urls.py
│   ├── manage.py
│   └── requirements.txt
│
└── README.md
```

## 🛠️ Tech Stack

### Frontend
- **Flutter** - Cross-platform mobile framework
- **Dart** - Programming language
- **Material Design 3** - UI/UX

### Backend
- **Django 5.0** - Python web framework
- **Django REST Framework** - API framework
- **PostgreSQL** - Database
- **JWT** - Authentication
- **CORS Headers** - Cross-origin support

## 📋 Prerequisites

Before you begin, ensure you have the following installed:

- Flutter SDK (latest stable version)
- Python 3.9+
- PostgreSQL 13+
- Android Studio / Xcode (for mobile development)
- Git

## 🔧 Installation & Setup

### 1. Clone the Repository

```bash
cd Auditra
```

### 2. Backend Setup (Django)

#### Step 1: Install PostgreSQL

**Windows:**
- Download from https://www.postgresql.org/download/windows/
- Install and remember your password

**Mac:**
```bash
brew install postgresql
brew services start postgresql
```

**Linux:**
```bash
sudo apt-get update
sudo apt-get install postgresql postgresql-contrib
```

#### Step 2: Create Database

```bash
# Connect to PostgreSQL
psql -U postgres

# In PostgreSQL shell:
CREATE DATABASE auditra_db;
\q
```

#### Step 3: Install Python Dependencies

```bash
cd backend
pip install -r requirements.txt
```

#### Step 4: Configure Environment

Create a `.env` file in the `backend/` directory:

```env
DB_NAME=auditra_db
DB_USER=postgres
DB_PASSWORD=your_postgres_password
DB_HOST=localhost
DB_PORT=5432
```

#### Step 5: Run Migrations

```bash
python manage.py makemigrations
python manage.py migrate
```

#### Step 6: Create Admin User

The system requires an admin user to manage roles and access. Create the admin user:

```bash
python manage.py create_admin
```

This will create an admin user with:
- **Username:** `admin`
- **Password:** `admin@auditra2024`

**Important:** Change the default password after first login for security:
```bash
python manage.py changepassword admin
```

#### Step 7: Start Django Server

```bash
python manage.py runserver
```

Backend will be available at: `http://localhost:8000/`

### 3. Frontend Setup (Flutter)

#### Step 1: Install Dependencies

```bash
cd ../auditra
flutter pub get
```

**Note:** For location services (used in valuations), you may need to configure permissions:

**Android:** Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

**iOS:** Add to `ios/Runner/Info.plist`:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to capture property coordinates for valuations.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>We need your location to capture property coordinates for valuations.</string>
```

#### Step 2: Configure API URL

Edit `lib/services/api_service.dart` and update the `baseUrl`:

```dart
// For Android Emulator
static const String baseUrl = 'http://10.0.2.2:8000/api';

// For iOS Simulator
static const String baseUrl = 'http://localhost:8000/api';

// For Physical Device (replace with your computer's IP)
static const String baseUrl = 'http://192.168.1.XXX:8000/api';
```

#### Step 3: Run the App

```bash
flutter run
```

## 🌐 API Endpoints

### Authentication

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | `/api/auth/register/` | Register new user | No |
| POST | `/api/auth/login/` | Login user | No |
| GET | `/api/auth/profile/` | Get user profile | Yes |
| GET | `/api/auth/my-role/` | Get current user role | Yes |

### Attendance

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | `/api/attendance/mark/` | Mark attendance (check-in) | Yes |
| GET | `/api/attendance/today/` | Get today's attendance | Yes |
| POST | `/api/attendance/checkout/` | Check out | Yes |
| POST | `/api/attendance/leave-early/` | Leave early | Yes |
| POST | `/api/attendance/overtime/start/` | Start overtime | Yes |
| POST | `/api/attendance/overtime/end/` | End overtime | Yes |
| GET | `/api/attendance/summary/` | Get attendance summary | Yes |

### Projects

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | `/api/projects/` | List projects | Yes |
| POST | `/api/projects/` | Create project (Coordinator) | Yes |
| GET | `/api/projects/<id>/` | Get project details | Yes |
| GET | `/api/projects/field-officers/` | List available field officers | Yes |
| POST | `/api/projects/<id>/assign/` | Assign project to field officer | Yes |

### Valuations

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | `/api/valuations/` | List valuations | Yes |
| POST | `/api/valuations/` | Create valuation | Yes |
| GET | `/api/valuations/<id>/` | Get valuation details | Yes |
| PUT | `/api/valuations/<id>/` | Update valuation | Yes |
| DELETE | `/api/valuations/<id>/` | Delete valuation | Yes |
| POST | `/api/valuations/<id>/submit/` | Submit valuation | Yes |
| GET | `/api/valuations/<id>/photos/` | List valuation photos | Yes |
| POST | `/api/valuations/<id>/photos/` | Upload photo | Yes |
| DELETE | `/api/valuations/photos/<id>/` | Delete photo | Yes |

### Example API Requests

**Register:**
```bash
curl -X POST http://localhost:8000/api/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{
    "username":"testuser",
    "email":"test@example.com",
    "password":"securepass123",
    "password2":"securepass123"
  }'
```

**Login:**
```bash
curl -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{
    "username":"testuser",
    "password":"securepass123"
  }'
```

**Get Profile:**
```bash
curl -X GET http://localhost:8000/api/auth/profile/ \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

## 📱 App Screenshots

### Features:
1. **Splash Screen** - Animated loading screen with branding
2. **Login Screen** - Clean authentication UI with validation
3. **Registration Screen** - Comprehensive signup form
4. **Home Screen** - Dashboard with user info and quick actions

## 🔐 Authentication Flow

1. User registers with username, email, and password
2. Backend validates and creates user account
3. JWT access & refresh tokens are generated
4. Tokens stored securely in device (SharedPreferences)
5. All API requests include Bearer token in headers
6. User stays logged in until explicit logout

## 🐛 Troubleshooting

### Connection Refused Error

**Problem:** Flutter app can't connect to Django backend

**Solutions:**
1. Verify Django is running: `python manage.py runserver`
2. Check firewall settings allow port 8000
3. For physical device, use your computer's IP address
4. Ensure both devices are on same network

### PostgreSQL Connection Error

**Problem:** Django can't connect to PostgreSQL

**Solutions:**
1. Verify PostgreSQL is running: `pg_isready`
2. Check credentials in `.env` file
3. Ensure database `auditra_db` exists
4. Update `pg_hba.conf` for authentication method

### Flutter Build Errors

**Problem:** App won't build or dependencies fail

**Solutions:**
```bash
flutter clean
flutter pub get
flutter pub upgrade
```

### Symlink Error on Windows

Enable Developer Mode:
```
start ms-settings:developers
```

## 🚀 Deployment Tips

### Backend (Django)

1. Set `DEBUG = False` in production
2. Use proper `SECRET_KEY`
3. Configure `ALLOWED_HOSTS`
4. Use environment variables for sensitive data
5. Set up HTTPS
6. Use production WSGI server (Gunicorn, uWSGI)

### Frontend (Flutter)

1. Update API URLs to production
2. Enable code obfuscation
3. Build release APK/IPA:
```bash
flutter build apk --release
flutter build ios --release
```

## 📚 Dependencies

### Flutter (pubspec.yaml)
```yaml
dependencies:
  http: ^1.1.0
  shared_preferences: ^2.2.2
  provider: ^6.1.1
  cupertino_icons: ^1.0.8
  fl_chart: ^0.66.0
  intl: ^0.19.0
  file_picker: ^8.0.0
  path_provider: ^2.1.1
  image_picker: ^1.0.7
  geolocator: ^12.0.0
```

### Django (requirements.txt)
```
Django==5.0.0
djangorestframework==3.14.0
psycopg==3.1.18
django-cors-headers==4.3.1
python-decouple==3.8
djangorestframework-simplejwt==5.3.1
```

## 📖 Valuation System

The valuation system allows field officers to create detailed valuations for assigned projects.

### Features

1. **Category Selection**
   - Land: Area, type, location with GPS coordinates
   - Building: Area, type, location, floors, year built
   - Vehicle: Make, model, year, registration, mileage, condition
   - Other: Custom type and specifications

2. **Photo Management**
   - Upload multiple photos from gallery or camera
   - Add captions to photos
   - Delete photos

3. **Location Services**
   - Capture live GPS location for Land and Building categories
   - Stores latitude and longitude coordinates

4. **Workflow**
   - Save as draft for later editing
   - Submit when complete
   - View and edit existing valuations

### Usage

1. Coordinator assigns a project to a field officer
2. Field officer opens project details
3. Field officer clicks "Create Valuation"
4. Select category and fill in relevant details
5. Attach photos and capture location (if applicable)
6. Save draft or submit directly

## 👤 Admin User Setup

The system requires an admin user to manage roles and system access.

### Create Admin User

```bash
cd backend
python manage.py create_admin
```

This creates an admin user with:
- **Username:** `admin`
- **Password:** `admin@auditra2024`

### Change Admin Password

For security, change the default password:

```bash
python manage.py changepassword admin
```

### Admin Privileges

- View all registered users
- Assign roles to users (except admin role)
- Change user roles
- Access admin dashboard
- View system statistics

**Note:** Only one admin user exists in the system. The admin role cannot be assigned to other users.

### Create Admin Command Code

The admin user is created using a Django management command located at `backend/authentication/management/commands/create_admin.py`:

```python
from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from authentication.models import UserRole


class Command(BaseCommand):
    help = 'Creates admin user with shared credentials'

    def handle(self, *args, **options):
        # Shared admin credentials
        username = 'admin'
        password = 'admin@auditra2024'
        email = 'admin@auditra.com'
        
        # Check if admin already exists
        if User.objects.filter(username=username).exists():
            self.stdout.write(self.style.WARNING(
                f'Admin user "{username}" already exists!'
            ))
            admin_user = User.objects.get(username=username)
        else:
            # Create admin user
            admin_user = User.objects.create_user(
                username=username,
                email=email,
                password=password,
                first_name='System',
                last_name='Administrator',
                is_staff=True,
                is_superuser=True
            )
            self.stdout.write(self.style.SUCCESS(
                f'Successfully created admin user: {username}'
            ))
        
        # Assign admin role
        user_role, created = UserRole.objects.get_or_create(user=admin_user)
        user_role.role = 'admin'
        user_role.save()
        
        self.stdout.write(self.style.SUCCESS(
            '\n' + '='*50
        ))
        self.stdout.write(self.style.SUCCESS(
            'ADMIN CREDENTIALS (Share these with authorized admins):'
        ))
        self.stdout.write(self.style.SUCCESS(
            '='*50
        ))
        self.stdout.write(self.style.WARNING(
            f'Username: {username}'
        ))
        self.stdout.write(self.style.WARNING(
            f'Password: {password}'
        ))
        self.stdout.write(self.style.SUCCESS(
            '='*50 + '\n'
        ))
        
        self.stdout.write(self.style.SUCCESS(
            'Admin user is ready to assign roles to other users!'
        ))
```

For more details, see [ADMIN_SETUP.md](backend/ADMIN_SETUP.md)

## 🎯 Future Enhancements

- [ ] Email verification
- [ ] Password reset functionality
- [ ] Social authentication (Google, Facebook)
- [ ] Profile picture upload
- [ ] Two-factor authentication
- [ ] Push notifications
- [ ] Dark mode theme
- [ ] Multi-language support
- [ ] Valuation review and approval workflow
- [ ] Export valuations to PDF

## 📄 License

This project is created for educational purposes.

## 👥 Contributing

Contributions are welcome! Feel free to submit issues and pull requests.

## 📧 Support

For support, please open an issue in the repository.

---

**Built with ❤️ using Flutter & Django**

# Auditra
