# Attendance System - Field Officer Dashboard

## Overview

The attendance system allows field officers to mark their attendance, track working hours, and view attendance summaries with visual charts. The system enforces working hours from 8 AM to 5 PM on all days except Sundays and Sri Lankan public holidays.

## Features

### 1. Attendance Marking
- **Mark Attendance**: Field officers can mark their attendance when they start work
- **Working Hours**: 8:00 AM - 5:00 PM (9 hours)
- **Working Days**: Monday to Saturday (excluding Sri Lankan holidays)

### 2. Countdown Timer
- Real-time countdown showing time remaining until 5:00 PM
- Updates every second
- Displays in HH:MM:SS format

### 3. Early Leave
- Field officers can leave early before 5 PM
- System automatically calculates if it's a full day (≥4.5 hours) or half day (<4.5 hours)
- Shows working hours for the day

### 4. Overtime Tracking
- Can start overtime after 5 PM (after regular check-out)
- Separate timer for overtime hours
- Tracks total overtime hours per day

### 5. Attendance Summary
- **Daily**: Today's attendance status
- **Weekly**: This week's attendance statistics
- **Monthly**: This month's attendance statistics
- **Yearly**: This year's attendance statistics

### 6. Visual Charts
- Bar charts showing daily attendance patterns
- Color-coded by status (Green: Present, Orange: Half Day, Red: Absent)
- Interactive tooltips showing exact hours

## Database Models

### Attendance Model
- Tracks check-in/check-out times
- Calculates working hours automatically
- Tracks overtime separately
- Status: present, half_day, absent, leave

### Holiday Model
- Stores Sri Lankan public holidays
- Used to determine non-working days
- Can be populated using management command

## API Endpoints

### Attendance Operations
- `POST /api/attendance/mark/` - Mark attendance (check-in)
- `POST /api/attendance/leave-early/` - Leave early before 5 PM
- `POST /api/attendance/checkout/` - Regular check-out at 5 PM
- `POST /api/attendance/overtime/start/` - Start overtime
- `POST /api/attendance/overtime/end/` - End overtime
- `GET /api/attendance/today/` - Get today's attendance status
- `GET /api/attendance/summary/?period={daily|weekly|monthly|yearly}` - Get attendance summary
- `GET /api/attendance/my-attendances/` - Get all attendances for current user

## Setup Instructions

### Backend Setup

1. **Run Migrations**
```bash
cd backend
python manage.py makemigrations attendance
python manage.py migrate
```

2. **Populate Holidays**
```bash
python manage.py populate_holidays
# For specific year:
python manage.py populate_holidays --year 2025
```

### Flutter Setup

1. **Install Dependencies**
```bash
cd auditra
flutter pub get
```

2. **Run the App**
```bash
flutter run
```

## Usage Flow

### For Field Officers

1. **Morning (8 AM)**
   - Open the Field Officer Dashboard
   - Tap "Mark Attendance" button
   - Countdown timer starts showing time until 5 PM

2. **During Work**
   - View countdown timer showing remaining time
   - Can tap "Leave Early" if needed to leave before 5 PM

3. **End of Day (5 PM)**
   - Tap "Check Out" button
   - System records full day (9 hours)

4. **Overtime (After 5 PM)**
   - After checking out, tap "Start Overtime"
   - Work additional hours
   - Tap "End Overtime" when done
   - System calculates and records overtime hours

5. **View Summary**
   - Select period (Daily/Weekly/Monthly/Yearly)
   - View statistics and charts
   - Track attendance percentage and total hours

## Business Rules

1. **Working Hours Calculation**
   - Full Day: ≥ 4.5 hours of work
   - Half Day: > 0 but < 4.5 hours
   - Absent: No check-in recorded

2. **Overtime Rules**
   - Can only start after 5 PM
   - Must check out regular hours first
   - Tracked separately from regular hours

3. **Holiday Handling**
   - Sundays are automatically non-working days
   - Sri Lankan public holidays are non-working days
   - Attendance cannot be marked on non-working days

## Statistics Displayed

- **Present Days**: Full working days
- **Half Days**: Partial working days
- **Absent Days**: Days without attendance
- **Attendance Percentage**: (Present + Half Days * 0.5) / Working Days * 100
- **Total Working Hours**: Sum of all working hours
- **Total Overtime Hours**: Sum of all overtime hours

## Charts

The attendance summary includes interactive bar charts showing:
- Daily attendance pattern over the selected period
- Color-coded bars (Green: Present, Orange: Half Day, Red: Absent)
- Tooltips showing exact working hours
- Date labels on X-axis
- Hours on Y-axis

## Future Enhancements

- Location-based attendance (GPS check-in)
- Photo verification for check-in/check-out
- Leave request integration
- Attendance reports export (PDF/Excel)
- Notifications for attendance reminders
- Team attendance view for coordinators

---

**Last Updated:** 2024  
**Version:** 1.0.0

