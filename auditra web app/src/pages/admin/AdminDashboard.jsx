import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Box, Typography, Grid, Alert } from '@mui/material';
import PeopleIcon from '@mui/icons-material/People';
import EventNoteIcon from '@mui/icons-material/EventNote';
import BeachAccessIcon from '@mui/icons-material/BeachAccess';
import PaymentIcon from '@mui/icons-material/Payment';
import authService from '../../services/authService';
import attendanceService from '../../services/attendanceService';
import leaveService from '../../services/leaveService';
import paymentService from '../../services/paymentService';
import StatsCard from '../../components/StatsCard';
import LoadingSpinner from '../../components/LoadingSpinner';

export default function AdminDashboard() {
  const [stats, setStats] = useState({ users: 0, attendance: 0, leaves: 0, payments: 0 });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const navigate = useNavigate();

  useEffect(() => {
    const fetchStats = async () => {
      try {
        const [usersRes, attendanceRes, leavesRes, paymentsRes] = await Promise.all([
          authService.getAllUsers().catch(() => ({ data: [] })),
          attendanceService.getWeeklySummary().catch(() => ({ data: [] })),
          leaveService.getAllRequests().catch(() => ({ data: [] })),
          paymentService.getAllSlips().catch(() => ({ data: [] })),
        ]);
        setStats({
          users: Array.isArray(usersRes.data) ? usersRes.data.length : 0,
          attendance: Array.isArray(attendanceRes.data) ? attendanceRes.data.length : 0,
          leaves: Array.isArray(leavesRes.data) ? leavesRes.data.filter(l => l.status === 'pending').length : 0,
          payments: Array.isArray(paymentsRes.data) ? paymentsRes.data.length : 0,
        });
      } catch {
        setError('Failed to load dashboard data');
      } finally {
        setLoading(false);
      }
    };
    fetchStats();
  }, []);

  if (loading) return <LoadingSpinner />;

  return (
    <Box>
      <Typography variant="h5" sx={{ fontWeight: 700, mb: 3 }}>Admin Dashboard</Typography>
      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
      <Grid container spacing={3}>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard title="Total Users" value={stats.users} icon={PeopleIcon} color="#1565C0"
            onClick={() => navigate('/dashboard/users')} />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard title="This Week" value={stats.attendance} icon={EventNoteIcon} color="#1565C0" subtitle="Attendance Records"
            onClick={() => navigate('/dashboard/attendance-summary')} />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard title="Pending Leaves" value={stats.leaves} icon={BeachAccessIcon} color="#D97706"
            onClick={() => navigate('/dashboard/leave-management')} />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard title="Payment Slips" value={stats.payments} icon={PaymentIcon} color="#16A34A"
            onClick={() => navigate('/dashboard/payments')} />
        </Grid>
      </Grid>
    </Box>
  );
}
