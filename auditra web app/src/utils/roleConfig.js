import DashboardIcon from '@mui/icons-material/Dashboard';
import PeopleIcon from '@mui/icons-material/People';
import EventNoteIcon from '@mui/icons-material/EventNote';
import BeachAccessIcon from '@mui/icons-material/BeachAccess';
import PaymentIcon from '@mui/icons-material/Payment';
import PersonRemoveIcon from '@mui/icons-material/PersonRemove';
import FolderIcon from '@mui/icons-material/Folder';
import AddCircleIcon from '@mui/icons-material/AddCircle';
import PersonIcon from '@mui/icons-material/Person';
import AssignmentIcon from '@mui/icons-material/Assignment';
import RateReviewIcon from '@mui/icons-material/RateReview';
import ApprovalIcon from '@mui/icons-material/Approval';

export const roleMenuConfig = {
  admin: [
    { label: 'Dashboard', path: '/dashboard', icon: DashboardIcon },
    { label: 'User Management', path: '/dashboard/users', icon: PeopleIcon },
    { label: 'Attendance Summary', path: '/dashboard/attendance-summary', icon: EventNoteIcon },
    { label: 'Leave Management', path: '/dashboard/leave-management', icon: BeachAccessIcon },
    { label: 'Payments', path: '/dashboard/payments', icon: PaymentIcon },
    { label: 'Removal Requests', path: '/dashboard/removal-requests', icon: PersonRemoveIcon },
  ],
  coordinator: [
    { label: 'Dashboard', path: '/dashboard', icon: DashboardIcon },
    { label: 'Projects', path: '/dashboard/projects', icon: FolderIcon },
    { label: 'Create Project', path: '/dashboard/projects/create', icon: AddCircleIcon },
    { label: 'My Attendance', path: '/dashboard/my-attendance', icon: EventNoteIcon },
    { label: 'My Leave', path: '/dashboard/my-leave', icon: BeachAccessIcon },
    { label: 'My Payments', path: '/dashboard/my-payments', icon: PaymentIcon },
    { label: 'Profile', path: '/dashboard/profile', icon: PersonIcon },
  ],
  hr_staff: [
    { label: 'Dashboard', path: '/dashboard', icon: DashboardIcon },
    { label: 'Leave Requests', path: '/dashboard/leave-requests', icon: BeachAccessIcon },
    { label: 'Attendance View', path: '/dashboard/attendance-view', icon: EventNoteIcon },
    { label: 'Request Removal', path: '/dashboard/request-removal', icon: PersonRemoveIcon },
    { label: 'My Attendance', path: '/dashboard/my-attendance', icon: EventNoteIcon },
    { label: 'My Leave', path: '/dashboard/my-leave', icon: BeachAccessIcon },
    { label: 'My Payments', path: '/dashboard/my-payments', icon: PaymentIcon },
    { label: 'Profile', path: '/dashboard/profile', icon: PersonIcon },
  ],
  accessor: [
    { label: 'Dashboard', path: '/dashboard', icon: DashboardIcon },
    { label: 'My Projects', path: '/dashboard/my-projects', icon: FolderIcon },
    { label: 'My Attendance', path: '/dashboard/my-attendance', icon: EventNoteIcon },
    { label: 'My Leave', path: '/dashboard/my-leave', icon: BeachAccessIcon },
    { label: 'My Payments', path: '/dashboard/my-payments', icon: PaymentIcon },
    { label: 'Profile', path: '/dashboard/profile', icon: PersonIcon },
  ],
  senior_valuer: [
    { label: 'Dashboard', path: '/dashboard', icon: DashboardIcon },
    { label: 'Valuation Review', path: '/dashboard/valuation-review', icon: RateReviewIcon },
    { label: 'My Attendance', path: '/dashboard/my-attendance', icon: EventNoteIcon },
    { label: 'My Leave', path: '/dashboard/my-leave', icon: BeachAccessIcon },
    { label: 'My Payments', path: '/dashboard/my-payments', icon: PaymentIcon },
    { label: 'Profile', path: '/dashboard/profile', icon: PersonIcon },
  ],
  md_gm: [
    { label: 'Dashboard', path: '/dashboard', icon: DashboardIcon },
    { label: 'Project Approval', path: '/dashboard/project-approval', icon: ApprovalIcon },
    { label: 'My Attendance', path: '/dashboard/my-attendance', icon: EventNoteIcon },
    { label: 'My Leave', path: '/dashboard/my-leave', icon: BeachAccessIcon },
    { label: 'My Payments', path: '/dashboard/my-payments', icon: PaymentIcon },
    { label: 'Profile', path: '/dashboard/profile', icon: PersonIcon },
  ],
  field_officer: [
    { label: 'Dashboard', path: '/dashboard', icon: DashboardIcon },
    { label: 'My Attendance', path: '/dashboard/my-attendance', icon: EventNoteIcon },
    { label: 'My Leave', path: '/dashboard/my-leave', icon: BeachAccessIcon },
    { label: 'My Payments', path: '/dashboard/my-payments', icon: PaymentIcon },
    { label: 'Profile', path: '/dashboard/profile', icon: PersonIcon },
  ],
  general_employee: [
    { label: 'My Attendance', path: '/dashboard', icon: EventNoteIcon },
    { label: 'My Leave', path: '/dashboard/my-leave', icon: BeachAccessIcon },
    { label: 'My Payments', path: '/dashboard/my-payments', icon: PaymentIcon },
    { label: 'Profile', path: '/dashboard/profile', icon: PersonIcon },
  ],
  client: [
    { label: 'My Projects', path: '/dashboard', icon: FolderIcon },
    { label: 'Profile', path: '/dashboard/profile', icon: PersonIcon },
  ],
  agent: [
    { label: 'My Projects', path: '/dashboard', icon: FolderIcon },
    { label: 'Profile', path: '/dashboard/profile', icon: PersonIcon },
  ],
  unassigned: [
    { label: 'Profile', path: '/dashboard', icon: PersonIcon },
  ],
};

export const getRoleDashboardPath = (role) => {
  return '/dashboard';
};

export const getRoleLabel = (role) => {
  const labels = {
    admin: 'Admin',
    coordinator: 'Coordinator',
    field_officer: 'Field Officer',
    hr_staff: 'HR Staff',
    accessor: 'Accessor',
    senior_valuer: 'Senior Valuer',
    md_gm: 'MD/GM',
    general_employee: 'General Employee',
    client: 'Client',
    agent: 'Agent',
    unassigned: 'Unassigned',
  };
  return labels[role] || role;
};
