import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
  Box, Typography, Card, CardContent, Grid, Chip, Button, Alert,
  Select, MenuItem, Dialog, DialogTitle, DialogContent, DialogActions,
  Divider, IconButton, Tooltip, FormControl, InputLabel
} from '@mui/material';
import {
  ArrowBack, PersonAdd, PlayArrow, CheckCircle, Cancel, Lock,
  Timeline as TimelineIcon, Update, Description, Download,
  EventNote, AssignmentInd, FactCheck
} from '@mui/icons-material';
import projectService from '../../services/projectService';
import LoadingSpinner from '../../components/LoadingSpinner';
import StatusChip from '../../components/StatusChip';
import { formatDate, formatDateTime, getPriorityColor } from '../../utils/helpers';
import { useAuth } from '../../contexts/AuthContext';

export default function ProjectDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { role } = useAuth();
  const [project, setProject] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [assignDialog, setAssignDialog] = useState(null);
  const [availableUsers, setAvailableUsers] = useState([]);
  const [selectedUser, setSelectedUser] = useState('');
  const [starting, setStarting] = useState(false);
  const [updatingStatus, setUpdatingStatus] = useState(false);
  const [statusToUpdate, setStatusToUpdate] = useState('');

  const fetchProject = async () => {
    try {
      const res = await projectService.getProject(id);
      setProject(res.data);
    } catch {
      setError('Failed to load project');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchProject();
  }, [id]);

  useEffect(() => {
    if (project) {
      setStatusToUpdate(project.status);
    }
  }, [project]);

  const openAssignDialog = async (type) => {
    setAssignDialog(type);
    try {
      const fetchers = {
        field_officer: projectService.getFieldOfficers,
        client: projectService.getClients,
        agent: projectService.getAgents,
        accessor: projectService.getAccessors,
        senior_valuer: projectService.getSeniorValuers,
      };
      const dataKeys = {
        field_officer: 'field_officers',
        client: 'clients',
        agent: 'agents',
        accessor: 'accessors',
        senior_valuer: 'senior_valuers',
      };
      const res = await fetchers[type]();
      const users = res.data?.[dataKeys[type]] || (Array.isArray(res.data) ? res.data : []);
      setAvailableUsers(users);
    } catch {
      setError('Failed to load users');
    }
  };

  const handleAssign = async () => {
    if (!selectedUser || !assignDialog) return;
    setError('');
    try {
      const assigners = {
        field_officer: projectService.assignFieldOfficer,
        client: projectService.assignClient,
        agent: projectService.assignAgent,
        accessor: projectService.assignAccessor,
        senior_valuer: projectService.assignSeniorValuer,
      };
      await assigners[assignDialog](id, selectedUser);
      setSuccess(`${assignDialog.replace(/_/g, ' ')} assigned!`);
      setAssignDialog(null);
      setSelectedUser('');
      await fetchProject();
    } catch (err) {
      setError(err.response?.data?.error || 'Assignment failed');
    }
  };

  const handleUpdateStatus = async (newStatus) => {
    setUpdatingStatus(true);
    setError('');
    try {
      await projectService.updateProject(id, { status: newStatus });
      setSuccess(`Project status updated to ${newStatus.replace(/_/g, ' ')}!`);
      await fetchProject();
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to update status');
    } finally {
      setUpdatingStatus(false);
    }
  };

  const handleStartProject = async () => {
    setStarting(true);
    setError('');
    try {
      await projectService.updateProject(id, { status: 'in_progress' });
      setSuccess('Project started successfully!');
      await fetchProject();
    } catch (err) {
      const data = err.response?.data;
      if (typeof data === 'string') {
        setError(data);
      } else if (Array.isArray(data)) {
        setError(data.join('. '));
      } else if (data?.detail) {
        setError(data.detail);
      } else if (data && typeof data === 'object') {
        const msgs = Object.values(data).flat();
        setError(msgs.join('. '));
      } else {
        setError('Failed to start project');
      }
    } finally {
      setStarting(false);
    }
  };

  if (loading) return <LoadingSpinner />;
  if (!project) return <Alert severity="error">Project not found</Alert>;

  const isCoordinator = role === 'coordinator';
  const isPending = project.status === 'pending';

  // Readiness check for starting the project
  const requiredAssignments = [
    { label: 'Field Officer', assigned: !!project.assigned_field_officer },
    { label: 'Client', assigned: !!project.assigned_client },
    { label: 'Accessor', assigned: !!project.assigned_accessor },
    { label: 'Senior Valuer', assigned: !!project.assigned_senior_valuer },
  ];
  if (project.has_agent) {
    requiredAssignments.splice(2, 0, { label: 'Agent', assigned: !!project.assigned_agent });
  }
  const allAssigned = requiredAssignments.every(r => r.assigned);

  return (
    <Box>
      <Button startIcon={<ArrowBack />} onClick={() => navigate(-1)} sx={{ mb: 2 }}>Back</Button>
      {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError('')}>{error}</Alert>}
      {success && <Alert severity="success" sx={{ mb: 2 }} onClose={() => setSuccess('')}>{success}</Alert>}

      <Card sx={{ mb: 3 }}>
        <CardContent sx={{ p: 3 }}>
          <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', mb: 2 }}>
            <Box>
              <Typography variant="h5" sx={{ fontWeight: 700 }}>{project.title}</Typography>
              <Box sx={{ display: 'flex', gap: 1, mt: 1 }}>
                <StatusChip status={project.status} label={project.status_display || project.status} />
                <Chip label={project.priority} size="small" sx={{ bgcolor: `${getPriorityColor(project.priority)}20`, color: getPriorityColor(project.priority), fontWeight: 600 }} />
              </Box>
            </Box>
            {isCoordinator && (
              <Box sx={{ display: 'flex', gap: 1 }}>
                {isPending ? (
                  <Button
                    variant="contained"
                    color="success"
                    startIcon={<PlayArrow />}
                    onClick={handleStartProject}
                    disabled={starting || !allAssigned}
                    sx={{ fontWeight: 600 }}
                  >
                    {starting ? 'Starting...' : 'Start Project'}
                  </Button>
                ) : (
                  <FormControl size="small" sx={{ minWidth: 150 }}>
                    <InputLabel>Update Status</InputLabel>
                    <Select
                      value={statusToUpdate}
                      label="Update Status"
                      onChange={(e) => handleUpdateStatus(e.target.value)}
                      disabled={updatingStatus}
                    >
                      <MenuItem value="pending">Pending</MenuItem>
                      <MenuItem value="in_progress">In Progress</MenuItem>
                      <MenuItem value="completed">Completed</MenuItem>
                      <MenuItem value="cancelled">Cancelled</MenuItem>
                    </Select>
                  </FormControl>
                )}
              </Box>
            )}
          </Box>
          <Typography variant="body1" sx={{ mb: 3 }}>{project.description}</Typography>
          <Grid container spacing={2}>
            <Grid item xs={6} sm={3}>
              <Typography variant="body2" color="text.secondary">Start Date</Typography>
              <Typography fontWeight={600}>{formatDate(project.start_date)}</Typography>
            </Grid>
            <Grid item xs={6} sm={3}>
              <Typography variant="body2" color="text.secondary">End Date</Typography>
              <Typography fontWeight={600}>{formatDate(project.end_date)}</Typography>
            </Grid>
            <Grid item xs={6} sm={3}>
              <Typography variant="body2" color="text.secondary">Coordinator</Typography>
              <Typography fontWeight={600}>{project.coordinator_name || project.coordinator_username || '-'}</Typography>
            </Grid>
            <Grid item xs={6} sm={3}>
              <Typography variant="body2" color="text.secondary">Created</Typography>
              <Typography fontWeight={600}>{formatDate(project.created_at)}</Typography>
            </Grid>
          </Grid>
        </CardContent>
      </Card>

      {/* Readiness checklist - shown only for coordinator when project is pending */}
      {isCoordinator && isPending && (
        <Card sx={{ mb: 3, border: (t) => allAssigned ? `1px solid ${t.palette.success.main}` : `1px solid ${t.palette.warning.main}` }}>
          <CardContent sx={{ p: 3 }}>
            <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>
              {allAssigned ? 'Ready to Start' : 'Assign Team Before Starting'}
            </Typography>
            <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1.5 }}>
              {requiredAssignments.map(({ label, assigned }) => (
                <Chip
                  key={label}
                  icon={assigned ? <CheckCircle /> : <Cancel />}
                  label={label}
                  color={assigned ? 'success' : 'warning'}
                  variant="outlined"
                  sx={{ fontWeight: 600 }}
                />
              ))}
            </Box>
          </CardContent>
        </Card>
      )}

      <Card sx={{ mb: 3 }}>
        <CardContent sx={{ p: 3 }}>
          <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>Team Assignments</Typography>
          <Grid container spacing={3}>
            {/* First column: Field Officer, Accessor, Senior Valuer */}
            <Grid item xs={12} sm={6}>
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                {[
                  { label: 'Field Officer', key: 'assigned_field_officer', type: 'field_officer', nameKey: 'assigned_field_officer_name' },
                  { label: 'Accessor', key: 'assigned_accessor', type: 'accessor', nameKey: 'assigned_accessor_name' },
                  { label: 'Senior Valuer', key: 'assigned_senior_valuer', type: 'senior_valuer', nameKey: 'assigned_senior_valuer_name' },
                ].map(({ label, key, type, nameKey }) => (
                  <Box key={key} sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', p: 1.5, bgcolor: (t) => t.palette.custom.cardInner, borderRadius: 2 }}>
                    <Box>
                      <Typography variant="body2" color="text.secondary">{label}</Typography>
                      <Typography fontWeight={600}>{project[nameKey] || (project[key] ? `User #${project[key]}` : 'Not assigned')}</Typography>
                    </Box>
                    {isCoordinator && (
                      <Button size="small" startIcon={<PersonAdd />} onClick={() => openAssignDialog(type)}>
                        {project[key] ? 'Change' : 'Assign'}
                      </Button>
                    )}
                  </Box>
                ))}
              </Box>
            </Grid>
            {/* Second column: Client, Agent */}
            <Grid item xs={12} sm={6}>
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                {[
                  { label: 'Client', key: 'assigned_client', type: 'client', nameKey: 'assigned_client_name' },
                  { label: 'Agent', key: 'assigned_agent', type: 'agent', nameKey: 'assigned_agent_name' },
                ].map(({ label, key, type, nameKey }) => (
                  <Box key={key} sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', p: 1.5, bgcolor: (t) => t.palette.custom.cardInner, borderRadius: 2 }}>
                    <Box>
                      <Typography variant="body2" color="text.secondary">{label}</Typography>
                      <Typography fontWeight={600}>{project[nameKey] || (project[key] ? `User #${project[key]}` : 'Not assigned')}</Typography>
                    </Box>
                    {isCoordinator && (
                      <Chip icon={<Lock />} label="Set at creation" size="small" variant="outlined" color="default" />
                    )}
                  </Box>
                ))}
              </Box>
            </Grid>
          </Grid>
        </CardContent>
      </Card>

      {project.client_info && (
        <Card sx={{ mb: 3 }}>
          <CardContent sx={{ p: 3 }}>
            <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>Client Information</Typography>
            <Grid container spacing={2}>
              {['name', 'email', 'phone', 'company'].map(f => (
                <Grid item xs={6} sm={3} key={f}>
                  <Typography variant="body2" color="text.secondary" sx={{ textTransform: 'capitalize' }}>{f}</Typography>
                  <Typography fontWeight={600}>{project.client_info[f] || '-'}</Typography>
                </Grid>
              ))}
            </Grid>
          </CardContent>
        </Card>
      )}

      <Dialog open={!!assignDialog} onClose={() => { setAssignDialog(null); setSelectedUser(''); }} maxWidth="sm" fullWidth>
        <DialogTitle>Assign {assignDialog?.replace(/_/g, ' ')}</DialogTitle>
        <DialogContent>
          <Select
            fullWidth
            value={selectedUser}
            onChange={(e) => setSelectedUser(e.target.value)}
            displayEmpty
            sx={{ mt: 1 }}
          >
            <MenuItem value="" disabled>
              {assignDialog === 'field_officer' && 'Select a field officer...'}
              {assignDialog === 'accessor' && 'Select an accessor...'}
              {assignDialog === 'senior_valuer' && 'Select a senior valuer...'}
              {assignDialog === 'client' && 'Select a client...'}
              {assignDialog === 'agent' && 'Select an agent...'}
            </MenuItem>
            {availableUsers.map((u) => (
              <MenuItem key={u.id} value={u.id}>
                {u.full_name || `${u.first_name} ${u.last_name}`.trim() || u.username}
                {u.email ? ` (${u.email})` : ''}
                {u.assigned_projects_count > 0 ? ` — ${u.assigned_projects_count} project${u.assigned_projects_count > 1 ? 's' : ''}` : ''}
              </MenuItem>
            ))}
          </Select>
          {availableUsers.length === 0 && (
            <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
              No {assignDialog?.replace(/_/g, ' ')}s available
            </Typography>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => { setAssignDialog(null); setSelectedUser(''); }}>Cancel</Button>
          <Button variant="contained" onClick={handleAssign} disabled={!selectedUser}>Assign</Button>
        </DialogActions>
      </Dialog>
      {/* Project Timeline & Approved Reports */}
      <Grid container spacing={3} sx={{ mt: 1 }}>
        <Grid item xs={12} md={6}>
          <Card sx={{ height: '100%', minHeight: 400 }}>
            <CardContent sx={{ p: 3 }}>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 3 }}>
                <TimelineIcon color="primary" />
                <Typography variant="h6" sx={{ fontWeight: 600 }}>Project Timeline</Typography>
              </Box>

              {project.history && project.history.length > 0 ? (
                <Box sx={{ position: 'relative', pl: 2, '&::before': { content: '""', position: 'absolute', left: 7, top: 0, bottom: 0, width: '2px', bgcolor: 'divider' } }}>
                  {project.history.slice().reverse().map((event, index) => (
                    <Box key={event.id} sx={{ mb: 3, position: 'relative' }}>
                      <Box sx={{
                        position: 'absolute',
                        left: -20,
                        top: 4,
                        width: 12,
                        height: 12,
                        borderRadius: '50%',
                        bgcolor: index === 0 ? 'primary.main' : 'divider',
                        border: '2px solid white',
                        boxShadow: '0 0 0 2px rgba(0,0,0,0.05)'
                      }} />
                      <Typography variant="subtitle2" sx={{ fontWeight: 700, lineHeight: 1.2 }}>
                        {event.status_display || event.status}
                      </Typography>
                      <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5 }}>
                        {event.notes}
                      </Typography>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mt: 1 }}>
                        <Typography variant="caption" color="text.secondary" sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                          <AssignmentInd sx={{ fontSize: 14 }} /> {event.created_by_name || event.created_by_username}
                        </Typography>
                        <Typography variant="caption" color="text.secondary">•</Typography>
                        <Typography variant="caption" color="text.secondary" sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                          <EventNote sx={{ fontSize: 14 }} /> {formatDate(event.created_at)}
                        </Typography>
                      </Box>
                    </Box>
                  ))}
                </Box>
              ) : (
                <Box sx={{ py: 4, textAlign: 'center' }}>
                  <Typography color="text.secondary">No activity recorded yet</Typography>
                </Box>
              )}
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} md={6}>
          <Card sx={{ height: '100%', minHeight: 400 }}>
            <CardContent sx={{ p: 3 }}>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 3 }}>
                <FactCheck color="primary" />
                <Typography variant="h6" sx={{ fontWeight: 600 }}>Final Valuation Reports</Typography>
              </Box>

              {project.valuations && project.valuations.filter(v => v.status === 'approved').length > 0 ? (
                <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                  {project.valuations.filter(v => v.status === 'approved').map(valuation => (
                    <Box key={valuation.id} sx={{ p: 2, bgcolor: (t) => t.palette.custom.cardInner, borderRadius: 2, border: '1px solid', borderColor: 'divider' }}>
                      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', mb: 1 }}>
                        <Box>
                          <Typography variant="subtitle2" sx={{ fontWeight: 700 }}>
                            {valuation.category_display} Report
                          </Typography>
                          <Typography variant="caption" color="text.secondary">
                            Approved by Senior Valuer
                          </Typography>
                        </Box>
                        {valuation.final_report_url && (
                          <Button
                            variant="outlined"
                            size="small"
                            startIcon={<Download />}
                            href={valuation.final_report_url}
                            target="_blank"
                          >
                            PDF
                          </Button>
                        )}
                      </Box>
                      {valuation.senior_valuer_comments && (
                        <Typography variant="body2" sx={{ mt: 1, fontStyle: 'italic', color: 'text.secondary', fontSize: '0.8125rem' }}>
                          "{valuation.senior_valuer_comments}"
                        </Typography>
                      )}
                    </Box>
                  ))}
                </Box>
              ) : (
                <Box sx={{ py: 4, textAlign: 'center' }}>
                  <Description sx={{ fontSize: 48, color: 'text.disabled', mb: 1 }} />
                  <Typography color="text.secondary">No approved reports available yet</Typography>
                </Box>
              )}
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
}
