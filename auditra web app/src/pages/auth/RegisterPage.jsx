import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import {
  Box, Card, CardContent, TextField, Button, Typography, Alert, Grid,
} from '@mui/material';
import { PersonAdd } from '@mui/icons-material';
import axiosClient from '../../api/axiosClient';

export default function RegisterPage() {
  const [form, setForm] = useState({
    username: '', email: '', password: '', password2: '', first_name: '', last_name: '',
  });
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const handleChange = (e) => setForm({ ...form, [e.target.name]: e.target.value });

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setSuccess('');
    if (form.password !== form.password2) {
      setError('Passwords do not match');
      return;
    }
    setLoading(true);
    try {
      await axiosClient.post('/auth/register/', form);
      setSuccess('Registration successful! You can now login. An admin will assign your role.');
      setTimeout(() => navigate('/login'), 3000);
    } catch (err) {
      const data = err.response?.data;
      if (data && typeof data === 'object') {
        const messages = Object.entries(data).map(([key, val]) => `${key}: ${Array.isArray(val) ? val.join(', ') : val}`);
        setError(messages.join('\n'));
      } else {
        setError('Registration failed. Please try again.');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <Box sx={{
      minHeight: '100vh',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      background: 'linear-gradient(135deg, #0D47A1 0%, #1565C0 50%, #1976D2 100%)',
      p: 2,
    }}>
      <Card sx={{ maxWidth: 500, width: '100%' }}>
        <CardContent sx={{ p: 4 }}>
          <Box sx={{ textAlign: 'center', mb: 3 }}>
            <Typography variant="h4" sx={{ color: 'primary.main', fontWeight: 700, letterSpacing: 2 }}>
              AUDITRA
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
              Create your account
            </Typography>
          </Box>

          {error && <Alert severity="error" sx={{ mb: 2, whiteSpace: 'pre-line' }}>{error}</Alert>}
          {success && <Alert severity="success" sx={{ mb: 2 }}>{success}</Alert>}

          <form onSubmit={handleSubmit}>
            <Grid container spacing={2}>
              <Grid item xs={6}>
                <TextField fullWidth label="First Name" name="first_name" value={form.first_name} onChange={handleChange} />
              </Grid>
              <Grid item xs={6}>
                <TextField fullWidth label="Last Name" name="last_name" value={form.last_name} onChange={handleChange} />
              </Grid>
              <Grid item xs={12}>
                <TextField fullWidth label="Username" name="username" value={form.username} onChange={handleChange} required />
              </Grid>
              <Grid item xs={12}>
                <TextField fullWidth label="Email" name="email" type="email" value={form.email} onChange={handleChange} required />
              </Grid>
              <Grid item xs={12}>
                <TextField fullWidth label="Password" name="password" type="password" value={form.password} onChange={handleChange} required helperText="Minimum 8 characters" />
              </Grid>
              <Grid item xs={12}>
                <TextField fullWidth label="Confirm Password" name="password2" type="password" value={form.password2} onChange={handleChange} required />
              </Grid>
            </Grid>
            <Button
              type="submit"
              fullWidth
              variant="contained"
              size="large"
              disabled={loading}
              startIcon={<PersonAdd />}
              sx={{ mt: 3, py: 1.5 }}
            >
              {loading ? 'Creating account...' : 'Register'}
            </Button>
          </form>

          <Box sx={{ textAlign: 'center', mt: 3 }}>
            <Typography variant="body2" color="text.secondary">
              Already have an account?{' '}
              <Link to="/login" style={{ color: '#1565C0', fontWeight: 600 }}>Sign In</Link>
            </Typography>
          </Box>
        </CardContent>
      </Card>
    </Box>
  );
}
