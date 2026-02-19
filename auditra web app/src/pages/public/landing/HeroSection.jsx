import { useState, useEffect, useCallback } from 'react';
import { Box, Container, Typography, Button, IconButton, Stack } from '@mui/material';
import { ArrowForward, ChevronLeft, ChevronRight } from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';

const slides = [
    {
        badge: 'AUDITRA SRI LANKA',
        heading: 'Your Trusted Partner in\nAuditing Insight',
        description: 'Delivering comprehensive audit and advisory services across Sri Lanka with over 15 years of trusted expertise.',
        cta1: { label: 'Get in Touch', link: '/client-register' },
        cta2: { label: 'Get a Quote', link: '/client-register' },
        bg: 'linear-gradient(135deg, #0D47A1 0%, #1565C0 30%, #1976D2 60%, #1E88E5 85%, #1565C0 100%)',
    },
    {
        badge: 'AUDITRA SRI LANKA',
        heading: 'Beyond Numbers,\nDelivering Clarity',
        description: 'Our team of certified auditors ensure accuracy, compliance, and strategic value for every business engagement.',
        cta1: { label: 'Our Services', link: '#services' },
        cta2: { label: 'Get a Quote', link: '/client-register' },
        bg: 'linear-gradient(135deg, #1565C0 0%, #1976D2 25%, #2196F3 50%, #1E88E5 75%, #1565C0 100%)',
    },
    {
        badge: 'AUDITRA SRI LANKA',
        heading: '15+ Years of\nProfessional Excellence',
        description: 'Trusted by 500+ clients for precision auditing, tax advisory, asset valuation, and business consulting.',
        cta1: { label: 'Get in Touch', link: '/client-register' },
        cta2: { label: 'Get a Quote', link: '/client-register' },
        bg: 'linear-gradient(135deg, #0D47A1 0%, #1565C0 25%, #1976D2 50%, #60A5FA 75%, #1565C0 100%)',
    },
];

export default function HeroSection() {
    const [current, setCurrent] = useState(0);
    const [animating, setAnimating] = useState(false);
    const [direction, setDirection] = useState(1); // 1 = forward, -1 = backward
    const navigate = useNavigate();

    const goTo = useCallback((index, dir) => {
        if (animating) return;
        setDirection(dir);
        setAnimating(true);
        setCurrent(index);
        setTimeout(() => setAnimating(false), 700);
    }, [animating]);

    const next = useCallback(() => {
        goTo((current + 1) % slides.length, 1);
    }, [current, goTo]);

    const prev = useCallback(() => {
        goTo((current - 1 + slides.length) % slides.length, -1);
    }, [current, goTo]);

    // Auto-advance
    useEffect(() => {
        const timer = setInterval(next, 5000);
        return () => clearInterval(timer);
    }, [next]);

    const handleCTA = (link) => {
        if (link.startsWith('#')) {
            const el = document.querySelector(link);
            if (el) el.scrollIntoView({ behavior: 'smooth' });
        } else {
            navigate(link);
        }
    };

    const slide = slides[current];

    return (
        <Box
            id="hero"
            sx={{
                position: 'relative',
                height: { xs: '85vh', md: '92vh' },
                minHeight: 520,
                overflow: 'hidden',
                mt: { xs: '64px', md: '100px' }, // offset for fixed navbar + top bar
                pb: { xs: '60px', md: '80px' }, // extra space for angled bottom
            }}
        >
            {/* Slides */}
            {slides.map((s, i) => (
                <Box
                    key={i}
                    sx={{
                        position: 'absolute',
                        inset: 0,
                        background: s.bg,
                        opacity: i === current ? 1 : 0,
                        transition: 'opacity 0.7s ease-in-out',
                        zIndex: i === current ? 1 : 0,
                    }}
                />
            ))}

            {/* Subtle diagonal overlay */}
            <Box
                sx={{
                    position: 'absolute',
                    inset: 0,
                    zIndex: 2,
                    background: 'linear-gradient(160deg, rgba(255,255,255,0.08) 0%, transparent 40%, rgba(0,0,0,0.05) 100%)',
                    pointerEvents: 'none',
                }}
            />

            {/* Content */}
            <Container
                maxWidth="lg"
                sx={{
                    position: 'relative',
                    zIndex: 5,
                    height: '100%',
                    display: 'flex',
                    flexDirection: 'column',
                    justifyContent: 'center',
                    py: 4,
                }}
            >
                <Box
                    key={current}
                    sx={{
                        animation: `slideIn${direction > 0 ? 'Right' : 'Left'} 0.6s ease-out`,
                        '@keyframes slideInRight': {
                            '0%': { opacity: 0, transform: 'translateX(60px)' },
                            '100%': { opacity: 1, transform: 'translateX(0)' },
                        },
                        '@keyframes slideInLeft': {
                            '0%': { opacity: 0, transform: 'translateX(-60px)' },
                            '100%': { opacity: 1, transform: 'translateX(0)' },
                        },
                        maxWidth: 620,
                    }}
                >
                    {/* Badge */}
                    <Box
                        sx={{
                            display: 'inline-block',
                            border: '1.5px solid rgba(255,255,255,0.5)',
                            borderRadius: 0.5,
                            px: 2,
                            py: 0.5,
                            mb: 3,
                        }}
                    >
                        <Typography
                            variant="caption"
                            sx={{
                                color: 'rgba(255,255,255,0.9)',
                                fontWeight: 600,
                                letterSpacing: 2.5,
                                fontSize: '0.7rem',
                                textTransform: 'uppercase',
                            }}
                        >
                            {slide.badge}
                        </Typography>
                    </Box>

                    {/* Heading */}
                    <Typography
                        variant="h1"
                        sx={{
                            color: '#fff',
                            fontWeight: 700,
                            fontSize: { xs: '2rem', sm: '2.8rem', md: '3.5rem' },
                            lineHeight: 1.2,
                            mb: 2.5,
                            whiteSpace: 'pre-line',
                            textShadow: '0 2px 20px rgba(0,0,0,0.1)',
                        }}
                    >
                        {slide.heading}
                    </Typography>

                    {/* Description */}
                    <Typography
                        variant="body1"
                        sx={{
                            color: 'rgba(255,255,255,0.85)',
                            fontSize: { xs: '0.95rem', md: '1.05rem' },
                            lineHeight: 1.7,
                            mb: 4,
                            maxWidth: 500,
                        }}
                    >
                        {slide.description}
                    </Typography>

                    {/* CTA Buttons */}
                    <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2}>
                        <Button
                            variant="contained"
                            size="large"
                            endIcon={<ArrowForward />}
                            onClick={() => handleCTA(slide.cta1.link)}
                            sx={{
                                bgcolor: 'rgba(255,255,255,0.2)',
                                color: '#fff',
                                fontWeight: 600,
                                textTransform: 'none',
                                px: 3.5,
                                py: 1.3,
                                borderRadius: 0.5,
                                fontSize: '0.95rem',
                                border: '1.5px solid rgba(255,255,255,0.5)',
                                backdropFilter: 'blur(4px)',
                                boxShadow: 'none',
                                '&:hover': {
                                    bgcolor: '#fff',
                                    color: '#1565C0',
                                    borderColor: '#fff',
                                    boxShadow: '0 4px 16px rgba(0,0,0,0.15)',
                                },
                                transition: 'all 0.3s',
                            }}
                        >
                            {slide.cta1.label}
                        </Button>
                        <Button
                            variant="outlined"
                            size="large"
                            onClick={() => handleCTA(slide.cta2.link)}
                            sx={{
                                color: 'rgba(255,255,255,0.9)',
                                borderColor: 'rgba(255,255,255,0.35)',
                                fontWeight: 600,
                                textTransform: 'none',
                                px: 3.5,
                                py: 1.3,
                                borderRadius: 0.5,
                                fontSize: '0.95rem',
                                '&:hover': {
                                    borderColor: '#fff',
                                    bgcolor: 'rgba(255,255,255,0.1)',
                                },
                            }}
                        >
                            {slide.cta2.label}
                        </Button>
                    </Stack>
                </Box>
            </Container>

            {/* Navigation Arrows */}
            <IconButton
                onClick={prev}
                sx={{
                    position: 'absolute',
                    left: { xs: 8, md: 24 },
                    top: '50%',
                    transform: 'translateY(-50%)',
                    zIndex: 10,
                    color: 'rgba(255,255,255,0.7)',
                    bgcolor: 'rgba(255,255,255,0.08)',
                    border: '1px solid rgba(255,255,255,0.2)',
                    width: { xs: 40, md: 48 },
                    height: { xs: 40, md: 48 },
                    '&:hover': { bgcolor: 'rgba(255,255,255,0.15)', color: '#fff' },
                    transition: 'all 0.3s',
                }}
            >
                <ChevronLeft sx={{ fontSize: 28 }} />
            </IconButton>
            <IconButton
                onClick={next}
                sx={{
                    position: 'absolute',
                    right: { xs: 8, md: 24 },
                    top: '50%',
                    transform: 'translateY(-50%)',
                    zIndex: 10,
                    color: 'rgba(255,255,255,0.7)',
                    bgcolor: 'rgba(255,255,255,0.08)',
                    border: '1px solid rgba(255,255,255,0.2)',
                    width: { xs: 40, md: 48 },
                    height: { xs: 40, md: 48 },
                    '&:hover': { bgcolor: 'rgba(255,255,255,0.15)', color: '#fff' },
                    transition: 'all 0.3s',
                }}
            >
                <ChevronRight sx={{ fontSize: 28 }} />
            </IconButton>

            {/* Pagination Dots */}
            <Box
                sx={{
                    position: 'absolute',
                    bottom: { xs: 70, md: 90 },
                    left: '50%',
                    transform: 'translateX(-50%)',
                    zIndex: 10,
                    display: 'flex',
                    alignItems: 'center',
                    gap: 1.2,
                }}
            >
                {slides.map((_, i) => (
                    <Box
                        key={i}
                        onClick={() => goTo(i, i > current ? 1 : -1)}
                        sx={{
                            width: i === current ? 28 : 10,
                            height: 10,
                            borderRadius: 5,
                            bgcolor: i === current ? '#fff' : 'rgba(255,255,255,0.4)',
                            cursor: 'pointer',
                            transition: 'all 0.35s ease',
                            '&:hover': { bgcolor: 'rgba(255,255,255,0.7)' },
                        }}
                    />
                ))}
            </Box>

            {/* Angled / Diagonal bottom edge */}
            <Box
                sx={{
                    position: 'absolute',
                    bottom: -1,
                    left: 0,
                    width: '100%',
                    zIndex: 10,
                    lineHeight: 0,
                }}
            >
                <svg
                    viewBox="0 0 1440 80"
                    preserveAspectRatio="none"
                    style={{ display: 'block', width: '100%', height: '60px' }}
                >
                    <polygon points="0,80 1440,0 1440,80" fill="#F1F5F9" />
                </svg>
            </Box>
        </Box>
    );
}
