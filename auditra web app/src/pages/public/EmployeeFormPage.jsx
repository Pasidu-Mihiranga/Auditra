import { useState, useRef } from 'react';
import { Link } from 'react-router-dom';
import {
  Box, Card, CardContent, TextField, Button, Typography, Alert, Grid, AppBar, Toolbar, Container,
} from '@mui/material';
import { Upload } from '@mui/icons-material';
import authService from '../../services/authService';

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
          <Box sx={{ background: 'linear-gradient(135deg, #16A34A 0%, #15803D 100%)', p: 3, color: '#FFF' }}>
            <Typography variant="h5" sx={{ fontWeight: 700 }}>Employee Registration</Typography>
            <Typography variant="body2" sx={{ opacity: 0.8 }}>Submit your details to apply</Typography>
          </Box>
          <CardContent sx={{ p: 4 }}>
            {error && <Alert severity="error" sx={{ mb: 3, whiteSpace: 'pre-line' }}>{error}</Alert>}
            {success && <Alert severity="success" sx={{ mb: 3 }}>{success}</Alert>}
            <form onSubmit={handleSubmit}>
              <Grid container spacing={2}>
                <Grid item xs={6}><TextField fullWidth label="First Name" name="first_name" value={form.first_name} onChange={handleChange} required /></Grid>
                <Grid item xs={6}><TextField fullWidth label="Last Name" name="last_name" value={form.last_name} onChange={handleChange} required /></Grid>
                <Grid item xs={12}><TextField fullWidth label="Address" name="address" value={form.address} onChange={handleChange} /></Grid>
                <Grid item xs={6}><TextField fullWidth label="Phone" name="phone" value={form.phone} onChange={handleChange} /></Grid>
                <Grid item xs={6}><TextField fullWidth label="Birthday" name="birthday" type="date" value={form.birthday} onChange={handleChange} required InputLabelProps={{ shrink: true }} /></Grid>
                <Grid item xs={6}><TextField fullWidth label="NIC" name="nic" value={form.nic} onChange={handleChange} /></Grid>
                <Grid item xs={6}><TextField fullWidth label="Email" name="email" type="email" value={form.email} onChange={handleChange} /></Grid>
                <Grid item xs={12}>
                  <input type="file" ref={fileRef} accept=".pdf,.doc,.docx" onChange={handleFileChange} style={{ display: 'none' }} />
                  <Button variant="outlined" startIcon={<Upload />} onClick={() => fileRef.current.click()} fullWidth
                    sx={{ py: 1.5, justifyContent: 'flex-start' }}>
                    {cvFile ? cvFile.name : 'Upload CV (PDF, DOC, DOCX)'}
                  </Button>
                </Grid>
              </Grid>
              <Button type="submit" fullWidth variant="contained" size="large" disabled={loading}
                sx={{ mt: 4, py: 1.5, background: 'linear-gradient(135deg, #16A34A 0%, #15803D 100%)', color: '#FFF' }}>
                {loading ? 'Submitting...' : 'Submit Application'}
              </Button>
            </form>
          </CardContent>
        </Card>
      </Container>
    </Box>
  );
}
