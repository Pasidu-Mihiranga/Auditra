# How to View the Client and Employee Forms

## 🚀 Quick Start (Easiest Method)

### Option 1: Open the Main Page
1. Navigate to: `C:\SoftwareProject\Auditra\Auditra\auditra web app`
2. Double-click `index.html`
3. Your browser will open showing two buttons:
   - **Client Registration** → Opens client form
   - **Employee Registration** → Opens employee form

### Option 2: Open Forms Directly
- Double-click `client-form.html` to open the client form directly
- Double-click `employee-form.html` to open the employee form directly

---

## 🌐 Using a Local Web Server (Recommended)

If you encounter any issues with direct file opening, use a web server:

### Step 1: Open Terminal/PowerShell
Navigate to the folder:
```bash
cd "C:\SoftwareProject\Auditra\Auditra\auditra web app"
```

### Step 2: Start a Local Server

**Using Python 3:**
```bash
python -m http.server 8080
```

**Using Python 2:**
```bash
python -m SimpleHTTPServer 8080
```

**Using Node.js (if installed):**
```bash
npx http-server -p 8080
```

### Step 3: Open in Browser
Open your web browser and go to:
- Main page: `http://localhost:8080/index.html`
- Client form: `http://localhost:8080/client-form.html`
- Employee form: `http://localhost:8080/employee-form.html`

---

## 📁 File Locations

All files are located in:
```
C:\SoftwareProject\Auditra\Auditra\auditra web app\
```

**Files:**
- `index.html` - Landing page (choose between client/employee)
- `client-form.html` - Client registration form
- `employee-form.html` - Employee registration form
- `README.md` - Documentation
- `API_CONFIGURATION.md` - API setup guide

---

## 🔍 Manual Navigation

1. Open File Explorer
2. Navigate to: `C:\SoftwareProject\Auditra\Auditra\auditra web app`
3. Right-click on `index.html`
4. Select "Open with" → Choose your browser (Chrome, Edge, Firefox, etc.)

---

## ✅ What You Should See

### Main Page (index.html)
- A beautiful gradient background
- Two large cards:
  - 👤 Client Registration (purple/blue gradient)
  - 👨‍💼 Employee Registration (pink/red gradient)

### Client Form
- Form with fields: Username, Email, First Name, Last Name, Company Name, Phone, Address, Password
- API URL field (defaults to `http://localhost:8000/api`)
- "Register as Client" button

### Employee Form
- Form with fields: Username, Email, First Name, Last Name, Employee ID, Phone, Department, Notes, Password
- API URL field (defaults to `http://localhost:8000/api`)
- "Register as Employee" button

---

## ⚠️ Before Testing the Forms

Make sure your Django backend is running:

```bash
cd C:\SoftwareProject\Auditra\Auditra\backend
python manage.py runserver
```

The backend should start on `http://127.0.0.1:8000/`

---

## 🎨 Browser Compatibility

The forms work in all modern browsers:
- ✅ Google Chrome
- ✅ Microsoft Edge
- ✅ Mozilla Firefox
- ✅ Safari
- ✅ Opera

---

## 💡 Troubleshooting

### Forms don't load?
- Make sure you're opening the HTML files, not viewing them as text
- Try right-clicking → "Open with" → Select a browser

### Connection errors when submitting?
- Make sure the Django backend is running
- Check that the API URL in the form is correct (`http://localhost:8000/api`)
- Verify the backend is accessible at `http://127.0.0.1:8000/`

### Forms look broken?
- Try using a local web server (Option 2 above)
- Clear your browser cache and reload


