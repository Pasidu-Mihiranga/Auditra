import { useState, useEffect, useCallback, Fragment } from 'react';
import {
  Box, Typography, Paper, Table, TableBody, TableCell, TableContainer,
  TableHead, TableRow, TablePagination, TextField, MenuItem, Chip,
  Button, InputAdornment, IconButton, CircularProgress, Collapse, Grid,
} from '@mui/material';
import {
  Search as SearchIcon,
  KeyboardArrowDown as ExpandMoreIcon,
  KeyboardArrowUp as ExpandLessIcon,
  AddCircle as AddCircleIcon,
  CheckCircle as CheckCircleIcon,
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import axiosClient from '../../api/axiosClient';

/* ------------------------------------------------------------------ */
/*  Constants                                                         */
/* ------------------------------------------------------------------ */
const STATUS_OPTIONS = [
  { value: '', label: 'All' },
  { value: 'assigned', label: 'Assigned' },
  { value: 'approved', label: 'Approved' },
];

const STATUS_CHIP_COLORS = {
  assigned: '#009688',
  approved: '#2e7d32',
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
/*  Detail field helper                                               */
/* ------------------------------------------------------------------ */
const DetailField = ({ label, value }) => (
  <Box sx={{ mb: 1.5 }}>
    <Typography
      variant="caption"
      sx={{ color: 'text.secondary', fontWeight: 600, display: 'block', mb: 0.25 }}
    >
      {label}
    </Typography>
    <Typography variant="body2" sx={{ wordBreak: 'break-word' }}>
      {value || '-'}
    </Typography>
  </Box>
);

/* ------------------------------------------------------------------ */
/*  Component                                                         */
/* ------------------------------------------------------------------ */
export default function AssignedSubmissions() {
  const navigate = useNavigate();

  /* ---- state ---- */
  const [submissions, setSubmissions] = useState([]);
  const [totalCount, setTotalCount] = useState(0);
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(10);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [loading, setLoading] = useState(true);
  const [expandedRow, setExpandedRow] = useState(null);

  /* ================================================================
     Fetch submissions
     ================================================================ */
  const fetchSubmissions = useCallback(async () => {
    setLoading(true);
    try {
      const params = { page: page + 1, page_size: rowsPerPage };
      if (search) params.search = search;
      if (statusFilter) params.status = statusFilter;

      const res = await axiosClient.get('/auth/client-submissions/', { params });
      setSubmissions(res.data.results || []);
      setTotalCount(res.data.count || 0);
    } catch {
      setSubmissions([]);
      setTotalCount(0);
    } finally {
      setLoading(false);
    }
  }, [page, rowsPerPage, search, statusFilter]);

  useEffect(() => {
    fetchSubmissions();
  }, [fetchSubmissions]);

  /* ================================================================
     Handlers
     ================================================================ */
  const handleToggleExpand = (id) => {
    setExpandedRow((prev) => (prev === id ? null : id));
  };

  const handleCreateProject = (submission) => {
    navigate('/dashboard/projects/create', {
      state: {
        submissionData: submission,
        submissionId: submission.id,
      },
    });
  };

  const handlePageChange = (_, newPage) => setPage(newPage);

  const handleRowsPerPageChange = (e) => {
    setRowsPerPage(parseInt(e.target.value, 10));
    setPage(0);
  };

  /* ================================================================
     Render
     ================================================================ */
  const colCount = 9;

  return (
    <Box>
      {/* ---- Page Title ---- */}
      <Typography variant="h5" sx={{ fontWeight: 700, mb: 3 }}>
        Assigned Submissions
      </Typography>

      {/* ---- Search & Filter Toolbar ---- */}
      <Paper sx={{ p: 2, mb: 2, display: 'flex', gap: 2, flexWrap: 'wrap', alignItems: 'center' }}>
        <TextField
          size="small"
          placeholder="Search by name, email, company, project..."
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
          sx={{ minWidth: 320 }}
        />
        <TextField
          select
          size="small"
          value={statusFilter}
          onChange={(e) => {
            setStatusFilter(e.target.value);
            setPage(0);
          }}
          sx={{ minWidth: 170 }}
        >
          {STATUS_OPTIONS.map((opt) => (
            <MenuItem key={opt.value} value={opt.value}>
              {opt.label}
            </MenuItem>
          ))}
        </TextField>
      </Paper>

      {/* ---- Data Table ---- */}
      <TableContainer component={Paper}>
        <Table size="small">
          <TableHead>
            <TableRow sx={{ bgcolor: 'action.hover' }}>
              <TableCell sx={{ width: 48 }} />
              <TableCell sx={{ fontWeight: 700 }}>Name</TableCell>
              <TableCell sx={{ fontWeight: 700 }}>Email</TableCell>
              <TableCell sx={{ fontWeight: 700 }}>Company</TableCell>
              <TableCell sx={{ fontWeight: 700 }}>Project Title</TableCell>
              <TableCell sx={{ fontWeight: 700 }}>Agent</TableCell>
              <TableCell sx={{ fontWeight: 700 }}>Status</TableCell>
              <TableCell sx={{ fontWeight: 700 }}>Date</TableCell>
              <TableCell sx={{ fontWeight: 700 }}>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {loading ? (
              <TableRow>
                <TableCell colSpan={colCount} align="center" sx={{ py: 6 }}>
                  <CircularProgress size={28} />
                </TableCell>
              </TableRow>
            ) : submissions.length === 0 ? (
              <TableRow>
                <TableCell colSpan={colCount} align="center" sx={{ py: 6, color: 'text.secondary' }}>
                  No submissions found
                </TableCell>
              </TableRow>
            ) : (
              submissions.map((sub) => {
                const isExpanded = expandedRow === sub.id;
                const fullName =
                  [sub.first_name, sub.last_name].filter(Boolean).join(' ') || '-';
                const statusLabel = sub.status
                  ? sub.status.charAt(0).toUpperCase() + sub.status.slice(1)
                  : 'Unknown';
                const chipBg = STATUS_CHIP_COLORS[sub.status] || '#757575';

                return (
                  <Fragment key={sub.id}>
                    {/* ---- Main row ---- */}
                    <TableRow hover sx={{ '& > *': { borderBottom: 'unset' } }}>
                      {/* Expand chevron */}
                      <TableCell sx={{ width: 48 }}>
                        <IconButton
                          size="small"
                          onClick={() => handleToggleExpand(sub.id)}
                        >
                          {isExpanded ? <ExpandLessIcon /> : <ExpandMoreIcon />}
                        </IconButton>
                      </TableCell>

                      <TableCell sx={{ fontWeight: 500 }}>{fullName}</TableCell>
                      <TableCell>{sub.email || '-'}</TableCell>
                      <TableCell>{sub.company_name || '-'}</TableCell>
                      <TableCell
                        sx={{
                          maxWidth: 200,
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                          whiteSpace: 'nowrap',
                        }}
                      >
                        {sub.project_title || '-'}
                      </TableCell>
                      <TableCell>{sub.agent_name || '-'}</TableCell>

                      {/* Status chip */}
                      <TableCell>
                        <Chip
                          label={statusLabel}
                          size="small"
                          sx={{
                            fontSize: '0.72rem',
                            fontWeight: 600,
                            bgcolor: chipBg,
                            color: '#fff',
                          }}
                        />
                      </TableCell>

                      {/* Date */}
                      <TableCell sx={{ whiteSpace: 'nowrap', fontSize: '0.8rem' }}>
                        {formatDate(sub.submitted_at)}
                      </TableCell>

                      {/* Actions */}
                      <TableCell>
                        {sub.status === 'assigned' ? (
                          <Button
                            variant="contained"
                            color="primary"
                            size="small"
                            startIcon={<AddCircleIcon />}
                            onClick={() => handleCreateProject(sub)}
                          >
                            Create Project
                          </Button>
                        ) : sub.status === 'approved' ? (
                          <Chip
                            icon={<CheckCircleIcon sx={{ color: '#fff !important' }} />}
                            label="Project Created"
                            size="small"
                            disabled
                            sx={{
                              fontSize: '0.72rem',
                              fontWeight: 600,
                              bgcolor: '#2e7d32',
                              color: '#fff',
                              opacity: 0.7,
                              '& .MuiChip-icon': { color: '#fff' },
                            }}
                          />
                        ) : null}
                      </TableCell>
                    </TableRow>

                    {/* ---- Expandable detail row ---- */}
                    <TableRow>
                      <TableCell
                        colSpan={colCount}
                        sx={{ py: 0, borderBottom: isExpanded ? undefined : 'none' }}
                      >
                        <Collapse in={isExpanded} timeout="auto" unmountOnExit>
                          <Box sx={{ py: 2, px: 2 }}>
                            <Grid container spacing={3}>
                              {/* Left column: Client Info */}
                              <Grid item xs={12} md={4}>
                                <Typography
                                  variant="subtitle2"
                                  sx={{ fontWeight: 700, mb: 1.5, color: 'primary.main' }}
                                >
                                  Client Information
                                </Typography>
                                <DetailField
                                  label="Full Name"
                                  value={fullName}
                                />
                                <DetailField label="Email" value={sub.email} />
                                <DetailField label="Phone" value={sub.phone} />
                                <DetailField label="NIC" value={sub.nic} />
                              </Grid>

                              {/* Center column: Project Info */}
                              <Grid item xs={12} md={4}>
                                <Typography
                                  variant="subtitle2"
                                  sx={{ fontWeight: 700, mb: 1.5, color: 'primary.main' }}
                                >
                                  Project Information
                                </Typography>
                                <DetailField
                                  label="Company"
                                  value={sub.company_name}
                                />
                                <DetailField label="Address" value={sub.address} />
                                <DetailField
                                  label="Project Title"
                                  value={sub.project_title}
                                />
                                <DetailField
                                  label="Project Description"
                                  value={sub.project_description}
                                />
                              </Grid>

                              {/* Right column: Agent Info */}
                              <Grid item xs={12} md={4}>
                                <Typography
                                  variant="subtitle2"
                                  sx={{ fontWeight: 700, mb: 1.5, color: 'primary.main' }}
                                >
                                  Agent Information
                                </Typography>
                                <DetailField label="Agent" value={sub.agent_name} />
                                <DetailField
                                  label="Agent Email"
                                  value={sub.agent_email}
                                />
                                <DetailField
                                  label="Agent Phone"
                                  value={sub.agent_phone}
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

        {/* ---- Pagination ---- */}
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
    </Box>
  );
}
