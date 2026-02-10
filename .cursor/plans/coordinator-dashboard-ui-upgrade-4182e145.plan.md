<!-- 4182e145-c29f-4e8c-b752-b188a65beba9 7b76f7f3-fb4f-4cf9-bb94-d651b07d6e2f -->
# Coordinator Dashboard UI Upgrade Plan

## Overview

Transform the coordinator dashboard to match the provided modern banking/finance app design while preserving all existing functionality. The new design features light blue/cyan gradients, rounded cards, and a clean modern aesthetic.

## Design Mapping Strategy

### 1. Header Section

**Location**: `coordinator_dashboard.dart` - AppBar section (lines ~6000-6065)

**Changes**:

- Replace current AppBar with custom header matching design
- Left side: Circular profile picture + "Hi, [Username]!" greeting
- Right side: Notification bell icon + Analytics/graph icon
- Remove current title/role display from AppBar
- Use light green background (`bg-green-100`) for header area
- Font: Use 'Arimo' font family (or closest Flutter equivalent)

**Implementation**:

- Create custom header widget replacing AppBar
- Add profile image loading from user data
- Style with exact colors: `bg-green-100` background, gray-800 text

### 2. Main Balance Card (Project Statistics Card)

**Location**: New widget to replace attendance summary card

**Design Elements**:

- Large rounded card with gradient: `from-blue-200 via-sky-300 to-sky-200`
- Rounded corners: `rounded-tl-[32px] rounded-tr-[32px] rounded-bl-[70px] rounded-br-[70px]`
- Top section: Role/Type indicator (e.g., "COORDINATOR") + Eye icon (toggle visibility)
- Main display: Large number showing total active projects or key metric
- Change indicator: "+X projects" or similar recent activity
- Exchange rate area: Project status breakdown (e.g., "1 Active = 2 Pending = 3 Completed")

**Data Mapping**:

- Main number: Total active projects count
- Change: Recent projects added this week/month
- Status breakdown: Active/Pending/Completed project ratios

**Implementation**:

- Create `_buildMainStatsCard()` widget
- Use `Container` with `BoxDecoration` and `LinearGradient`
- Position elements using absolute positioning where needed
- Add eye icon toggle for hiding/showing sensitive stats

### 3. Action Buttons Section

**Location**: Below main stats card

**Design Elements**:

- Three vertical buttons with white background
- Rounded corners, separated by vertical dividers
- Icons: Circular arrow (Pay), Double arrow (Transfer), Circular arrow (Receive)
- Labels below icons

**Feature Mapping**:

- **Pay Button** → Create New Project
- **Transfer Button** → Assign Users/Resources to Projects
- **Receive Button** → View/Download Project Documents

**Implementation**:

- Create `_buildActionButtons()` widget
- Use `Row` with three `Expanded` children
- Add dividers between buttons
- Style with white background, rounded corners
- Map to existing project creation/assignment functions

### 4. Latest Transactions Section

**Location**: Replace or enhance project list display

**Design Elements**:

- Section header: "Latest Transactions" with "See All" link
- White rounded card (`rounded-3xl`) with shadow
- Transaction items showing:
  - Left: Colored circle with icon (project type indicator)
  - Middle: Project name + time ago
  - Right: Status or action indicator (color-coded)

**Data Mapping**:

- Show recent project activities (created, assigned, status changed)
- Or show recent attendance records if in Attendance tab
- Format: Project name, time ago, status/action

**Implementation**:

- Create `_buildLatestTransactions()` widget
- Use `ListView` or `Column` for transaction items
- Style cards with white background, rounded corners
- Add "See All" navigation to full project list

### 5. Currency Section (Project Categories/Statuses)

**Location**: New section below transactions

**Design Elements**:

- Section header: "Projects" or "Categories"
- Three horizontal cards:
  - First two: White cards with colored currency symbols (€, £) replaced with project icons
  - Third: Dark card (`bg-gray-900`) with "+" icon and "Add Project" text

**Data Mapping**:

- Card 1: Active Projects (green icon, count)
- Card 2: Pending Projects (blue icon, count)
- Card 3: "Add Project" button (dark background)

**Implementation**:

- Create `_buildProjectCategories()` widget
- Use `Row` with three cards
- Style first two as white cards with colored icons
- Style third as dark card with white text
- Map to project creation and category views

### 6. Bottom Navigation

**Location**: Replace TabBar with custom bottom navigation

**Design Elements**:

- Three circular icons centered at bottom
- Active tab: Dark blue circle with white icon
- Inactive tabs: White circles with gray icons
- Icons: Refresh/arrow (left), Home (center), Refresh/arrow (right)

**Feature Mapping**:

- Left icon: Refresh/Reload data
- Center icon: Home/Dashboard (active)
- Right icon: Projects/Other view

**Implementation**:

- Create custom bottom navigation widget
- Replace `TabBar` with custom `Row` of circular buttons
- Use `TabBarView` logic but with custom navigation
- Style with shadows and rounded circles

## Color Scheme

Use exact colors from design:

- Background: `bg-green-100` (light green: `Color(0xFFDCEDC8)` or similar)
- Main card gradient: `from-blue-200 via-sky-300 to-sky-200`
- Text: `text-gray-800`, `text-gray-700`, `text-gray-900`
- Accents: Green (€), Blue (£), Red for negative values
- Dark elements: `bg-gray-900` for add button

## Typography

- Font family: 'Arimo' (add to `pubspec.yaml` if not available, or use system font)
- Font sizes: Match design (text-lg, text-base, text-sm, text-xs)
- Font weights: Normal for most text, Bold for numbers/headings

## Layout Structure

```
Scaffold
├── Custom Header (replaces AppBar)
│   ├── Profile + Greeting (left)
│   └── Icons (right)
├── Body (SingleChildScrollView)
│   ├── Main Stats Card (gradient blue)
│   ├── Action Buttons Row
│   ├── Latest Transactions Section
│   └── Project Categories Section
└── Custom Bottom Navigation (replaces TabBar)
```

## Key Files to Modify

1. **`auditra/lib/screens/coordinator_dashboard.dart`**

   - Replace AppBar with custom header widget
   - Add new widget methods for each section
   - Update `build()` method structure
   - Preserve all existing functionality and data loading

2. **`auditra/pubspec.yaml`** (if needed)

   - Add 'Arimo' font family if not using system fonts

## Implementation Steps

1. Create custom header widget replacing AppBar
2. Build main statistics card with gradient background
3. Create action buttons section with proper mappings
4. Implement latest transactions widget
5. Build project categories section
6. Replace TabBar with custom bottom navigation
7. Apply color scheme and typography throughout
8. Test all existing functionality still works
9. Ensure responsive design for different screen sizes

## Preserved Features

- All attendance tracking functionality
- All project management features
- User assignment capabilities
- Document upload/download
- Project creation and editing
- Search and filter functionality
- All API integrations remain unchanged

### To-dos

- [x] Create custom header widget with profile picture, greeting, and notification icons to replace AppBar
- [x] Build main statistics card with gradient background showing project metrics (total projects, status breakdown)
- [x] Create action buttons section (Create Project, Assign Users, View Documents) with white cards and dividers
- [x] Implement latest transactions section showing recent project activities with rounded cards
- [x] Build project categories section with three cards (Active, Pending, Add Project)
- [x] Replace TabBar with custom circular bottom navigation matching design
- [x] Apply exact color scheme (light green background, blue gradients, gray text) throughout dashboard
- [x] Test all existing features (attendance, projects, assignments) to ensure nothing is broken
- [ ] Create custom header widget with profile picture, greeting, and notification icons to replace AppBar
- [ ] Build main statistics card with gradient background showing project metrics (total projects, status breakdown)
- [ ] Create action buttons section (Create Project, Assign Users, View Documents) with white cards and dividers
- [ ] Implement latest transactions section showing recent project activities with rounded cards
- [ ] Build project categories section with three cards (Active, Pending, Add Project)
- [ ] Replace TabBar with custom circular bottom navigation matching design
- [ ] Apply exact color scheme (light green background, blue gradients, gray text) throughout dashboard
- [ ] Test all existing features (attendance, projects, assignments) to ensure nothing is broken
- [ ] Create custom header widget with profile picture, greeting, and notification icons to replace AppBar
- [ ] Build main statistics card with gradient background showing project metrics (total projects, status breakdown)
- [ ] Create action buttons section (Create Project, Assign Users, View Documents) with white cards and dividers
- [ ] Implement latest transactions section showing recent project activities with rounded cards
- [ ] Build project categories section with three cards (Active, Pending, Add Project)
- [ ] Replace TabBar with custom circular bottom navigation matching design
- [ ] Apply exact color scheme (light green background, blue gradients, gray text) throughout dashboard
- [ ] Test all existing features (attendance, projects, assignments) to ensure nothing is broken