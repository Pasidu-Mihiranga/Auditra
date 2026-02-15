import { useState, useEffect, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { Box, Typography, Grid, Alert, Card, CardContent, useTheme, Divider } from '@mui/material';
import {
  ResponsiveContainer, PieChart, Pie, Cell, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend
} from 'recharts';
import PeopleIcon from '@mui/icons-material/People';
import EventNoteIcon from '@mui/icons-material/EventNote';
import BeachAccessIcon from '@mui/icons-material/BeachAccess';
import PaymentIcon from '@mui/icons-material/Payment';
import WorkOutlineIcon from '@mui/icons-material/WorkOutline';
import ReportProblemIcon from '@mui/icons-material/ReportProblem';
import AccountBalanceWalletIcon from '@mui/icons-material/AccountBalanceWallet';
import AssessmentIcon from '@mui/icons-material/Assessment';
import authService from '../../services/authService';
import attendanceService from '../../services/attendanceService';
import leaveService from '../../services/leaveService';
import paymentService from '../../services/paymentService';
import projectService from '../../services/projectService';
import removalService from '../../services/removalService';
import StatsCard from '../../components/StatsCard';
import LoadingSpinner from '../../components/LoadingSpinner';

export default function AdminDashboard() {
  const [data, setData] = useState({
    users: [],
    attendance: [],
    leaves: [],
    payments: [],
    removals: [],
    projects: [],
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const navigate = useNavigate();
  const theme = useTheme();

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [usersRes, attendanceRes, leavesRes, paymentsRes, removalsRes, projectsRes] = await Promise.all([
          authService.getAllUsers().catch(() => ({ data: [] })),
          attendanceService.getWeeklySummary().catch(() => ({ data: { data: [] } })),
          leaveService.getAllRequests().catch(() => ({ data: { data: [] } })),
          paymentService.getAllSlips().catch(() => ({ data: [] })),
          removalService.getAllRequests().catch(() => ({ data: [] })),
          projectService.getProjects().catch(() => ({ data: [] })),
        ]);

        const getArray = (res) => {
          if (res && res.data) {
            if (Array.isArray(res.data.data)) return res.data.data;
            if (Array.isArray(res.data)) return res.data;
          }
          return [];
        };

        setData({
          users: getArray(usersRes),
          attendance: getArray(attendanceRes),
          leaves: getArray(leavesRes),
          payments: getArray(paymentsRes),
          removals: getArray(removalsRes),
          projects: getArray(projectsRes),
        });
      } catch (err) {
        console.error('Admin Dashboard Fetch Error:', err);
        setError('Failed to load dashboard data');
      } finally {
        setLoading(false);
      }
    };
    fetchData();
  }, []);

  // Process Stats
  const stats = useMemo(() => {
    const currentMonth = new Date().getMonth() + 1;
    const currentYear = new Date().getFullYear();
    const monthlyPayments = data.payments.filter(p => p.month === currentMonth && p.year === currentYear);
    const payrollTotal = monthlyPayments.reduce((sum, p) => sum + parseFloat(p.net_salary || 0), 0);

    return {
      users: data.users.length,
      attendance: data.attendance.length,
      leaves: data.leaves.filter(l => l.status === 'pending').length,
      payments: data.payments.length,
      removals: data.removals.filter(r => r.status === 'pending').length,
      projects: data.projects.filter(p => !['completed', 'cancelled'].includes(p.status)).length,
      totalPayroll: payrollTotal,
    };
  }, [data]);

  // Process Chart Data
  const chartData = useMemo(() => {
    // 1. Status Distribution
    const statusMap = {};
    data.projects.forEach(p => {
      const status = p.status.charAt(0).toUpperCase() + p.status.slice(1).replace('_', ' ');
      statusMap[status] = (statusMap[status] || 0) + 1;
    });
    const statusChart = Object.keys(statusMap).map(key => ({ name: key, value: statusMap[key] }));

    // 2. Priority Distribution
    const priorityMap = {};
    data.projects.forEach(p => {
      const priority = p.priority.charAt(0).toUpperCase() + p.priority.slice(1);
      priorityMap[priority] = (priorityMap[priority] || 0) + 1;
    });
    const priorityChart = Object.keys(priorityMap).map(key => ({ name: key, value: priorityMap[key] }));

    // 3. Monthly Acquisition (Last 6 Months)
    const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    const acquisitionMap = {};

    // Initialize last 6 months
    for (let i = 5; i >= 0; i--) {
      const d = new Date();
      d.setMonth(d.getMonth() - i);
      const label = `${monthNames[d.getMonth()]} ${d.getFullYear() % 100}`;
      acquisitionMap[label] = 0;
    }

    data.projects.forEach(p => {
      const d = new Date(p.created_at);
      const label = `${monthNames[d.getMonth()]} ${d.getFullYear() % 100}`;
      if (acquisitionMap[label] !== undefined) {
        acquisitionMap[label]++;
      }
    });

    const acquisitionChart = Object.keys(acquisitionMap).map(key => ({ month: key, count: acquisitionMap[key] }));

    return { statusChart, priorityChart, acquisitionChart };
  }, [data.projects]);

  const COLORS = ['#2563EB', '#16A34A', '#D97706', '#DC2626', '#8B5CF6', '#EC4899'];
  const PRIORITY_COLORS = {
    'High': '#DC2626',
    'Medium': '#D97706',
    'Low': '#16A34A'
  };

  if (loading) return <LoadingSpinner />;

  return (
    <Box>
      <Typography variant="h5" sx={{ fontWeight: 700, mb: 3 }}>Admin Dashboard</Typography>
      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

      {/* KPI Cards Section */}
      <Grid container spacing={3} sx={{ mb: 4 }}>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard title="Total Users" value={stats.users} icon={PeopleIcon} color="#1565C0"
            onClick={() => navigate('/dashboard/users')} />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard title="Weekly Attendance" value={stats.attendance} icon={EventNoteIcon} color="#2563EB" subtitle="Staff Records"
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

        <Grid item xs={12} sm={6} md={3}>
          <StatsCard title="Active Projects" value={stats.projects} icon={WorkOutlineIcon} color="#0EA5E9"
            onClick={() => navigate('/dashboard/projects')} />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard title="Removal Requests" value={stats.removals} icon={ReportProblemIcon} color="#DC2626" subtitle="Pending Approval"
            onClick={() => navigate('/dashboard/removal-requests')} />
        </Grid>
        <Grid item xs={12} md={6}>
          <StatsCard title="Estimated Monthly Payroll" value={stats.totalPayroll.toLocaleString('en-US', { style: 'currency', currency: 'LKR' })}
            icon={AccountBalanceWalletIcon} color="#059669"
            subtitle={`${new Date().toLocaleString('default', { month: 'long' })} ${new Date().getFullYear()}`}
            onClick={() => navigate('/dashboard/payments')} />
        </Grid>
      </Grid>

      {/* Visual Analytics Section */}
      <Box sx={{ mb: 4 }}>
        <Box sx={{ display: 'flex', alignItems: 'center', mb: 2, gap: 1 }}>
          <AssessmentIcon color="primary" />
          <Typography variant="h6" sx={{ fontWeight: 600 }}>Visual Analytics</Typography>
        </Box>
        <Grid container spacing={3}>
          {/* Project Status Chart */}
          <Grid item xs={12} md={4}>
            <Card sx={{ height: '100%', borderRadius: 2, boxShadow: '0 4px 20px rgba(0,0,0,0.05)' }}>
              <CardContent>
                <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 2, color: 'text.secondary' }}>
                  Project Status Distribution
                </Typography>
                <Box sx={{ height: 250 }}>
                  <ResponsiveContainer width="100%" height="100%">
                    <PieChart>
                      <Pie
                        data={chartData.statusChart}
                        cx="50%"
                        cy="50%"
                        innerRadius={60}
                        outerRadius={80}
                        paddingAngle={5}
                        dataKey="value"
                      >
                        {chartData.statusChart.map((entry, index) => (
                          <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                        ))}
                      </Pie>
                      <Tooltip />
                      <Legend verticalAlign="bottom" height={36} />
                    </PieChart>
                  </ResponsiveContainer>
                </Box>
              </CardContent>
            </Card>
          </Grid>

          {/* Project Acquisition Trend */}
          <Grid item xs={12} md={5}>
            <Card sx={{ height: '100%', borderRadius: 2, boxShadow: '0 4px 20px rgba(0,0,0,0.05)' }}>
              <CardContent>
                <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 2, color: 'text.secondary' }}>
                  New Projects (Last 6 Months)
                </Typography>
                <Box sx={{ height: 250 }}>
                  <ResponsiveContainer width="100%" height="100%">
                    <BarChart data={chartData.acquisitionChart} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                      <CartesianGrid strokeDasharray="3 3" vertical={false} stroke={theme.palette.divider} />
                      <XAxis dataKey="month" axisLine={false} tickLine={false} tick={{ fontSize: 12 }} />
                      <YAxis axisLine={false} tickLine={false} tick={{ fontSize: 12 }} />
                      <Tooltip cursor={{ fill: 'transparent' }} />
                      <Bar dataKey="count" fill="#2563EB" radius={[4, 4, 0, 0]} />
                    </BarChart>
                  </ResponsiveContainer>
                </Box>
              </CardContent>
            </Card>
          </Grid>

          {/* Project Priority Chart */}
          <Grid item xs={12} md={3}>
            <Card sx={{ height: '100%', borderRadius: 2, boxShadow: '0 4px 20px rgba(0,0,0,0.05)' }}>
              <CardContent>
                <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 2, color: 'text.secondary' }}>
                  Priority Overview
                </Typography>
                <Box sx={{ height: 250 }}>
                  <ResponsiveContainer width="100%" height="100%">
                    <PieChart>
                      <Pie
                        data={chartData.priorityChart}
                        cx="50%"
                        cy="50%"
                        outerRadius={80}
                        dataKey="value"
                        labelLine={false}
                        label={({ name, percent }) => `${(percent * 100).toFixed(0)}%`}
                      >
                        {chartData.priorityChart.map((entry, index) => (
                          <Cell key={`cell-${index}`} fill={PRIORITY_COLORS[entry.name] || COLORS[index % COLORS.length]} />
                        ))}
                      </Pie>
                      <Tooltip />
                      <Legend verticalAlign="bottom" height={36} />
                    </PieChart>
                  </ResponsiveContainer>
                </Box>
              </CardContent>
            </Card>
          </Grid>
        </Grid>
      </Box>
    </Box>
  );
}
