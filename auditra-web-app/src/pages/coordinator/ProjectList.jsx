import { useState, useEffect } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import {
  Box, Typography, Tabs, Tab, Table, TableBody, TableCell, TableContainer,
  TableHead, TableRow, Paper, Button, TextField, InputAdornment, Alert, Chip,
} from '@mui/material';
import { Search, Add, Visibility } from '@mui/icons-material';
import projectService from '../../services/projectService';
import LoadingSpinner from '../../components/LoadingSpinner';
import StatusChip from '../../components/StatusChip';
import { formatDate, getPriorityColor } from '../../utils/helpers';

const STATUS_TAB_MAP = { pending: 1, in_progress: 2, completed: 3 };

export default function ProjectList() {
  const [projects, setProjects] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const location = useLocation();
  const initialTab = STATUS_TAB_MAP[location.state?.filter] || 0;
  const [tab, setTab] = useState(initialTab);
  const [search, setSearch] = useState('');
  const navigate = useNavigate();

  useEffect(() => {
    const fetchProjects = async () => {
      try {
        const res = await projectService.getProjects();
        setProjects(Array.isArray(res.data) ? res.data : res.data?.results || []);
      } catch {
        setError('Failed to load projects');
      } finally {
        setLoading(false);
      }
    };
    fetchProjects();
  }, []);

  const statuses = ['', 'pending', 'in_progress', 'completed'];
  const filtered = projects
    .filter(p => !statuses[tab] || p.status === statuses[tab])
    .filter(p => p.title?.toLowerCase().includes(search.toLowerCase()));

  if (loading) return <LoadingSpinner />;

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Typography variant="h5" sx={{ fontWeight: 700 }}>Projects</Typography>
        <Button variant="contained" startIcon={<Add />} onClick={() => navigate('/dashboard/projects/create')}>
          Create Project
        </Button>
      </Box>
      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

      <Tabs value={tab} onChange={(_, v) => setTab(v)} sx={{ mb: 2 }}>
        <Tab label={`All (${projects.length})`} />
        <Tab label={`Pending (${projects.filter(p => p.status === 'pending').length})`} />
        <Tab label={`In Progress (${projects.filter(p => p.status === 'in_progress').length})`} />
        <Tab label={`Completed (${projects.filter(p => p.status === 'completed').length})`} />
      </Tabs>

      <TextField fullWidth placeholder="Search projects..." value={search} onChange={(e) => setSearch(e.target.value)}
        InputProps={{ startAdornment: <InputAdornment position="start"><Search /></InputAdornment> }}
        sx={{ mb: 2 }} size="small" />

      <TableContainer component={Paper}>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Title</TableCell>
              <TableCell>Priority</TableCell>
              <TableCell>Status</TableCell>
              <TableCell>Start</TableCell>
              <TableCell>End</TableCell>
              <TableCell>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {filtered.length === 0 ? (
              <TableRow><TableCell colSpan={6} align="center">No projects found</TableCell></TableRow>
            ) : (
              filtered.map((p) => (
                <TableRow key={p.id} hover sx={{ cursor: 'pointer' }} onClick={() => navigate(`/dashboard/projects/${p.id}`)}>
                  <TableCell sx={{ fontWeight: 600 }}>{p.title}</TableCell>
                  <TableCell>
                    <Chip label={p.priority} size="small" sx={{ bgcolor: `${getPriorityColor(p.priority)}20`, color: getPriorityColor(p.priority), fontWeight: 600, fontSize: 11 }} />
                  </TableCell>
                  <TableCell><StatusChip status={p.status} label={p.status_display || p.status} /></TableCell>
                  <TableCell>{formatDate(p.start_date)}</TableCell>
                  <TableCell>{formatDate(p.end_date)}</TableCell>
                  <TableCell>
                    <Button size="small" startIcon={<Visibility />} onClick={(e) => { e.stopPropagation(); navigate(`/dashboard/projects/${p.id}`); }}>
                      View
                    </Button>
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
