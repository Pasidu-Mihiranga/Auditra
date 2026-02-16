import { useState, useEffect, useCallback } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import {
  Box, TextField, Button, Typography, Alert, InputAdornment, IconButton,
  Container, Paper, Grid, Stack, Divider,
} from '@mui/material';
import { Visibility, VisibilityOff, Login as LoginIcon, ArrowBack } from '@mui/icons-material';
import { useAuth } from '../../contexts/AuthContext';
import logo from '../../assets/logo.png';
import hero1 from '../../assets/hero1.png';
import hero2 from '../../assets/hero2.png';
import hero3 from '../../assets/hero3.png';

const heroImages = [hero1, hero2, hero3];

export default function LoginPage() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const { login } = useAuth();
  const navigate = useNavigate();

  // Hero slideshow
  const [heroIndex, setHeroIndex] = useState(0);
  useEffect(() => {
    const timer = setInterval(() => {
      setHeroIndex((prev) => (prev + 1) % heroImages.length);
    }, 5000);
    return () => clearInterval(timer);
  }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const result = await login(username, password);
      if (result.passwordChanged === false) {
        navigate('/dashboard/force-change-password');
      } else {
        navigate('/dashboard');
      }
    } catch (err) {
      setError(err.response?.data?.detail || err.response?.data?.error || 'Login failed. Please check your credentials.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Box sx={{ minHeight: '100vh', display: 'flex' }}>
      <Grid container sx={{ minHeight: '100vh' }}>

        {/* ── Left — Photo Panel ── */}
        <Grid
          item xs={12} md={6}
          sx={{
            position: 'relative',
            overflow: 'hidden',
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'flex-end',
            minHeight: { xs: 300, md: 'auto' },
          }}
        >
          {/* Background Photo Slideshow */}
          {heroImages.map((img, i) => (
            <Box
              key={i}
              sx={{
                position: 'absolute',
                inset: 0,
                backgroundImage: `url(${img})`,
                backgroundSize: 'cover',
                backgroundPosition: 'center',
                opacity: i === heroIndex ? 1 : 0,
                transition: 'opacity 0.8s ease-in-out',
              }}
            />
          ))}
          {/* Dark overlay */}
          <Box
            sx={{
              position: 'absolute',
              inset: 0,
              background: 'linear-gradient(180deg, rgba(13,71,161,0.65) 0%, rgba(21,101,192,0.80) 50%, rgba(13,71,161,0.90) 100%)',
            }}
          />

          {/* Content on top of overlay */}
          <Box sx={{ position: 'relative', zIndex: 2, p: { xs: 3, md: 5 }, mt: 'auto' }}>
            {/* Logo */}
            <Box
              component="img"
              src={logo}
              alt="Auditra"
              sx={{ height: { xs: 40, md: 48 }, mb: 3, filter: 'brightness(0) invert(1)' }}
            />

            {/* Heading */}
            <Typography
              variant="h4"
              sx={{
                color: '#fff',
                fontWeight: 700,
                fontSize: { xs: '1.5rem', md: '2rem' },
                lineHeight: 1.3,
                mb: 1.5,
              }}
            >
              Your Trusted Partner<br />in Auditing
            </Typography>

            {/* Description */}
            <Typography
              variant="body2"
              sx={{
                color: 'rgba(255,255,255,0.8)',
                fontSize: { xs: '0.85rem', md: '0.9rem' },
                lineHeight: 1.6,
                maxWidth: 360,
                mb: 4,
              }}
            >
              Precision auditing, compliance advisory, and financial
              services across Sri Lanka.
            </Typography>

            {/* Stats */}
            <Stack direction="row" spacing={4} sx={{ mb: { xs: 2, md: 3 } }}>
              {[
                { value: '15+', label: 'Years' },
                { value: '500+', label: 'Projects' },
                { value: '200+', label: 'Clients' },
              ].map((stat) => (
                <Box key={stat.label}>
                  <Typography
                    variant="h6"
                    sx={{ color: '#fff', fontWeight: 700, fontSize: '1.2rem', lineHeight: 1 }}
                  >
                    {stat.value}
                  </Typography>
                  <Typography
                    variant="caption"
                    sx={{ color: 'rgba(255,255,255,0.6)', fontSize: '0.7rem', textTransform: 'uppercase', letterSpacing: 0.5 }}
                  >
                    {stat.label}
                  </Typography>
                </Box>
              ))}
            </Stack>
          </Box>
        </Grid>

        {/* ── Right — Login Form ── */}
        <Grid
          item xs={12} md={6}
          sx={{
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'center',
            alignItems: 'center',
            bgcolor: '#fff',
            p: { xs: 3, md: 6 },
            position: 'relative',
          }}
        >
          <Container maxWidth="sm" sx={{ width: '100%', maxWidth: 440 }}>
            {/* Header */}
            <Typography
              variant="h5"
              sx={{ fontWeight: 700, color: '#0F172A', mb: 0.5, fontSize: { xs: '1.5rem', md: '1.75rem' } }}
            >
              Welcome back
            </Typography>
            <Typography variant="body2" sx={{ color: '#64748B', mb: 4, fontSize: '0.9rem' }}>
              Sign in to your Auditra dashboard
            </Typography>

            {error && <Alert severity="error" sx={{ mb: 3, borderRadius: 2 }}>{error}</Alert>}

            <form onSubmit={handleSubmit}>
              <Stack spacing={2.5}>
                {/* Username */}
                <Box>
                  <Typography variant="body2" sx={{ fontWeight: 600, color: '#0F172A', mb: 0.8, fontSize: '0.85rem' }}>
                    Username
                  </Typography>
                  <TextField
                    fullWidth
                    placeholder="Enter your username"
                    value={username}
                    onChange={(e) => setUsername(e.target.value)}
                    required
                    autoFocus
                    variant="outlined"
                    size="medium"
                    sx={{
                      '& .MuiOutlinedInput-root': {
                        borderRadius: 1.5,
                        bgcolor: '#F8FAFC',
                        '& fieldset': { borderColor: '#E2E8F0' },
                        '&:hover fieldset': { borderColor: '#1565C0' },
                        '&.Mui-focused fieldset': { borderColor: '#1565C0' },
                      },
                    }}
                  />
                </Box>

                {/* Password */}
                <Box>
                  <Typography variant="body2" sx={{ fontWeight: 600, color: '#0F172A', mb: 0.8, fontSize: '0.85rem' }}>
                    Password
                  </Typography>
                  <TextField
                    fullWidth
                    placeholder="Enter your password"
                    type={showPassword ? 'text' : 'password'}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    required
                    variant="outlined"
                    size="medium"
                    InputProps={{
                      endAdornment: (
                        <InputAdornment position="end">
                          <IconButton onClick={() => setShowPassword(!showPassword)} edge="end" size="small">
                            {showPassword ? <VisibilityOff fontSize="small" /> : <Visibility fontSize="small" />}
                          </IconButton>
                        </InputAdornment>
                      ),
                    }}
                    sx={{
                      '& .MuiOutlinedInput-root': {
                        borderRadius: 1.5,
                        bgcolor: '#F8FAFC',
                        '& fieldset': { borderColor: '#E2E8F0' },
                        '&:hover fieldset': { borderColor: '#1565C0' },
                        '&.Mui-focused fieldset': { borderColor: '#1565C0' },
                      },
                    }}
                  />
                </Box>

                {/* Sign In Button */}
                <Button
                  type="submit"
                  fullWidth
                  variant="contained"
                  size="large"
                  disabled={loading}
                  startIcon={<LoginIcon />}
                  sx={{
                    bgcolor: '#1565C0',
                    py: 1.4,
                    borderRadius: 1.5,
                    fontWeight: 600,
                    textTransform: 'none',
                    fontSize: '0.95rem',
                    boxShadow: 'none',
                    '&:hover': { bgcolor: '#0D47A1', boxShadow: '0 4px 12px rgba(21,101,192,0.3)' },
                  }}
                >
                  {loading ? 'Signing in...' : 'Sign In'}
                </Button>
              </Stack>
            </form>

            {/* OR Divider */}
            <Box sx={{ display: 'flex', alignItems: 'center', my: 3 }}>
              <Divider sx={{ flex: 1 }} />
              <Typography variant="caption" sx={{ mx: 2, color: '#94A3B8', fontWeight: 500, fontSize: '0.75rem' }}>
                OR
              </Typography>
              <Divider sx={{ flex: 1 }} />
            </Box>

            {/* Back to Home */}
            <Button
              component={Link}
              to="/"
              fullWidth
              variant="outlined"
              startIcon={<ArrowBack />}
              sx={{
                borderColor: '#E2E8F0',
                color: '#64748B',
                textTransform: 'none',
                fontWeight: 500,
                py: 1.3,
                borderRadius: 1.5,
                fontSize: '0.9rem',
                '&:hover': { borderColor: '#1565C0', color: '#1565C0', bgcolor: '#F1F5F9' },
              }}
            >
              Back to Home
            </Button>
          </Container>

          {/* Copyright — bottom right */}
          <Typography
            variant="caption"
            sx={{
              position: 'absolute',
              bottom: 16,
              right: 24,
              color: '#94A3B8',
              fontSize: '0.7rem',
            }}
          >
            © 2025 Auditra (Pvt) Ltd. All rights reserved.
          </Typography>
        </Grid>
      </Grid>
    </Box>
  );
}
