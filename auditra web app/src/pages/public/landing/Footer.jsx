import { Box, Container, Grid, Typography, Stack, IconButton, Divider, Link as MuiLink } from '@mui/material';
import { Phone, Email, LocationOn, Facebook, LinkedIn, Instagram, Twitter } from '@mui/icons-material';
import { Link } from 'react-router-dom';
import logo from '../../../assets/logo.png';

const quickLinks = ['Home', 'About Us', 'Services', 'Careers', 'Contact'];
const serviceLinks = ['Financial Auditing', 'Tax Advisory', 'Asset Valuation', 'Business Consulting', 'IT Auditing'];

export default function Footer() {
    return (
        <Box component="footer" sx={{ bgcolor: '#0F172A', color: '#fff', pt: 10, pb: 4 }}>
            <Container maxWidth="lg">
                <Grid container spacing={6}>
                    {/* Company Info */}
                    <Grid item xs={12} md={4}>
                        <Box component="img" src={logo} alt="Auditra" sx={{ height: 40, mb: 2, filter: 'brightness(2)' }} />
                        <Typography variant="body2" sx={{ color: 'rgba(255,255,255,0.6)', lineHeight: 1.8, mb: 3, maxWidth: 300 }}>
                            Professional auditing and financial advisory services. Trusted by
                            industry leaders for accuracy, integrity, and strategic value.
                        </Typography>
                        <Stack direction="row" spacing={1}>
                            {[Facebook, Twitter, LinkedIn, Instagram].map((Icon, i) => (
                                <IconButton
                                    key={i}
                                    size="small"
                                    sx={{
                                        color: 'rgba(255,255,255,0.5)',
                                        border: '1px solid rgba(255,255,255,0.15)',
                                        '&:hover': { color: '#60A5FA', borderColor: '#60A5FA', bgcolor: 'rgba(96,165,250,0.1)' },
                                        transition: 'all 0.3s',
                                    }}
                                >
                                    <Icon fontSize="small" />
                                </IconButton>
                            ))}
                        </Stack>
                    </Grid>

                    {/* Quick Links */}
                    <Grid item xs={6} sm={4} md={2}>
                        <Typography variant="subtitle2" sx={{ fontWeight: 700, color: '#fff', mb: 2.5, letterSpacing: 1, textTransform: 'uppercase', fontSize: '0.75rem' }}>
                            Quick Links
                        </Typography>
                        <Stack spacing={1.5}>
                            {quickLinks.map((link) => (
                                <MuiLink
                                    key={link}
                                    href="#"
                                    underline="none"
                                    sx={{
                                        color: 'rgba(255,255,255,0.55)',
                                        fontSize: '0.875rem',
                                        transition: 'all 0.2s',
                                        '&:hover': { color: '#60A5FA', pl: 0.5 },
                                    }}
                                >
                                    {link}
                                </MuiLink>
                            ))}
                        </Stack>
                    </Grid>

                    {/* Services Links */}
                    <Grid item xs={6} sm={4} md={3}>
                        <Typography variant="subtitle2" sx={{ fontWeight: 700, color: '#fff', mb: 2.5, letterSpacing: 1, textTransform: 'uppercase', fontSize: '0.75rem' }}>
                            Services
                        </Typography>
                        <Stack spacing={1.5}>
                            {serviceLinks.map((link) => (
                                <MuiLink
                                    key={link}
                                    href="#services"
                                    underline="none"
                                    sx={{
                                        color: 'rgba(255,255,255,0.55)',
                                        fontSize: '0.875rem',
                                        transition: 'all 0.2s',
                                        '&:hover': { color: '#60A5FA', pl: 0.5 },
                                    }}
                                >
                                    {link}
                                </MuiLink>
                            ))}
                        </Stack>
                    </Grid>

                    {/* Contact Info */}
                    <Grid item xs={12} sm={4} md={3}>
                        <Typography variant="subtitle2" sx={{ fontWeight: 700, color: '#fff', mb: 2.5, letterSpacing: 1, textTransform: 'uppercase', fontSize: '0.75rem' }}>
                            Contact Us
                        </Typography>
                        <Stack spacing={2}>
                            <Stack direction="row" spacing={1.5} alignItems="flex-start">
                                <LocationOn sx={{ color: '#60A5FA', fontSize: 20, mt: 0.3 }} />
                                <Typography variant="body2" sx={{ color: 'rgba(255,255,255,0.6)', lineHeight: 1.6 }}>
                                    123 Financial District,<br />Colombo 01, Sri Lanka
                                </Typography>
                            </Stack>
                            <Stack direction="row" spacing={1.5} alignItems="center">
                                <Phone sx={{ color: '#60A5FA', fontSize: 20 }} />
                                <Typography variant="body2" sx={{ color: 'rgba(255,255,255,0.6)' }}>
                                    +94 11 234 5678
                                </Typography>
                            </Stack>
                            <Stack direction="row" spacing={1.5} alignItems="center">
                                <Email sx={{ color: '#60A5FA', fontSize: 20 }} />
                                <Typography variant="body2" sx={{ color: 'rgba(255,255,255,0.6)' }}>
                                    info@auditra.lk
                                </Typography>
                            </Stack>
                        </Stack>
                    </Grid>
                </Grid>

                <Divider sx={{ borderColor: 'rgba(255,255,255,0.08)', my: 5 }} />

                <Stack
                    direction={{ xs: 'column', sm: 'row' }}
                    justifyContent="space-between"
                    alignItems="center"
                    spacing={1}
                >
                    <Typography variant="caption" sx={{ color: 'rgba(255,255,255,0.4)' }}>
                        &copy; {new Date().getFullYear()} Auditra. All rights reserved.
                    </Typography>
                    <Stack direction="row" spacing={3}>
                        <MuiLink href="#" underline="none" sx={{ color: 'rgba(255,255,255,0.4)', fontSize: '0.75rem', '&:hover': { color: '#60A5FA' } }}>
                            Privacy Policy
                        </MuiLink>
                        <MuiLink href="#" underline="none" sx={{ color: 'rgba(255,255,255,0.4)', fontSize: '0.75rem', '&:hover': { color: '#60A5FA' } }}>
                            Terms of Service
                        </MuiLink>
                    </Stack>
                </Stack>
            </Container>
        </Box>
    );
}
