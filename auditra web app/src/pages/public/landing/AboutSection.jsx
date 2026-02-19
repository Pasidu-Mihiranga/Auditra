import { Box, Container, Grid, Typography, Stack } from '@mui/material';
import { CheckCircle } from '@mui/icons-material';
import { motion } from 'framer-motion';

const features = [
    'Certified Audit Professionals',
    'ISO Compliant Processes',
    'Regulatory Compliance Experts',
    'Tailored Advisory Solutions',
    'Transparent Reporting',
    'Industry Best Practices',
];

const MotionBox = motion.create(Box);

export default function AboutSection() {
    return (
        <Box
            id="about"
            sx={{ py: { xs: 10, md: 14 }, bgcolor: '#FFFFFF' }}
        >
            <Container maxWidth="lg">
                <Grid container spacing={8} alignItems="center">
                    {/* Left — Image / Illustration */}
                    <Grid item xs={12} md={6}>
                        <MotionBox
                            initial={{ opacity: 0, x: -40 }}
                            whileInView={{ opacity: 1, x: 0 }}
                            viewport={{ once: true, margin: '-100px' }}
                            transition={{ duration: 0.7 }}
                            sx={{ position: 'relative' }}
                        >
                            <Box
                                sx={{
                                    width: '100%',
                                    height: { xs: 320, md: 460 },
                                    borderRadius: 4,
                                    background: 'linear-gradient(135deg, #E3F2FD 0%, #BBDEFB 100%)',
                                    display: 'flex',
                                    alignItems: 'center',
                                    justifyContent: 'center',
                                    position: 'relative',
                                    overflow: 'hidden',
                                }}
                            >
                                {/* Decorative elements inside the image placeholder */}
                                <Box sx={{
                                    position: 'absolute', top: 20, right: 20,
                                    width: 80, height: 80, borderRadius: '50%',
                                    bgcolor: 'rgba(21,101,192,0.1)',
                                }} />
                                <Box sx={{
                                    position: 'absolute', bottom: 30, left: 30,
                                    width: 60, height: 60, borderRadius: 2,
                                    bgcolor: 'rgba(21,101,192,0.08)',
                                }} />
                                <Typography
                                    sx={{
                                        color: '#1565C0',
                                        fontWeight: 700,
                                        fontSize: { xs: '1.5rem', md: '2rem' },
                                        textAlign: 'center',
                                        opacity: 0.6,
                                        letterSpacing: 2,
                                    }}
                                >
                                    ABOUT<br />AUDITRA
                                </Typography>
                            </Box>

                            {/* Experience badge */}
                            <Box
                                sx={{
                                    position: 'absolute',
                                    bottom: -20,
                                    right: { xs: 10, md: -20 },
                                    bgcolor: '#1565C0',
                                    color: '#fff',
                                    px: 3,
                                    py: 2,
                                    borderRadius: 2,
                                    boxShadow: '0 8px 24px rgba(21,101,192,0.3)',
                                    textAlign: 'center',
                                }}
                            >
                                <Typography variant="h3" fontWeight="800">15+</Typography>
                                <Typography variant="caption" fontWeight="600" sx={{ letterSpacing: 1 }}>
                                    YEARS OF TRUST
                                </Typography>
                            </Box>
                        </MotionBox>
                    </Grid>

                    {/* Right — Text */}
                    <Grid item xs={12} md={6}>
                        <MotionBox
                            initial={{ opacity: 0, x: 40 }}
                            whileInView={{ opacity: 1, x: 0 }}
                            viewport={{ once: true, margin: '-100px' }}
                            transition={{ duration: 0.7, delay: 0.15 }}
                        >
                            <Typography
                                variant="overline"
                                sx={{ color: '#1565C0', fontWeight: 700, letterSpacing: 2.5, fontSize: '0.8rem' }}
                            >
                                ABOUT US
                            </Typography>

                            <Typography
                                variant="h3"
                                sx={{
                                    fontWeight: 700,
                                    color: '#0F172A',
                                    mt: 1,
                                    mb: 3,
                                    fontSize: { xs: '1.8rem', md: '2.4rem' },
                                    lineHeight: 1.25,
                                }}
                            >
                                Your Trusted Partner in Financial Excellence
                            </Typography>

                            <Typography
                                variant="body1"
                                sx={{
                                    color: '#64748B',
                                    lineHeight: 1.8,
                                    fontSize: '1.05rem',
                                    mb: 4,
                                }}
                            >
                                At Auditra, we deliver more than numbers — we provide clarity, insight,
                                and confidence. Our team of seasoned professionals combines cutting-edge
                                technology with deep industry knowledge to ensure accuracy, compliance,
                                and strategic value for every engagement.
                            </Typography>

                            <Grid container spacing={1.5}>
                                {features.map((feature, i) => (
                                    <Grid item xs={12} sm={6} key={i}>
                                        <Stack direction="row" spacing={1.5} alignItems="center">
                                            <CheckCircle sx={{ color: '#16A34A', fontSize: 20 }} />
                                            <Typography variant="body2" sx={{ fontWeight: 500, color: '#0F172A' }}>
                                                {feature}
                                            </Typography>
                                        </Stack>
                                    </Grid>
                                ))}
                            </Grid>
                        </MotionBox>
                    </Grid>
                </Grid>
            </Container>
        </Box>
    );
}
