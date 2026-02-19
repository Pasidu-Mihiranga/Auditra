import { Box, Container, Grid, Typography, Card, CardContent } from '@mui/material';
import {
    AccountBalance, Assessment, Gavel, Business, Security, Computer,
} from '@mui/icons-material';
import { motion } from 'framer-motion';

const services = [
    {
        icon: AccountBalance,
        title: 'Financial Auditing',
        desc: 'Comprehensive financial statement audits and reviews ensuring accuracy and regulatory compliance.',
        color: '#1565C0',
    },
    {
        icon: Assessment,
        title: 'Tax Advisory',
        desc: 'Strategic tax planning, compliance reviews, and advisory services to optimize your financial position.',
        color: '#0D47A1',
    },
    {
        icon: Business,
        title: 'Business Consulting',
        desc: 'Expert strategic advisory to improve business performance, operations, and long-term profitability.',
        color: '#1976D2',
    },
    {
        icon: Gavel,
        title: 'Legal Compliance',
        desc: 'Ensuring your operations adhere to all relevant legal frameworks and regulatory requirements.',
        color: '#0D47A1',
    },
    {
        icon: Security,
        title: 'Asset Valuation',
        desc: 'Accurate and reliable property, plant, and equipment valuations trusted by financial institutions.',
        color: '#1565C0',
    },
    {
        icon: Computer,
        title: 'IT Auditing',
        desc: 'Information systems audits and cybersecurity assessments to protect your digital infrastructure.',
        color: '#1976D2',
    },
];

const MotionCard = motion.create(Card);

export default function ServicesSection() {
    return (
        <Box id="services" sx={{ py: { xs: 10, md: 14 }, bgcolor: '#F1F5F9' }}>
            <Container maxWidth="lg">
                {/* Section Header */}
                <Box sx={{ textAlign: 'center', mb: 8, maxWidth: 640, mx: 'auto' }}>
                    <Typography
                        variant="overline"
                        sx={{ color: '#1565C0', fontWeight: 700, letterSpacing: 2.5, fontSize: '0.8rem' }}
                    >
                        OUR SERVICES
                    </Typography>
                    <Typography
                        variant="h3"
                        sx={{
                            fontWeight: 700, color: '#0F172A', mt: 1, mb: 2,
                            fontSize: { xs: '1.8rem', md: '2.4rem' },
                        }}
                    >
                        Comprehensive Professional Solutions
                    </Typography>
                    <Typography variant="body1" sx={{ color: '#64748B', fontSize: '1.05rem', lineHeight: 1.7 }}>
                        We offer a wide range of services designed to meet the diverse needs of modern businesses.
                    </Typography>
                </Box>

                {/* Services Grid */}
                <Grid container spacing={3}>
                    {services.map((service, i) => (
                        <Grid item xs={12} sm={6} md={4} key={i}>
                            <MotionCard
                                elevation={0}
                                initial={{ opacity: 0, y: 30 }}
                                whileInView={{ opacity: 1, y: 0 }}
                                viewport={{ once: true, margin: '-50px' }}
                                transition={{ duration: 0.5, delay: i * 0.08 }}
                                sx={{
                                    height: '100%',
                                    bgcolor: '#fff',
                                    border: '1px solid #E2E8F0',
                                    borderRadius: 3,
                                    transition: 'all 0.3s cubic-bezier(.4,0,.2,1)',
                                    cursor: 'default',
                                    '&:hover': {
                                        transform: 'translateY(-6px)',
                                        boxShadow: '0 12px 32px rgba(21,101,192,0.1)',
                                        borderColor: '#1565C0',
                                        '& .service-icon-box': {
                                            bgcolor: '#1565C0',
                                            '& .MuiSvgIcon-root': { color: '#fff' },
                                        },
                                    },
                                }}
                            >
                                <CardContent sx={{ p: 4 }}>
                                    <Box
                                        className="service-icon-box"
                                        sx={{
                                            width: 56,
                                            height: 56,
                                            borderRadius: 2,
                                            bgcolor: '#EFF6FF',
                                            display: 'flex',
                                            alignItems: 'center',
                                            justifyContent: 'center',
                                            mb: 3,
                                            transition: 'all 0.3s',
                                        }}
                                    >
                                        <service.icon sx={{ fontSize: 28, color: '#1565C0', transition: 'color 0.3s' }} />
                                    </Box>
                                    <Typography variant="h6" sx={{ fontWeight: 600, color: '#0F172A', mb: 1.5 }}>
                                        {service.title}
                                    </Typography>
                                    <Typography variant="body2" sx={{ color: '#64748B', lineHeight: 1.7 }}>
                                        {service.desc}
                                    </Typography>
                                </CardContent>
                            </MotionCard>
                        </Grid>
                    ))}
                </Grid>
            </Container>
        </Box>
    );
}
