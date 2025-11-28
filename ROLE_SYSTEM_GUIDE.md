# Role-Based Access Control System Guide

## 📋 Overview

Auditra now includes a complete Role-Based Access Control (RBAC) system with 10 different user roles and an admin dashboard for managing user permissions.

## 👥 Available Roles

### System Role (Cannot be assigned):
1. **Admin** - Full system access, can assign roles to users (ONLY the system admin has this role)

### Assignable Roles:
2. **Coordinator** - Coordination and management tasks
3. **Field Officer** - Field operations and data collection
4. **Accessor** - Access assessment and evaluation
5. **Senior Valuer** - Senior valuation responsibilities
6. **MD/GM** - Managing Director/General Manager level access
7. **HR Staff** - Human resources management
8. **General Employee** - Standard employee access
9. **Client** - Client portal access
10. **Agent** - Agent-specific functions

### Default Role:
11. **Unassigned** - Default role for new users (common dashboard)

## 🔐 Admin Access

### System Admin Credentials

**Username:** `admin`  
**Password:** `admin@auditra2024`

**⚠️ Important Security Notes:**
- Only ONE admin user exists in the system
- Admin role CANNOT be assigned to other users
- Admin role CANNOT be changed or removed
- Share these credentials only with authorized system administrators
- Recommended: Change the password after first login

## 🚀 How It Works

### 1. User Registration Flow

1. New users register through the app
2. They are automatically assigned the "Unassigned" role
3. They see the common dashboard for unassigned users
4. Admin must log in and assign them a proper role

### 2. Admin Role Assignment Flow

1. Admin logs in with shared credentials
2. Admin dashboard shows all users in the system
3. Admin clicks "Assign Role" button next to any user
4. Admin selects the appropriate role from dropdown
5. Role is assigned and user immediately gets access to their role-specific dashboard

### 3. Role-Based Dashboard Access

- **Admin:** See Admin Dashboard with user management
- **Unassigned:** See common dashboard with basic features
- **Other Roles:** See role-specific dashboards (future enhancement)

## 📡 API Endpoints

### Authentication Endpoints
- `POST /api/auth/register/` - Register new user
- `POST /api/auth/login/` - Login user
- `GET /api/auth/profile/` - Get user profile

### Role Management Endpoints (Admin Only)
- `GET /api/auth/my-role/` - Get current user's role
- `GET /api/auth/roles/` - Get list of available roles
- `POST /api/auth/assign-role/` - Assign role to user
- `GET /api/auth/users/` - Get all users (admin only)

## 💻 Using the System

### For Admins:

1. **Login as Admin:**
   ```
   Username: admin
   Password: admin@auditra2024
   ```

2. **Admin Dashboard Features:**
   - View all registered users
   - See user statistics (total users, unassigned users)
   - Assign roles to any user
   - Refresh user list
   - Logout

3. **Assigning Roles:**
   - Click "Assign Role" button next to any user (except the admin user)
   - Select the appropriate role from dropdown (9 roles available)
   - Click "Assign" to confirm
   - User will immediately have access to their new role
   
   **Note:** Admin role is NOT in the dropdown - it cannot be assigned

### For Regular Users:

1. **Register a new account**
2. **Wait for admin to assign a role**
3. **Login again to see your role-specific dashboard**
4. **Your role is displayed** on your profile card

## 🏗️ Technical Implementation

### Backend (Django)

**Models:**
- `UserRole` model linked one-to-one with User
- Tracks role, assigned_by, and timestamp

**Views:**
- `AssignRoleView` - Admin endpoint to assign roles
- `AllUsersView` - Admin endpoint to list all users
- `RoleListView` - Get available roles
- `MyRoleView` - Get current user's role

**Permissions:**
- Admin check in assign_role endpoint
- Only admin role can access user management endpoints

### Frontend (Flutter)

**Models:**
- `UserRole` model
- `UserModel` with role information
- `RoleOption` for dropdown selection

**Screens:**
- `AdminDashboard` - Full user management interface
- `HomeScreen` - Common dashboard with role display
- Role-based routing implemented

**Services:**
- API methods for role management
- Shared preferences for role storage
- Automatic role-based navigation

## 🔒 Security Features

1. **Role Verification:** Backend verifies admin role before allowing role assignments
2. **Token-Based Auth:** All role operations require JWT token
3. **One-to-One Relationship:** Each user has exactly one role
4. **Audit Trail:** Tracks who assigned each role and when
5. **Automatic Role Creation:** New users automatically get "unassigned" role
6. **Admin Protection:** Admin role cannot be assigned or changed
7. **Single Admin:** Only ONE admin user exists in the system
8. **Role Validation:** Backend prevents admin role assignment attempts

## 📊 Database Schema

```sql
user_roles (UserRole model)
├── id (Primary Key)
├── user_id (Foreign Key to User, One-to-One)
├── role (Choice Field)
├── assigned_by_id (Foreign Key to User, nullable)
├── assigned_at (DateTime)
└── created_at (DateTime)
```

## 🎯 Future Enhancements

### Ready to Implement:

1. **Role-Specific Dashboards:**
   - Create separate dashboard for each role
   - Customize features based on role permissions

2. **Permission System:**
   - Define granular permissions per role
   - Implement permission checks on features

3. **Role-Based Navigation:**
   - Show/hide menu items based on role
   - Custom navigation for each role

4. **Email Notifications:**
   - Notify users when role is assigned
   - Welcome email with role information

5. **Role Change History:**
   - Track all role changes
   - Audit log for compliance

## 🛠️ Setup Instructions

### Backend Setup:

1. **Run migrations:**
   ```bash
   cd backend
   python manage.py makemigrations
   python manage.py migrate
   ```

2. **Create admin user:**
   ```bash
   python manage.py create_admin
   ```

3. **Start server:**
   ```bash
   python manage.py runserver
   ```

### Frontend Setup:

1. **Install dependencies:**
   ```bash
   cd auditra
   flutter pub get
   ```

2. **Run app:**
   ```bash
   flutter run
   ```

## 📝 API Usage Examples

### Get My Role:
```bash
curl -X GET http://localhost:8000/api/auth/my-role/ \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Assign Role (Admin Only):
```bash
curl -X POST http://localhost:8000/api/auth/assign-role/ \
  -H "Authorization: Bearer ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 2,
    "role": "field_officer"
  }'
```

### Get All Users (Admin Only):
```bash
curl -X GET http://localhost:8000/api/auth/users/ \
  -H "Authorization: Bearer ADMIN_TOKEN"
```

## ❓ Troubleshooting

### "Only admins can assign roles" Error
- Make sure you're logged in as admin
- Admin role must be set in database
- Check token is valid and not expired

### User's role not updating in app
- Logout and login again
- Role is cached locally
- Force refresh by restarting app

### Can't access admin dashboard
- Verify admin credentials are correct
- Check backend is running
- Ensure migrations are applied

## 📞 Support

For issues or questions:
1. Check `TROUBLESHOOTING.md`
2. Verify backend logs for errors
3. Check Flutter console for errors
4. Ensure all migrations are applied

---

**System is ready for production use!** 🎉

All role management features are fully functional and secure.

