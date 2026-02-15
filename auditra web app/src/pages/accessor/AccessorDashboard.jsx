import { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import {
  Box, Typography, Grid, Card, CardContent,
  Table, TableBody, TableCell, TableContainer,
  TableHead, TableRow, Paper, Button, Chip, Divider
} from '@mui/material';
import { Assignment, PendingActions, CheckCircle, RateReview, AccessTime } from '@mui/icons-material';
import StatsCard from '../../components/StatsCard';
import LoadingSpinner from '../../components/LoadingSpinner';
import projectService from '../../services/projectService';
import valuationService from '../../services/valuationService';
import StatusChip from '../../components/StatusChip';

export default function AccessorDashboard() {
  const [stats, setStats] = useState({
    totalProjects: 0, completedProjects: 0, inProgressProjects: 0,
    totalValuations: 0, pendingValuations: 0, approvedValuations: 0, rejectedValuations: 0
  });
  const [recentProjects, setRecentProjects] = useState([]);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    const fetchAllStats = async () => {
      try {
        setLoading(true);
        const [projectRes, valuationRes] = await Promise.all([
          projectService.getProjects(),
          valuationService.getValuations()
        ]);

        const projects = Array.isArray(projectRes.data) ? projectRes.data : projectRes.data?.results || [];
        const valuations = Array.isArray(valuationRes.data) ? valuationRes.data : valuationRes.data?.results || [];

        // Calculate Project Stats
        const projectStats = {
          totalProjects: projects.length,
          completedProjects: projects.filter(p => p.status === 'completed').length,
          inProgressProjects: projects.filter(p => p.status === 'active' || p.status === 'in_progress').length,
        };

        // Calculate Valuation Stats
        const valuationStats = {
          totalValuations: valuations.length,
          pendingValuations: valuations.filter(v => v.status === 'pending' || v.status === 'submitted').length,
          approvedValuations: valuations.filter(v => v.status === 'reviewed' || v.status === 'approved').length,
          rejectedValuations: valuations.filter(v => v.status === 'rejected').length,
        };

        setStats({ ...projectStats, ...valuationStats });

        // Get 5 most recent projects
        const sorted = [...projects].sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
        setRecentProjects(sorted.slice(0, 5));
      } catch (err) {
        console.error('Failed to fetch stats:', err);
      } finally {
        setLoading(false);
      }
    };
    fetchAllStats();
  }, []);

  const formatDate = (dateString) => {
    if (!dateString) return '-';
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  };

  const getPriorityColor = (priority) => {
    switch (priority?.toLowerCase()) {
      case 'high': return 'error';
      case 'medium': return 'warning';
      case 'low': return 'info';
      default: return 'default';
    }
  };

  if (loading) return <LoadingSpinner />;

  return (
    <Box>
      <Typography variant="h5" sx={{ fontWeight: 700 }} gutterBottom>Accessor Dashboard</Typography>
      <Typography variant="body1" color="text.secondary" sx={{ mb: 4 }}>
        Welcome back! Here is an overview of your work and assigned projects.
      </Typography>

      <Typography variant="h6" sx={{ mb: 2, fontWeight: 600 }}>Valuation Overview</Typography>
      <Grid container spacing={3} sx={{ mb: 5 }}>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard title="Total Valuations" value={stats.totalValuations} icon={Assignment} color="#2563EB"
            onClick={() => navigate('/dashboard/my-projects')} />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard title="Pending Review" value={stats.pendingValuations} icon={PendingActions} color="#D97706"
            onClick={() => navigate('/dashboard/my-projects')} />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard title="Processed" value={stats.approvedValuations} icon={CheckCircle} color="#16A34A"
            onClick={() => navigate('/dashboard/my-projects')} />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard title="Rejected" value={stats.rejectedValuations} icon={RateReview} color="#DC2626"
            onClick={() => navigate('/dashboard/my-projects')} />
        </Grid>
      </Grid>

      <Divider sx={{ mb: 4 }} />

      <Typography variant="h6" sx={{ mb: 2, fontWeight: 600 }}>Project Overview</Typography>
      <Grid container spacing={3} sx={{ mb: 4 }}>
        <Grid item xs={12} sm={4}>
          <StatsCard title="Total Projects" value={stats.totalProjects} icon={Assignment} color="#4F46E5"
            onClick={() => navigate('/dashboard/my-projects')} />
        </Grid>
        <Grid item xs={12} sm={4}>
          <StatsCard title="In Progress" value={stats.inProgressProjects} icon={AccessTime} color="#0891B2"
            onClick={() => navigate('/dashboard/my-projects', { state: { filter: 'in_progress' } })} />
        </Grid>
        <Grid item xs={12} sm={4}>
          <StatsCard title="Completed" value={stats.completedProjects} icon={CheckCircle} color="#059669"
            onClick={() => navigate('/dashboard/my-projects', { state: { filter: 'completed' } })} />
        </Grid>
      </Grid>

      <Box sx={{ mt: 4 }}>
        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
          <Typography variant="h6" sx={{ fontWeight: 600 }}>Recent Projects</Typography>
          <Button component={Link} to="/dashboard/my-projects" variant="text" size="small">
            View All
          </Button>
        </Box>

        <TableContainer component={Paper} sx={{ borderRadius: 2, boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)' }}>
          <Table>
            <TableHead sx={{ bgcolor: 'grey.50' }}>
              <TableRow>
                <TableCell sx={{ fontWeight: 600 }}>Project Title</TableCell>
                <TableCell sx={{ fontWeight: 600 }}>Status</TableCell>
                <TableCell sx={{ fontWeight: 600 }}>Priority</TableCell>
                <TableCell sx={{ fontWeight: 600 }}>Created Date</TableCell>
                <TableCell sx={{ fontWeight: 600 }} align="right">Actions</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {recentProjects.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={5} align="center" sx={{ py: 4 }}>
                    <Typography color="text.secondary">No projects assigned yet.</Typography>
                  </TableCell>
                </TableRow>
              ) : (
                recentProjects.map((project) => (
                  <TableRow key={project.id} hover sx={{ '&:last-child td, &:last-child th': { border: 0 } }}>
                    <TableCell sx={{ fontWeight: 500 }}>{project.title}</TableCell>
                    <TableCell>
                      <StatusChip status={project.status} />
                    </TableCell>
                    <TableCell>
                      <Chip
                        label={project.priority?.toUpperCase()}
                        size="small"
                        color={getPriorityColor(project.priority)}
                        variant="soft"
                        sx={{ fontWeight: 600, fontSize: '0.65rem' }}
                      />
                    </TableCell>
                    <TableCell color="text.secondary">{formatDate(project.created_at)}</TableCell>
                    <TableCell align="right">
                      <Button
                        component={Link}
                        to={`/dashboard/projects/${project.id}`}
                        size="small"
                        variant="outlined"
                        sx={{ textTransform: 'none' }}
                      >
                        Details
                      </Button>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </TableContainer>
      </Box>
    </Box>
  );
}
