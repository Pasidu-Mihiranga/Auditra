import { useState, useEffect } from 'react';
import {
  Box, Typography, Table, TableBody, TableCell, TableContainer,
  TableHead, TableRow, Paper, Button, Alert, Tabs, Tab, Tooltip,
} from '@mui/material';
import { Check, Close } from '@mui/icons-material';
import leaveService from '../../services/leaveService';
import LoadingSpinner from '../../components/LoadingSpinner';
import StatusChip from '../../components/StatusChip';
import { formatDate } from '../../utils/helpers';

export default function LeaveManagement() {
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [tab, setTab] = useState(0);

  const fetchData = async () => {
    try {
      const res = await leaveService.getAllRequests();
      setRequests(Array.isArray(res.data.data) ? res.data.data : []);
    } catch {
      setError('Failed to load leave requests');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { fetchData(); }, []);

  const handleAction = async (id, status) => {
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

  const filtered = tab === 0 ? requests :
    tab === 1 ? requests.filter(r => r.status === 'pending') :
      tab === 2 ? requests.filter(r => r.status === 'approved') :
        requests.filter(r => r.status === 'rejected');

  if (loading) return <LoadingSpinner />;

  return (
    <Box>
      <Typography variant="h5" sx={{ fontWeight: 700, mb: 3 }}>Leave Management</Typography>
      {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError('')}>{error}</Alert>}
      {success && <Alert severity="success" sx={{ mb: 2 }} onClose={() => setSuccess('')}>{success}</Alert>}

      <Tabs value={tab} onChange={(_, v) => setTab(v)} sx={{ mb: 2 }}>
        <Tab label={`All (${requests.length})`} />
        <Tab label={`Pending (${requests.filter(r => r.status === 'pending').length})`} />
        <Tab label={`Approved (${requests.filter(r => r.status === 'approved').length})`} />
        <Tab label={`Rejected (${requests.filter(r => r.status === 'rejected').length})`} />
      </Tabs>

      <TableContainer component={Paper}>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Employee</TableCell>
              <TableCell>Type</TableCell>
              <TableCell>From</TableCell>
              <TableCell>To</TableCell>
              <TableCell>Reason</TableCell>
              <TableCell>Status & Details</TableCell>
              <TableCell>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {filtered.length === 0 ? (
              <TableRow><TableCell colSpan={7} align="center">No requests found</TableCell></TableRow>
            ) : (
              filtered.map((r) => (
                <TableRow key={r.id}>
                  <TableCell>
                    <Typography variant="body2" sx={{ fontWeight: 600 }}>{r.employee_name || '-'}</Typography>
                    <Typography variant="caption" color="text.secondary">{r.employee_id ? `#${r.employee_id}` : ''}</Typography>
                  </TableCell>
                  <TableCell>{r.leave_type_display || r.leave_type}</TableCell>
                  <TableCell>{formatDate(r.start_date)}</TableCell>
                  <TableCell>{formatDate(r.end_date)}</TableCell>
                  <TableCell sx={{ maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    <Tooltip title={r.reason}>
                      <span>{r.reason}</span>
                    </Tooltip>
                  </TableCell>
                  <TableCell>
                    <StatusChip status={r.status} />
                    {(r.status === 'approved' || r.status === 'rejected') && (
                      <Box sx={{ mt: 0.5 }}>
                        {r.reviewed_by_username && (
                          <Typography variant="caption" display="block" color="text.secondary">
                            By: {r.reviewed_by_username}
                          </Typography>
                        )}
                        {r.notes && (
                          <Typography variant="caption" display="block" sx={{ fontStyle: 'italic', maxWidth: 150 }} noWrap>
                            "{r.notes}"
                          </Typography>
                        )}
                      </Box>
                    )}
                  </TableCell>
                  <TableCell>
                    {r.status === 'pending' && (
                      <Box sx={{ display: 'flex', gap: 0.5 }}>
                        <Button size="small" variant="contained" color="success" startIcon={<Check />}
                          sx={{ minWidth: 90 }}
                          onClick={() => handleAction(r.id, 'approved')}>Approve</Button>
                        <Button size="small" variant="outlined" color="error" startIcon={<Close />}
                          sx={{ minWidth: 90 }}
                          onClick={() => handleAction(r.id, 'rejected')}>Reject</Button>
                      </Box>
                    )}
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </TableContainer>
    </Box>
  );
}
