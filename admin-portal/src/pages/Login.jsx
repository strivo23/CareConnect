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
      color: 'var(--text-primary)'
    }}>
      <Card sx={{ width: 400, p: 2, backgroundColor: 'var(--bg-card)', boxShadow: 'var(--shadow-md)', borderRadius: '16px' }}>
        <CardContent>
          <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center', mb: 3 }}>
            <FaHeartbeat size={48} color="var(--primary)" style={{ marginBottom: 16 }} />
            <Typography variant="h5" fontWeight="bold">CareConnect Admin</Typography>
            <Typography variant="body2" color="var(--text-secondary)">Login to manage societies</Typography>
          </Box>

          {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
          {successMsg && <Alert severity="success" sx={{ mb: 2 }}>{successMsg}</Alert>}

          <form onSubmit={handleLogin}>
            <TextField 
              fullWidth 
              label="Email Address" 
              variant="outlined" 
              margin="normal" 
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
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
            />
            <Button 
              type="submit" 
              fullWidth 
              variant="contained" 
              color="primary" 
              size="large"
              disabled={loading || creatingSuperuser}
              sx={{ mt: 3, mb: 1.5, py: 1.5 }}
            >
              {loading ? <CircularProgress size={24} color="inherit" /> : 'Sign In'}
            </Button>
          </form>

          <Button
            fullWidth
            variant="outlined"
            color="secondary"
            size="medium"
            disabled={loading}
            onClick={() => navigate('/create-superuser')}
            sx={{ py: 1 }}
          >
            Create Superuser
          </Button>
        </CardContent>
      </Card>
    </Box>
  );
};

export default Login;
