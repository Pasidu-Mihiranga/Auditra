import { useState, useEffect } from 'react';
import {
  Box, Typography, Paper, Table, TableBody, TableCell, TableContainer,
  TableHead, TableRow, Chip, IconButton, TextField, InputAdornment,
  Tabs, Tab, Alert, Snackbar, Dialog, DialogTitle, DialogContent,
  DialogActions, Button, CircularProgress
} from '@mui/material';
import { Search, CheckCircle, Cancel, Visibility } from '@mui/icons-material';
import leaveService from '../../services/leaveService';
import { formatDate } from '../../utils/helpers';

export default function LeaveRequests() {
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [tabValue, setTabValue] = useState(0);
  const [searchQuery, setSearchQuery] = useState('');
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });
  const [detailDialog, setDetailDialog] = useState({ open: false, request: null });

  const statusFilters = ['all', 'pending', 'approved', 'rejected'];

  useEffect(() => { fetchRequests(); }, []);

  const fetchRequests = async () => {
    try {
      setLoading(true);
      const res = await leaveService.getAllRequests();
      setRequests(Array.isArray(res.data.data) ? res.data.data : []);
    } catch (err) {
      setSnackbar({ open: true, message: 'Failed to load leave requests', severity: 'error' });
    } finally {
      setLoading(false);
    }
  };

  const handleAction = async (id, status) => {
    try {
      await leaveService.updateRequest(id, { status });
      setSnackbar({ open: true, message: `Request ${status} successfully`, severity: 'success' });
      fetchRequests();
    } catch (err) {
      setSnackbar({ open: true, message: `Failed to ${status} request`, severity: 'error' });
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

  const filteredRequests = requests.filter(r => {
    const statusMatch = tabValue === 0 || r.status === statusFilters[tabValue];
    const searchMatch = !searchQuery ||
      (r.user_name || r.employee_name || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
      (r.leave_type || '').toLowerCase().includes(searchQuery.toLowerCase());
    return statusMatch && searchMatch;
  });

  if (loading) return <Box sx={{ display: 'flex', justifyContent: 'center', py: 8 }}><CircularProgress /></Box>;

  return (
    <Box>
      <Typography variant="h4" fontWeight="bold" gutterBottom>Leave Requests</Typography>
      <Typography variant="body1" color="text.secondary" sx={{ mb: 3 }}>
        Review and manage employee leave requests
      </Typography>

      <Paper sx={{ mb: 3 }}>
        <Tabs value={tabValue} onChange={(_, v) => setTabValue(v)} sx={{ borderBottom: 1, borderColor: 'divider' }}>
          <Tab label={`All (${requests.length})`} />
          <Tab label={`Pending (${requests.filter(r => r.status === 'pending').length})`} />
          <Tab label={`Approved (${requests.filter(r => r.status === 'approved').length})`} />
          <Tab label={`Rejected (${requests.filter(r => r.status === 'rejected').length})`} />
        </Tabs>
      </Paper>

      <TextField
        placeholder="Search by employee name or leave type..."
        value={searchQuery}
        onChange={(e) => setSearchQuery(e.target.value)}
        fullWidth
        sx={{ mb: 3 }}
        InputProps={{
          startAdornment: <InputAdornment position="start"><Search /></InputAdornment>,
        }}
      />

      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Employee</TableCell>
              <TableCell>Leave Type</TableCell>
              <TableCell>Start Date</TableCell>
              <TableCell>End Date</TableCell>
              <TableCell>Reason</TableCell>
              <TableCell>Status</TableCell>
              <TableCell align="right">Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {filteredRequests.length === 0 ? (
              <TableRow>
                <TableCell colSpan={7} align="center" sx={{ py: 4 }}>
                  <Typography color="text.secondary">No leave requests found</Typography>
                </TableCell>
              </TableRow>
            ) : (
              filteredRequests.map((req) => (
                <TableRow key={req.id} hover>
                  <TableCell>{req.user_name || req.employee_name || 'N/A'}</TableCell>
                  <TableCell sx={{ textTransform: 'capitalize' }}>{req.leave_type || 'N/A'}</TableCell>
                  <TableCell>{formatDate(req.start_date)}</TableCell>
                  <TableCell>{formatDate(req.end_date)}</TableCell>
                  <TableCell sx={{ maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {req.reason || '-'}
                  </TableCell>
                  <TableCell>
                    <Chip label={req.status} color={getStatusColor(req.status)} size="small" sx={{ width: 110, justifyContent: 'center', textTransform: 'capitalize' }} />
                  </TableCell>
                  <TableCell align="right">
                    <IconButton size="small" onClick={() => setDetailDialog({ open: true, request: req })}>
                      <Visibility fontSize="small" />
                    </IconButton>
                    {req.status === 'pending' && (
                      <>
                        <IconButton size="small" color="primary" onClick={() => handleAction(req.id, 'approved')}>
                          <CheckCircle fontSize="small" />
                        </IconButton>
                        <IconButton size="small" color="error" onClick={() => handleAction(req.id, 'rejected')}>
                          <Cancel fontSize="small" />
                        </IconButton>
                      </>
                    )}
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </TableContainer>

      <Dialog open={detailDialog.open} onClose={() => setDetailDialog({ open: false, request: null })} maxWidth="sm" fullWidth>
        <DialogTitle>Leave Request Details</DialogTitle>
        <DialogContent dividers>
          {detailDialog.request && (
            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
              <Box><Typography variant="subtitle2" color="text.secondary">Employee</Typography><Typography>{detailDialog.request.user_name || detailDialog.request.employee_name}</Typography></Box>
              <Box><Typography variant="subtitle2" color="text.secondary">Leave Type</Typography><Typography sx={{ textTransform: 'capitalize' }}>{detailDialog.request.leave_type}</Typography></Box>
              <Box><Typography variant="subtitle2" color="text.secondary">Period</Typography><Typography>{formatDate(detailDialog.request.start_date)} - {formatDate(detailDialog.request.end_date)}</Typography></Box>
              <Box><Typography variant="subtitle2" color="text.secondary">Reason</Typography><Typography>{detailDialog.request.reason || 'No reason provided'}</Typography></Box>
              <Box><Typography variant="subtitle2" color="text.secondary">Status</Typography><Chip label={detailDialog.request.status} color={getStatusColor(detailDialog.request.status)} size="small" /></Box>
              {detailDialog.request.admin_remarks && (
                <Box><Typography variant="subtitle2" color="text.secondary">Admin Remarks</Typography><Typography>{detailDialog.request.admin_remarks}</Typography></Box>
              )}
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          {detailDialog.request?.status === 'pending' && (
            <>
              <Button color="error" sx={{ width: 110 }} onClick={() => { handleAction(detailDialog.request.id, 'rejected'); setDetailDialog({ open: false, request: null }); }}>Reject</Button>
              <Button color="primary" variant="contained" sx={{ width: 110 }} onClick={() => { handleAction(detailDialog.request.id, 'approved'); setDetailDialog({ open: false, request: null }); }}>Approve</Button>
            </>
          )}
          <Button onClick={() => setDetailDialog({ open: false, request: null })}>Close</Button>
        </DialogActions>
      </Dialog>

      <Snackbar open={snackbar.open} autoHideDuration={4000} onClose={() => setSnackbar({ ...snackbar, open: false })}>
        <Alert severity={snackbar.severity} onClose={() => setSnackbar({ ...snackbar, open: false })}>{snackbar.message}</Alert>
      </Snackbar>
    </Box>
  );
}
