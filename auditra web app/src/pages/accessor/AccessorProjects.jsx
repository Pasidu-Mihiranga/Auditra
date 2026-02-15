import { useState, useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import {
  Box, Typography, Paper, Table, TableBody, TableCell, TableContainer,
  TableHead, TableRow, Chip, TextField, InputAdornment, CircularProgress,
  Alert, Snackbar, Button, Dialog, DialogTitle, DialogContent,
  DialogActions, Tabs, Tab, Divider
} from '@mui/material';
import { Search, Visibility, Map, CheckCircle, Cancel } from '@mui/icons-material';
import valuationService from '../../services/valuationService';
import { formatDate, getStatusColor } from '../../utils/helpers';
import StatusChip from '../../components/StatusChip';

const STATUS_TAB_MAP = { pending: 1, reviewed: 2, approved: 2, rejected: 3 };

export default function AccessorProjects() {
  const [valuations, setValuations] = useState([]);
  const [loading, setLoading] = useState(true);
  const location = useLocation();
  const [tabValue, setTabValue] = useState(STATUS_TAB_MAP[location.state?.filter] || 0);
  const [searchQuery, setSearchQuery] = useState('');
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });
  const [detailDialog, setDetailDialog] = useState({ open: false, valuation: null });
  const [rejectDialog, setRejectDialog] = useState({ open: false, valuationId: null, reason: '' });

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

  const handleAcceptValuation = async (id) => {
    try {
      await valuationService.acceptValuation(id);
      setSnackbar({ open: true, message: 'Valuation accepted and sent to Senior Valuer', severity: 'success' });
      setDetailDialog({ open: false, valuation: null });
      fetchValuations();
    } catch (err) {
      setSnackbar({ open: true, message: 'Failed to accept valuation', severity: 'error' });
    }
  };

  const handleRejectValuation = async () => {
    if (!rejectDialog.reason.trim()) {
      setSnackbar({ open: true, message: 'Please provide a reason for rejection', severity: 'warning' });
      return;
    }
    try {
      await valuationService.rejectValuation(rejectDialog.valuationId, { rejection_reason: rejectDialog.reason });
      setSnackbar({ open: true, message: 'Valuation rejected and Field Officer notified', severity: 'info' });
      setRejectDialog({ open: false, valuationId: null, reason: '' });
      fetchValuations();
    } catch (err) {
      setSnackbar({ open: true, message: 'Failed to reject valuation', severity: 'error' });
    }
  };

  const filteredValuations = valuations.filter(v => {
    const statusMatch = tabValue === 0 ||
      (statusFilters[tabValue] === 'all') ||
      (statusFilters[tabValue] === 'pending' && (v.status === 'submitted' || v.status === 'under_review')) ||
      (statusFilters[tabValue] === 'approved' && (v.status === 'reviewed' || v.status === 'approved')) ||
      (v.status === statusFilters[tabValue]);

    const searchMatch = !searchQuery ||
      (v.project_title || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
      (v.field_officer_name || v.field_officer_username || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
      (v.category_display || v.category || '').toLowerCase().includes(searchQuery.toLowerCase());

    return statusMatch && searchMatch;
  });

  if (loading) return <Box sx={{ display: 'flex', justifyContent: 'center', py: 8 }}><CircularProgress /></Box>;

  return (
    <Box>
      <Typography variant="h4" fontWeight="bold" gutterBottom>My Projects</Typography>
      <Typography variant="body1" color="text.secondary" sx={{ mb: 3 }}>
        Review and manage valuations submitted for your assigned projects
      </Typography>

      <Paper sx={{ mb: 3 }}>
        <Tabs value={tabValue} onChange={(_, v) => setTabValue(v)} sx={{ borderBottom: 1, borderColor: 'divider' }}>
          <Tab label={`All (${valuations.length})`} />
          <Tab label={`Pending (${valuations.filter(v => v.status === 'submitted' || v.status === 'under_review').length})`} />
          <Tab label={`Processed (${valuations.filter(v => v.status === 'reviewed' || v.status === 'approved').length})`} />
          <Tab label={`Rejected (${valuations.filter(v => v.status === 'rejected').length})`} />
        </Tabs>
      </Paper>

      <TextField
        placeholder="Search by project, officer, or type..."
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
              <TableCell>Field Officer</TableCell>
              <TableCell>Valuation Type</TableCell>
              <TableCell>Value (Rs.)</TableCell>
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
                  <TableCell sx={{ fontWeight: 500 }}>{val.project_title || val.project?.title || 'N/A'}</TableCell>
                  <TableCell>{val.field_officer_name || val.field_officer_username || 'N/A'}</TableCell>
                  <TableCell sx={{ textTransform: 'capitalize' }}>{val.category_display || val.category || 'N/A'}</TableCell>
                  <TableCell>
                    {val.estimated_value ? parseFloat(val.estimated_value).toLocaleString() : 'N/A'}
                  </TableCell>
                  <TableCell>{formatDate(val.submitted_at || val.created_at)}</TableCell>
                  <TableCell>
                    <StatusChip
                      status={val.status}
                      label={val.status === 'submitted' ? 'Pending Review' : undefined}
                    />
                  </TableCell>
                  <TableCell align="right">
                    <Button
                      size="small"
                      startIcon={<Visibility />}
                      onClick={() => setDetailDialog({ open: true, valuation: val })}
                    >
                      Review
                    </Button>
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </TableContainer>

      {/* Valuation Detail Dialog */}
      <Dialog
        open={detailDialog.open}
        onClose={() => setDetailDialog({ open: false, valuation: null })}
        maxWidth="md"
        fullWidth
      >
        <DialogTitle sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          Valuation Review
          <StatusChip status={detailDialog.valuation?.status} />
        </DialogTitle>
        <DialogContent dividers>
          {detailDialog.valuation && (
            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
              {/* Project Info */}
              <Box>
                <Typography variant="subtitle2" color="text.secondary">Project</Typography>
                <Typography variant="h6" color="primary.main">{detailDialog.valuation.project_title || detailDialog.valuation.project?.title}</Typography>
              </Box>

              <Divider />

              {/* Core Info */}
              <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 2 }}>
                <Box>
                  <Typography variant="subtitle2" color="text.secondary">Category</Typography>
                  <Typography variant="body1" fontWeight="medium">{detailDialog.valuation.category_display}</Typography>
                </Box>
                <Box>
                  <Typography variant="subtitle2" color="text.secondary">Estimated Value</Typography>
                  <Typography variant="body1" fontWeight="medium" color="success.main">
                    {detailDialog.valuation.estimated_value ? `Rs. ${parseFloat(detailDialog.valuation.estimated_value).toLocaleString()}` : 'N/A'}
                  </Typography>
                </Box>
                <Box>
                  <Typography variant="subtitle2" color="text.secondary">Field Officer</Typography>
                  <Typography variant="body1">{detailDialog.valuation.field_officer_name || detailDialog.valuation.field_officer_username}</Typography>
                </Box>
                <Box>
                  <Typography variant="subtitle2" color="text.secondary">Submitted Date</Typography>
                  <Typography variant="body1">{formatDate(detailDialog.valuation.submitted_at || detailDialog.valuation.created_at)}</Typography>
                </Box>
              </Box>

              {/* Category Specific Info */}
              {detailDialog.valuation.category === 'land' && (
                <Paper variant="outlined" sx={{ p: 2, bgcolor: 'grey.50' }}>
                  <Typography variant="subtitle1" fontWeight="bold" gutterBottom>Land Details</Typography>
                  <Box sx={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 2 }}>
                    <Box><Typography variant="caption" color="text.secondary">Area</Typography><Typography variant="body2">{detailDialog.valuation.land_area} sqft</Typography></Box>
                    <Box><Typography variant="caption" color="text.secondary">Type</Typography><Typography variant="body2">{detailDialog.valuation.land_type}</Typography></Box>
                    <Box sx={{ gridColumn: 'span 2' }}>
                      <Typography variant="caption" color="text.secondary">Location</Typography>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <Typography variant="body2">{detailDialog.valuation.land_location || 'N/A'}</Typography>
                        {detailDialog.valuation.land_latitude && detailDialog.valuation.land_longitude && (
                          <Button
                            size="small"
                            startIcon={<Map />}
                            onClick={() => window.open(`https://www.google.com/maps?q=${detailDialog.valuation.land_latitude},${detailDialog.valuation.land_longitude}`, '_blank')}
                          >
                            View Maps
                          </Button>
                        )}
                      </Box>
                    </Box>
                  </Box>
                </Paper>
              )}

              {detailDialog.valuation.category === 'building' && (
                <Paper variant="outlined" sx={{ p: 2, bgcolor: 'grey.50' }}>
                  <Typography variant="subtitle1" fontWeight="bold" gutterBottom>Building Details</Typography>
                  <Box sx={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 2 }}>
                    <Box><Typography variant="caption" color="text.secondary">Area</Typography><Typography variant="body2">{detailDialog.valuation.building_area} sqft</Typography></Box>
                    <Box><Typography variant="caption" color="text.secondary">Type</Typography><Typography variant="body2">{detailDialog.valuation.building_type}</Typography></Box>
                    <Box><Typography variant="caption" color="text.secondary">Floors</Typography><Typography variant="body2">{detailDialog.valuation.number_of_floors}</Typography></Box>
                    <Box sx={{ gridColumn: 'span 2' }}>
                      <Typography variant="caption" color="text.secondary">Location</Typography>
                      <Typography variant="body2">{detailDialog.valuation.building_location || 'N/A'}</Typography>
                    </Box>
                  </Box>
                </Paper>
              )}

              {/* Photos Section */}
              {detailDialog.valuation.photos?.length > 0 && (
                <Box>
                  <Typography variant="subtitle1" fontWeight="bold" gutterBottom>Evidence Photos</Typography>
                  <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap' }}>
                    {detailDialog.valuation.photos.map(photo => (
                      <Box
                        key={photo.id}
                        component="img"
                        src={photo.photo_url || photo.photo}
                        alt="Evidence"
                        sx={{ width: 140, height: 140, objectFit: 'cover', borderRadius: 1, border: '1px solid', borderColor: 'divider' }}
                      />
                    ))}
                  </Box>
                </Box>
              )}

              {/* Rejection Info */}
              {detailDialog.valuation.status === 'rejected' && detailDialog.valuation.rejection_reason && (
                <Alert severity="error">
                  <Typography variant="subtitle2" fontWeight="bold">Rejection Reason:</Typography>
                  {detailDialog.valuation.rejection_reason}
                </Alert>
              )}
            </Box>
          )}
        </DialogContent>
        <DialogActions sx={{ px: 3, py: 2 }}>
          <Button onClick={() => setDetailDialog({ open: false, valuation: null })}>Close</Button>
          {(detailDialog.valuation?.status === 'submitted' || detailDialog.valuation?.status === 'under_review') && (
            <>
              <Button
                variant="contained"
                color="success"
                startIcon={<CheckCircle />}
                onClick={() => handleAcceptValuation(detailDialog.valuation.id)}
              >
                Accept
              </Button>
              <Button
                variant="outlined"
                color="error"
                startIcon={<Cancel />}
                onClick={() => {
                  setRejectDialog({ open: true, valuationId: detailDialog.valuation.id, reason: '' });
                  setDetailDialog({ open: false, valuation: null });
                }}
              >
                Reject
              </Button>
            </>
          )}
        </DialogActions>
      </Dialog>

      {/* Reject Reason Dialog */}
      <Dialog open={rejectDialog.open} onClose={() => setRejectDialog({ ...rejectDialog, open: false })}>
        <DialogTitle>Reject Valuation</DialogTitle>
        <DialogContent>
          <Typography variant="body2" sx={{ mb: 2 }}>
            Please provide a reason for rejection. This will be sent back to the field officer.
          </Typography>
          <TextField
            autoFocus
            fullWidth
            multiline
            rows={3}
            label="Rejection Reason"
            value={rejectDialog.reason}
            onChange={(e) => setRejectDialog({ ...rejectDialog, reason: e.target.value })}
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setRejectDialog({ ...rejectDialog, open: false })}>Cancel</Button>
          <Button onClick={handleRejectValuation} color="error" variant="contained">Confirm Rejection</Button>
        </DialogActions>
      </Dialog>

      <Snackbar open={snackbar.open} autoHideDuration={4000} onClose={() => setSnackbar({ ...snackbar, open: false })}>
        <Alert severity={snackbar.severity} onClose={() => setSnackbar({ ...snackbar, open: false })}>{snackbar.message}</Alert>
      </Snackbar>
    </Box>
  );
}
