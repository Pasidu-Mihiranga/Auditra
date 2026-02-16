import { useState, useEffect } from 'react';
import {
  Box, Typography, Paper, Table, TableBody, TableCell, TableContainer,
  TableHead, TableRow, TextField, MenuItem, CircularProgress, Alert, Snackbar, Chip
} from '@mui/material';
import attendanceService from '../../services/attendanceService';
import { formatDate } from '../../utils/helpers';

export default function AttendanceView() {
  const [summary, setSummary] = useState([]);
  const [loading, setLoading] = useState(true);
  const [period, setPeriod] = useState('weekly');
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'error' });

  useEffect(() => { fetchSummary(); }, [period]);

  const fetchSummary = async () => {
    try {
      setLoading(true);
      const res = period === 'weekly'
        ? await attendanceService.getWeeklySummary()
        : await attendanceService.getSummary({ period });

      const data = res.data?.data;
      if (period === 'weekly') {
        setSummary(Array.isArray(data) ? data : []);
      } else {
        setSummary(data?.daily_data || []);
      }
    } catch (err) {
      setSnackbar({ open: true, message: 'Failed to load attendance summary', severity: 'error' });
    } finally {
      setLoading(false);
    }
  };

  if (loading) return <Box sx={{ display: 'flex', justifyContent: 'center', py: 8 }}><CircularProgress /></Box>;

  return (
    <Box>
      <Typography variant="h4" fontWeight="bold" gutterBottom>Attendance Overview</Typography>
      <Typography variant="body1" color="text.secondary" sx={{ mb: 3 }}>
        View employee attendance summaries
      </Typography>

      <Box sx={{ display: 'flex', gap: 2, mb: 3 }}>
        <TextField
          select
          label="Period"
          value={period}
          onChange={(e) => setPeriod(e.target.value)}
          sx={{ minWidth: 200 }}
        >
          <MenuItem value="weekly">Weekly</MenuItem>
          <MenuItem value="monthly">Monthly</MenuItem>
          <MenuItem value="daily">Daily</MenuItem>
        </TextField>
      </Box>

      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Employee</TableCell>
              <TableCell>Date / Period</TableCell>
              <TableCell>Check In</TableCell>
              <TableCell>Check Out</TableCell>
              <TableCell>Total Hours</TableCell>
              <TableCell>Status</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {summary.length === 0 ? (
              <TableRow>
                <TableCell colSpan={6} align="center" sx={{ py: 4 }}>
                  <Typography color="text.secondary">No records found for this period</Typography>
                </TableCell>
              </TableRow>
            ) : (
              summary.map((record, idx) => (
                <TableRow key={idx} hover>
                  <TableCell>
                    {record.employee_name || record.username || (record.user_username) || 'N/A'}
                  </TableCell>
                  <TableCell>{formatDate(record.date || record.week_start)}</TableCell>
                  <TableCell>{record.check_in ? new Date(record.check_in).toLocaleTimeString() : '-'}</TableCell>
                  <TableCell>{record.check_out ? new Date(record.check_out).toLocaleTimeString() : '-'}</TableCell>
                  <TableCell>{record.working_hours || record.hours_worked || record.total_working_hours || '0.00'}</TableCell>
                  <TableCell>
                    <Chip
                      label={record.status || (record.check_in ? 'Present' : 'Absent')}
                      color={record.status === 'present' ? 'success' : record.status === 'half_day' ? 'warning' : 'default'}
                      size="small"
                    />
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </TableContainer>

      <Snackbar open={snackbar.open} autoHideDuration={4000} onClose={() => setSnackbar({ ...snackbar, open: false })}>
        <Alert severity={snackbar.severity} onClose={() => setSnackbar({ ...snackbar, open: false })}>{snackbar.message}</Alert>
      </Snackbar>
    </Box>
  );
}
