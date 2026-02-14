import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Box, Typography, Grid } from '@mui/material';
import { Assignment, PendingActions, CheckCircle, Assessment } from '@mui/icons-material';
import StatsCard from '../../components/StatsCard';
import LoadingSpinner from '../../components/LoadingSpinner';
import projectService from '../../services/projectService';

export default function AccessorDashboard() {
  const [stats, setStats] = useState({ total: 0, pending: 0, completed: 0, inProgress: 0 });
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    const fetchStats = async () => {
      try {
        const res = await projectService.getProjects();
        const projects = Array.isArray(res.data) ? res.data : res.data?.results || [];
        setStats({
          total: projects.length,
          pending: projects.filter(p => p.status === 'pending').length,
          completed: projects.filter(p => p.status === 'completed').length,
          inProgress: projects.filter(p => p.status === 'active' || p.status === 'in_progress').length,
        });
      } catch (err) {
        console.error('Failed to fetch stats:', err);
      } finally {
        setLoading(false);
      }
    };
    fetchStats();
  }, []);

  if (loading) return <LoadingSpinner />;

  return (
    <Box>
      <Typography variant="h5" sx={{ fontWeight: 700 }} gutterBottom>Accessor Dashboard</Typography>
      <Typography variant="body1" color="text.secondary" sx={{ mb: 4 }}>
        Welcome back! Here is an overview of your assigned projects.
      </Typography>

      <Grid container spacing={3}>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard title="Total Projects" value={stats.total} icon={Assignment} color="#2563EB"
            onClick={() => navigate('/dashboard/my-projects')} />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard title="In Progress" value={stats.inProgress} icon={PendingActions} color="#D97706"
            onClick={() => navigate('/dashboard/my-projects', { state: { filter: 'in_progress' } })} />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard title="Completed" value={stats.completed} icon={CheckCircle} color="#16A34A"
            onClick={() => navigate('/dashboard/my-projects', { state: { filter: 'completed' } })} />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard title="Pending" value={stats.pending} icon={Assessment} color="#DC2626"
            onClick={() => navigate('/dashboard/my-projects', { state: { filter: 'pending' } })} />
        </Grid>
      </Grid>
    </Box>
  );
}
