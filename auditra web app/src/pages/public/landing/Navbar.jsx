import { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import {
    AppBar, Box, Toolbar, IconButton, Typography, Button, Container,
    Drawer, List, ListItem, ListItemButton, ListItemText, Divider, useMediaQuery, useTheme
} from '@mui/material';
import { Menu as MenuIcon, Close, KeyboardArrowDown } from '@mui/icons-material';
import logo from '../../../assets/logo.png';

const navLinks = [
    { label: 'HOME', href: '#hero' },
    { label: 'SERVICES', href: '#services', hasDropdown: true },
    { label: 'ABOUT US', href: '#about', hasDropdown: true },
    { label: 'WHY US', href: '#why-us' },
    { label: 'CAREERS', href: '#contact' },
    { label: 'CONTACT US', href: '#contact' },
];

export default function Navbar() {
    const [scrolled, setScrolled] = useState(false);
    const [drawerOpen, setDrawerOpen] = useState(false);
    const navigate = useNavigate();
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('lg'));

    useEffect(() => {
        const onScroll = () => setScrolled(window.scrollY > 20);
        window.addEventListener('scroll', onScroll);
        return () => window.removeEventListener('scroll', onScroll);
    }, []);

    const scrollTo = (id) => {
        setDrawerOpen(false);
        const el = document.querySelector(id);
        if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' });
    };

    return (
        <>
            {/* Top thin bar */}
            <Box
                sx={{
                    bgcolor: '#F8F9FA',
                    borderBottom: '1px solid #EEEEEE',
                    py: 0.5,
                    position: 'fixed',
                    top: 0,
                    left: 0,
                    right: 0,
                    zIndex: 1201,
                    display: { xs: 'none', md: 'block' },
                    transition: 'transform 0.3s',
                    transform: scrolled ? 'translateY(-100%)' : 'translateY(0)',
                }}
            >
                <Container maxWidth="xl">
                    <Box sx={{ display: 'flex', justifyContent: 'flex-end' }}>
                        <Typography
                            variant="caption"
                            sx={{ color: '#1565C0', fontWeight: 500, fontSize: '0.75rem', cursor: 'pointer', '&:hover': { textDecoration: 'underline' } }}
                        >
                            Auditra Key People
                        </Typography>
                    </Box>
                </Container>
            </Box>

            {/* Main Navbar */}
            <AppBar
                position="fixed"
                elevation={scrolled ? 3 : 0}
                sx={{
                    bgcolor: '#FFFFFF',
                    top: scrolled ? 0 : { xs: 0, md: '28px' },
                    transition: 'all 0.3s cubic-bezier(.4,0,.2,1)',
                    borderBottom: '1px solid #EEEEEE',
                }}
            >
                <Container maxWidth="xl">
                    <Toolbar disableGutters sx={{ py: 1, minHeight: { xs: 64, md: 72 } }}>
                        {/* Logo */}
                        <Box
                            component="img"
                            src={logo}
                            alt="Auditra"
                            onClick={() => scrollTo('#hero')}
                            sx={{
                                height: { xs: 40, md: 50 },
                                cursor: 'pointer',
                                mr: 4,
                                transition: 'transform 0.2s',
                                '&:hover': { transform: 'scale(1.02)' },
                            }}
                        />

                        {/* Spacer */}
                        <Box sx={{ flexGrow: 1 }} />

                        {/* Desktop Nav Links */}
                        {!isMobile && (
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                                {navLinks.map((link) => (
                                    <Button
                                        key={link.label}
                                        onClick={() => scrollTo(link.href)}
                                        endIcon={link.hasDropdown ? <KeyboardArrowDown sx={{ fontSize: '18px !important', ml: -0.5 }} /> : undefined}
                                        sx={{
                                            color: '#333333',
                                            fontWeight: 600,
                                            fontSize: '0.82rem',
                                            textTransform: 'uppercase',
                                            px: 1.8,
                                            py: 1,
                                            letterSpacing: '0.5px',
                                            borderRadius: 0,
                                            position: 'relative',
                                            '&::after': {
                                                content: '""',
                                                position: 'absolute',
                                                bottom: 0,
                                                left: '50%',
                                                width: 0,
                                                height: 2,
                                                bgcolor: '#1565C0',
                                                transition: 'all 0.3s',
                                                transform: 'translateX(-50%)',
                                            },
                                            '&:hover': {
                                                bgcolor: 'transparent',
                                                color: '#3BA4CC',
                                                '&::after': { width: '80%' },
                                            },
                                        }}
                                    >
                                        {link.label}
                                    </Button>
                                ))}

                                {/* CTA Button — LET'S TALK style */}
                                <Button
                                    onClick={() => navigate('/client-register')}
                                    variant="contained"
                                    disableElevation
                                    sx={{
                                        ml: 2,
                                        bgcolor: '#1565C0',
                                        color: '#fff',
                                        fontWeight: 700,
                                        textTransform: 'uppercase',
                                        px: 4,
                                        py: 1.2,
                                        borderRadius: 0.5,
                                        fontSize: '0.82rem',
                                        letterSpacing: '1px',
                                        '&:hover': { bgcolor: '#0D47A1' },
                                    }}
                                >
                                    LET'S TALK
                                </Button>
                            </Box>
                        )}

                        {/* Mobile Menu Button */}
                        {isMobile && (
                            <IconButton onClick={() => setDrawerOpen(true)} sx={{ color: '#333' }}>
                                <MenuIcon />
                            </IconButton>
                        )}
                    </Toolbar>
                </Container>
            </AppBar>

            {/* Mobile Drawer */}
            <Drawer
                anchor="right"
                open={drawerOpen}
                onClose={() => setDrawerOpen(false)}
                PaperProps={{ sx: { width: 300, bgcolor: '#fff' } }}
            >
                <Box sx={{ p: 2, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <Box component="img" src={logo} alt="Auditra" sx={{ height: 36 }} />
                    <IconButton onClick={() => setDrawerOpen(false)}><Close /></IconButton>
                </Box>
                <Divider />
                <List>
                    {navLinks.map((link) => (
                        <ListItem key={link.label} disablePadding>
                            <ListItemButton onClick={() => scrollTo(link.href)}>
                                <ListItemText
                                    primary={link.label}
                                    primaryTypographyProps={{ fontWeight: 600, fontSize: '0.875rem', letterSpacing: 0.5 }}
                                />
                            </ListItemButton>
                        </ListItem>
                    ))}
                </List>
                <Divider />
                <Box sx={{ p: 2, display: 'flex', flexDirection: 'column', gap: 1.5 }}>
                    <Button
                        fullWidth variant="outlined" onClick={() => { setDrawerOpen(false); navigate('/login'); }}
                        sx={{ borderColor: '#1565C0', color: '#1565C0', textTransform: 'uppercase', fontWeight: 700, borderRadius: 0.5, letterSpacing: 1 }}
                    >
                        Log In
                    </Button>
                    <Button
                        fullWidth variant="contained" onClick={() => { setDrawerOpen(false); navigate('/client-register'); }}
                        sx={{ bgcolor: '#1565C0', textTransform: 'uppercase', fontWeight: 700, borderRadius: 0.5, letterSpacing: 1, '&:hover': { bgcolor: '#0D47A1' } }}
                    >
                        LET'S TALK
                    </Button>
                </Box>
            </Drawer>
        </>
    );
}
