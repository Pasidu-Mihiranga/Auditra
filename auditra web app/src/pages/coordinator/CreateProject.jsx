import { useState, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Box, Typography, Card, CardContent, TextField, Button, Grid, Alert, MenuItem,
  CircularProgress, InputAdornment,
} from '@mui/material';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import ErrorIcon from '@mui/icons-material/Error';
import InfoIcon from '@mui/icons-material/Info';
import projectService from '../../services/projectService';

export default function CreateProject() {
  const navigate = useNavigate();
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [form, setForm] = useState({
    title: '', description: '', priority: 'medium', start_date: '', end_date: '',
    client_name: '', client_email: '', client_phone: '', client_address: '', client_company: '',
    agent_name: '', agent_email: '', agent_phone: '', agent_address: '', agent_license_number: '',
  });

  // Email check states
  const [clientEmailStatus, setClientEmailStatus] = useState(null); // null | 'checking' | 'found' | 'not_found' | 'mismatch' | 'error'
  const [clientEmailMessage, setClientEmailMessage] = useState('');
  const [agentEmailStatus, setAgentEmailStatus] = useState(null);
  const [agentEmailMessage, setAgentEmailMessage] = useState('');

  const handleChange = (e) => setForm({ ...form, [e.target.name]: e.target.value });

  const checkEmail = useCallback(async (email, roleType, setStatus, setMessage) => {
    if (!email || !email.includes('@')) {
      setStatus(null);
      setMessage('');
      return;
    }

    setStatus('checking');
    setMessage('');
    try {
      const res = await projectService.checkEmail(email, roleType);
      const data = res.data;
      if (data.exists && !data.role_mismatch) {
        setStatus('found');
        setMessage(`Account found: ${data.user.full_name} (${data.user.email})`);
      } else if (data.exists && data.role_mismatch) {
        setStatus('mismatch');
        setMessage(data.message);
      } else {
        setStatus('not_found');
        setMessage('No account found — will be created on submit');
      }
    } catch {
      setStatus('error');
      setMessage('Failed to check email');
    }
  }, []);

  const handleClientEmailBlur = () => {
    checkEmail(form.client_email, 'client', setClientEmailStatus, setClientEmailMessage);
  };

  const handleAgentEmailBlur = () => {
    if (form.agent_email) {
      checkEmail(form.agent_email, 'agent', setAgentEmailStatus, setAgentEmailMessage);
    }
  };

  const getEmailAdornment = (status) => {
    if (!status) return null;
    if (status === 'checking') return <CircularProgress size={20} />;
    if (status === 'found') return <CheckCircleIcon sx={{ color: 'success.main' }} />;
    if (status === 'not_found') return <InfoIcon sx={{ color: 'info.main' }} />;
    if (status === 'mismatch') return <ErrorIcon sx={{ color: 'warning.main' }} />;
    if (status === 'error') return <ErrorIcon sx={{ color: 'error.main' }} />;
    return null;
  };

  const getEmailHelperColor = (status) => {
    if (status === 'found') return '#16A34A';
    if (status === 'not_found') return '#2563EB';
    if (status === 'mismatch') return '#D97706';
    if (status === 'error') return '#DC2626';
    return undefined;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    // Package data: flat project fields + client_info/agent_info as JSON objects
    const payload = {
      title: form.title,
      description: form.description,
      priority: form.priority,
      start_date: form.start_date || null,
      end_date: form.end_date || null,
    };

    // Build client_info if email is provided
    if (form.client_email) {
      payload.client_info = {
        name: form.client_name,
        email: form.client_email,
        phone: form.client_phone,
        address: form.client_address,
        company: form.client_company,
      };
    }

    // Build agent_info if email is provided
    if (form.agent_email) {
      payload.agent_info = {
        name: form.agent_name,
        email: form.agent_email,
        phone: form.agent_phone,
        address: form.agent_address,
        license_number: form.agent_license_number,
      };
    }

    try {
      await projectService.createProject(payload);
      navigate('/dashboard/projects');
    } catch (err) {
      const data = err.response?.data;
      if (data && typeof data === 'object') {
        const msgs = Object.entries(data).map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(', ') : v}`);
        setError(msgs.join('\n'));
      } else {
        setError('Failed to create project');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <Box>
      <Typography variant="h5" sx={{ fontWeight: 700, mb: 3 }}>Create New Project</Typography>
      {error && <Alert severity="error" sx={{ mb: 2, whiteSpace: 'pre-line' }}>{error}</Alert>}
      <form onSubmit={handleSubmit}>
        <Card sx={{ mb: 3 }}>
          <CardContent sx={{ p: 3 }}>
            <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>Project Details</Typography>
            <Grid container spacing={2}>
              <Grid item xs={12}><TextField fullWidth label="Project Title" name="title" value={form.title} onChange={handleChange} required /></Grid>
              <Grid item xs={12}><TextField fullWidth label="Description" name="description" value={form.description} onChange={handleChange} multiline rows={3} required /></Grid>
              <Grid item xs={12} sm={4}>
                <TextField select fullWidth label="Priority" name="priority" value={form.priority} onChange={handleChange}>
                  <MenuItem value="high">High</MenuItem>
                  <MenuItem value="medium">Medium</MenuItem>
                  <MenuItem value="low">Low</MenuItem>
                </TextField>
              </Grid>
              <Grid item xs={12} sm={4}><TextField fullWidth label="Start Date" name="start_date" type="date" value={form.start_date} onChange={handleChange} InputLabelProps={{ shrink: true }} /></Grid>
              <Grid item xs={12} sm={4}><TextField fullWidth label="End Date" name="end_date" type="date" value={form.end_date} onChange={handleChange} InputLabelProps={{ shrink: true }} /></Grid>
            </Grid>
          </CardContent>
        </Card>
        <Card sx={{ mb: 3 }}>
          <CardContent sx={{ p: 3 }}>
            <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>Client Information</Typography>
            <Grid container spacing={2}>
              <Grid item xs={12} sm={6}><TextField fullWidth label="Client Name" name="client_name" value={form.client_name} onChange={handleChange} /></Grid>
              <Grid item xs={12} sm={6}>
                <TextField
                  fullWidth
                  label="Client Email"
                  name="client_email"
                  type="email"
                  value={form.client_email}
                  onChange={(e) => {
                    handleChange(e);
                    if (clientEmailStatus) { setClientEmailStatus(null); setClientEmailMessage(''); }
                  }}
                  onBlur={handleClientEmailBlur}
                  helperText={clientEmailMessage}
                  FormHelperTextProps={{ sx: { color: getEmailHelperColor(clientEmailStatus) } }}
                  InputProps={{
                    endAdornment: clientEmailStatus ? (
                      <InputAdornment position="end">{getEmailAdornment(clientEmailStatus)}</InputAdornment>
                    ) : null,
                  }}
                />
              </Grid>
              <Grid item xs={12} sm={6}><TextField fullWidth label="Client Phone" name="client_phone" value={form.client_phone} onChange={handleChange} /></Grid>
              <Grid item xs={12} sm={6}><TextField fullWidth label="Company" name="client_company" value={form.client_company} onChange={handleChange} /></Grid>
              <Grid item xs={12}><TextField fullWidth label="Client Address" name="client_address" value={form.client_address} onChange={handleChange} /></Grid>
            </Grid>
            {clientEmailStatus === 'not_found' && form.client_email && (
              <Alert severity="info" sx={{ mt: 2 }}>
                A new client account will be created when you submit this project. Login credentials will be emailed to {form.client_email}.
              </Alert>
            )}
            {clientEmailStatus === 'mismatch' && (
              <Alert severity="warning" sx={{ mt: 2 }}>
                {clientEmailMessage}. This email cannot be used for a client role.
              </Alert>
            )}
          </CardContent>
        </Card>
        <Card sx={{ mb: 3 }}>
          <CardContent sx={{ p: 3 }}>
            <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>Agent Information (Optional)</Typography>
            <Grid container spacing={2}>
              <Grid item xs={12} sm={6}><TextField fullWidth label="Agent Name" name="agent_name" value={form.agent_name} onChange={handleChange} /></Grid>
              <Grid item xs={12} sm={6}>
                <TextField
                  fullWidth
                  label="Agent Email"
                  name="agent_email"
                  type="email"
                  value={form.agent_email}
                  onChange={(e) => {
                    handleChange(e);
                    if (agentEmailStatus) { setAgentEmailStatus(null); setAgentEmailMessage(''); }
                  }}
                  onBlur={handleAgentEmailBlur}
                  helperText={agentEmailMessage}
                  FormHelperTextProps={{ sx: { color: getEmailHelperColor(agentEmailStatus) } }}
                  InputProps={{
                    endAdornment: agentEmailStatus ? (
                      <InputAdornment position="end">{getEmailAdornment(agentEmailStatus)}</InputAdornment>
                    ) : null,
                  }}
                />
              </Grid>
              <Grid item xs={12} sm={4}><TextField fullWidth label="Agent Phone" name="agent_phone" value={form.agent_phone} onChange={handleChange} /></Grid>
              <Grid item xs={12} sm={4}><TextField fullWidth label="License Number" name="agent_license_number" value={form.agent_license_number} onChange={handleChange} /></Grid>
              <Grid item xs={12} sm={4}><TextField fullWidth label="Agent Address" name="agent_address" value={form.agent_address} onChange={handleChange} /></Grid>
            </Grid>
            {agentEmailStatus === 'not_found' && form.agent_email && (
              <Alert severity="info" sx={{ mt: 2 }}>
                A new agent account will be created when you submit this project. Login credentials will be emailed to {form.agent_email}.
              </Alert>
            )}
            {agentEmailStatus === 'mismatch' && (
              <Alert severity="warning" sx={{ mt: 2 }}>
                {agentEmailMessage}. This email cannot be used for an agent role.
              </Alert>
            )}
          </CardContent>
        </Card>
        <Box sx={{ display: 'flex', gap: 2 }}>
          <Button variant="outlined" onClick={() => navigate('/dashboard/projects')}>Cancel</Button>
          <Button type="submit" variant="contained" disabled={loading}>{loading ? 'Creating...' : 'Create Project'}</Button>
        </Box>
      </form>
    </Box>
  );
}
