import { useState, useEffect } from 'react';
import {
  Box, Typography, Paper, TextField, Button, MenuItem, CircularProgress,
  Alert, Snackbar, Card, CardContent, Table, TableBody, TableCell,
  TableContainer, TableHead, TableRow, Chip, Divider
} from '@mui/material';
import { Send, History } from '@mui/icons-material';
import authService from '../../services/authService';
import removalService from '../../services/removalService';
import { formatDate } from '../../utils/helpers';

export default function RemovalRequest() {
  const [users, setUsers] = useState([]);
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });
  const [form, setForm] = useState({ employee: '', reason: '', details: '' });

  useEffect(() => {
    const load = async () => {
      try {
        const [usersRes, requestsRes] = await Promise.all([
          authService.getUsers(),
          removalService.getRemovalRequests(),
        ]);
        setUsers(Array.isArray(usersRes.data) ? usersRes.data : usersRes.data?.results || []);
        setRequests(Array.isArray(requestsRes.data) ? requestsRes.data : requestsRes.data?.results || []);
      } catch (err) {
        setSnackbar({ open: true, message: 'Failed to load data', severity: 'error' });
      } finally {
        setLoading(false);
      }
    };
    load();
  }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!form.employee || !form.reason) {
      setSnackbar({ open: true, message: 'Please fill in all required fields', severity: 'warning' });
      return;
    }
    try {
      setSubmitting(true);
      await removalService.createRemovalRequest({
        employee: form.employee,
        reason: form.reason,
        details: form.details,
      });
      setSnackbar({ open: true, message: 'Removal request submitted successfully', severity: 'success' });
      setForm({ employee: '', reason: '', details: '' });
      const res = await removalService.getRemovalRequests();
      setRequests(Array.isArray(res.data) ? res.data : res.data?.results || []);
    } catch (err) {
      setSnackbar({ open: true, message: err.response?.data?.detail || 'Failed to submit request', severity: 'error' });
    } finally {
      setSubmitting(false);
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'approved': return 'success';
      case 'rejected': return 'error';
      case 'pending': return 'warning';
      default: return 'default';
    }
  };

  if (loading) return <Box sx={{ display: 'flex', justifyContent: 'center', py: 8 }}><CircularProgress /></Box>;

  return (
    <Box>
      <Typography variant="h4" fontWeight="bold" gutterBottom>Employee Removal Request</Typography>
      <Typography variant="body1" color="text.secondary" sx={{ mb: 3 }}>
        Submit a request to remove an employee from the system
      </Typography>

      <Card sx={{ mb: 4 }}>
        <CardContent>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 3 }}>
            <Send color="primary" />
            <Typography variant="h6">New Removal Request</Typography>
          </Box>
          <form onSubmit={handleSubmit}>
            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2.5 }}>
              <TextField
                select
                label="Select Employee *"
                value={form.employee}
                onChange={(e) => setForm({ ...form, employee: e.target.value })}
                fullWidth
              >
                {users.map((user) => (
                  <MenuItem key={user.id} value={user.id}>
                    {user.first_name} {user.last_name} ({user.username})
                  </MenuItem>
                ))}
              </TextField>
              <TextField
                select
                label="Reason *"
                value={form.reason}
                onChange={(e) => setForm({ ...form, reason: e.target.value })}
                fullWidth
              >
                <MenuItem value="performance">Poor Performance</MenuItem>
                <MenuItem value="misconduct">Misconduct</MenuItem>
                <MenuItem value="redundancy">Redundancy</MenuItem>
                <MenuItem value="resignation">Resignation</MenuItem>
                <MenuItem value="contract_end">Contract End</MenuItem>
                <MenuItem value="other">Other</MenuItem>
              </TextField>
              <TextField
                label="Additional Details"
                value={form.details}
                onChange={(e) => setForm({ ...form, details: e.target.value })}
                multiline
                rows={4}
                fullWidth
              />
              <Button type="submit" variant="contained" disabled={submitting} startIcon={submitting ? <CircularProgress size={20} /> : <Send />}>
                {submitting ? 'Submitting...' : 'Submit Request'}
              </Button>
            </Box>
          </form>
        </CardContent>
      </Card>

      <Divider sx={{ my: 3 }} />

      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
        <History color="primary" />
        <Typography variant="h6">Previous Requests</Typography>
      </Box>

      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Employee</TableCell>
              <TableCell>Reason</TableCell>
              <TableCell>Date Submitted</TableCell>
              <TableCell>Status</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {requests.length === 0 ? (
              <TableRow>
                <TableCell colSpan={4} align="center" sx={{ py: 4 }}>
                  <Typography color="text.secondary">No removal requests found</Typography>
                </TableCell>
              </TableRow>
            ) : (
              requests.map((req) => (
                <TableRow key={req.id} hover>
                  <TableCell>{req.employee_name || 'N/A'}</TableCell>
                  <TableCell sx={{ textTransform: 'capitalize' }}>{req.reason?.replace('_', ' ') || 'N/A'}</TableCell>
                  <TableCell>{formatDate(req.created_at)}</TableCell>
                  <TableCell><Chip label={req.status} color={getStatusColor(req.status)} size="small" /></TableCell>
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
