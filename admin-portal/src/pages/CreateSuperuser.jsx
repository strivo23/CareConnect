import React, { useState } from 'react';
import { Box, Card, CardContent, Typography, TextField, Button, Alert, CircularProgress } from '@mui/material';
import { FaHeartbeat, FaArrowLeft } from 'react-icons/fa';
import { useNavigate } from 'react-router-dom';
import { authService } from '../services/api';

const CreateSuperuser = () => {
  const navigate = useNavigate();

  const [fullName, setFullName] = useState('');
  const [email, setEmail] = useState('');
  const [phoneNumber, setPhoneNumber] = useState('');
  const [password, setPassword] = useState('');
  const [otp, setOtp] = useState('');

  const [otpSent, setOtpSent] = useState(false);
  const [otpLoading, setOtpLoading] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  const [error, setError] = useState('');
  const [successMsg, setSuccessMsg] = useState('');
  const [demoOtpNotice, setDemoOtpNotice] = useState('');

  const handleSendOTP = async () => {
    if (!email) {
      setError('Please enter your Gmail / Email address first.');
      return;
    }
    setError('');
    setSuccessMsg('');
    setOtpLoading(true);
    try {
      const res = await authService.sendSuperuserOTP(email);
      setOtpSent(true);
      setDemoOtpNotice(res.message || `OTP sent to ${email}. Please check your Gmail inbox.`);
    } catch (err) {
      console.error(err);
      setError(err.response?.data?.detail || err.response?.data?.message || 'Failed to send OTP. Please check backend.');
    } finally {
      setOtpLoading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setSuccessMsg('');

    if (!fullName || !email || !password || !otp) {
      setError('Please fill in Full Name, Gmail, Password, and OTP.');
      return;
    }

    setSubmitting(true);
    try {
      const res = await authService.createSuperuser({
        full_name: fullName,
        email: email,
        phone_number: phoneNumber,
        password: password,
        otp: otp
      });

      setSuccessMsg(res.message || 'Superuser created successfully! Redirecting to login...');
      setTimeout(() => {
        navigate('/login', { state: { email, password } });
      }, 2000);
    } catch (err) {
      console.error(err);
      setError(err.response?.data?.detail || err.response?.data?.message || 'Failed to create superuser.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <Box sx={{ 
      minHeight: '100vh', 
      display: 'flex', 
      alignItems: 'center', 
      justifyContent: 'center',
      backgroundColor: 'var(--bg-main)',
      color: 'var(--text-primary)',
      px: 2,
      py: 4
    }}>
      <Card sx={{ 
        width: '100%',
        maxWidth: 460, 
        p: { xs: 2.5, sm: 3.5 }, 
        backgroundColor: 'var(--bg-card)', 
        boxShadow: 'var(--shadow-md)', 
        borderRadius: '20px',
        border: '1px solid var(--border-color)',
        position: 'relative',
        overflow: 'hidden'
      }}>
        {/* Subtle Brand Accent Header Line */}
        <Box sx={{
          position: 'absolute',
          top: 0,
          left: 0,
          right: 0,
          height: 4,
          background: 'linear-gradient(90deg, #D92F32 0%, #E93F41 50%, #F04446 100%)'
        }} />

        <CardContent sx={{ p: 0, '&:last-child': { pb: 0 } }}>
          <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center', mb: 3, textAlign: 'center' }}>
            <Box sx={{
              width: 52,
              height: 52,
              borderRadius: '16px',
              backgroundColor: 'var(--danger-subtle)',
              border: '1px solid rgba(233, 63, 65, 0.25)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: 'var(--primary)',
              mb: 2,
              boxShadow: '0 4px 14px rgba(233, 63, 65, 0.15)'
            }}>
              <FaHeartbeat size={28} />
            </Box>
            <Typography variant="h5" fontWeight="800" sx={{ letterSpacing: '-0.5px', color: 'var(--text-primary)' }}>
              Create Operations Superuser
            </Typography>
            <Typography variant="body2" sx={{ color: 'var(--text-secondary)', mt: 0.5, fontSize: '0.875rem' }}>
              Register a verified administrator account for CareConnect
            </Typography>
          </Box>

          {error && <Alert severity="error" sx={{ mb: 2, borderRadius: '12px' }}>{error}</Alert>}
          {successMsg && <Alert severity="success" sx={{ mb: 2, borderRadius: '12px' }}>{successMsg}</Alert>}
          {demoOtpNotice && <Alert severity="info" sx={{ mb: 2, borderRadius: '12px' }}>{demoOtpNotice}</Alert>}

          <form onSubmit={handleSubmit}>
            <TextField 
              fullWidth 
              label="Full Name" 
              variant="outlined" 
              margin="normal"
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              placeholder="e.g. John Doe"
              required
              sx={{ '& .MuiOutlinedInput-root': { borderRadius: '12px', backgroundColor: 'var(--bg-surface)' } }}
            />

            <Box sx={{ display: 'flex', gap: 1, alignItems: 'center', mt: 1, mb: 1 }}>
              <TextField 
                fullWidth 
                label="Gmail / Email Address" 
                variant="outlined" 
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="admin@gmail.com"
                required
                sx={{ '& .MuiOutlinedInput-root': { borderRadius: '12px', backgroundColor: 'var(--bg-surface)' } }}
              />
              <Button 
                variant="contained" 
                onClick={handleSendOTP}
                disabled={otpLoading || !email}
                sx={{ 
                  height: 56, 
                  minWidth: 120, 
                  whiteSpace: 'nowrap',
                  borderRadius: '12px',
                  fontWeight: 700,
                  textTransform: 'none',
                  backgroundColor: 'var(--secondary)',
                  '&:hover': { backgroundColor: 'var(--secondary-hover)' }
                }}
              >
                {otpLoading ? <CircularProgress size={20} color="inherit" /> : (otpSent ? 'Resend OTP' : 'Send OTP')}
              </Button>
            </Box>

            <TextField 
              fullWidth 
              label="OTP Received to Gmail" 
              variant="outlined" 
              margin="normal"
              value={otp}
              onChange={(e) => setOtp(e.target.value)}
              placeholder="6-digit OTP"
              required
              sx={{ '& .MuiOutlinedInput-root': { borderRadius: '12px', backgroundColor: 'var(--bg-surface)' } }}
            />

            <TextField 
              fullWidth 
              label="Phone Number" 
              variant="outlined" 
              margin="normal"
              value={phoneNumber}
              onChange={(e) => setPhoneNumber(e.target.value)}
              placeholder="+1234567890"
              sx={{ '& .MuiOutlinedInput-root': { borderRadius: '12px', backgroundColor: 'var(--bg-surface)' } }}
            />

            <TextField 
              fullWidth 
              label="Password" 
              type="password" 
              variant="outlined" 
              margin="normal"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Set secure password"
              required
              sx={{ '& .MuiOutlinedInput-root': { borderRadius: '12px', backgroundColor: 'var(--bg-surface)' } }}
            />

            <Button 
              type="submit" 
              fullWidth 
              variant="contained" 
              size="large"
              disabled={submitting}
              sx={{ 
                mt: 3, 
                mb: 2, 
                py: 1.4,
                borderRadius: '12px',
                fontWeight: 700,
                fontSize: '0.95rem',
                textTransform: 'none',
                background: 'linear-gradient(135deg, #E93F41 0%, #D92F32 100%)',
                boxShadow: '0 4px 14px rgba(233, 63, 65, 0.3)',
                '&:hover': {
                  background: 'linear-gradient(135deg, #F04446 0%, #E93F41 100%)'
                }
              }}
            >
              {submitting ? <CircularProgress size={24} color="inherit" /> : 'Create Superuser Account'}
            </Button>
          </form>

          <Button
            fullWidth
            variant="text"
            startIcon={<FaArrowLeft />}
            onClick={() => navigate('/login')}
            sx={{ 
              mt: 1, 
              color: 'var(--text-secondary)',
              textTransform: 'none',
              fontWeight: 600,
              '&:hover': { color: 'var(--primary)' }
            }}
          >
            Back to Sign In
          </Button>
        </CardContent>
      </Card>
    </Box>
  );
};

export default CreateSuperuser;
