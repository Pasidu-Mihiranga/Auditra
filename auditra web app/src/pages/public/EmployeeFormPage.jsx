import { useState, useRef } from 'react';
import { Link } from 'react-router-dom';
import {
  Box, TextField, Button, Typography, Alert, Grid, Container, Paper, Stack, Divider,
} from '@mui/material';
import { Upload, Send, ArrowBack, Person, AttachFile } from '@mui/icons-material';
import authService from '../../services/authService';
import logo from '../../assets/logo.png';

export default function EmployeeFormPage() {
  const [form, setForm] = useState({
    first_name: '', last_name: '', address: '', phone: '', birthday: '', nic: '', email: '',
  });
  const [cvFile, setCvFile] = useState(null);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [loading, setLoading] = useState(false);
  const fileRef = useRef();

  const handleChange = (e) => setForm({ ...form, [e.target.name]: e.target.value });

  const handleFileChange = (e) => {
    const file = e.target.files[0];
    if (file) {
      const allowed = ['application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'];
      if (!allowed.includes(file.type)) {
        setError('Only PDF, DOC, DOCX files are allowed');
        setCvFile(null);
        return;
      }
      setCvFile(file);
      setError('');
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setSuccess('');
    setLoading(true);
    try {
      const data = { ...form };
      if (cvFile) data.cv = cvFile;
      await authService.registerEmployee(data);
      setSuccess('Application submitted successfully! We will review and contact you.');
      setForm({ first_name: '', last_name: '', address: '', phone: '', birthday: '', nic: '', email: '' });
      setCvFile(null);
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

  const inputSx = { '& .MuiOutlinedInput-root': { borderRadius: 2, '&:hover fieldset': { borderColor: '#16A34A' } } };

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
            Employee Registration
          </Typography>
          <Typography variant="body1" sx={{ color: '#64748B' }}>
            Submit your application to join the Auditra team
          </Typography>
        </Box>

        <Paper elevation={0} sx={{ borderRadius: 3, border: '1px solid #E2E8F0', overflow: 'hidden' }}>
          {error && <Alert severity="error" sx={{ borderRadius: 0, whiteSpace: 'pre-line' }}>{error}</Alert>}
          {success && <Alert severity="success" sx={{ borderRadius: 0 }}>{success}</Alert>}

          <form onSubmit={handleSubmit}>
            {/* Section 1: Personal */}
            <Box sx={{ p: { xs: 3, sm: 5 } }}>
              <Stack direction="row" spacing={1.5} alignItems="center" sx={{ mb: 3 }}>
                <Box sx={{ width: 40, height: 40, borderRadius: 2, bgcolor: '#F0FDF4', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Person sx={{ color: '#16A34A' }} />
                </Box>
                <Box>
                  <Typography variant="subtitle1" sx={{ fontWeight: 700, color: '#0F172A' }}>Personal Information</Typography>
                  <Typography variant="caption" sx={{ color: '#64748B' }}>Your basic details</Typography>
                </Box>
              </Stack>
              <Grid container spacing={2.5}>
                <Grid item xs={12} sm={6}><TextField fullWidth label="First Name" name="first_name" value={form.first_name} onChange={handleChange} required sx={inputSx} /></Grid>
                <Grid item xs={12} sm={6}><TextField fullWidth label="Last Name" name="last_name" value={form.last_name} onChange={handleChange} required sx={inputSx} /></Grid>
                <Grid item xs={12}><TextField fullWidth label="Address" name="address" value={form.address} onChange={handleChange} sx={inputSx} /></Grid>
                <Grid item xs={12} sm={6}><TextField fullWidth label="Phone" name="phone" value={form.phone} onChange={handleChange} sx={inputSx} /></Grid>
                <Grid item xs={12} sm={6}>
                  <TextField fullWidth label="Birthday" name="birthday" type="date" value={form.birthday} onChange={handleChange} required
                    InputLabelProps={{ shrink: true }} sx={inputSx} />
                </Grid>
                <Grid item xs={12} sm={6}><TextField fullWidth label="NIC" name="nic" value={form.nic} onChange={handleChange} sx={inputSx} /></Grid>
                <Grid item xs={12} sm={6}><TextField fullWidth label="Email" name="email" type="email" value={form.email} onChange={handleChange} sx={inputSx} /></Grid>
              </Grid>
            </Box>

            <Divider />

            {/* Section 2: Documents */}
            <Box sx={{ p: { xs: 3, sm: 5 } }}>
              <Stack direction="row" spacing={1.5} alignItems="center" sx={{ mb: 3 }}>
                <Box sx={{ width: 40, height: 40, borderRadius: 2, bgcolor: '#F0FDF4', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <AttachFile sx={{ color: '#16A34A' }} />
                </Box>
                <Box>
                  <Typography variant="subtitle1" sx={{ fontWeight: 700, color: '#0F172A' }}>Documents</Typography>
                  <Typography variant="caption" sx={{ color: '#64748B' }}>Upload your CV or resume</Typography>
                </Box>
              </Stack>

              <input type="file" ref={fileRef} accept=".pdf,.doc,.docx" onChange={handleFileChange} style={{ display: 'none' }} />
              <Button
                variant="outlined"
                startIcon={<Upload />}
                onClick={() => fileRef.current.click()}
                fullWidth
                sx={{
                  py: 2,
                  justifyContent: 'flex-start',
                  borderRadius: 2,
                  borderColor: '#E2E8F0',
                  color: cvFile ? '#16A34A' : '#64748B',
                  borderStyle: 'dashed',
                  bgcolor: '#FAFAFA',
                  '&:hover': { borderColor: '#16A34A', bgcolor: '#F0FDF4' },
                }}
              >
                {cvFile ? cvFile.name : 'Upload CV (PDF, DOC, DOCX)'}
              </Button>

              <Button
                type="submit" fullWidth variant="contained" size="large" disabled={loading}
                endIcon={<Send />}
                sx={{
                  mt: 4, py: 1.5, borderRadius: 2,
                  background: 'linear-gradient(135deg, #16A34A 0%, #15803D 100%)',
                  fontWeight: 600, textTransform: 'none', fontSize: '1rem',
                  '&:hover': { background: 'linear-gradient(135deg, #15803D 0%, #166534 100%)' },
                }}
              >
                {loading ? 'Submitting...' : 'Submit Application'}
              </Button>
            </Box>
          </form>
        </Paper>
      </Container>
    </Box>
  );
}
