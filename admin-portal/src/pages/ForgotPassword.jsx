import React, { useState, useEffect } from 'react';
import { Box, Card, CardContent, Typography, TextField, Button, Alert, CircularProgress } from '@mui/material';
import { FaHeartbeat, FaKey, FaEnvelope, FaCheckCircle, FaArrowLeft } from 'react-icons/fa';
import { useNavigate } from 'react-router-dom';
import { authService } from '../services/api';

const ForgotPassword = () => {
  const navigate = useNavigate();

  // Wizard Steps: 1 = Email, 2 = OTP, 3 = Reset Password, 4 = Success
  const [step, setStep] = useState(1);

  const [email, setEmail] = useState('');
  const [otp, setOtp] = useState('');
  const [resetToken, setResetToken] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [successMsg, setSuccessMsg] = useState('');

  // Resend Cooldown Timer (30s)
  const [cooldown, setCooldown] = useState(0);

  useEffect(() => {
    let timer;
    if (cooldown > 0) {
      timer = setInterval(() => setCooldown((prev) => prev - 1), 1000);
    }
    return () => clearInterval(timer);
  }, [cooldown]);

  // Step 1: Send OTP
  const handleSendOTP = async (e) => {
    if (e) e.preventDefault();
    if (!email.trim()) {
      setError('Please enter a valid email address.');
      return;
    }
    setError('');
    setSuccessMsg('');
    setLoading(true);
    try {
      const res = await authService.forgotPassword(email.trim());
      setSuccessMsg(res.message || 'Verification code has been sent if the email is registered.');
      setStep(2);
      setCooldown(30);
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to send verification code. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  // Step 2: Verify OTP
  const handleVerifyOTP = async (e) => {
    e.preventDefault();
    if (!otp.trim() || otp.trim().length !== 6) {
      setError('Please enter a 6-digit verification code.');
      return;
    }
    setError('');
    setSuccessMsg('');
    setLoading(true);
    try {
      const res = await authService.verifyResetOTP(email.trim(), otp.trim());
      if (res.reset_token) {
        setResetToken(res.reset_token);
        setStep(3);
        setSuccessMsg('Verification successful. Please enter your new password.');
      } else {
        setError('Failed to verify token. Please try again.');
      }
    } catch (err) {
      setError(err.response?.data?.message || 'Invalid or expired verification code.');
    } finally {
      setLoading(false);
    }
  };

  // Step 3: Reset Password
  const handleResetPassword = async (e) => {
    e.preventDefault();
    if (newPassword.length < 8) {
      setError('Password must be at least 8 characters long.');
      return;
    }
    if (newPassword !== confirmPassword) {
      setError('Passwords do not match.');
      return;
    }
    setError('');
    setSuccessMsg('');
    setLoading(true);
    try {
      const res = await authService.resetPassword(resetToken, newPassword, confirmPassword);
      setSuccessMsg(res.message || 'Password reset successfully!');
      setStep(4);
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to reset password. Token may be expired.');
    } finally {
      setLoading(false);
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
        maxWidth: 440, 
        p: { xs: 2.5, sm: 3.5 }, 
        backgroundColor: 'var(--bg-card)', 
        boxShadow: 'var(--shadow-md)', 
        borderRadius: '20px',
        border: '1px solid var(--border-color)',
        position: 'relative',
        overflow: 'hidden'
      }}>
        {/* Brand Header Line */}
        <Box sx={{
          position: 'absolute',
          top: 0,
          left: 0,
          right: 0,
          height: 4,
          background: 'linear-gradient(90deg, #D92F32 0%, #E93F41 50%, #F04446 100%)'
        }} />

        <CardContent sx={{ p: 0, '&:last-child': { pb: 0 } }}>
          {/* Top Logo & Header */}
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
              mb: 1.5,
              boxShadow: '0 4px 14px rgba(233, 63, 65, 0.15)'
            }}>
              {step === 4 ? <FaCheckCircle size={28} color="#22C55E" /> : <FaKey size={26} />}
            </Box>
            <Typography variant="h5" fontWeight="800" sx={{ letterSpacing: '-0.5px', color: 'var(--text-primary)' }}>
              {step === 1 && 'Forgot Password'}
              {step === 2 && 'OTP Verification'}
              {step === 3 && 'Reset Password'}
              {step === 4 && 'Password Reset Successful'}
            </Typography>
            <Typography variant="body2" sx={{ color: 'var(--text-secondary)', mt: 0.5, fontSize: '0.85rem' }}>
              {step === 1 && 'Enter your registered email address to receive a 6-digit verification code.'}
              {step === 2 && `We sent a 6-digit verification code to ${email}`}
              {step === 3 && 'Create a strong new password for your account.'}
              {step === 4 && 'Your password has been updated. You can now sign in with your new credentials.'}
            </Typography>
          </Box>

          {/* Feedback Messages */}
          {error && (
            <Alert severity="error" sx={{ mb: 2.5, borderRadius: '12px' }} onClose={() => setError('')}>
              {error}
            </Alert>
          )}
          {successMsg && step !== 4 && (
            <Alert severity="success" sx={{ mb: 2.5, borderRadius: '12px' }} onClose={() => setSuccessMsg('')}>
              {successMsg}
            </Alert>
          )}

          {/* STEP 1: Email Form */}
          {step === 1 && (
            <form onSubmit={handleSendOTP}>
              <TextField
                fullWidth
                label="Registered Email Address"
                type="email"
                variant="outlined"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                disabled={loading}
                sx={{ mb: 3 }}
                InputProps={{
                  startAdornment: <FaEnvelope style={{ marginRight: 10, color: 'var(--text-secondary)' }} />
                }}
              />
              <Button
                fullWidth
                type="submit"
                variant="contained"
                disabled={loading}
                sx={{
                  py: 1.4,
                  borderRadius: '12px',
                  fontWeight: '700',
                  fontSize: '0.95rem',
                  backgroundColor: 'var(--primary)',
                  '&:hover': { backgroundColor: 'var(--primary-dark)' }
                }}
              >
                {loading ? <CircularProgress size={24} color="inherit" /> : 'Send Verification Code'}
              </Button>
            </form>
          )}

          {/* STEP 2: OTP Entry Form */}
          {step === 2 && (
            <form onSubmit={handleVerifyOTP}>
              <TextField
                fullWidth
                label="6-Digit Verification Code"
                type="text"
                variant="outlined"
                value={otp}
                onChange={(e) => setOtp(e.target.value)}
                required
                disabled={loading}
                inputProps={{ maxLength: 6, style: { letterSpacing: '6px', textAlign: 'center', fontSize: '1.25rem', fontWeight: 'bold' } }}
                sx={{ mb: 2 }}
              />
              <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                <Typography variant="caption" sx={{ color: 'var(--text-secondary)' }}>
                  Code expires in 5:00
                </Typography>
                <Button
                  size="small"
                  disabled={cooldown > 0 || loading}
                  onClick={handleSendOTP}
                  sx={{ color: 'var(--primary)', fontWeight: '600', textTransform: 'none' }}
                >
                  {cooldown > 0 ? `Resend code in ${cooldown}s` : 'Resend Code'}
                </Button>
              </Box>
              <Button
                fullWidth
                type="submit"
                variant="contained"
                disabled={loading}
                sx={{
                  py: 1.4,
                  borderRadius: '12px',
                  fontWeight: '700',
                  fontSize: '0.95rem',
                  backgroundColor: 'var(--primary)',
                  '&:hover': { backgroundColor: 'var(--primary-dark)' }
                }}
              >
                {loading ? <CircularProgress size={24} color="inherit" /> : 'Verify Code'}
              </Button>
            </form>
          )}

          {/* STEP 3: Reset Password Form */}
          {step === 3 && (
            <form onSubmit={handleResetPassword}>
              <TextField
                fullWidth
                label="New Password"
                type="password"
                variant="outlined"
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                required
                disabled={loading}
                helperText="Must be at least 8 characters long"
                sx={{ mb: 2 }}
              />
              <TextField
                fullWidth
                label="Confirm New Password"
                type="password"
                variant="outlined"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                required
                disabled={loading}
                sx={{ mb: 3 }}
              />
              <Button
                fullWidth
                type="submit"
                variant="contained"
                disabled={loading}
                sx={{
                  py: 1.4,
                  borderRadius: '12px',
                  fontWeight: '700',
                  fontSize: '0.95rem',
                  backgroundColor: 'var(--primary)',
                  '&:hover': { backgroundColor: 'var(--primary-dark)' }
                }}
              >
                {loading ? <CircularProgress size={24} color="inherit" /> : 'Reset Password'}
              </Button>
            </form>
          )}

          {/* STEP 4: Success Action */}
          {step === 4 && (
            <Box sx={{ textAlign: 'center', mt: 1 }}>
              <Button
                fullWidth
                variant="contained"
                onClick={() => navigate('/login')}
                sx={{
                  py: 1.4,
                  borderRadius: '12px',
                  fontWeight: '700',
                  fontSize: '0.95rem',
                  backgroundColor: 'var(--primary)',
                  '&:hover': { backgroundColor: 'var(--primary-dark)' }
                }}
              >
                Back to Sign In
              </Button>
            </Box>
          )}

          {/* Footer Back Link */}
          {step !== 4 && (
            <Box sx={{ textAlign: 'center', mt: 3 }}>
              <Button
                startIcon={<FaArrowLeft />}
                onClick={() => navigate('/login')}
                sx={{ color: 'var(--text-secondary)', textTransform: 'none', fontSize: '0.875rem' }}
              >
                Back to Sign In
              </Button>
            </Box>
          )}
        </CardContent>
      </Card>
    </Box>
  );
};

export default ForgotPassword;
