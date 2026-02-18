import { useState, useEffect } from 'react';
import {
  Box, Typography, Paper, Table, TableBody, TableCell, TableContainer,
  TableHead, TableRow, Chip, TextField, InputAdornment, CircularProgress,
  Alert, Snackbar, Button, Dialog, DialogTitle, DialogContent,
  DialogActions, Tabs, Tab
} from '@mui/material';
import { Search, Visibility, Add, Map } from '@mui/icons-material';
import projectService from '../../services/projectService';
import valuationService from '../../services/valuationService';
import StatusChip from '../../components/StatusChip';
import LoadingSpinner from '../../components/LoadingSpinner';
import { formatDate, getStatusColor, getPriorityColor, capitalize } from '../../utils/helpers';

export default function AccessorProjects() {
  const [projects, setProjects] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [tabValue, setTabValue] = useState(0);
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });
  const [detailDialog, setDetailDialog] = useState({ open: false, project: null });
  const [valuations, setValuations] = useState([]);
  const [valuationDetailDialog, setValuationDetailDialog] = useState({ open: false, valuation: null });

  const statusFilters = ['all', 'active', 'completed'];

  useEffect(() => { fetchProjects(); }, []);

  const fetchProjects = async () => {
    try {
      setLoading(true);
      const res = await projectService.getProjects();
      setProjects(Array.isArray(res.data) ? res.data : res.data?.results || []);
    } catch (err) {
      setSnackbar({ open: true, message: 'Failed to load projects', severity: 'error' });
    } finally {
      setLoading(false);
    }
  };

  const handleViewProject = async (project) => {
    setDetailDialog({ open: true, project });
    try {
      const res = await valuationService.getValuations(project.id);
      setValuations(Array.isArray(res.data) ? res.data : res.data?.results || []);
    } catch {
      setValuations([]);
    }
  };

  const handleAcceptValuation = async (id) => {
    try {
      await valuationService.acceptValuation(id);
      setSnackbar({ open: true, message: 'Valuation accepted and sent to Senior Valuer', severity: 'success' });
      // Refresh valuations for the current project
      if (detailDialog.project) handleViewProject(detailDialog.project);
    } catch (err) {
      setSnackbar({ open: true, message: 'Failed to accept valuation', severity: 'error' });
    }
  };

  const [rejectDialog, setRejectDialog] = useState({ open: false, valuationId: null, reason: '' });

  const handleRejectValuation = async () => {
    if (!rejectDialog.reason.trim()) {
      setSnackbar({ open: true, message: 'Please provide a reason for rejection', severity: 'warning' });
      return;
    }
    try {
      await valuationService.rejectValuation(rejectDialog.valuationId, { rejection_reason: rejectDialog.reason });
      setSnackbar({ open: true, message: 'Valuation rejected and Field Officer notified', severity: 'info' });
      setRejectDialog({ open: false, valuationId: null, reason: '' });
      if (detailDialog.project) handleViewProject(detailDialog.project);
    } catch (err) {
      setSnackbar({ open: true, message: 'Failed to reject valuation', severity: 'error' });
    }
  };

  const filteredProjects = projects.filter(p => {
    const statusMatch = tabValue === 0 ||
      (statusFilters[tabValue] === 'active' && (p.status === 'in_progress' || p.status === 'pending')) ||
      (p.status === statusFilters[tabValue]);
    const searchMatch = !searchQuery ||
      (p.title || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
      (p.description || '').toLowerCase().includes(searchQuery.toLowerCase());
    return statusMatch && searchMatch;
  });

  if (loading) return <LoadingSpinner />;

  return (
    <Box>
      <Typography variant="h5" sx={{ fontWeight: 700, mb: 3 }}>My Projects</Typography>

      <Paper sx={{ mb: 3 }}>
        <Tabs value={tabValue} onChange={(_, v) => setTabValue(v)} sx={{ borderBottom: 1, borderColor: 'divider' }}>
          <Tab label={`All (${projects.length})`} />
          <Tab label="Active" />
          <Tab label="Completed" />
        </Tabs>
      </Paper>

      <TextField
        placeholder="Search projects..."
        value={searchQuery}
        onChange={(e) => setSearchQuery(e.target.value)}
        fullWidth
        sx={{ mb: 3 }}
        InputProps={{
          startAdornment: <InputAdornment position="start"><Search /></InputAdornment>,
        }}
      />

      <TableContainer component={Paper}>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell sx={{ fontWeight: 700 }}>Project Title</TableCell>
              <TableCell sx={{ fontWeight: 700 }}>Client</TableCell>
              <TableCell sx={{ fontWeight: 700 }}>Start Date</TableCell>
              <TableCell sx={{ fontWeight: 700 }}>Due Date</TableCell>
              <TableCell sx={{ fontWeight: 700 }}>Priority</TableCell>
              <TableCell sx={{ fontWeight: 700 }}>Status</TableCell>
              <TableCell sx={{ fontWeight: 700 }} align="right">Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {filteredProjects.length === 0 ? (
              <TableRow>
                <TableCell colSpan={7} align="center" sx={{ py: 4 }}>
                  <Typography color="text.secondary">No projects found</Typography>
                </TableCell>
              </TableRow>
            ) : (
              filteredProjects.map((project) => (
                <TableRow key={project.id} hover>
                  <TableCell sx={{ fontWeight: 600 }}>{project.title}</TableCell>
                  <TableCell>{project.client_name || project.client_info?.name || 'N/A'}</TableCell>
                  <TableCell>{formatDate(project.start_date)}</TableCell>
                  <TableCell>{formatDate(project.end_date || project.due_date)}</TableCell>
                  <TableCell>
                    <Chip label={capitalize(project.priority) || 'Normal'} size="small"
                      sx={{ bgcolor: `${getPriorityColor(project.priority)}20`, color: getPriorityColor(project.priority), fontWeight: 600, fontSize: 12, width: 90, justifyContent: 'center', border: `1px solid ${getPriorityColor(project.priority)}50` }} />
                  </TableCell>
                  <TableCell>
                    <StatusChip status={project.status === 'pending' ? 'active' : project.status} label={project.status === 'pending' ? 'Active' : project.status.replace('_', ' ')} />
                  </TableCell>
                  <TableCell align="right">
                    <Button size="small" startIcon={<Visibility />} onClick={() => handleViewProject(project)}>View</Button>
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </TableContainer>

      <Dialog open={detailDialog.open} onClose={() => setDetailDialog({ open: false, project: null })} maxWidth="md" fullWidth>
        <DialogTitle>{detailDialog.project?.title}</DialogTitle>
        <DialogContent dividers>
          {detailDialog.project && (
            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
              <Box><Typography variant="subtitle2" color="text.secondary">Description</Typography><Typography>{detailDialog.project.description || 'No description'}</Typography></Box>
              <Box sx={{ display: 'flex', gap: 4 }}>
                <Box><Typography variant="subtitle2" color="text.secondary">Status</Typography><Chip label={detailDialog.project.status} size="small" color={getStatusColor(detailDialog.project.status) || 'default'} /></Box>
                <Box><Typography variant="subtitle2" color="text.secondary">Priority</Typography><Typography>{capitalize(detailDialog.project.priority) || 'Normal'}</Typography></Box>
              </Box>
              <Box sx={{ display: 'flex', gap: 4 }}>
                <Box><Typography variant="subtitle2" color="text.secondary">Start Date</Typography><Typography>{formatDate(detailDialog.project.start_date)}</Typography></Box>
                <Box><Typography variant="subtitle2" color="text.secondary">Due Date</Typography><Typography>{formatDate(detailDialog.project.end_date || detailDialog.project.due_date)}</Typography></Box>
              </Box>

              {valuations.length > 0 && (
                <Box sx={{ mt: 2 }}>
                  <Typography variant="h6" gutterBottom>Valuations</Typography>
                  <TableContainer component={Paper} variant="outlined">
                    <Table size="small">
                      <TableHead>
                        <TableRow>
                          <TableCell>Type</TableCell>
                          <TableCell>Value</TableCell>
                          <TableCell>Status</TableCell>
                          <TableCell>Date</TableCell>
                          <TableCell align="right">Actions</TableCell>
                        </TableRow>
                      </TableHead>
                      <TableBody>
                        {valuations.map((v) => (
                          <TableRow key={v.id}>
                            <TableCell>{v.category_display || v.category || 'N/A'}</TableCell>
                            <TableCell>{v.estimated_value ? `Rs. ${parseFloat(v.estimated_value).toLocaleString()}` : 'N/A'}</TableCell>
                            <TableCell><Chip label={v.status} size="small" color={getStatusColor(v.status) || 'default'} /></TableCell>
                            <TableCell>{formatDate(v.created_at)}</TableCell>
                            <TableCell align="right">
                              <Box sx={{ display: 'flex', gap: 1, justifyContent: 'flex-end', alignItems: 'center' }}>
                                <Button
                                  size="small"
                                  startIcon={<Visibility />}
                                  onClick={() => setValuationDetailDialog({ open: true, valuation: v })}
                                >
                                  View Details
                                </Button>
                                <Box sx={{ display: 'flex', gap: 1, justifyContent: 'flex-end', alignItems: 'center', minWidth: 175 }}>
                                  {(v.status === 'submitted' || v.status === 'under_review') ? (
                                    <>
                                      <Button
                                        size="small"
                                        variant="contained"
                                        color="primary"
                                        onClick={() => handleAcceptValuation(v.id)}
                                        sx={{ width: 110 }}
                                      >
                                        Accept
                                      </Button>
                                      <Button
                                        size="small"
                                        variant="outlined"
                                        color="error"
                                        onClick={() => setRejectDialog({ open: true, valuationId: v.id, reason: '' })}
                                        sx={{ width: 110 }}
                                      >
                                        Reject
                                      </Button>
                                    </>
                                  ) : (
                                    ['reviewed', 'approved', 'rejected'].includes(v.status) && (
                                      <Typography variant="body2" sx={{
                                        color: (v.status === 'reviewed' || v.status === 'approved') ? 'success.main' : 'error.main',
                                        fontWeight: 'bold',
                                        minWidth: 80,
                                        textAlign: 'center'
                                      }}>
                                        {(v.status === 'reviewed' || v.status === 'approved') ? 'Accepted' : 'Rejected'}
                                      </Typography>
                                    )
                                  )}
                                </Box>
                              </Box>
                            </TableCell>
                          </TableRow>
                        ))}
                      </TableBody>
                    </Table>
                  </TableContainer>
                </Box>
              )}
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDetailDialog({ open: false, project: null })}>Close</Button>
        </DialogActions>
      </Dialog>

      {/* Valuation Detail Dialog */}
      <Dialog
        open={valuationDetailDialog.open}
        onClose={() => setValuationDetailDialog({ open: false, valuation: null })}
        maxWidth="md"
        fullWidth
      >
        <DialogTitle sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          Valuation Details
          <Chip
            label={valuationDetailDialog.valuation?.status}
            size="small"
            color={getStatusColor(valuationDetailDialog.valuation?.status) || 'default'}
          />
        </DialogTitle>
        <DialogContent dividers>
          {valuationDetailDialog.valuation && (
            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
              {/* Core Info */}
              <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 2 }}>
                <Box>
                  <Typography variant="subtitle2" color="text.secondary">Category</Typography>
                  <Typography variant="body1" fontWeight="medium">{valuationDetailDialog.valuation.category_display}</Typography>
                </Box>
                <Box>
                  <Typography variant="subtitle2" color="text.secondary">Estimated Value</Typography>
                  <Typography variant="body1" fontWeight="medium" color="primary.main">
                    {valuationDetailDialog.valuation.estimated_value ? `Rs. ${parseFloat(valuationDetailDialog.valuation.estimated_value).toLocaleString()}` : 'N/A'}
                  </Typography>
                </Box>
                <Box>
                  <Typography variant="subtitle2" color="text.secondary">Field Officer</Typography>
                  <Typography variant="body1">{valuationDetailDialog.valuation.field_officer_name || valuationDetailDialog.valuation.field_officer_username}</Typography>
                </Box>
                <Box>
                  <Typography variant="subtitle2" color="text.secondary">Submitted Date</Typography>
                  <Typography variant="body1">{formatDate(valuationDetailDialog.valuation.submitted_at || valuationDetailDialog.valuation.created_at)}</Typography>
                </Box>
              </Box>

              {/* Category Specific Info */}
              {valuationDetailDialog.valuation.category === 'land' && (
                <Paper variant="outlined" sx={{ p: 2, bgcolor: 'grey.50' }}>
                  <Typography variant="subtitle1" fontWeight="bold" gutterBottom>Land Details</Typography>
                  <Box sx={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 2 }}>
                    <Box><Typography variant="caption" color="text.secondary">Area</Typography><Typography variant="body2">{valuationDetailDialog.valuation.land_area} sqft</Typography></Box>
                    <Box><Typography variant="caption" color="text.secondary">Type</Typography><Typography variant="body2">{valuationDetailDialog.valuation.land_type}</Typography></Box>
                    {valuationDetailDialog.valuation.land_location && (
                      <Box sx={{ gridColumn: 'span 2' }}>
                        <Typography variant="caption" color="text.secondary">Location</Typography>
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                          <Typography variant="body2">{valuationDetailDialog.valuation.land_location}</Typography>
                          {valuationDetailDialog.valuation.land_latitude && valuationDetailDialog.valuation.land_longitude && (
                            <Button
                              size="small"
                              startIcon={<Map />}
                              onClick={() => window.open(`https://www.google.com/maps?q=${valuationDetailDialog.valuation.land_latitude},${valuationDetailDialog.valuation.land_longitude}`, '_blank')}
                              sx={{ ml: 1, textTransform: 'none' }}
                            >
                              View on Maps
                            </Button>
                          )}
                        </Box>
                      </Box>
                    )}
                  </Box>
                </Paper>
              )}

              {valuationDetailDialog.valuation.category === 'building' && (
                <Paper variant="outlined" sx={{ p: 2, bgcolor: 'grey.50' }}>
                  <Typography variant="subtitle1" fontWeight="bold" gutterBottom>Building Details</Typography>
                  <Box sx={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 2 }}>
                    <Box><Typography variant="caption" color="text.secondary">Area</Typography><Typography variant="body2">{valuationDetailDialog.valuation.building_area} sqft</Typography></Box>
                    <Box><Typography variant="caption" color="text.secondary">Type</Typography><Typography variant="body2">{valuationDetailDialog.valuation.building_type}</Typography></Box>
                    <Box><Typography variant="caption" color="text.secondary">Floors</Typography><Typography variant="body2">{valuationDetailDialog.valuation.number_of_floors}</Typography></Box>
                    <Box><Typography variant="caption" color="text.secondary">Year Built</Typography><Typography variant="body2">{valuationDetailDialog.valuation.year_built}</Typography></Box>
                    {valuationDetailDialog.valuation.building_location && (
                      <Box sx={{ gridColumn: 'span 2' }}>
                        <Typography variant="caption" color="text.secondary">Location</Typography>
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                          <Typography variant="body2">{valuationDetailDialog.valuation.building_location}</Typography>
                          {valuationDetailDialog.valuation.building_latitude && valuationDetailDialog.valuation.building_longitude && (
                            <Button
                              size="small"
                              startIcon={<Map />}
                              onClick={() => window.open(`https://www.google.com/maps?q=${valuationDetailDialog.valuation.building_latitude},${valuationDetailDialog.valuation.building_longitude}`, '_blank')}
                              sx={{ ml: 1, textTransform: 'none' }}
                            >
                              View on Maps
                            </Button>
                          )}
                        </Box>
                      </Box>
                    )}
                  </Box>
                </Paper>
              )}

              {valuationDetailDialog.valuation.category === 'vehicle' && (
                <Paper variant="outlined" sx={{ p: 2, bgcolor: 'grey.50' }}>
                  <Typography variant="subtitle1" fontWeight="bold" gutterBottom>Vehicle Details</Typography>
                  <Box sx={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 2 }}>
                    <Box><Typography variant="caption" color="text.secondary">Make/Model</Typography><Typography variant="body2">{valuationDetailDialog.valuation.vehicle_make} {valuationDetailDialog.valuation.vehicle_model}</Typography></Box>
                    <Box><Typography variant="caption" color="text.secondary">Year</Typography><Typography variant="body2">{valuationDetailDialog.valuation.vehicle_year}</Typography></Box>
                    <Box><Typography variant="caption" color="text.secondary">Registration</Typography><Typography variant="body2">{valuationDetailDialog.valuation.vehicle_registration_number}</Typography></Box>
                    <Box><Typography variant="caption" color="text.secondary">Mileage</Typography><Typography variant="body2">{valuationDetailDialog.valuation.vehicle_mileage} km</Typography></Box>
                    {valuationDetailDialog.valuation.vehicle_condition && (
                      <Box sx={{ gridColumn: 'span 2' }}>
                        <Typography variant="caption" color="text.secondary">Condition</Typography>
                        <Typography variant="body2">{valuationDetailDialog.valuation.vehicle_condition}</Typography>
                      </Box>
                    )}
                  </Box>
                </Paper>
              )}

              {/* Photos Section */}
              {valuationDetailDialog.valuation.photos?.length > 0 && (
                <Box>
                  <Typography variant="subtitle1" fontWeight="bold" gutterBottom>Uploaded Photos</Typography>
                  <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap' }}>
                    {valuationDetailDialog.valuation.photos.map(photo => (
                      <Box
                        key={photo.id}
                        component="img"
                        src={photo.photo_url || photo.photo}
                        alt={photo.caption || 'Valuation photo'}
                        sx={{ width: 150, height: 150, objectFit: 'cover', borderRadius: 1, border: '1px solid', borderColor: 'divider' }}
                      />
                    ))}
                  </Box>
                </Box>
              )}

              {/* Description & Notes */}
              <Box>
                <Typography variant="subtitle2" color="text.secondary">Description</Typography>
                <Typography variant="body2">{valuationDetailDialog.valuation.description || 'No description provided.'}</Typography>
              </Box>

              {valuationDetailDialog.valuation.notes && (
                <Box>
                  <Typography variant="subtitle2" color="text.secondary">Notes</Typography>
                  <Typography variant="body2" sx={{ fontStyle: 'italic' }}>{valuationDetailDialog.valuation.notes}</Typography>
                </Box>
              )}

              {/* Rejection Info */}
              {valuationDetailDialog.valuation.status === 'rejected' && valuationDetailDialog.valuation.rejection_reason && (
                <Alert severity="error" sx={{ mt: 1 }}>
                  <Typography variant="subtitle2" fontWeight="bold">Rejection Reason:</Typography>
                  {valuationDetailDialog.valuation.rejection_reason}
                </Alert>
              )}
            </Box>
          )}
        </DialogContent>
        <DialogActions sx={{ px: 3, py: 2 }}>
          {valuationDetailDialog.valuation?.final_report_url && (
            <Button
              variant="outlined"
              onClick={() => window.open(valuationDetailDialog.valuation.final_report_url, '_blank')}
            >
              View Generated PDF
            </Button>
          )}
          <Box sx={{ flexGrow: 1 }} />
          <Button onClick={() => setValuationDetailDialog({ open: false, valuation: null })}>Close</Button>
          {(valuationDetailDialog.valuation?.status === 'submitted' || valuationDetailDialog.valuation?.status === 'under_review') && (
            <>
              <Button
                variant="contained"
                color="primary"
                sx={{ width: 110 }}
                onClick={() => {
                  handleAcceptValuation(valuationDetailDialog.valuation.id);
                  setValuationDetailDialog({ open: false, valuation: null });
                }}
              >
                Accept
              </Button>
              <Button
                variant="outlined"
                color="error"
                sx={{ width: 110 }}
                onClick={() => {
                  setRejectDialog({ open: true, valuationId: valuationDetailDialog.valuation.id, reason: '' });
                  setValuationDetailDialog({ open: false, valuation: null });
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
            Please provide a reason for rejecting this valuation. This will be sent to the field officer.
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
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button onClick={() => setRejectDialog({ ...rejectDialog, open: false })} sx={{ width: 110 }}>Cancel</Button>
          <Button onClick={handleRejectValuation} color="error" variant="contained" sx={{ width: 110 }}>Reject</Button>
        </DialogActions>
      </Dialog>

      <Snackbar open={snackbar.open} autoHideDuration={4000} onClose={() => setSnackbar({ ...snackbar, open: false })}>
        <Alert severity={snackbar.severity} onClose={() => setSnackbar({ ...snackbar, open: false })}>{snackbar.message}</Alert>
      </Snackbar>
    </Box>
  );
}
