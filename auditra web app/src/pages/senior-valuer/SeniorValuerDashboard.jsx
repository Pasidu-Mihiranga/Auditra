import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Box, Typography, Grid, Alert } from '@mui/material';
import { RateReview, PendingActions, CheckCircle, Assignment } from '@mui/icons-material';
import StatsCard from '../../components/StatsCard';
import LoadingSpinner from '../../components/LoadingSpinner';
import valuationService from '../../services/valuationService';

export default function SeniorValuerDashboard() {
  const [stats, setStats] = useState({ total: 0, pending: 0, approved: 0, rejected: 0 });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const navigate = useNavigate();

  useEffect(() => {
    const fetchStats = async () => {
      try {
        const res = await valuationService.getValuations();
        const valuations = Array.isArray(res.data) ? res.data : res.data?.results || [];
        setStats({
          total: valuations.length,
          pending: valuations.filter(v => v.status === 'pending' || v.status === 'submitted').length,
          approved: valuations.filter(v => v.status === 'approved').length,
          rejected: valuations.filter(v => v.status === 'rejected').length,
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
      <Typography variant="h5" sx={{ fontWeight: 700, mb: 3 }}>Senior Valuer Dashboard</Typography>
      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
      <Grid container spacing={3}>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard title="Total Valuations" value={stats.total} icon={Assignment} color="#1565C0"
            onClick={() => navigate('/dashboard/valuation-review')} />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard title="Pending Review" value={stats.pending} icon={PendingActions} color="#1E88E5"
            onClick={() => navigate('/dashboard/valuation-review', { state: { filter: 'pending' } })} />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard title="Approved" value={stats.approved} icon={CheckCircle} color="#1565C0"
            onClick={() => navigate('/dashboard/valuation-review', { state: { filter: 'approved' } })} />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard title="Rejected" value={stats.rejected} icon={RateReview} color="#DC2626"
            onClick={() => navigate('/dashboard/valuation-review', { state: { filter: 'rejected' } })} />
        </Grid>
      </Grid>
    </Box>
  );
}
