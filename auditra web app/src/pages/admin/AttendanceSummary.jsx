import { useState, useEffect } from 'react';
import {
  Box, Typography, Table, TableBody, TableCell, TableContainer,
  TableHead, TableRow, Paper, Alert,
} from '@mui/material';
import attendanceService from '../../services/attendanceService';
import LoadingSpinner from '../../components/LoadingSpinner';
import StatusChip from '../../components/StatusChip';
import { formatDate } from '../../utils/helpers';

export default function AttendanceSummary() {
  const [records, setRecords] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const fetchData = async () => {
      try {
        const res = await attendanceService.getWeeklySummary();
        setRecords(Array.isArray(res.data?.data) ? res.data.data : []);
      } catch {
        setError('Failed to load attendance summary');
      } finally {
        setLoading(false);
      }
    };
    fetchData();
  }, []);

  if (loading) return <LoadingSpinner />;

  return (
    <Box>
      <Typography variant="h5" sx={{ fontWeight: 700, mb: 3 }}>Attendance Summary</Typography>
      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
      <TableContainer component={Paper}>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Employee Name</TableCell>
              <TableCell>Employee ID</TableCell>
              <TableCell align="center">Absent Days</TableCell>
              <TableCell align="center">Half Days</TableCell>
              <TableCell align="center">Overtime (Hrs)</TableCell>
              <TableCell align="center">Attendance %</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {records.length === 0 ? (
              <TableRow><TableCell colSpan={6} align="center">No summary data found for this week</TableCell></TableRow>
            ) : (
              records.map((r, i) => (
                <TableRow key={i}>
                  <TableCell sx={{ fontWeight: 600 }}>{r.employee_name}</TableCell>
                  <TableCell>{r.employee_number}</TableCell>
                  <TableCell align="center">{r.absent_days}</TableCell>
                  <TableCell align="center">{r.half_days}</TableCell>
                  <TableCell align="center">{r.overtime_hours}</TableCell>
                  <TableCell align="center">{r.attendance_percentage}%</TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </TableContainer>
    </Box>
  );
}
