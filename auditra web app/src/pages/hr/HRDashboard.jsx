import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Box, Typography, Grid, Alert } from '@mui/material';
import BeachAccessIcon from '@mui/icons-material/BeachAccess';
import EventNoteIcon from '@mui/icons-material/EventNote';
import PersonRemoveIcon from '@mui/icons-material/PersonRemove';
import leaveService from '../../services/leaveService';
import attendanceService from '../../services/attendanceService';
import StatsCard from '../../components/StatsCard';
import LoadingSpinner from '../../components/LoadingSpinner';

export default function HRDashboard() {
  const [stats, setStats] = useState({ pending: 0, attendance: 0 });
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    const fetch = async () => {
      try {
        const [leavesRes, attRes] = await Promise.all([
          leaveService.getAllRequests().catch(() => ({ data: [] })),
          attendanceService.getWeeklySummary().catch(() => ({ data: [] })),
        ]);
        const leaves = Array.isArray(leavesRes.data) ? leavesRes.data : [];
        setStats({
          pending: leaves.filter(l => l.status === 'pending').length,
          attendance: Array.isArray(attRes.data) ? attRes.data.length : 0,
        });
      } catch {} finally { setLoading(false); }
    };
    fetch();
  }, []);

  if (loading) return <LoadingSpinner />;

  return (
    <Box>
      <Typography variant="h5" sx={{ fontWeight: 700, mb: 3 }}>HR Dashboard</Typography>
      <Grid container spacing={3}>
        <Grid item xs={12} sm={4}>
          <StatsCard title="Pending Leave Requests" value={stats.pending} icon={BeachAccessIcon} color="#D97706"
            onClick={() => navigate('/dashboard/leave-requests')} />
        </Grid>
        <Grid item xs={12} sm={4}>
          <StatsCard title="Weekly Attendance" value={stats.attendance} icon={EventNoteIcon} color="#2563EB"
            onClick={() => navigate('/dashboard/attendance-view')} />
        </Grid>
        <Grid item xs={12} sm={4}>
          <StatsCard title="Employee Actions" value="Manage" icon={PersonRemoveIcon} color="#DC2626" subtitle="Leave & Removal"
            onClick={() => navigate('/dashboard/request-removal')} />
        </Grid>
      </Grid>
    </Box>
  );
}
