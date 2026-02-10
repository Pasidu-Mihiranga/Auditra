# Payment Slip Structure Documentation

This document describes the complete structure of payment slips in the Auditra system, including database schema, API structure, frontend model, and UI layout.

## Table of Contents
1. [Database Model Structure](#database-model-structure)
2. [API Serializer Structure](#api-serializer-structure)
3. [Frontend Model Structure](#frontend-model-structure)
4. [UI Layout Structure](#ui-layout-structure)
5. [Calculation Formulas](#calculation-formulas)
6. [Field Descriptions](#field-descriptions)
7. [Status Values](#status-values)
8. [Role-Specific Structures](#role-specific-structures)

---

## Database Model Structure

**Model:** `PaymentSlip` (Django)
**Table:** `payment_slips`

### Fields

| Field Name | Type | Description | Constraints |
|------------|------|-------------|-------------|
| `id` | AutoField | Primary key | Auto-generated |
| `user` | ForeignKey | Reference to User | Required, CASCADE on delete |
| `month` | IntegerField | Month (1-12) | Required |
| `year` | IntegerField | Year | Required |
| `salary` | DecimalField | Basic salary | max_digits=10, decimal_places=2 |
| `allowances` | DecimalField | Total allowances | max_digits=10, decimal_places=2, default=0.00 |
| `epf_contribution` | DecimalField | EPF contribution (8% of basic) | max_digits=10, decimal_places=2, default=0.00 |
| `overtime_hours` | DecimalField | Total overtime hours for the month | max_digits=5, decimal_places=2, default=0.00 |
| `overtime_pay` | DecimalField | Overtime payment amount | max_digits=10, decimal_places=2, default=0.00 |
| `net_salary` | DecimalField | Net salary (calculated) | max_digits=10, decimal_places=2, default=0.00 |
| `role` | CharField | User role code | max_length=50 |
| `role_display` | CharField | User role display name | max_length=100 |
| `pay_slip_number` | CharField | Unique pay slip number | max_length=50, unique=True, nullable |
| `employee_number` | CharField | Employee number (User ID) | max_length=50, nullable |
| `status` | CharField | Payment slip status | max_length=20, choices=STATUS_CHOICES, default='generated' |
| `generated_by` | ForeignKey | Admin who created the slip | nullable, SET_NULL on delete |
| `generated_at` | DateTimeField | Creation timestamp | auto_now_add=True |
| `paid_at` | DateTimeField | Payment timestamp | nullable |

### Unique Constraints
- `(user, month, year)` - One payment slip per user per month

### Status Choices
- `'pending'` - Pending
- `'generated'` - Generated
- `'paid'` - Paid

---

## API Serializer Structure

**Serializer:** `PaymentSlipSerializer` (Django REST Framework)

### Response Fields

```json
{
  "id": 1,
  "user": 3,
  "user_username": "john_doe",
  "user_full_name": "John Doe",
  "month": 12,
  "month_display": "December",
  "year": 2025,
  "salary": "150000.00",
  "allowances": "1200.00",
  "epf_contribution": "12000.00",
  "overtime_hours": "10.50",
  "overtime_pay": "7875.00",
  "net_salary": "151075.00",
  "role": "coordinator",
  "role_display": "Coordinator",
  "pay_slip_number": "PS-202512-3",
  "employee_number": "3",
  "status": "generated",
  "generated_by": 1,
  "generated_by_username": "admin",
  "generated_at": "2025-12-01T10:30:00Z",
  "paid_at": null
}
```

### Field Mappings

| API Field | Model Field | Type | Notes |
|-----------|-------------|------|-------|
| `id` | `id` | Integer | Primary key |
| `user` | `user.id` | Integer | User ID |
| `user_username` | `user.username` | String | Read-only |
| `user_full_name` | Computed | String | `first_name + last_name` |
| `month` | `month` | Integer | 1-12 |
| `month_display` | Computed | String | Month name |
| `year` | `year` | Integer | Year |
| `salary` | `salary` | Decimal | Formatted as string |
| `allowances` | `allowances` | Decimal | Formatted as string |
| `epf_contribution` | `epf_contribution` | Decimal | Formatted as string |
| `overtime_hours` | `overtime_hours` | Decimal | Formatted as string |
| `overtime_pay` | `overtime_pay` | Decimal | Formatted as string |
| `net_salary` | `net_salary` | Decimal | Formatted as string |
| `role` | `role` | String | Role code |
| `role_display` | `role_display` | String | Role display name |
| `pay_slip_number` | `pay_slip_number` | String | Format: PS-YYYYMM-USERID |
| `employee_number` | `employee_number` | String | User ID as string |
| `status` | `status` | String | Status code |
| `generated_by` | `generated_by.id` | Integer | Admin user ID |
| `generated_by_username` | `generated_by.username` | String | Read-only |
| `generated_at` | `generated_at` | DateTime | ISO format |
| `paid_at` | `paid_at` | DateTime | ISO format, nullable |

---

## Frontend Model Structure

**Model:** `PaymentSlip` (Flutter/Dart)
**File:** `auditra/lib/models/payment_slip_model.dart`

### Class Properties

```dart
class PaymentSlip {
  final int id;
  final int userId;
  final String userUsername;
  final String userFullName;
  final int month;
  final String monthDisplay;
  final int year;
  final double salary;              // Basic salary
  final double allowances;          // Total allowances
  final double epfContribution;     // EPF 8% of basic
  final double overtimeHours;       // Total overtime hours
  final double overtimePay;         // Overtime payment
  final double netSalary;           // Net salary
  final String role;
  final String roleDisplay;
  final String? paySlipNumber;
  final String? employeeNumber;
  final String status;
  final int? generatedById;
  final String? generatedByUsername;
  final DateTime generatedAt;
  final DateTime? paidAt;
}
```

---

## UI Layout Structure

### Payment Slip Display Layout

The payment slip is displayed in a card format with the following sections:

#### 1. Header Section
- **Company Logo** (centered)
- **Company Name** (centered, below logo)
- **Payment Period** (Month Year)

#### 2. Employee Information Section
- **Employee Name**
- **Employee no** (User ID)
- **Pay Slip no** (Format: PS-YYYYMM-USERID)
- **Month of Payment** (Month Year)

#### 3. Salary Details Section

**For Admin and HR Staff (Left-aligned, Black text):**
- Basic Salary: [amount] (black)
- Allowances: [amount] (black)
- EPF Contribution: [amount] (black)
- Overtime Hours: [hours]
- Overtime Pay: [amount]
- Net Salary: [amount] (black)

**For Other Roles (Coordinator, Field Officer, Senior Valuer, Assessor, MD/GM, General Employee):**
- Basic Salary: [amount]
- Allowances: [amount]
- EPF Contribution: [amount]
- Overtime Hours: [hours]
- Overtime Pay: [amount]
- Net Salary: [amount]

#### 4. Footer Section
- Generated timestamp
- Status indicator

---

## Calculation Formulas

### 1. Allowances
```
Allowances = Fixed amount of 1200.00
```

### 2. EPF Contribution
```
EPF Contribution = Basic Salary × (8/100)
EPF Contribution = Basic Salary × 0.08
```

### 3. Overtime Pay
```
Overtime Pay = Overtime Hours × (Basic Salary × 5/100)
Overtime Pay = Overtime Hours × (Basic Salary × 0.05)
```

### 4. Net Salary
```
Net Salary = Basic Salary - EPF Contribution + Allowances + Overtime Pay
```

### 5. Overtime Hours
```
Overtime Hours = Sum of all overtime_hours from Attendance records for the month
```

### 6. Pay Slip Number
```
Pay Slip Number = "PS-" + YYYY + MM + "-" + USER_ID
Example: PS-202512-3
```

### 7. Employee Number
```
Employee Number = User ID (as string)
```

---

## Field Descriptions

### Basic Salary
- **Source:** UserRole.salary (role-based salary)
- **Type:** Decimal
- **Default by Role:**
  - Admin: 300,000
  - Coordinator: 150,000
  - Field Officer: 130,000
  - Accessor: 110,000
  - Senior Valuer: 120,000
  - MD/GM: 100,000
  - HR Staff: 80,000
  - General Employee: 50,000

### Allowances
- **Type:** Fixed amount
- **Value:** 1,200.00
- **Purpose:** Fixed monthly allowance for all employees

### EPF Contribution
- **Type:** Calculated (8% of basic salary)
- **Purpose:** Employee Provident Fund contribution
- **Deduction:** Subtracted from basic salary

### Overtime Hours
- **Source:** Attendance system
- **Calculation:** Sum of `overtime_hours` from Attendance records for the specific month/year
- **Type:** Decimal (hours)

### Overtime Pay
- **Type:** Calculated
- **Formula:** Overtime Hours × (Basic Salary × 5%)
- **Purpose:** Additional payment for overtime work

### Net Salary
- **Type:** Calculated
- **Formula:** Basic Salary - EPF Contribution + Allowances + Overtime Pay
- **Purpose:** Final amount payable to employee

---

## Status Values

| Status | Code | Description |
|--------|------|-------------|
| Pending | `pending` | Payment slip is pending generation |
| Generated | `generated` | Payment slip has been generated |
| Paid | `paid` | Payment has been processed |

---

## Role-Specific Structures

### Admin & HR Staff Payment Slips
- **Layout:** Left-aligned text
- **Text Color:** Black for amounts
- **Fields Shown:**
  - Employee Name
  - Employee no
  - Pay Slip no
  - Month of Payment
  - Basic Salary (black)
  - Allowances (black)
  - EPF Contribution (black)
  - Overtime Hours
  - Overtime Pay
  - Net Salary (black)

### Other Roles (Coordinator, Field Officer, Senior Valuer, Assessor, MD/GM, General Employee)
- **Layout:** Standard centered layout
- **Text Color:** Default theme colors
- **Fields Shown:**
  - Employee Name
  - Employee no
  - Pay Slip no
  - Month of Payment
  - Basic Salary
  - Allowances
  - EPF Contribution
  - Overtime Hours
  - Overtime Pay
  - Net Salary

---

## Visibility Rules

### Employee Visibility
- Employees can only see payment slips where `generated_by` is not null
- Payment slips must be created by admin to be visible to employees
- Auto-generated payment slips (without `generated_by`) are not visible to employees

### Admin Visibility
- Admin can see all payment slips (their own and all employees')
- Admin can see payment slips regardless of `generated_by` status

---

## Generation Process

### When Admin Creates Payment Slips:
1. Admin clicks "Create Payment Slips" button
2. System generates payment slips for all employee roles:
   - Coordinator
   - Field Officer
   - Senior Valuer
   - Assessor
   - MD/GM
   - HR Staff
   - General Employee
   - Admin (own payment slip)
3. For each employee:
   - Calculate allowances (fixed: 1200)
   - Calculate EPF (8% of basic salary)
   - Retrieve overtime hours from Attendance system
   - Calculate overtime pay
   - Calculate net salary
   - Set `generated_by` to admin user
   - Set `pay_slip_number` (PS-YYYYMM-USERID)
   - Set `employee_number` (User ID)
4. Payment slips become visible to employees

---

## API Endpoints

### Get My Payment Slips
- **Endpoint:** `GET /api/auth/payment-slips/my/`
- **Auth:** Required (JWT)
- **Response:** List of payment slips for current user
- **Filter:** Employees only see slips with `generated_by__isnull=False`

### Get All Payment Slips (Admin)
- **Endpoint:** `GET /api/auth/payment-slips/all/`
- **Auth:** Required (JWT, Admin only)
- **Response:** List of all payment slips
- **Query Params:**
  - `month` (optional)
  - `year` (optional)
  - `user_id` (optional)

### Generate Payment Slips (Admin)
- **Endpoint:** `POST /api/auth/payment-slips/generate/`
- **Auth:** Required (JWT, Admin only)
- **Body:**
  ```json
  {
    "month": 12,
    "year": 2025,
    "force_regenerate": true
  }
  ```
- **Response:**
  ```json
  {
    "message": "Payment slips processed successfully...",
    "month": 12,
    "year": 2025,
    "generated_count": 5,
    "updated_count": 2,
    "total_count": 7
  }
  ```

---

## Database Schema (SQL)

```sql
CREATE TABLE payment_slips (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES auth_user(id) ON DELETE CASCADE,
    month INTEGER NOT NULL CHECK (month >= 1 AND month <= 12),
    year INTEGER NOT NULL,
    salary NUMERIC(10, 2) NOT NULL,
    allowances NUMERIC(10, 2) DEFAULT 0.00,
    epf_contribution NUMERIC(10, 2) DEFAULT 0.00,
    overtime_hours NUMERIC(5, 2) DEFAULT 0.00,
    overtime_pay NUMERIC(10, 2) DEFAULT 0.00,
    net_salary NUMERIC(10, 2) DEFAULT 0.00,
    role VARCHAR(50) NOT NULL,
    role_display VARCHAR(100) NOT NULL,
    pay_slip_number VARCHAR(50) UNIQUE,
    employee_number VARCHAR(50),
    status VARCHAR(20) DEFAULT 'generated',
    generated_by_id INTEGER REFERENCES auth_user(id) ON DELETE SET NULL,
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    paid_at TIMESTAMP,
    UNIQUE(user_id, month, year)
);
```

---

## Notes

1. **Payment slips are generated monthly** - One payment slip per user per month
2. **Overtime hours** are retrieved from the Attendance system for the specific month/year
3. **Employee number** is the User ID from the database
4. **Pay slip number** format: `PS-YYYYMM-USERID`
5. **Visibility control:** Only payment slips created by admin (`generated_by` is not null) are visible to employees
6. **Auto-generation is disabled** for employees - they can only see admin-created payment slips

---

## Last Updated
December 2025

