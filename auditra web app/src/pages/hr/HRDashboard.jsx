import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Box, Typography, Grid, Alert } from '@mui/material';
import BeachAccessIcon from '@mui/icons-material/BeachAccess';
import EventNoteIcon from '@mui/icons-material/EventNote';
import PersonRemoveIcon from '@mui/icons-material/PersonRemove';
import PaymentIcon from '@mui/icons-material/Payment';
import leaveService from '../../services/leaveService';
import attendanceService from '../../services/attendanceService';
import paymentService from '../../services/paymentService';
import removalService from '../../services/removalService';
import StatsCard from '../../components/StatsCard';
import LoadingSpinner from '../../components/LoadingSpinner';

export default function HRDashboard() {
  const [stats, setStats] = useState({ pendingLeaves: 0, attendance: 0, payments: 0, pendingRemovals: 0 });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const navigate = useNavigate();

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [leavesRes, attRes, paymentsRes, removalRes] = await Promise.all([
          leaveService.getAllRequests().catch(() => ({ data: { data: [] } })),
          attendanceService.getHRAttendanceSummary('daily').catch(() => ({ data: { data: [] } })),
          paymentService.getAllSlips().catch(() => ({ data: { data: [] } })),
          removalService.getAllRequests().catch(() => ({ data: [] })),
        ]);

        const leaves = Array.isArray(leavesRes.data?.data)
          ? leavesRes.data.data
          : (Array.isArray(leavesRes.data) ? leavesRes.data : []);
        const attendance = Array.isArray(attRes.data?.data)
          ? attRes.data.data
          : (Array.isArray(attRes.data) ? attRes.data : []);
        const payments = Array.isArray(paymentsRes.data?.data)
          ? paymentsRes.data.data
          : (Array.isArray(paymentsRes.data) ? paymentsRes.data : []);
        const removals = Array.isArray(removalRes.data?.results)
          ? removalRes.data.results
          : (Array.isArray(removalRes.data) ? removalRes.data : []);

        const now = new Date();
        const currentMonth = now.getMonth() + 1;
        const currentYear = now.getFullYear();

        setStats({
          pendingLeaves: leaves.filter(l => l.status === 'pending').length,
          attendance: attendance.filter(a => a.status === 'present').length,
          payments: payments.filter(p => Number(p.month) === currentMonth && Number(p.year) === currentYear).length,
          pendingRemovals: removals.filter(r => r.status === 'pending').length,
        });
      } catch {
        setError('Failed to load dashboard data');
      } finally {
        setLoading(false);
      }
    };
    fetchData();
  }, []);

  if (loading) return <LoadingSpinner />;

  return (
    <Box>
      <Typography variant="h5" sx={{ fontWeight: 700 }} gutterBottom>
        HR Head Dashboard
      </Typography>

      {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError('')}>{error}</Alert>}

      <Grid container spacing={3} sx={{ mb: 4 }}>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard
            title="Pending Leave Requests"
            value={stats.pendingLeaves}
            icon={BeachAccessIcon}
            color="#1E88E5"
            onClick={() => navigate('/dashboard/leave-management')}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard
            title="Payment Slips"
            value={stats.payments}
            icon={PaymentIcon}
            color="#1565C0"
            onClick={() => navigate('/dashboard/payments')}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard
            title="Daily Attendance"
            value={stats.attendance}
            icon={EventNoteIcon}
            color="#2563EB"
            onClick={() => navigate('/dashboard/attendance-summary')}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard
            title="Pending Removals"
            value={stats.pendingRemovals}
            icon={PersonRemoveIcon}
            color="#0D47A1"
            onClick={() => navigate('/dashboard/request-removal')}
          />
        </Grid>
      </Grid>
    </Box>
  );
}
