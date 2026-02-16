import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Box, Typography, Grid } from '@mui/material';
import { Gavel, PendingActions, CheckCircle, Assignment } from '@mui/icons-material';
import StatsCard from '../../components/StatsCard';
import LoadingSpinner from '../../components/LoadingSpinner';
import projectService from '../../services/projectService';

export default function MDGMDashboard() {
  const [stats, setStats] = useState({ total: 0, pending: 0, approved: 0, rejected: 0 });
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
          approved: projects.filter(p => p.status === 'approved' || p.status === 'active').length,
          rejected: projects.filter(p => p.status === 'rejected').length,
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
      <Typography variant="h5" sx={{ fontWeight: 700 }} gutterBottom>MD / GM Dashboard</Typography>
      <Typography variant="body1" color="text.secondary" sx={{ mb: 4 }}>
        Welcome back! Here is an overview of projects awaiting your approval.
      </Typography>

      <Grid container spacing={3}>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard title="Total Projects" value={stats.total} icon={Assignment} color="#2563EB"
            onClick={() => navigate('/dashboard/project-approval')} />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard title="Pending Approval" value={stats.pending} icon={PendingActions} color="#D97706"
            onClick={() => navigate('/dashboard/project-approval', { state: { filter: 'pending' } })} />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard title="Approved" value={stats.approved} icon={CheckCircle} color="#16A34A"
            onClick={() => navigate('/dashboard/project-approval', { state: { filter: 'approved' } })} />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard title="Rejected" value={stats.rejected} icon={Gavel} color="#DC2626"
            onClick={() => navigate('/dashboard/project-approval', { state: { filter: 'rejected' } })} />
        </Grid>
      </Grid>
    </Box>
  );
}
