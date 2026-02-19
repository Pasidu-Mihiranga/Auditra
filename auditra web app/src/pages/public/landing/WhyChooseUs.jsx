import { Box, Container, Grid, Typography, Stack } from '@mui/material';
import { Speed, Shield, Handshake, SupportAgent } from '@mui/icons-material';
import { motion } from 'framer-motion';

const reasons = [
    {
        icon: Speed,
        title: 'Fast Turnaround',
        desc: 'We deliver results on time, every time. Our streamlined processes ensure efficiency without sacrificing quality.',
    },
    {
        icon: Shield,
        title: 'Unmatched Accuracy',
        desc: 'Our rigorous quality control and peer review systems ensure the highest level of accuracy in every engagement.',
    },
    {
        icon: Handshake,
        title: 'Client-Centric Approach',
        desc: 'We tailor our services to your unique needs, building long-term partnerships based on trust and mutual success.',
    },
    {
        icon: SupportAgent,
        title: 'Dedicated Support',
        desc: 'Our team is always available to answer questions, provide guidance, and support your ongoing financial needs.',
    },
];

const MotionBox = motion.create(Box);

export default function WhyChooseUs() {
    return (
        <Box id="why-us" sx={{ py: { xs: 10, md: 14 }, bgcolor: '#FFFFFF' }}>
            <Container maxWidth="lg">
                <Grid container spacing={8} alignItems="center">
                    {/* Left — Section Text */}
                    <Grid item xs={12} md={5}>
                        <MotionBox
                            initial={{ opacity: 0, x: -30 }}
                            whileInView={{ opacity: 1, x: 0 }}
                            viewport={{ once: true, margin: '-100px' }}
                            transition={{ duration: 0.6 }}
                        >
                            <Typography
                                variant="overline"
                                sx={{ color: '#1565C0', fontWeight: 700, letterSpacing: 2.5, fontSize: '0.8rem' }}
                            >
                                WHY CHOOSE US
                            </Typography>
                            <Typography
                                variant="h3"
                                sx={{
                                    fontWeight: 700, color: '#0F172A', mt: 1, mb: 3,
                                    fontSize: { xs: '1.8rem', md: '2.4rem' }, lineHeight: 1.25,
                                }}
                            >
                                Excellence You Can Count On
                            </Typography>
                            <Typography variant="body1" sx={{ color: '#64748B', lineHeight: 1.8, fontSize: '1.05rem' }}>
                                With over 15 years of experience in auditing, tax advisory, and business
                                consulting, Auditra has built a reputation for integrity, precision,
                                and client satisfaction. We don't just audit — we partner with you
                                for long-term success.
                            </Typography>
                        </MotionBox>
                    </Grid>

                    {/* Right — Feature Cards */}
                    <Grid item xs={12} md={7}>
                        <Grid container spacing={3}>
                            {reasons.map((reason, i) => (
                                <Grid item xs={12} sm={6} key={i}>
                                    <MotionBox
                                        initial={{ opacity: 0, y: 25 }}
                                        whileInView={{ opacity: 1, y: 0 }}
                                        viewport={{ once: true, margin: '-50px' }}
                                        transition={{ duration: 0.5, delay: i * 0.1 }}
                                        sx={{
                                            p: 3,
                                            borderRadius: 3,
                                            bgcolor: '#F8FAFC',
                                            border: '1px solid #E2E8F0',
                                            height: '100%',
                                            transition: 'all 0.3s',
                                            '&:hover': {
                                                bgcolor: '#EFF6FF',
                                                borderColor: '#BFDBFE',
                                                boxShadow: '0 4px 16px rgba(21,101,192,0.08)',
                                            },
                                        }}
                                    >
                                        <Box
                                            sx={{
                                                width: 48, height: 48, borderRadius: 2,
                                                bgcolor: '#DBEAFE', display: 'flex',
                                                alignItems: 'center', justifyContent: 'center', mb: 2,
                                            }}
                                        >
                                            <reason.icon sx={{ color: '#1565C0', fontSize: 24 }} />
                                        </Box>
                                        <Typography variant="subtitle1" sx={{ fontWeight: 600, color: '#0F172A', mb: 1 }}>
                                            {reason.title}
                                        </Typography>
                                        <Typography variant="body2" sx={{ color: '#64748B', lineHeight: 1.6 }}>
                                            {reason.desc}
                                        </Typography>
                                    </MotionBox>
                                </Grid>
                            ))}
                        </Grid>
                    </Grid>
                </Grid>
            </Container>
        </Box>
    );
}
