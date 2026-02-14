import { useState, useEffect } from 'react';
import {
  Box, Typography, Paper, Grid, Button, Alert, Card, CardContent, CardActions, Chip
} from '@mui/material';
import PhoneAndroidIcon from '@mui/icons-material/PhoneAndroid';
import EventNoteIcon from '@mui/icons-material/EventNote';
import BeachAccessIcon from '@mui/icons-material/BeachAccess';
import PaymentIcon from '@mui/icons-material/Payment';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import LogoutIcon from '@mui/icons-material/Logout';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../../contexts/AuthContext';
import attendanceService from '../../services/attendanceService';
import leaveService from '../../services/leaveService';

export default function FieldOfficerDashboard() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [todayAttendance, setTodayAttendance] = useState(null);
  const [leaveStats, setLeaveStats] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [attendanceRes, leaveRes] = await Promise.allSettled([
          attendanceService.getTodayStatus(),
          leaveService.getMyStatistics(),
        ]);
        if (attendanceRes.status === 'fulfilled') setTodayAttendance(attendanceRes.value.data);
        if (leaveRes.status === 'fulfilled') setLeaveStats(leaveRes.value.data);
      } catch (err) {
        // Silent fail - dashboard still renders
      } finally {
        setLoading(false);
      }
    };
    fetchData();
  }, []);

  const isCheckedIn = todayAttendance?.is_checked_in || todayAttendance?.checked_in;

  return (
    <Box>
      <Typography variant="h4" fontWeight={700} gutterBottom>
        Welcome, {user?.first_name || user?.username || 'Field Officer'}
      </Typography>
      <Typography variant="body1" color="text.secondary" sx={{ mb: 3 }}>
        Field Officer Dashboard
      </Typography>

      {/* Mobile app banner */}
      <Alert
        severity="info"
        icon={<PhoneAndroidIcon />}
        sx={{
          mb: 3,
          borderRadius: 2,
          '& .MuiAlert-message': { width: '100%' },
        }}
      >
        <Typography variant="subtitle1" fontWeight={600}>
          Project & Valuation Work
        </Typography>
        <Typography variant="body2">
          For project assignments, valuations, site visits, and document uploads, please use the
          <strong> Auditra mobile app</strong>. This web portal is for attendance, leave, and payment management.
        </Typography>
      </Alert>

      {/* Quick stats */}
      <Grid container spacing={3} sx={{ mb: 3 }}>
        {/* Today's Attendance */}
        <Grid item xs={12} sm={6} md={4}>
          <Paper sx={{ p: 3, borderRadius: 2, height: '100%' }}>
            <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
              <EventNoteIcon color="primary" sx={{ mr: 1 }} />
              <Typography variant="h6" fontWeight={600}>Today's Attendance</Typography>
            </Box>
            {isCheckedIn ? (
              <Chip label="Checked In" color="success" icon={<CheckCircleIcon />} />
            ) : (
              <Chip label="Not Checked In" color="default" />
            )}
            {todayAttendance?.check_in_time && (
              <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                Checked in at: {new Date(todayAttendance.check_in_time).toLocaleTimeString()}
              </Typography>
            )}
          </Paper>
        </Grid>

        {/* Leave Balance */}
        <Grid item xs={12} sm={6} md={4}>
          <Paper sx={{ p: 3, borderRadius: 2, height: '100%' }}>
            <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
              <BeachAccessIcon color="primary" sx={{ mr: 1 }} />
              <Typography variant="h6" fontWeight={600}>Leave Requests</Typography>
            </Box>
            <Typography variant="h3" fontWeight={700} color="primary">
              {leaveStats?.pending_count ?? leaveStats?.pending ?? '-'}
            </Typography>
            <Typography variant="body2" color="text.secondary">Pending requests</Typography>
          </Paper>
        </Grid>

        {/* Payments */}
        <Grid item xs={12} sm={6} md={4}>
          <Paper sx={{ p: 3, borderRadius: 2, height: '100%' }}>
            <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
              <PaymentIcon color="primary" sx={{ mr: 1 }} />
              <Typography variant="h6" fontWeight={600}>Payment Slips</Typography>
            </Box>
            <Typography variant="body2" color="text.secondary">
              View your salary slips and payment history
            </Typography>
          </Paper>
        </Grid>
      </Grid>

      {/* Quick actions */}
      <Typography variant="h6" fontWeight={600} sx={{ mb: 2 }}>Quick Actions</Typography>
      <Grid container spacing={2}>
        <Grid item xs={12} sm={6} md={3}>
          <Card sx={{ borderRadius: 2 }}>
            <CardContent>
              <EventNoteIcon color="primary" sx={{ fontSize: 40, mb: 1 }} />
              <Typography variant="subtitle1" fontWeight={600}>Attendance</Typography>
              <Typography variant="body2" color="text.secondary">
                Mark check-in/out and view summary
              </Typography>
            </CardContent>
            <CardActions>
              <Button size="small" onClick={() => navigate('/dashboard/my-attendance')}>
                Open
              </Button>
            </CardActions>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card sx={{ borderRadius: 2 }}>
            <CardContent>
              <BeachAccessIcon color="primary" sx={{ fontSize: 40, mb: 1 }} />
              <Typography variant="subtitle1" fontWeight={600}>Leave Requests</Typography>
              <Typography variant="body2" color="text.secondary">
                Apply for leave or view request status
              </Typography>
            </CardContent>
            <CardActions>
              <Button size="small" onClick={() => navigate('/dashboard/my-leave')}>
                Open
              </Button>
            </CardActions>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card sx={{ borderRadius: 2 }}>
            <CardContent>
              <PaymentIcon color="primary" sx={{ fontSize: 40, mb: 1 }} />
              <Typography variant="subtitle1" fontWeight={600}>Payment Slips</Typography>
              <Typography variant="body2" color="text.secondary">
                View your salary and payment history
              </Typography>
            </CardContent>
            <CardActions>
              <Button size="small" onClick={() => navigate('/dashboard/my-payments')}>
                Open
              </Button>
            </CardActions>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card sx={{ borderRadius: 2, bgcolor: 'action.hover' }}>
            <CardContent>
              <PhoneAndroidIcon sx={{ fontSize: 40, mb: 1, color: 'text.secondary' }} />
              <Typography variant="subtitle1" fontWeight={600}>Project Work</Typography>
              <Typography variant="body2" color="text.secondary">
                Use the Auditra mobile app for projects & valuations
              </Typography>
            </CardContent>
            <CardActions>
              <Button size="small" disabled>
                Mobile Only
              </Button>
            </CardActions>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
}
