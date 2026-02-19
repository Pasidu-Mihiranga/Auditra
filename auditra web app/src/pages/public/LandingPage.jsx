import { Box } from '@mui/material';
import Navbar from './landing/Navbar';
import HeroSection from './landing/HeroSection';
import AboutSection from './landing/AboutSection';
import ServicesSection from './landing/ServicesSection';
import WhyChooseUs from './landing/WhyChooseUs';
import CTASection from './landing/CTASection';
import Footer from './landing/Footer';

export default function LandingPage() {
  return (
    <Box sx={{ bgcolor: '#FFFFFF', minHeight: '100vh' }}>
      <Navbar />
      <HeroSection />
      <AboutSection />
      <ServicesSection />
      <WhyChooseUs />
      <CTASection />
      <Footer />
    </Box>
  );
}
