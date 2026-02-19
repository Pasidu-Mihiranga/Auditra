import { useState } from 'react';
import { Link } from 'react-router-dom';
import {
  Box, TextField, Button, Typography, Alert, Grid, Container, Paper, Stack, Divider,
} from '@mui/material';
import { Send, ArrowBack, Person, Business, AssignmentInd } from '@mui/icons-material';
import axiosClient from '../../api/axiosClient';
import logo from '../../assets/logo.png';

export default function ClientFormPage() {
  const [form, setForm] = useState({
    first_name: '', last_name: '', address: '', phone: '', nic: '', email: '',
    company_name: '', project_title: '', project_description: '',
    agent_name: '', agent_phone: '', agent_email: '',
  });
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [loading, setLoading] = useState(false);

  const handleChange = (e) => setForm({ ...form, [e.target.name]: e.target.value });

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setSuccess('');
    setLoading(true);
    try {
      await axiosClient.post('/clients/register/', form);
      setSuccess('Registration submitted successfully! We will contact you soon.');
      setForm({
        first_name: '', last_name: '', address: '', phone: '', nic: '', email: '',
        company_name: '', project_title: '', project_description: '', agent_name: '', agent_phone: '', agent_email: ''
      });
    } catch (err) {
      const data = err.response?.data;
      if (data && typeof data === 'object') {
        const messages = Object.entries(data).map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(', ') : v}`);
        setError(messages.join('\n'));
      } else {
        setError('Submission failed. Please try again.');
      }
    } finally {
      setLoading(false);
    }
  };

  const inputSx = { '& .MuiOutlinedInput-root': { borderRadius: 2, '&:hover fieldset': { borderColor: '#1565C0' } } };

  return (
    <Box sx={{ minHeight: '100vh', bgcolor: '#F1F5F9' }}>
      {/* Top Navigation */}
      <Box sx={{ bgcolor: '#fff', borderBottom: '1px solid #E2E8F0', py: 1.5 }}>
        <Container maxWidth="lg">
          <Stack direction="row" justifyContent="space-between" alignItems="center">
            <Stack direction="row" alignItems="center" spacing={2}>
              <Box component="img" src={logo} alt="Auditra" sx={{ height: 36 }} />
            </Stack>
            <Stack direction="row" spacing={1}>
              <Button component={Link} to="/" startIcon={<ArrowBack />}
                sx={{ color: '#64748B', textTransform: 'none', fontWeight: 500 }}>
                Home
              </Button>
              <Button component={Link} to="/login"
                sx={{ color: '#1565C0', textTransform: 'none', fontWeight: 600 }}>
                Log In
              </Button>
            </Stack>
          </Stack>
        </Container>
      </Box>

      <Container maxWidth="md" sx={{ py: 6 }}>
        {/* Header */}
        <Box sx={{ textAlign: 'center', mb: 5 }}>
          <Typography variant="h4" sx={{ fontWeight: 700, color: '#0F172A', mb: 1 }}>
            Client Registration
          </Typography>
          <Typography variant="body1" sx={{ color: '#64748B' }}>
            Submit your details and project information to get started
          </Typography>
        </Box>

        <Paper elevation={0} sx={{ borderRadius: 3, border: '1px solid #E2E8F0', overflow: 'hidden' }}>
          {error && <Alert severity="error" sx={{ borderRadius: 0, whiteSpace: 'pre-line' }}>{error}</Alert>}
          {success && <Alert severity="success" sx={{ borderRadius: 0 }}>{success}</Alert>}

          <form onSubmit={handleSubmit}>
            {/* Section 1: Personal */}
            <Box sx={{ p: { xs: 3, sm: 5 } }}>
              <Stack direction="row" spacing={1.5} alignItems="center" sx={{ mb: 3 }}>
                <Box sx={{ width: 40, height: 40, borderRadius: 2, bgcolor: '#EFF6FF', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Person sx={{ color: '#1565C0' }} />
                </Box>
                <Box>
                  <Typography variant="subtitle1" sx={{ fontWeight: 700, color: '#0F172A' }}>Personal Information</Typography>
                  <Typography variant="caption" sx={{ color: '#64748B' }}>Your basic contact details</Typography>
                </Box>
              </Stack>
              <Grid container spacing={2.5}>
                <Grid item xs={12} sm={6}><TextField fullWidth label="First Name" name="first_name" value={form.first_name} onChange={handleChange} sx={inputSx} /></Grid>
                <Grid item xs={12} sm={6}><TextField fullWidth label="Last Name" name="last_name" value={form.last_name} onChange={handleChange} sx={inputSx} /></Grid>
                <Grid item xs={12}><TextField fullWidth label="Address" name="address" value={form.address} onChange={handleChange} sx={inputSx} /></Grid>
                <Grid item xs={12} sm={6}><TextField fullWidth label="Phone" name="phone" value={form.phone} onChange={handleChange} sx={inputSx} /></Grid>
                <Grid item xs={12} sm={6}><TextField fullWidth label="NIC" name="nic" value={form.nic} onChange={handleChange} sx={inputSx} /></Grid>
                <Grid item xs={12}><TextField fullWidth label="Email" name="email" type="email" value={form.email} onChange={handleChange} required sx={inputSx} /></Grid>
                <Grid item xs={12}><TextField fullWidth label="Company Name" name="company_name" value={form.company_name} onChange={handleChange} sx={inputSx} /></Grid>
              </Grid>
            </Box>

            <Divider />

            {/* Section 2: Project */}
            <Box sx={{ p: { xs: 3, sm: 5 } }}>
              <Stack direction="row" spacing={1.5} alignItems="center" sx={{ mb: 3 }}>
                <Box sx={{ width: 40, height: 40, borderRadius: 2, bgcolor: '#EFF6FF', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Business sx={{ color: '#1565C0' }} />
                </Box>
                <Box>
                  <Typography variant="subtitle1" sx={{ fontWeight: 700, color: '#0F172A' }}>Project Information</Typography>
                  <Typography variant="caption" sx={{ color: '#64748B' }}>Details about your project or engagement</Typography>
                </Box>
              </Stack>
              <Grid container spacing={2.5}>
                <Grid item xs={12}><TextField fullWidth label="Project Title" name="project_title" value={form.project_title} onChange={handleChange} required sx={inputSx} /></Grid>
                <Grid item xs={12}><TextField fullWidth label="Project Description" name="project_description" value={form.project_description} onChange={handleChange} required multiline rows={4} sx={inputSx} /></Grid>
              </Grid>
            </Box>

            <Divider />

            {/* Section 3: Agent */}
            <Box sx={{ p: { xs: 3, sm: 5 } }}>
              <Stack direction="row" spacing={1.5} alignItems="center" sx={{ mb: 3 }}>
                <Box sx={{ width: 40, height: 40, borderRadius: 2, bgcolor: '#EFF6FF', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <AssignmentInd sx={{ color: '#1565C0' }} />
                </Box>
                <Box>
                  <Typography variant="subtitle1" sx={{ fontWeight: 700, color: '#0F172A' }}>Agent Information</Typography>
                  <Typography variant="caption" sx={{ color: '#64748B' }}>Details of your referring agent (if applicable)</Typography>
                </Box>
              </Stack>
              <Grid container spacing={2.5}>
                <Grid item xs={12}><TextField fullWidth label="Agent Name" name="agent_name" value={form.agent_name} onChange={handleChange} required sx={inputSx} /></Grid>
                <Grid item xs={12} sm={6}><TextField fullWidth label="Agent Phone" name="agent_phone" value={form.agent_phone} onChange={handleChange} required sx={inputSx} /></Grid>
                <Grid item xs={12} sm={6}><TextField fullWidth label="Agent Email" name="agent_email" type="email" value={form.agent_email} onChange={handleChange} required sx={inputSx} /></Grid>
              </Grid>

              <Button
                type="submit" fullWidth variant="contained" size="large" disabled={loading}
                endIcon={<Send />}
                sx={{
                  mt: 4, py: 1.5, borderRadius: 2, bgcolor: '#1565C0',
                  fontWeight: 600, textTransform: 'none', fontSize: '1rem',
                  '&:hover': { bgcolor: '#0D47A1' },
                }}
              >
                {loading ? 'Submitting...' : 'Submit Registration'}
              </Button>
            </Box>
          </form>
        </Paper>
      </Container>
    </Box>
  );
}
