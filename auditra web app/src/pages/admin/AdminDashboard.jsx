import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Box, Typography, Grid, Alert } from '@mui/material';
import PeopleIcon from '@mui/icons-material/People';
import PersonRemoveIcon from '@mui/icons-material/PersonRemove';
import authService from '../../services/authService';
import removalService from '../../services/removalService';
import StatsCard from '../../components/StatsCard';
import LoadingSpinner from '../../components/LoadingSpinner';

export default function AdminDashboard() {
  const [stats, setStats] = useState({ users: 0, removalRequests: 0 });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const navigate = useNavigate();

  useEffect(() => {
    const fetchStats = async () => {
      try {
        const [usersRes, removalRes] = await Promise.all([
          authService.getAllUsers().catch(() => ({ data: [] })),
          removalService.getAllRequests().catch(() => ({ data: [] })),
        ]);
        const removals = Array.isArray(removalRes.data) ? removalRes.data : [];
        setStats({
          users: Array.isArray(usersRes.data) ? usersRes.data.length : 0,
          removalRequests: removals.filter(r => r.status === 'pending').length,
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
        <Grid item xs={12} sm={6}>
          <StatsCard title="Total Users" value={stats.users} icon={PeopleIcon} color="#1565C0"
            onClick={() => navigate('/dashboard/users')} />
        </Grid>
        <Grid item xs={12} sm={6}>
          <StatsCard title="Pending Removal Requests" value={stats.removalRequests} icon={PersonRemoveIcon} color="#DC2626"
            onClick={() => navigate('/dashboard/removal-requests')} />
        </Grid>
      </Grid>
    </Box>
  );
}
