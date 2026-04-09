import { useState, useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import {
  Box, Typography, Paper, Table, TableBody, TableCell, TableContainer,
  TableHead, TableRow, Chip, TextField, InputAdornment, CircularProgress,
  Alert, Snackbar, Button, Dialog, DialogTitle, DialogContent,
  DialogActions, Tabs, Tab, Divider
} from '@mui/material';
import { Search, CheckCircle, Cancel, Visibility } from '@mui/icons-material';
import valuationService from '../../services/valuationService';
import { formatDate, getStatusColor } from '../../utils/helpers';

const STATUS_TAB_MAP = { pending: 1, approved: 2, rejected: 3 };

export default function ValuationReview() {
  const [valuations, setValuations] = useState([]);
  const [loading, setLoading] = useState(true);
  const location = useLocation();
  const [tabValue, setTabValue] = useState(STATUS_TAB_MAP[location.state?.filter] || 0);
  const [searchQuery, setSearchQuery] = useState('');
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });
  const [detailDialog, setDetailDialog] = useState({ open: false, valuation: null });
  const [remarks, setRemarks] = useState('');

  const statusFilters = ['all', 'pending', 'approved', 'rejected'];

  useEffect(() => { fetchValuations(); }, []);

  const fetchValuations = async () => {
    try {
      setLoading(true);
      const res = await valuationService.getValuations();
      setValuations(Array.isArray(res.data) ? res.data : res.data?.results || []);
    } catch (err) {
      setSnackbar({ open: true, message: 'Failed to load valuations', severity: 'error' });
    } finally {
      setLoading(false);
    }
  };

  const handleAction = async (id, status) => {
    try {
      await valuationService.updateValuation(id, { status, remarks });
      setSnackbar({ open: true, message: `Valuation ${status} successfully`, severity: 'success' });
      setRemarks('');
      setDetailDialog({ open: false, valuation: null });
      fetchValuations();
    } catch (err) {
      setSnackbar({ open: true, message: `Failed to ${status} valuation`, severity: 'error' });
    }
  };

  const filteredValuations = valuations.filter(v => {
    const statusMatch = tabValue === 0 ||
      v.status === statusFilters[tabValue] ||
      (statusFilters[tabValue] === 'pending' && v.status === 'submitted');
    const searchMatch = !searchQuery ||
      (v.project_title || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
      (v.accessor_name || '').toLowerCase().includes(searchQuery.toLowerCase());
    return statusMatch && searchMatch;
  });

  if (loading) return <Box sx={{ display: 'flex', justifyContent: 'center', py: 8 }}><CircularProgress /></Box>;

  return (
    <Box>
      <Typography variant="h4" fontWeight="bold" gutterBottom>Valuation Review</Typography>
      <Typography variant="body1" color="text.secondary" sx={{ mb: 3 }}>
        Review and approve or reject valuations submitted by accessors
      </Typography>

      <Paper sx={{ mb: 3 }}>
        <Tabs value={tabValue} onChange={(_, v) => setTabValue(v)} sx={{ borderBottom: 1, borderColor: 'divider' }}>
          <Tab label={`All (${valuations.length})`} />
          <Tab label={`Pending (${valuations.filter(v => v.status === 'pending' || v.status === 'submitted').length})`} />
          <Tab label={`Approved (${valuations.filter(v => v.status === 'approved').length})`} />
          <Tab label={`Rejected (${valuations.filter(v => v.status === 'rejected').length})`} />
        </Tabs>
      </Paper>

      <TextField
        placeholder="Search by project or accessor..."
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
              <TableCell>Project</TableCell>
              <TableCell>Accessor</TableCell>
              <TableCell>Valuation Type</TableCell>
              <TableCell>Value</TableCell>
              <TableCell>Date Submitted</TableCell>
              <TableCell>Status</TableCell>
              <TableCell align="right">Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {filteredValuations.length === 0 ? (
              <TableRow>
                <TableCell colSpan={7} align="center" sx={{ py: 4 }}>
                  <Typography color="text.secondary">No valuations found</Typography>
                </TableCell>
              </TableRow>
            ) : (
              filteredValuations.map((val) => (
                <TableRow key={val.id} hover>
                  <TableCell>{val.project_title || val.project?.title || 'N/A'}</TableCell>
                  <TableCell>{val.accessor_name || val.created_by_name || 'N/A'}</TableCell>
                  <TableCell sx={{ textTransform: 'capitalize' }}>{val.valuation_type || val.type || 'N/A'}</TableCell>
                  <TableCell>{val.value || val.amount || 'N/A'}</TableCell>
                  <TableCell>{formatDate(val.created_at || val.submitted_at)}</TableCell>
                  <TableCell>
                    <Chip label={val.status} size="small"
                      color={val.status === 'approved' ? 'success' : val.status === 'rejected' ? 'error' : 'warning'} />
                  </TableCell>
                  <TableCell align="right">
                    <Button size="small" startIcon={<Visibility />}
                      onClick={() => { setDetailDialog({ open: true, valuation: val }); setRemarks(''); }}>
                      Review
                    </Button>
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </TableContainer>

      <Dialog open={detailDialog.open} onClose={() => setDetailDialog({ open: false, valuation: null })} maxWidth="md" fullWidth>
        <DialogTitle>Valuation Review</DialogTitle>
        <DialogContent dividers>
          {detailDialog.valuation && (
            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
              <Box sx={{ display: 'flex', gap: 4 }}>
                <Box sx={{ flex: 1 }}>
                  <Typography variant="subtitle2" color="text.secondary">Project</Typography>
                  <Typography>{detailDialog.valuation.project_title || detailDialog.valuation.project?.title}</Typography>
                </Box>
                <Box sx={{ flex: 1 }}>
                  <Typography variant="subtitle2" color="text.secondary">Accessor</Typography>
                  <Typography>{detailDialog.valuation.accessor_name || detailDialog.valuation.created_by_name}</Typography>
                </Box>
              </Box>
              <Box sx={{ display: 'flex', gap: 4 }}>
                <Box sx={{ flex: 1 }}>
                  <Typography variant="subtitle2" color="text.secondary">Valuation Type</Typography>
                  <Typography sx={{ textTransform: 'capitalize' }}>{detailDialog.valuation.valuation_type || detailDialog.valuation.type}</Typography>
                </Box>
                <Box sx={{ flex: 1 }}>
                  <Typography variant="subtitle2" color="text.secondary">Value</Typography>
                  <Typography>{detailDialog.valuation.value || detailDialog.valuation.amount}</Typography>
                </Box>
              </Box>
              <Box>
                <Typography variant="subtitle2" color="text.secondary">Description</Typography>
                <Typography>{detailDialog.valuation.description || detailDialog.valuation.notes || 'No description provided'}</Typography>
              </Box>
              <Box>
                <Typography variant="subtitle2" color="text.secondary">Status</Typography>
                <Chip label={detailDialog.valuation.status} size="small"
                  color={detailDialog.valuation.status === 'approved' ? 'success' : detailDialog.valuation.status === 'rejected' ? 'error' : 'warning'} />
              </Box>

              {(detailDialog.valuation.status === 'pending' || detailDialog.valuation.status === 'submitted') && (
                <>
                  <Divider sx={{ my: 1 }} />
                  <TextField
                    label="Remarks (optional)"
                    value={remarks}
                    onChange={(e) => setRemarks(e.target.value)}
                    multiline
                    rows={3}
                    fullWidth
                  />
                </>
              )}
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          {(detailDialog.valuation?.status === 'pending' || detailDialog.valuation?.status === 'submitted') && (
            <>
              <Button color="error" startIcon={<Cancel />}
                onClick={() => handleAction(detailDialog.valuation.id, 'rejected')}>
                Reject
              </Button>
              <Button color="success" variant="contained" startIcon={<CheckCircle />}
                onClick={() => handleAction(detailDialog.valuation.id, 'approved')}>
                Approve
              </Button>
            </>
          )}
          <Button onClick={() => setDetailDialog({ open: false, valuation: null })}>Close</Button>
        </DialogActions>
      </Dialog>

      <Snackbar open={snackbar.open} autoHideDuration={4000} onClose={() => setSnackbar({ ...snackbar, open: false })}>
        <Alert severity={snackbar.severity} onClose={() => setSnackbar({ ...snackbar, open: false })}>{snackbar.message}</Alert>
      </Snackbar>
    </Box>
  );
}
