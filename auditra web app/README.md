# Auditra Web App

A web-based registration system for Auditra, allowing clients and employees to register through a browser interface.

## 📁 Files

- **index.html** - Main landing page with links to registration forms
- **client-form.html** - Client registration form
- **employee-form.html** - Employee registration form

## 🚀 How to Use

### Option 1: Open directly in browser
1. Navigate to the `auditra web app` folder
2. Double-click `index.html` to open it in your default browser
3. Click on either "Client Registration" or "Employee Registration"

### Option 2: Using a local web server
If you encounter CORS issues, use a local web server:

```bash
# Using Python 3
cd "auditra web app"
python -m http.server 8080

# Then open in browser:
# http://localhost:8080
```

## 📝 Features

### Client Registration Form
- Username (required, min 3 characters)
- Email (required, valid email format)
- First Name (optional)
- Last Name (optional)
- Company Name (optional)
- Phone Number (optional)
- Address (optional)
- Password (required, min 8 characters)
- Confirm Password (must match)

### Employee Registration Form
- Username (required, min 3 characters)
- Email (required, valid email format)
- First Name (optional)
- Last Name (optional)
- Employee ID (optional)
- Phone Number (optional)
- Department (optional)
- Additional Notes (optional)
- Password (required, min 8 characters)
- Confirm Password (must match)

## ⚙️ Configuration

### API URL
Both forms include an optional "API Base URL" field that defaults to:
```
http://localhost:8000/api
```

If your backend is running on a different URL or port, update this field before submitting the form.

## 🔗 Backend Integration

The forms connect to the Django backend API endpoint:
```
POST /api/auth/register/
```

Required fields in the request body:
```json
{
  "username": "string",
  "email": "string",
  "password": "string",
  "password2": "string",
  "first_name": "string (optional)",
  "last_name": "string (optional)"
}
```

## 📋 Post-Registration

After successful registration:
- Users are automatically assigned the "Unassigned" role
- An administrator must log in and assign the appropriate role:
  - **For clients:** Assign "Client" role
  - **For employees:** Assign appropriate role (Coordinator, Field Officer, HR Staff, etc.)

## 🎨 Design

- Modern, responsive design
- Gradient backgrounds
- Smooth animations
- Mobile-friendly
- Clean form validation with error messages

## 🔧 Troubleshooting

### Connection Error
- Make sure the Django backend is running: `python manage.py runserver`
- Check that the API URL is correct in the form
- Ensure CORS is properly configured in Django settings

### Validation Errors
- Check that all required fields are filled
- Ensure password is at least 8 characters
- Verify email format is correct
- Check that passwords match

### 404 Error
- Verify the API URL path includes `/api` at the end
- Check that the registration endpoint is accessible at `/api/auth/register/`


