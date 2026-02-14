import { Link } from 'react-router-dom';
import { Box, Typography, Button, Container, Grid, Card, CardContent, AppBar, Toolbar } from '@mui/material';
import {
  AccountBalance, Assessment, Gavel, Business, Security, Computer,
} from '@mui/icons-material';

const services = [
  { icon: AccountBalance, title: 'Financial Auditing', desc: 'Comprehensive financial statement audits and reviews' },
  { icon: Assessment, title: 'Tax Auditing', desc: 'Tax compliance verification and advisory services' },
  { icon: Business, title: 'Business Consulting', desc: 'Strategic business advisory and optimization' },
  { icon: Gavel, title: 'Compliance Services', desc: 'Regulatory compliance assessments and guidance' },
  { icon: Security, title: 'Project Auditing', desc: 'Detailed project auditing and valuation services' },
  { icon: Computer, title: 'IT Auditing', desc: 'Information systems and technology audits' },
];

export default function LandingPage() {
  return (
    <Box sx={{ minHeight: '100vh' }}>
      {/* Navbar */}
      <AppBar position="static" sx={{ bgcolor: '#0F172A' }}>
        <Toolbar sx={{ justifyContent: 'space-between' }}>
          <Typography variant="h5" sx={{ fontWeight: 700, color: '#60A5FA', letterSpacing: 2 }}>
            AUDITRA
          </Typography>
          <Box sx={{ display: 'flex', gap: 1 }}>
            <Button component={Link} to="/login" sx={{ color: '#FFF' }}>Login</Button>
            <Button component={Link} to="/register" variant="outlined" sx={{ color: '#60A5FA', borderColor: '#60A5FA' }}>
              Register
            </Button>
          </Box>
        </Toolbar>
      </AppBar>

      {/* Hero */}
      <Box sx={{
        background: 'linear-gradient(135deg, #0D47A1 0%, #1565C0 100%)',
        color: '#FFF',
        py: 12,
        textAlign: 'center',
      }}>
        <Container maxWidth="md">
          <Typography variant="h2" sx={{ fontWeight: 700, mb: 2 }}>
            Professional Auditing Services
          </Typography>
          <Typography variant="h6" sx={{ color: '#60A5FA', mb: 4, fontWeight: 400 }}>
            Delivering excellence in audit, assurance, and advisory services
          </Typography>
          <Box sx={{ display: 'flex', gap: 2, justifyContent: 'center', flexWrap: 'wrap' }}>
            <Button component={Link} to="/client-register" variant="contained" size="large"
              sx={{ bgcolor: '#D97706', '&:hover': { bgcolor: '#B45309' }, px: 4 }}>
              Client Registration
            </Button>
            <Button component={Link} to="/employee-register" variant="outlined" size="large"
              sx={{ color: '#FFF', borderColor: '#FFF', px: 4 }}>
              Employee Registration
            </Button>
          </Box>
        </Container>
      </Box>

      {/* Services */}
      <Container maxWidth="lg" sx={{ py: 8 }}>
        <Typography variant="h4" align="center" sx={{ fontWeight: 700, mb: 1 }}>Our Services</Typography>
        <Typography variant="body1" align="center" color="text.secondary" sx={{ mb: 6 }}>
          Comprehensive auditing and consulting solutions
        </Typography>
        <Grid container spacing={3}>
          {services.map((s) => (
            <Grid item xs={12} sm={6} md={4} key={s.title}>
              <Card sx={{ height: '100%', textAlign: 'center', '&:hover': { boxShadow: '0 8px 24px rgba(0,0,0,0.12)' } }}>
                <CardContent sx={{ p: 4 }}>
                  <s.icon sx={{ fontSize: 48, color: '#1565C0', mb: 2 }} />
                  <Typography variant="h6" sx={{ fontWeight: 600, mb: 1 }}>{s.title}</Typography>
                  <Typography variant="body2" color="text.secondary">{s.desc}</Typography>
                </CardContent>
              </Card>
            </Grid>
          ))}
        </Grid>
      </Container>

      {/* Footer */}
      <Box sx={{ bgcolor: '#0F172A', color: '#FFF', py: 4, textAlign: 'center' }}>
        <Typography variant="body2" sx={{ color: 'rgba(255,255,255,0.6)' }}>
          &copy; {new Date().getFullYear()} Auditra. All rights reserved.
        </Typography>
      </Box>
    </Box>
  );
}
