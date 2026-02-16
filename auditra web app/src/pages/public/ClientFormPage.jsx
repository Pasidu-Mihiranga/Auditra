import { useState } from 'react';
import { Link } from 'react-router-dom';
import {
  Box, TextField, Button, Typography, Alert, Grid, Container, Paper, Stack, Divider,
} from '@mui/material';
import { Send, ArrowBack } from '@mui/icons-material';
import axiosClient from '../../api/axiosClient';

/* ------------------------------------------------------------------ */
/*  Section heading with blue underline                                */
/* ------------------------------------------------------------------ */
const SectionHeading = ({ children }) => (
  <Box sx={{ mb: 3 }}>
    <Typography
      variant="subtitle1"
      sx={{
        fontWeight: 700,
        color: '#1565C0',
        pb: 1,
        position: 'relative',
        display: 'inline-block',
        '&::after': {
          content: '""',
          position: 'absolute',
          bottom: 0,
          left: 0,
          width: 40,
          height: 3,
          bgcolor: '#1565C0',
          borderRadius: 1,
        },
      }}
    >
      {children}
    </Typography>
  </Box>
);

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

  const inputSx = { '& .MuiOutlinedInput-root': { borderRadius: '8px', '&:hover fieldset': { borderColor: '#1565C0' } } };

  return (
    <Box sx={{ minHeight: '100vh', bgcolor: '#F1F5F9' }}>
      {/* White top spacer */}
      <Box sx={{ bgcolor: '#fff', height: { xs: 44, md: 44 } }} />

      {/* Blue Hero Banner */}
      <Box
        sx={{
          bgcolor: '#1565C0',
          position: 'relative',
          pt: { xs: 5, md: 6 },
          pb: { xs: 8, md: 10 },
        }}
      >
        <Container maxWidth="lg">
          <Button
            component={Link}
            to="/"
            startIcon={<ArrowBack />}
            sx={{
              color: 'rgba(255,255,255,0.8)',
              textTransform: 'none',
              fontWeight: 500,
              fontSize: '0.85rem',
              mb: 2,
              px: 0,
              '&:hover': { color: '#fff', bgcolor: 'transparent' },
            }}
          >
            Back to Home
          </Button>
          <Typography
            variant="h3"
            sx={{
              fontWeight: 700,
              color: '#fff',
              fontSize: { xs: '1.8rem', md: '2.4rem' },
              mb: 1.5,
            }}
          >
            Client Registration
          </Typography>
          <Typography
            variant="body1"
            sx={{
              color: 'rgba(255,255,255,0.75)',
              fontSize: { xs: '0.9rem', md: '1rem' },
              maxWidth: 500,
              lineHeight: 1.7,
            }}
          >
            Submit your details and project information. Our team will
            reach out within 24 hours.
          </Typography>
        </Container>

        {/* Diagonal bottom edge */}
        <Box
          sx={{
            position: 'absolute',
            bottom: -1,
            left: 0,
            width: '100%',
            lineHeight: 0,
          }}
        >
          <svg
            viewBox="0 0 1440 60"
            preserveAspectRatio="none"
            style={{ display: 'block', width: '100%', height: '40px' }}
          >
            <polygon points="0,60 1440,0 1440,60" fill="#F1F5F9" />
          </svg>
        </Box>
      </Box>

      {/* Form Section */}
      <Container maxWidth="md" sx={{ py: { xs: 4, md: 6 }, mt: { xs: -2, md: -3 } }}>
        <Paper
          elevation={0}
          sx={{
            borderRadius: '16px',
            border: '1px solid #E2E8F0',
            overflow: 'hidden',
          }}
        >
          {error && <Alert severity="error" sx={{ borderRadius: 0, whiteSpace: 'pre-line' }}>{error}</Alert>}
          {success && <Alert severity="success" sx={{ borderRadius: 0 }}>{success}</Alert>}

          <form onSubmit={handleSubmit}>
            {/* Section 1: Personal Information */}
            <Box sx={{ p: { xs: 3, sm: 5 } }}>
              <SectionHeading>Personal Information</SectionHeading>
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

            {/* Section 2: Project Information */}
            <Box sx={{ p: { xs: 3, sm: 5 } }}>
              <SectionHeading>Project Information</SectionHeading>
              <Grid container spacing={2.5}>
                <Grid item xs={12}><TextField fullWidth label="Project Title" name="project_title" value={form.project_title} onChange={handleChange} required sx={inputSx} /></Grid>
                <Grid item xs={12}><TextField fullWidth label="Project Description" name="project_description" value={form.project_description} onChange={handleChange} required multiline rows={4} sx={inputSx} /></Grid>
              </Grid>
            </Box>

            <Divider />

            {/* Section 3: Agent Information */}
            <Box sx={{ p: { xs: 3, sm: 5 } }}>
              <SectionHeading>Agent Information</SectionHeading>
              <Grid container spacing={2.5}>
                <Grid item xs={12}><TextField fullWidth label="Agent Name" name="agent_name" value={form.agent_name} onChange={handleChange} required sx={inputSx} /></Grid>
                <Grid item xs={12} sm={6}><TextField fullWidth label="Agent Phone" name="agent_phone" value={form.agent_phone} onChange={handleChange} required sx={inputSx} /></Grid>
                <Grid item xs={12} sm={6}><TextField fullWidth label="Agent Email" name="agent_email" type="email" value={form.agent_email} onChange={handleChange} required sx={inputSx} /></Grid>
              </Grid>

              <Button
                type="submit" fullWidth variant="contained" size="large" disabled={loading}
                endIcon={<Send />}
                sx={{
                  mt: 4, py: 1.5, borderRadius: '8px', bgcolor: '#1565C0',
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
