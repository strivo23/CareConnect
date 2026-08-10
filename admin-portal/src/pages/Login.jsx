import React, { useState } from 'react';
import { Box, Card, CardContent, Typography, TextField, Button, Alert, CircularProgress } from '@mui/material';
import { FaHeartbeat } from 'react-icons/fa';
import { useNavigate } from 'react-router-dom';
import { authService } from '../services/api';

const Login = () => {
  const navigate = useNavigate();
  const [email, setEmail] = useState('admin@careconnect.com');
  const [password, setPassword] = useState('password123');
  const [error, setError] = useState('');
  const [successMsg, setSuccessMsg] = useState('');
  const [loading, setLoading] = useState(false);
  const [creatingSuperuser, setCreatingSuperuser] = useState(false);

  const handleLogin = async (e) => {
    e.preventDefault();
    setError('');
    setSuccessMsg('');
    setLoading(true);
    try {
      await authService.login(email, password);
      navigate('/dashboard');
    } catch (err) {
      console.error(err);
      setError(err.response?.data?.message || err.response?.data?.detail || 'Invalid email or password. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleCreateSuperuser = async () => {
    setError('');
    setSuccessMsg('');
    setCreatingSuperuser(true);
    try {
      const res = await authService.createSuperuser({ email, password });
      setSuccessMsg(res.message || 'Superuser created successfully! You can now Sign In.');
    } catch (err) {
      console.error(err);
      setError(err.response?.data?.message || err.response?.data?.detail || 'Failed to create superuser.');
    } finally {
      setCreatingSuperuser(false);
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
          <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center', mb: 3.5, textAlign: 'center' }}>
            <Box sx={{
              width: 56,
              height: 56,
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
              <FaHeartbeat size={30} />
            </Box>
            <Typography variant="h5" fontWeight="800" sx={{ letterSpacing: '-0.5px', color: 'var(--text-primary)' }}>
              CareConnect Command
            </Typography>
            <Typography variant="body2" sx={{ color: 'var(--text-secondary)', mt: 0.5, fontSize: '0.875rem' }}>
              Emergency Operations & Society Management Portal
            </Typography>
          </Box>

          {error && <Alert severity="error" sx={{ mb: 2.5, borderRadius: '12px' }}>{error}</Alert>}
          {successMsg && <Alert severity="success" sx={{ mb: 2.5, borderRadius: '12px' }}>{successMsg}</Alert>}

          <form onSubmit={handleLogin}>
            <TextField 
              fullWidth 
              label="Email Address" 
              variant="outlined" 
              margin="normal" 
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              sx={{
                '& .MuiOutlinedInput-root': {
                  borderRadius: '12px',
                  backgroundColor: 'var(--bg-surface)'
                }
              }}
            />
            <TextField 
              fullWidth 
              label="Password" 
              type="password" 
              variant="outlined" 
              margin="normal"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              sx={{
                '& .MuiOutlinedInput-root': {
                  borderRadius: '12px',
                  backgroundColor: 'var(--bg-surface)'
                }
              }}
            />
            <Box sx={{ display: 'flex', justifyContent: 'flex-end', mt: 0.5, mb: 1 }}>
              <Button
                size="small"
                onClick={() => navigate('/forgot-password')}
                sx={{ color: 'var(--primary)', textTransform: 'none', fontWeight: '600', fontSize: '0.85rem' }}
              >
                Forgot Password?
              </Button>
            </Box>
            <Button 
              type="submit" 
              fullWidth 
              variant="contained" 
              size="large"
              disabled={loading || creatingSuperuser}
              sx={{ 
                mt: 3, 
                mb: 1.5, 
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
              {loading ? <CircularProgress size={24} color="inherit" /> : 'Sign In to Operations Console'}
            </Button>
          </form>

          <Button
            fullWidth
            variant="outlined"
            size="medium"
            disabled={loading}
            onClick={() => navigate('/create-superuser')}
            sx={{ 
              py: 1.1, 
              borderRadius: '12px',
              textTransform: 'none',
              fontWeight: 600,
              borderColor: 'var(--border-color)',
              color: 'var(--text-secondary)',
              '&:hover': {
                borderColor: 'var(--primary)',
                color: 'var(--primary)',
                backgroundColor: 'var(--primary-subtle)'
              }
            }}
          >
            Setup Initial Superuser
          </Button>
        </CardContent>
      </Card>
    </Box>
  );
};

export default Login;
