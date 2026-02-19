import { useState, useEffect, useCallback, Fragment } from 'react';
import {
  Box, Typography, Paper, Table, TableBody, TableCell, TableContainer,
  TableHead, TableRow, TablePagination, TextField, MenuItem, Chip, Alert,
  Button, Snackbar, InputAdornment, CircularProgress, Collapse,
  Dialog, DialogTitle, DialogContent, DialogActions, Grid, IconButton,
  List, ListItemButton, ListItemText, ListItemIcon, Radio,
} from '@mui/material';
import {
  Search as SearchIcon,
  People as PeopleIcon,
  CheckCircle as CheckCircleIcon,
  Assignment as AssignmentIcon,
  PersonAdd as PersonAddIcon,
  KeyboardArrowDown as ExpandMoreIcon,
  KeyboardArrowUp as ExpandLessIcon,
} from '@mui/icons-material';
import PendingIcon from '@mui/icons-material/Pending';
import axiosClient from '../../api/axiosClient';
import StatsCard from '../../components/StatsCard';

/* ------------------------------------------------------------------ */
/*  Constants                                                          */
/* ------------------------------------------------------------------ */

const STATUS_OPTIONS = [
  { value: '', label: 'All' },
  { value: 'pending', label: 'Pending' },
  { value: 'reviewed', label: 'Reviewed' },
  { value: 'assigned', label: 'Assigned' },
  { value: 'approved', label: 'Approved' },
  { value: 'rejected', label: 'Rejected' },
];

const STATUS_CHIP_COLORS = {
  pending: '#ed6c02',
  rejected: '#d32f2f',
  approved: '#2e7d32',
  reviewed: '#1976d2',
  assigned: '#009688',
};

const formatDate = (dateStr) => {
  if (!dateStr) return '-';
  const d = new Date(dateStr);
  const day = String(d.getDate()).padStart(2, '0');
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const year = d.getFullYear();
  return `${day}/${month}/${year}`;
};

/* ------------------------------------------------------------------ */
/*  Detail Field (for expandable row)                                  */
/* ------------------------------------------------------------------ */

const DetailField = ({ label, value }) => (
  <Box sx={{ mb: 1.5 }}>
    <Typography
      variant="caption"
      sx={{ color: 'primary.main', fontWeight: 600, display: 'block', mb: 0.25 }}
    >
      {label}
    </Typography>
    <Typography variant="body2" sx={{ wordBreak: 'break-word' }}>
      {value || '-'}
    </Typography>
  </Box>
);

/* ================================================================== */
/*  Main Component                                                     */
/* ================================================================== */

export default function ClientSubmissions() {
  /* ---- state ---- */
  const [submissions, setSubmissions] = useState([]);
  const [totalCount, setTotalCount] = useState(0);
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(10);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [loading, setLoading] = useState(true);
  const [summary, setSummary] = useState({
    total: 0,
    pending: 0,
    assigned: 0,
    approved: 0,
  });

  /* expandable row */
  const [expandedId, setExpandedId] = useState(null);

  /* assign dialog */
  const [assignDialogOpen, setAssignDialogOpen] = useState(false);
  const [selectedSubmission, setSelectedSubmission] = useState(null);
  const [coordinators, setCoordinators] = useState([]);
  const [selectedCoordinator, setSelectedCoordinator] = useState(null);
  const [assignLoading, setAssignLoading] = useState(false);

  /* snackbar */
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });

  /* ================================================================ */
  /*  Data fetching                                                    */
  /* ================================================================ */

  const fetchSubmissions = useCallback(async () => {
    setLoading(true);
    try {
      const params = { page: page + 1, page_size: rowsPerPage };
      if (search) params.search = search;
      if (statusFilter) params.status = statusFilter;

      const res = await axiosClient.get('/auth/client-submissions/', { params });
      setSubmissions(res.data.results || []);
      setTotalCount(res.data.count || 0);

      if (res.data.summary) {
        setSummary({
          total: res.data.summary.total ?? 0,
          pending: res.data.summary.pending ?? 0,
          assigned: res.data.summary.assigned ?? 0,
          approved: res.data.summary.approved ?? 0,
        });
      }
    } catch (err) {
      showSnackbar(err.response?.data?.error || 'Failed to load submissions', 'error');
    } finally {
      setLoading(false);
    }
  }, [page, rowsPerPage, search, statusFilter]);

  useEffect(() => {
    fetchSubmissions();
  }, [fetchSubmissions]);

  /* ================================================================ */
  /*  Helpers                                                          */
  /* ================================================================ */

  const showSnackbar = (message, severity = 'success') => {
    setSnackbar({ open: true, message, severity });
  };

  /* ================================================================ */
  /*  Expandable row toggle                                            */
  /* ================================================================ */

  const handleToggleExpand = (id) => {
    setExpandedId((prev) => (prev === id ? null : id));
  };

  /* ================================================================ */
  /*  Assign coordinator                                               */
  /* ================================================================ */

  const handleOpenAssignDialog = async (e, submission) => {
    e.stopPropagation();
    setSelectedSubmission(submission);
    setSelectedCoordinator(null);
    setAssignDialogOpen(true);

    try {
      const res = await axiosClient.get('/auth/coordinators/');
      setCoordinators(res.data.coordinators || res.data.results || res.data || []);
    } catch (err) {
      showSnackbar('Failed to load coordinators', 'error');
    }
  };

  const handleAssignCoordinator = async () => {
    if (!selectedSubmission || !selectedCoordinator) return;
    setAssignLoading(true);
    try {
      await axiosClient.post(
        `/auth/client-submissions/${selectedSubmission.id}/assign-coordinator/`,
        { coordinator_id: selectedCoordinator }
      );
      showSnackbar('Coordinator assigned successfully');
      setAssignDialogOpen(false);
      setSelectedSubmission(null);
      setSelectedCoordinator(null);
      fetchSubmissions();
    } catch (err) {
      showSnackbar(err.response?.data?.error || 'Failed to assign coordinator', 'error');
    } finally {
      setAssignLoading(false);
    }
  };

  /* ================================================================ */
  /*  Pagination                                                       */
  /* ================================================================ */

  const handlePageChange = (_, newPage) => setPage(newPage);
  const handleRowsPerPageChange = (e) => {
    setRowsPerPage(parseInt(e.target.value, 10));
    setPage(0);
  };

  /* ================================================================ */
  /*  Render                                                           */
  /* ================================================================ */

  return (
    <Box>
      {/* Page Title */}
      <Typography variant="h5" sx={{ fontWeight: 700, mb: 3 }}>
        Client Submissions
      </Typography>

      {/* ========================================================== */}
      {/*  Summary Cards                                              */}
      {/* ========================================================== */}
      <Grid container spacing={2} sx={{ mb: 3 }}>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard
            icon={PeopleIcon}
            title="Total Submissions"
            value={summary.total}
            color="#1565C0"
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard
            icon={PendingIcon}
            title="Pending"
            value={summary.pending}
            color="#D97706"
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard
            icon={AssignmentIcon}
            title="Assigned"
            value={summary.assigned}
            color="#009688"
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatsCard
            icon={CheckCircleIcon}
            title="Approved"
            value={summary.approved}
            color="#16A34A"
          />
        </Grid>
      </Grid>

      {/* ========================================================== */}
      {/*  Search & Status Filter                                     */}
      {/* ========================================================== */}
      <Box sx={{ display: 'flex', gap: 2, mb: 2, flexWrap: 'wrap' }}>
        <TextField
          fullWidth
          size="small"
          placeholder="Search by name, email, company, or project..."
          value={search}
          onChange={(e) => {
            setSearch(e.target.value);
            setPage(0);
          }}
          InputProps={{
            startAdornment: (
              <InputAdornment position="start">
                <SearchIcon fontSize="small" />
              </InputAdornment>
            ),
          }}
          sx={{ flex: 1, minWidth: 280 }}
        />
        <TextField
          select
          size="small"
          value={statusFilter}
          onChange={(e) => {
            setStatusFilter(e.target.value);
            setPage(0);
          }}
          sx={{ minWidth: 160 }}
        >
          {STATUS_OPTIONS.map((opt) => (
            <MenuItem key={opt.value} value={opt.value}>
              {opt.label}
            </MenuItem>
          ))}
        </TextField>
      </Box>

      {/* ========================================================== */}
      {/*  Data Table                                                  */}
      {/* ========================================================== */}
      <TableContainer component={Paper}>
        <Table size="small">
          <TableHead>
            <TableRow sx={{ bgcolor: 'action.hover' }}>
              <TableCell sx={{ fontWeight: 700, width: 40 }} />
              <TableCell sx={{ fontWeight: 700 }}>Name</TableCell>
              <TableCell sx={{ fontWeight: 700 }}>Email</TableCell>
              <TableCell sx={{ fontWeight: 700 }}>Company</TableCell>
              <TableCell sx={{ fontWeight: 700 }}>Project Title</TableCell>
              <TableCell sx={{ fontWeight: 700 }}>Agent</TableCell>
              <TableCell sx={{ fontWeight: 700 }}>Status</TableCell>
              <TableCell sx={{ fontWeight: 700 }}>Coordinator</TableCell>
              <TableCell sx={{ fontWeight: 700 }}>Date</TableCell>
              <TableCell sx={{ fontWeight: 700 }}>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {loading ? (
              <TableRow>
                <TableCell colSpan={10} align="center" sx={{ py: 6 }}>
                  <CircularProgress size={28} />
                </TableCell>
              </TableRow>
            ) : submissions.length === 0 ? (
              <TableRow>
                <TableCell colSpan={10} align="center" sx={{ py: 6, color: 'text.secondary' }}>
                  No submissions found
                </TableCell>
              </TableRow>
            ) : (
              submissions.map((sub) => {
                const isExpanded = expandedId === sub.id;
                const fullName =
                  [sub.first_name, sub.last_name].filter(Boolean).join(' ') || '-';
                const hasCoordinator = !!sub.coordinator_name;

                return (
                  <Fragment key={sub.id}>
                    {/* Main Row */}
                    <TableRow
                      hover
                      onClick={() => handleToggleExpand(sub.id)}
                      sx={{ cursor: 'pointer', '& > *': { borderBottom: isExpanded ? 'unset' : undefined } }}
                    >
                      <TableCell sx={{ width: 40 }}>
                        <IconButton size="small">
                          {isExpanded ? <ExpandLessIcon /> : <ExpandMoreIcon />}
                        </IconButton>
                      </TableCell>
                      <TableCell sx={{ fontWeight: 500 }}>{fullName}</TableCell>
                      <TableCell>{sub.email || '-'}</TableCell>
                      <TableCell>{sub.company_name || '-'}</TableCell>
                      <TableCell
                        sx={{
                          maxWidth: 180,
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                          whiteSpace: 'nowrap',
                        }}
                      >
                        {sub.project_title || '-'}
                      </TableCell>
                      <TableCell>{sub.agent_name || '-'}</TableCell>
                      <TableCell>
                        <Chip
                          label={
                            sub.status
                              ? sub.status.charAt(0).toUpperCase() + sub.status.slice(1)
                              : 'Unknown'
                          }
                          size="small"
                          sx={{
                            fontSize: '0.72rem',
                            fontWeight: 600,
                            color: '#fff',
                            bgcolor: STATUS_CHIP_COLORS[sub.status] || '#757575',
                          }}
                        />
                      </TableCell>
                      <TableCell>{sub.coordinator_name || '-'}</TableCell>
                      <TableCell sx={{ whiteSpace: 'nowrap', fontSize: '0.8rem' }}>
                        {formatDate(sub.submitted_at)}
                      </TableCell>
                      <TableCell>
                        <Button
                          size="small"
                          variant="outlined"
                          startIcon={<PersonAddIcon />}
                          disabled={hasCoordinator}
                          onClick={(e) => handleOpenAssignDialog(e, sub)}
                          sx={{ textTransform: 'none', whiteSpace: 'nowrap' }}
                        >
                          {hasCoordinator ? 'Assigned' : 'Assign'}
                        </Button>
                      </TableCell>
                    </TableRow>

                    {/* Expandable Detail Row */}
                    <TableRow>
                      <TableCell
                        colSpan={10}
                        sx={{ py: 0, px: 0, borderBottom: isExpanded ? undefined : 'none' }}
                      >
                        <Collapse in={isExpanded} timeout="auto" unmountOnExit>
                          <Box sx={{ p: 3, bgcolor: 'grey.50' }}>
                            <Typography
                              variant="subtitle1"
                              sx={{ fontWeight: 700, mb: 2, color: '#1976d2' }}
                            >
                              Submission Details
                            </Typography>
                            <Grid container spacing={3}>
                              {/* Left Column */}
                              <Grid item xs={12} md={4}>
                                <DetailField label="Full Name" value={fullName} />
                                <DetailField label="Email" value={sub.email} />
                                <DetailField label="Phone" value={sub.phone} />
                                <DetailField label="NIC" value={sub.nic} />
                              </Grid>

                              {/* Center Column */}
                              <Grid item xs={12} md={4}>
                                <DetailField label="Company" value={sub.company_name} />
                                <DetailField label="Address" value={sub.address} />
                                <DetailField label="Project Title" value={sub.project_title} />
                                <DetailField
                                  label="Project Description"
                                  value={sub.project_description}
                                />
                              </Grid>

                              {/* Right Column */}
                              <Grid item xs={12} md={4}>
                                <DetailField label="Agent" value={sub.agent_name} />
                                <DetailField label="Agent Email" value={sub.agent_email} />
                                <DetailField label="Agent Phone" value={sub.agent_phone} />
                                <DetailField
                                  label="Coordinator"
                                  value={sub.coordinator_name || 'Not Assigned'}
                                />
                              </Grid>
                            </Grid>
                          </Box>
                        </Collapse>
                      </TableCell>
                    </TableRow>
                  </Fragment>
                );
              })
            )}
          </TableBody>
        </Table>
        <TablePagination
          component="div"
          count={totalCount}
          page={page}
          onPageChange={handlePageChange}
          rowsPerPage={rowsPerPage}
          onRowsPerPageChange={handleRowsPerPageChange}
          rowsPerPageOptions={[10, 25, 50]}
        />
      </TableContainer>

      {/* ========================================================== */}
      {/*  Assign Coordinator Dialog                                   */}
      {/* ========================================================== */}
      <Dialog
        open={assignDialogOpen}
        onClose={() => {
          if (!assignLoading) {
            setAssignDialogOpen(false);
            setSelectedSubmission(null);
            setSelectedCoordinator(null);
          }
        }}
        maxWidth="sm"
        fullWidth
      >
        <DialogTitle sx={{ fontWeight: 700 }}>Assign Coordinator</DialogTitle>
        <DialogContent dividers>
          {selectedSubmission && (
            <Typography variant="body2" sx={{ mb: 2, color: 'text.secondary' }}>
              Assign a coordinator to the submission from{' '}
              <strong>
                {[selectedSubmission.first_name, selectedSubmission.last_name]
                  .filter(Boolean)
                  .join(' ')}
              </strong>
            </Typography>
          )}

          {coordinators.length === 0 ? (
            <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}>
              <CircularProgress size={28} />
            </Box>
          ) : (
            <List sx={{ pt: 0 }}>
              {coordinators.map((coord) => (
                <ListItemButton
                  key={coord.id}
                  selected={selectedCoordinator === coord.id}
                  onClick={() => setSelectedCoordinator(coord.id)}
                  sx={{ borderRadius: 1, mb: 0.5 }}
                >
                  <ListItemIcon sx={{ minWidth: 36 }}>
                    <Radio
                      checked={selectedCoordinator === coord.id}
                      size="small"
                    />
                  </ListItemIcon>
                  <ListItemText
                    primary={
                      coord.name ||
                      coord.full_name ||
                      `${coord.first_name || ''} ${coord.last_name || ''}`.trim() ||
                      coord.username
                    }
                    secondary={`Assigned: ${coord.assigned_count ?? coord.assignment_count ?? 0}`}
                  />
                </ListItemButton>
              ))}
            </List>
          )}
        </DialogContent>
        <DialogActions sx={{ px: 3, py: 2 }}>
          <Button
            onClick={() => {
              setAssignDialogOpen(false);
              setSelectedSubmission(null);
              setSelectedCoordinator(null);
            }}
            disabled={assignLoading}
          >
            Cancel
          </Button>
          <Button
            variant="contained"
            onClick={handleAssignCoordinator}
            disabled={!selectedCoordinator || assignLoading}
            startIcon={
              assignLoading ? (
                <CircularProgress size={16} color="inherit" />
              ) : (
                <PersonAddIcon />
              )
            }
          >
            Assign
          </Button>
        </DialogActions>
      </Dialog>

      {/* ========================================================== */}
      {/*  Snackbar                                                    */}
      {/* ========================================================== */}
      <Snackbar
        open={snackbar.open}
        autoHideDuration={5000}
        onClose={() => setSnackbar((prev) => ({ ...prev, open: false }))}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}
      >
        <Alert
          onClose={() => setSnackbar((prev) => ({ ...prev, open: false }))}
          severity={snackbar.severity}
          sx={{ width: '100%' }}
        >
          {snackbar.message}
        </Alert>
      </Snackbar>
    </Box>
  );
}
