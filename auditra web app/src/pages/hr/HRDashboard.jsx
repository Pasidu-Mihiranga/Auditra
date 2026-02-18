import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Box, Typography, Grid, Alert, Card, CardContent, CardActions,
  Button, Table, TableBody, TableCell, TableContainer,
  TableHead, TableRow, Paper,
} from '@mui/material';
import BeachAccessIcon from '@mui/icons-material/BeachAccess';
import EventNoteIcon from '@mui/icons-material/EventNote';
import PersonRemoveIcon from '@mui/icons-material/PersonRemove';
import PaymentIcon from '@mui/icons-material/Payment';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import { Check, Close } from '@mui/icons-material';
import { useAuth } from '../../contexts/AuthContext';
import leaveService from '../../services/leaveService';
import attendanceService from '../../services/attendanceService';
import paymentService from '../../services/paymentService';
import removalService from '../../services/removalService';
import StatsCard from '../../components/StatsCard';
import StatusChip from '../../components/StatusChip';
import LoadingSpinner from '../../components/LoadingSpinner';
import { formatDate } from '../../utils/helpers';

export default function HRDashboard() {
  const { user } = useAuth();
  const [stats, setStats] = useState({ pendingLeaves: 0, attendance: 0, payments: 0, pendingRemovals: 0 });
  const [recentLeaves, setRecentLeaves] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const navigate = useNavigate();

  const fetchData = async () => {
    try {
      const [leavesRes, attRes, paymentsRes, removalRes] = await Promise.all([
        leaveService.getAllRequests().catch(() => ({ data: [] })),
        attendanceService.getWeeklySummary().catch(() => ({ data: [] })),
        paymentService.getAllSlips().catch(() => ({ data: { data: [] } })),
        removalService.getAllRequests().catch(() => ({ data: [] })),
      ]);

      const leaves = Array.isArray(leavesRes.data) ? leavesRes.data : [];
      const payments = Array.isArray(paymentsRes.data?.data)
        ? paymentsRes.data.data
        : (Array.isArray(paymentsRes.data) ? paymentsRes.data : []);
      const removals = Array.isArray(removalRes.data) ? removalRes.data : [];

      setStats({
        pendingLeaves: leaves.filter(l => l.status === 'pending').length,
        attendance: Array.isArray(attRes.data) ? attRes.data.length : 0,
        payments: payments.length,
        pendingRemovals: removals.filter(r => r.status === 'pending').length,
      });

      const pending = leaves
        .filter(l => l.status === 'pending')
        .sort((a, b) => new Date(b.submitted_at) - new Date(a.submitted_at))
        .slice(0, 5);
      setRecentLeaves(pending);
    } catch {
      setError('Failed to load dashboard data');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  const handleLeaveAction = async (id, status) => {
    setError('');
    setSuccess('');
    try {
      await leaveService.updateRequest(id, { status });
      setSuccess(`Leave request ${status}`);
      fetchData();
    } catch (err) {
      setError(err.response?.data?.error || 'Action failed');
    }
  };

  if (loading) return <LoadingSpinner />;

  return (
    <Box>
      <Typography variant="h5" sx={{ fontWeight: 700 }} gutterBottom>
        HR Head Dashboard
      </Typography>
      <Typography variant="body1" color="text.secondary" sx={{ mb: 4 }}>
        Welcome back{user?.first_name ? `, ${user.first_name}` : ''}! Here is an overview of employee management.
      </Typography>

      {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError('')}>{error}</Alert>}
      {success && <Alert severity="success" sx={{ mb: 2 }} onClose={() => setSuccess('')}>{success}</Alert>}

      {/* Stats Cards */}
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
            title="Weekly Attendance"
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
            color="#DC2626"
            onClick={() => navigate('/dashboard/request-removal')}
          />
        </Grid>
      </Grid>

      {/* Recent Pending Leave Requests */}
      <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>
        Recent Pending Leave Requests
      </Typography>
      {recentLeaves.length === 0 ? (
        <Paper sx={{ p: 3, textAlign: 'center', borderRadius: 2, mb: 4 }}>
          <CheckCircleIcon sx={{ fontSize: 40, color: 'text.disabled', mb: 1 }} />
          <Typography color="text.secondary">No pending leave requests</Typography>
        </Paper>
      ) : (
        <TableContainer component={Paper} sx={{ borderRadius: 2, mb: 4 }}>
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Employee</TableCell>
                <TableCell>Type</TableCell>
                <TableCell>From</TableCell>
                <TableCell>To</TableCell>
                <TableCell>Status</TableCell>
                <TableCell>Actions</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {recentLeaves.map((leave) => (
                <TableRow key={leave.id} hover>
                  <TableCell sx={{ fontWeight: 600 }}>
                    {leave.user_display || leave.user_name || leave.user_username || `User #${leave.user}`}
                  </TableCell>
                  <TableCell>
                    {leave.leave_type || leave.type || '-'}
                  </TableCell>
                  <TableCell>{formatDate(leave.start_date)}</TableCell>
                  <TableCell>{formatDate(leave.end_date)}</TableCell>
                  <TableCell>
                    <StatusChip status={leave.status} />
                  </TableCell>
                  <TableCell>
                    {leave.status === 'pending' && (
                      <Box sx={{ display: 'flex', gap: 0.5 }}>
                        <Button
                          size="small"
                          variant="contained"
                          color="primary"
                          startIcon={<Check />}
                          onClick={() => handleLeaveAction(leave.id, 'approved')}
                          sx={{ width: 110 }}
                        >
                          Approve
                        </Button>
                        <Button
                          size="small"
                          variant="outlined"
                          color="error"
                          startIcon={<Close />}
                          onClick={() => handleLeaveAction(leave.id, 'rejected')}
                          sx={{ width: 110 }}
                        >
                          Reject
                        </Button>
                      </Box>
                    )}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
          {stats.pendingLeaves > 5 && (
            <Box sx={{ p: 1.5, textAlign: 'center' }}>
              <Button
                size="small"
                onClick={() => navigate('/dashboard/leave-management')}
                sx={{ textTransform: 'none' }}
              >
                View all {stats.pendingLeaves} pending requests
              </Button>
            </Box>
          )}
        </TableContainer>
      )}

      {/* Quick Actions */}
      <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>Quick Actions</Typography>
      <Grid container spacing={2}>
        <Grid item xs={12} sm={6} md={3}>
          <Card sx={{
            borderRadius: 2,
            cursor: 'pointer',
            transition: 'all 0.2s ease',
            '&:hover': {
              transform: 'translateY(-2px)',
              boxShadow: (t) => t.palette.mode === 'dark'
                ? '0 8px 24px rgba(0,0,0,0.4)'
                : '0 8px 24px rgba(0,0,0,0.12)',
            },
          }} onClick={() => navigate('/dashboard/leave-management')}>
            <CardContent>
              <BeachAccessIcon sx={{ fontSize: 40, mb: 1, color: '#1E88E5' }} />
              <Typography variant="subtitle1" fontWeight={600}>Leave Management</Typography>
              <Typography variant="body2" color="text.secondary">
                Approve or reject employee leave requests
              </Typography>
            </CardContent>
            <CardActions>
              <Button size="small">Open</Button>
            </CardActions>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card sx={{
            borderRadius: 2,
            cursor: 'pointer',
            transition: 'all 0.2s ease',
            '&:hover': {
              transform: 'translateY(-2px)',
              boxShadow: (t) => t.palette.mode === 'dark'
                ? '0 8px 24px rgba(0,0,0,0.4)'
                : '0 8px 24px rgba(0,0,0,0.12)',
            },
          }} onClick={() => navigate('/dashboard/payments')}>
            <CardContent>
              <PaymentIcon sx={{ fontSize: 40, mb: 1, color: '#1565C0' }} />
              <Typography variant="subtitle1" fontWeight={600}>Payments</Typography>
              <Typography variant="body2" color="text.secondary">
                Generate and manage employee payment slips
              </Typography>
            </CardContent>
            <CardActions>
              <Button size="small">Open</Button>
            </CardActions>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card sx={{
            borderRadius: 2,
            cursor: 'pointer',
            transition: 'all 0.2s ease',
            '&:hover': {
              transform: 'translateY(-2px)',
              boxShadow: (t) => t.palette.mode === 'dark'
                ? '0 8px 24px rgba(0,0,0,0.4)'
                : '0 8px 24px rgba(0,0,0,0.12)',
            },
          }} onClick={() => navigate('/dashboard/attendance-summary')}>
            <CardContent>
              <EventNoteIcon sx={{ fontSize: 40, mb: 1, color: '#2563EB' }} />
              <Typography variant="subtitle1" fontWeight={600}>Attendance Summary</Typography>
              <Typography variant="body2" color="text.secondary">
                View weekly attendance records for all employees
              </Typography>
            </CardContent>
            <CardActions>
              <Button size="small">Open</Button>
            </CardActions>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card sx={{
            borderRadius: 2,
            cursor: 'pointer',
            transition: 'all 0.2s ease',
            '&:hover': {
              transform: 'translateY(-2px)',
              boxShadow: (t) => t.palette.mode === 'dark'
                ? '0 8px 24px rgba(0,0,0,0.4)'
                : '0 8px 24px rgba(0,0,0,0.12)',
            },
          }} onClick={() => navigate('/dashboard/request-removal')}>
            <CardContent>
              <PersonRemoveIcon sx={{ fontSize: 40, mb: 1, color: '#DC2626' }} />
              <Typography variant="subtitle1" fontWeight={600}>Request Removal</Typography>
              <Typography variant="body2" color="text.secondary">
                Submit employee removal requests for admin approval
              </Typography>
            </CardContent>
            <CardActions>
              <Button size="small">Open</Button>
            </CardActions>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
}
