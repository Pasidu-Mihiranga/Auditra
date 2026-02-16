import { useState } from 'react';
import { Link } from 'react-router-dom';
import {
  Box, Card, CardContent, TextField, Button, Typography, Alert, Grid, AppBar, Toolbar, Container,
} from '@mui/material';
import axiosClient from '../../api/axiosClient';

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
      setForm({ first_name: '', last_name: '', address: '', phone: '', nic: '', email: '',
        company_name: '', project_title: '', project_description: '', agent_name: '', agent_phone: '', agent_email: '' });
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

  return (
    <Box sx={{ minHeight: '100vh', bgcolor: '#F0F4F8' }}>
      <AppBar position="static" sx={{ bgcolor: '#0F172A' }}>
        <Toolbar>
          <Typography component={Link} to="/" variant="h5" sx={{ fontWeight: 700, color: '#60A5FA', textDecoration: 'none', letterSpacing: 2 }}>
            AUDITRA
          </Typography>
        </Toolbar>
      </AppBar>
      <Container maxWidth="md" sx={{ py: 4 }}>
        <Card>
          <Box sx={{ background: 'linear-gradient(135deg, #0D47A1 0%, #1565C0 100%)', p: 3, color: '#FFF' }}>
            <Typography variant="h5" sx={{ fontWeight: 700 }}>Client Registration</Typography>
            <Typography variant="body2" sx={{ opacity: 0.8 }}>Submit your details and project information</Typography>
          </Box>
          <CardContent sx={{ p: 4 }}>
            {error && <Alert severity="error" sx={{ mb: 3, whiteSpace: 'pre-line' }}>{error}</Alert>}
            {success && <Alert severity="success" sx={{ mb: 3 }}>{success}</Alert>}
            <form onSubmit={handleSubmit}>
              <Typography variant="h6" sx={{ mb: 2, fontWeight: 600 }}>Personal Information</Typography>
              <Grid container spacing={2}>
                <Grid item xs={6}><TextField fullWidth label="First Name" name="first_name" value={form.first_name} onChange={handleChange} /></Grid>
                <Grid item xs={6}><TextField fullWidth label="Last Name" name="last_name" value={form.last_name} onChange={handleChange} /></Grid>
                <Grid item xs={12}><TextField fullWidth label="Address" name="address" value={form.address} onChange={handleChange} /></Grid>
                <Grid item xs={6}><TextField fullWidth label="Phone" name="phone" value={form.phone} onChange={handleChange} /></Grid>
                <Grid item xs={6}><TextField fullWidth label="NIC" name="nic" value={form.nic} onChange={handleChange} /></Grid>
                <Grid item xs={12}><TextField fullWidth label="Email" name="email" type="email" value={form.email} onChange={handleChange} required /></Grid>
                <Grid item xs={12}><TextField fullWidth label="Company Name" name="company_name" value={form.company_name} onChange={handleChange} /></Grid>
              </Grid>

              <Typography variant="h6" sx={{ mt: 4, mb: 2, fontWeight: 600 }}>Project Information</Typography>
              <Grid container spacing={2}>
                <Grid item xs={12}><TextField fullWidth label="Project Title" name="project_title" value={form.project_title} onChange={handleChange} required /></Grid>
                <Grid item xs={12}><TextField fullWidth label="Project Description" name="project_description" value={form.project_description} onChange={handleChange} required multiline rows={3} /></Grid>
              </Grid>

              <Typography variant="h6" sx={{ mt: 4, mb: 2, fontWeight: 600 }}>Agent Information</Typography>
              <Grid container spacing={2}>
                <Grid item xs={12}><TextField fullWidth label="Agent Name" name="agent_name" value={form.agent_name} onChange={handleChange} required /></Grid>
                <Grid item xs={6}><TextField fullWidth label="Agent Phone" name="agent_phone" value={form.agent_phone} onChange={handleChange} required /></Grid>
                <Grid item xs={6}><TextField fullWidth label="Agent Email" name="agent_email" type="email" value={form.agent_email} onChange={handleChange} required /></Grid>
              </Grid>

              <Button type="submit" fullWidth variant="contained" size="large" disabled={loading}
                sx={{ mt: 4, py: 1.5, background: 'linear-gradient(135deg, #0D47A1 0%, #1565C0 100%)' }}>
                {loading ? 'Submitting...' : 'Submit Registration'}
              </Button>
            </form>
          </CardContent>
        </Card>
      </Container>
    </Box>
  );
}
