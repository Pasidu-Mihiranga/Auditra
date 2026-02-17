import { useState, useEffect } from 'react';
import {
  Box, Typography, Table, TableBody, TableCell, TableContainer,
  TableHead, TableRow, Paper, Button, Alert, Tabs, Tab, Dialog,
  DialogTitle, DialogContent, DialogActions, TextField
} from '@mui/material';
import { Check, Close, Visibility } from '@mui/icons-material';
import projectService from '../../services/projectService';
import LoadingSpinner from '../../components/LoadingSpinner';
import StatusChip from '../../components/StatusChip';
import { formatDateTime } from '../../utils/helpers';

export default function CancellationRequests() {
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [tab, setTab] = useState(0);
  const [processing, setProcessing] = useState(false);
  
  // Dialog states
  const [viewDialog, setViewDialog] = useState(null);
  const [approveDialog, setApproveDialog] = useState(null);
  const [rejectDialog, setRejectDialog] = useState(null);
  const [adminRemarks, setAdminRemarks] = useState('');
  
  // All requests for counts
  const [allRequests, setAllRequests] = useState([]);

  const fetchAllRequests = async () => {
    setLoading(true);
    try {
      const [pendingRes, approvedRes, rejectedRes] = await Promise.all([
        projectService.getCancellationRequests('pending'),
        projectService.getCancellationRequests('approved'),
        projectService.getCancellationRequests('rejected'),
      ]);
      const all = [
        ...(pendingRes.data.requests || []),
        ...(approvedRes.data.requests || []),
        ...(rejectedRes.data.requests || []),
      ];
      setAllRequests(all);
      setRequests(all);
    } catch {
      setError('Failed to load cancellation requests');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAllRequests();
  }, []);

  const handleApprove = async () => {
    if (!approveDialog) return;
    setProcessing(true);
    setError('');
    try {
      await projectService.approveCancellation(approveDialog.id, adminRemarks);
      setSuccess('Cancellation approved. Project has been cancelled and team notified.');
      setApproveDialog(null);
      setAdminRemarks('');
      fetchAllRequests();
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to approve cancellation');
    } finally {
      setProcessing(false);
    }
  };

  const handleReject = async () => {
    if (!rejectDialog || !adminRemarks.trim()) {
      setError('Please provide remarks for rejection');
      return;
    }
    setProcessing(true);
    setError('');
    try {
      await projectService.rejectCancellation(rejectDialog.id, adminRemarks);
      setSuccess('Cancellation request rejected. Coordinator has been notified.');
      setRejectDialog(null);
      setAdminRemarks('');
      fetchAllRequests();
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to reject cancellation');
    } finally {
      setProcessing(false);
    }
  };

  const pendingCount = allRequests.filter(r => r.status === 'pending').length;
  const approvedCount = allRequests.filter(r => r.status === 'approved').length;
  const rejectedCount = allRequests.filter(r => r.status === 'rejected').length;

  const filtered = tab === 0 ? allRequests :
    tab === 1 ? allRequests.filter(r => r.status === 'pending') :
    tab === 2 ? allRequests.filter(r => r.status === 'approved') :
    allRequests.filter(r => r.status === 'rejected');

  if (loading) return <LoadingSpinner />;

  return (
    <Box>
      <Typography variant="h5" sx={{ fontWeight: 700, mb: 3 }}>Cancellation Requests</Typography>
      {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError('')}>{error}</Alert>}
      {success && <Alert severity="success" sx={{ mb: 2 }} onClose={() => setSuccess('')}>{success}</Alert>}

      <Tabs value={tab} onChange={(_, v) => setTab(v)} sx={{ mb: 2 }}>
        <Tab label={`All (${allRequests.length})`} />
        <Tab label={`Pending (${pendingCount})`} />
        <Tab label={`Approved (${approvedCount})`} />
        <Tab label={`Rejected (${rejectedCount})`} />
      </Tabs>

      <TableContainer component={Paper}>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Project</TableCell>
              <TableCell>Coordinator</TableCell>
              <TableCell>Reason</TableCell>
              <TableCell>Requested</TableCell>
              <TableCell>Status</TableCell>
              <TableCell>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {filtered.length === 0 ? (
              <TableRow><TableCell colSpan={6} align="center">No cancellation requests</TableCell></TableRow>
            ) : (
              filtered.map((request) => (
                <TableRow key={request.id}>
                  <TableCell sx={{ fontWeight: 600 }}>{request.project_title}</TableCell>
                  <TableCell>{request.coordinator_name}</TableCell>
                  <TableCell sx={{ maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {request.reason}
                  </TableCell>
                  <TableCell>{formatDateTime(request.created_at)}</TableCell>
                  <TableCell><StatusChip status={request.status} /></TableCell>
                  <TableCell>
                    <Button size="small" startIcon={<Visibility />} onClick={() => setViewDialog(request)}>
                      View
                    </Button>
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </TableContainer>

      {/* View Dialog */}
      <Dialog open={!!viewDialog} onClose={() => setViewDialog(null)} maxWidth="sm" fullWidth>
        <DialogTitle sx={{ fontWeight: 700 }}>Cancellation Request Details</DialogTitle>
        {viewDialog && (
          <DialogContent dividers>
            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
              <Box>
                <Typography variant="subtitle2" color="text.secondary">Project</Typography>
                <Typography sx={{ fontWeight: 600 }}>{viewDialog.project_title}</Typography>
              </Box>
              <Box>
                <Typography variant="subtitle2" color="text.secondary">Project Status</Typography>
                <Typography>{viewDialog.project_status}</Typography>
              </Box>
              <Box>
                <Typography variant="subtitle2" color="text.secondary">Requested By</Typography>
                <Typography>{viewDialog.coordinator_name}</Typography>
              </Box>
              <Box>
                <Typography variant="subtitle2" color="text.secondary">Request Date</Typography>
                <Typography>{formatDateTime(viewDialog.created_at)}</Typography>
              </Box>
              <Box>
                <Typography variant="subtitle2" color="text.secondary">Reason for Cancellation</Typography>
                <Paper variant="outlined" sx={{ p: 2, mt: 0.5, bgcolor: 'grey.50' }}>
                  <Typography>{viewDialog.reason}</Typography>
                </Paper>
              </Box>
              <Box>
                <Typography variant="subtitle2" color="text.secondary">Status</Typography>
                <StatusChip status={viewDialog.status} />
              </Box>
              {viewDialog.status !== 'pending' && (
                <>
                  <Box>
                    <Typography variant="subtitle2" color="text.secondary">Reviewed By</Typography>
                    <Typography>{viewDialog.reviewed_by_name || '-'}</Typography>
                  </Box>
                  <Box>
                    <Typography variant="subtitle2" color="text.secondary">Review Date</Typography>
                    <Typography>{viewDialog.reviewed_at ? formatDateTime(viewDialog.reviewed_at) : '-'}</Typography>
                  </Box>
                  {viewDialog.admin_remarks && (
                    <Box>
                      <Typography variant="subtitle2" color="text.secondary">Admin Remarks</Typography>
                      <Paper variant="outlined" sx={{ p: 2, mt: 0.5, bgcolor: 'grey.50' }}>
                        <Typography>{viewDialog.admin_remarks}</Typography>
                      </Paper>
                    </Box>
                  )}
                </>
              )}
            </Box>
          </DialogContent>
        )}
        <DialogActions sx={{ px: 3, pb: 2 }}>
          {viewDialog?.status === 'pending' && (
            <>
              <Button variant="contained" color="success" startIcon={<Check />}
                onClick={() => { setViewDialog(null); setApproveDialog(viewDialog); }}>
                Approve
              </Button>
              <Button variant="outlined" color="error" startIcon={<Close />}
                onClick={() => { setViewDialog(null); setRejectDialog(viewDialog); }}>
                Reject
              </Button>
            </>
          )}
          <Button onClick={() => setViewDialog(null)}>Close</Button>
        </DialogActions>
      </Dialog>

      {/* Approve Dialog */}
      <Dialog open={!!approveDialog} onClose={() => !processing && setApproveDialog(null)} maxWidth="sm" fullWidth>
        <DialogTitle sx={{ fontWeight: 700, color: 'success.main' }}>Approve Cancellation</DialogTitle>
        {approveDialog && (
          <DialogContent>
            <Alert severity="warning" sx={{ mb: 2 }}>
              This will cancel the project "{approveDialog.project_title}" and notify all assigned team members.
            </Alert>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
              <strong>Reason:</strong> {approveDialog.reason}
            </Typography>
            <TextField
              fullWidth
              multiline
              rows={3}
              label="Admin Remarks (Optional)"
              placeholder="Add any additional remarks..."
              value={adminRemarks}
              onChange={(e) => setAdminRemarks(e.target.value)}
            />
          </DialogContent>
        )}
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button onClick={() => setApproveDialog(null)} disabled={processing}>Cancel</Button>
          <Button variant="contained" color="success" onClick={handleApprove} disabled={processing} startIcon={<Check />}>
            {processing ? 'Processing...' : 'Approve'}
          </Button>
        </DialogActions>
      </Dialog>

      {/* Reject Dialog */}
      <Dialog open={!!rejectDialog} onClose={() => !processing && setRejectDialog(null)} maxWidth="sm" fullWidth>
        <DialogTitle sx={{ fontWeight: 700, color: 'error.main' }}>Reject Cancellation Request</DialogTitle>
        {rejectDialog && (
          <DialogContent>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
              Please provide a reason for rejecting this cancellation request. The coordinator will be notified.
            </Typography>
            <Typography variant="body2" sx={{ mb: 2 }}>
              <strong>Original Reason:</strong> {rejectDialog.reason}
            </Typography>
            <TextField
              fullWidth
              multiline
              rows={3}
              label="Rejection Remarks"
              placeholder="Please explain why the cancellation request is being rejected..."
              value={adminRemarks}
              onChange={(e) => setAdminRemarks(e.target.value)}
              required
              error={!adminRemarks.trim() && !!rejectDialog}
            />
          </DialogContent>
        )}
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button onClick={() => setRejectDialog(null)} disabled={processing}>Cancel</Button>
          <Button variant="contained" color="error" onClick={handleReject} disabled={processing || !adminRemarks.trim()} startIcon={<Close />}>
            {processing ? 'Processing...' : 'Reject'}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
