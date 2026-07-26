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
      p: 2
    }}>
      <Card sx={{ width: 440, p: 2, backgroundColor: 'var(--bg-card)', boxShadow: 'var(--shadow-md)', borderRadius: '16px' }}>
        <CardContent>
          <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center', mb: 3 }}>
            <FaHeartbeat size={44} color="var(--primary)" style={{ marginBottom: 12 }} />
            <Typography variant="h5" fontWeight="bold">Create Superuser</Typography>
            <Typography variant="body2" color="var(--text-secondary)" textAlign="center">
              Register a new Administrator account with Gmail verification
            </Typography>
          </Box>

          {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
          {successMsg && <Alert severity="success" sx={{ mb: 2 }}>{successMsg}</Alert>}
          {demoOtpNotice && <Alert severity="info" sx={{ mb: 2 }}>{demoOtpNotice}</Alert>}

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
              />
              <Button 
                variant="contained" 
                color="secondary" 
                onClick={handleSendOTP}
                disabled={otpLoading || !email}
                sx={{ height: 56, minWidth: 120, whiteSpace: 'nowrap' }}
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
            />

            <TextField 
              fullWidth 
              label="Phone Number" 
              variant="outlined" 
              margin="normal"
              value={phoneNumber}
              onChange={(e) => setPhoneNumber(e.target.value)}
              placeholder="+1234567890"
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
            />

            <Button 
              type="submit" 
              fullWidth 
              variant="contained" 
              color="primary" 
              size="large"
              disabled={submitting}
              sx={{ mt: 3, mb: 2, py: 1.5 }}
            >
              {submitting ? <CircularProgress size={24} color="inherit" /> : 'Create Superuser Account'}
            </Button>
          </form>

          <Button
            fullWidth
            variant="text"
            color="inherit"
            startIcon={<FaArrowLeft />}
            onClick={() => navigate('/login')}
            sx={{ mt: 1 }}
          >
            Back to Sign In
          </Button>
        </CardContent>
      </Card>
    </Box>
  );
};

export default CreateSuperuser;
