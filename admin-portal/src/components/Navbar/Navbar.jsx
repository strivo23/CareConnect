import React, { useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { 
  Box, 
  Typography, 
  IconButton, 
  Badge, 
  Avatar, 
  Menu, 
  MenuItem, 
  Button, 
  Tooltip, 
  Divider,
  Paper
} from '@mui/material';
import { 
  MdNotifications, 
  MdLogout, 
  MdRefresh, 
  MdCalendarToday, 
  MdMenu, 
  MdOutlineSecurity,
  MdOutlineHelpOutline,
  MdPersonOutline
} from 'react-icons/md';
import ThemeToggle from '../ThemeToggle/ThemeToggle';

const Navbar = ({ onToggleSidebar, onRefresh }) => {
  const location = useLocation();
  const navigate = useNavigate();
  const [anchorEl, setAnchorEl] = useState(null);
  const [notifAnchor, setNotifAnchor] = useState(null);
  const [isRefreshing, setIsRefreshing] = useState(false);

  const userStr = localStorage.getItem('user');
  const currentUser = userStr ? JSON.parse(userStr) : null;
  const userName = currentUser?.full_name || currentUser?.name || currentUser?.email || 'Super Admin';
  const userEmail = currentUser?.email || 'admin@careconnect.com';
  const userRole = currentUser?.role ? (currentUser.role.charAt(0) + currentUser.role.slice(1).toLowerCase() + ' Admin') : 'Super Admin';

  const getPageTitle = () => {
    const path = location.pathname.split('/')[1];
    if (!path || path === 'dashboard') return 'SOS Emergency Response';
    return path.charAt(0).toUpperCase() + path.slice(1).replace('-', ' ');
  };

  const handleMenuOpen = (event) => setAnchorEl(event.currentTarget);
  const handleMenuClose = () => setAnchorEl(null);

  const handleNotifOpen = (event) => setNotifAnchor(event.currentTarget);
  const handleNotifClose = () => setNotifAnchor(null);

  const handleLogout = () => {
    handleMenuClose();
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    localStorage.removeItem('user');
    navigate('/login');
  };

  const handleRefreshClick = () => {
    setIsRefreshing(true);
    if (onRefresh) onRefresh();
    setTimeout(() => setIsRefreshing(false), 800);
  };

  const currentDateFormatted = new Date().toLocaleDateString('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    year: 'numeric'
  });

  return (
    <Box 
      sx={{ 
        minHeight: 76, 
        display: 'flex', 
        alignItems: 'center', 
        justifyContent: 'space-between',
        px: { xs: 2, md: 4 },
        py: 1.5,
        backgroundColor: 'var(--bg-glass)',
        backdropFilter: 'blur(16px)',
        borderBottom: '1px solid var(--border-color)',
        color: 'var(--text-primary)',
        position: 'sticky',
        top: 0,
        zIndex: 1100
      }}
    >
      {/* Title & Subtitle Area */}
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
        <IconButton 
          onClick={onToggleSidebar} 
          sx={{ 
            color: 'var(--text-primary)', 
            backgroundColor: 'rgba(255, 255, 255, 0.05)',
            borderRadius: '12px',
            '&:hover': { backgroundColor: 'rgba(255, 255, 255, 0.1)' }
          }}
        >
          <MdMenu size={22} />
        </IconButton>

        <Box>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
            <Typography variant="h5" fontWeight="800" sx={{ letterSpacing: '-0.5px', background: 'linear-gradient(135deg, #FFFFFF 0%, #9CA3AF 100%)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent' }}>
              {getPageTitle()}
            </Typography>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.8, px: 1.2, py: 0.3, borderRadius: '20px', backgroundColor: 'rgba(239, 68, 68, 0.15)', border: '1px solid rgba(239, 68, 68, 0.3)' }}>
              <span className="pulse-dot" />
              <Typography variant="caption" fontWeight="700" sx={{ color: '#EF4444', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
                LIVE SYSTEM
              </Typography>
            </Box>
          </Box>
          <Typography variant="body2" sx={{ color: 'var(--text-secondary)', fontSize: '0.875rem' }}>
            Real-time overview of alerts and response system
          </Typography>
        </Box>
      </Box>

      {/* Right Controls */}
      <Box sx={{ display: 'flex', alignItems: 'center', gap: { xs: 1, md: 1.5 } }}>
        {/* Date Picker Component */}
        <Button
          startIcon={<MdCalendarToday size={16} color="var(--primary)" />}
          sx={{
            display: { xs: 'none', sm: 'inline-flex' },
            backgroundColor: 'rgba(255, 255, 255, 0.05)',
            color: 'var(--text-primary)',
            border: '1px solid var(--border-color)',
            borderRadius: '12px',
            px: 2,
            py: 0.8,
            fontSize: '0.85rem',
            fontWeight: 500,
            textTransform: 'none',
            '&:hover': {
              backgroundColor: 'rgba(255, 255, 255, 0.08)',
              borderColor: 'var(--border-light)'
            }
          }}
        >
          {currentDateFormatted}
        </Button>

        {/* Refresh Button */}
        <Tooltip title="Refresh System Data">
          <IconButton 
            onClick={handleRefreshClick}
            sx={{ 
              color: 'var(--text-primary)',
              backgroundColor: 'rgba(255, 255, 255, 0.05)',
              borderRadius: '12px',
              border: '1px solid var(--border-color)',
              '&:hover': { backgroundColor: 'rgba(255, 255, 255, 0.1)' }
            }}
          >
            <MdRefresh 
              size={22} 
              style={{ 
                transition: 'transform 0.5s ease',
                transform: isRefreshing ? 'rotate(360deg)' : 'none' 
              }} 
            />
          </IconButton>
        </Tooltip>

        {/* Notification Icon */}
        <Tooltip title="Notifications">
          <IconButton 
            onClick={handleNotifOpen}
            sx={{ 
              color: 'var(--text-primary)',
              backgroundColor: 'rgba(255, 255, 255, 0.05)',
              borderRadius: '12px',
              border: '1px solid var(--border-color)',
              '&:hover': { backgroundColor: 'rgba(255, 255, 255, 0.1)' }
            }}
          >
            <Badge badgeContent={3} color="error">
              <MdNotifications size={22} />
            </Badge>
          </IconButton>
        </Tooltip>

        {/* Dark Mode Toggle */}
        <Box sx={{
          backgroundColor: 'rgba(255, 255, 255, 0.05)',
          borderRadius: '12px',
          border: '1px solid var(--border-color)',
          display: 'flex',
          alignItems: 'center',
          p: 0.2
        }}>
          <ThemeToggle />
        </Box>

        {/* Admin Profile Dropdown */}
        <Box sx={{ ml: 0.5 }}>
          <Button
            onClick={handleMenuOpen}
            sx={{
              p: 0.5,
              pr: 1.5,
              borderRadius: '14px',
              backgroundColor: 'rgba(255, 255, 255, 0.05)',
              border: '1px solid var(--border-color)',
              textTransform: 'none',
              '&:hover': { backgroundColor: 'rgba(255, 255, 255, 0.09)' }
            }}
          >
            <Avatar 
              alt={userName} 
              src="https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80" 
              sx={{ width: 36, height: 36, mr: 1, border: '2px solid var(--primary)' }}
            />
            <Box sx={{ textAlign: 'left', display: { xs: 'none', lg: 'block' } }}>
              <Typography variant="subtitle2" fontWeight="700" sx={{ color: 'var(--text-primary)', lineHeight: 1.2, fontSize: '0.85rem' }}>
                {userName}
              </Typography>
              <Typography variant="caption" sx={{ color: 'var(--text-secondary)', fontSize: '0.72rem' }}>
                {userRole}
              </Typography>
            </Box>
          </Button>

          {/* Profile Menu */}
          <Menu
            anchorEl={anchorEl}
            open={Boolean(anchorEl)}
            onClose={handleMenuClose}
            PaperProps={{
              elevation: 0,
              sx: {
                mt: 1.5,
                width: 230,
                borderRadius: '16px',
                border: '1px solid var(--border-light)',
                backgroundColor: 'var(--bg-card)',
                color: 'var(--text-primary)',
                boxShadow: '0 12px 32px rgba(0,0,0,0.5)',
                p: 1
              }
            }}
            transformOrigin={{ horizontal: 'right', vertical: 'top' }}
            anchorOrigin={{ horizontal: 'right', vertical: 'bottom' }}
          >
            <Box sx={{ px: 2, py: 1 }}>
              <Typography variant="subtitle2" fontWeight="700">{userName}</Typography>
              <Typography variant="caption" sx={{ color: 'var(--text-secondary)' }}>{userEmail}</Typography>
            </Box>
            <Divider sx={{ my: 1, borderColor: 'var(--border-color)' }} />
            <MenuItem onClick={handleMenuClose} sx={{ borderRadius: '8px', py: 1, gap: 1.5, fontSize: '0.875rem' }}>
              <MdPersonOutline size={18} color="var(--primary)" /> Profile Settings
            </MenuItem>
            <MenuItem onClick={handleMenuClose} sx={{ borderRadius: '8px', py: 1, gap: 1.5, fontSize: '0.875rem' }}>
              <MdOutlineSecurity size={18} color="var(--secondary)" /> System Logs
            </MenuItem>
            <MenuItem onClick={handleMenuClose} sx={{ borderRadius: '8px', py: 1, gap: 1.5, fontSize: '0.875rem' }}>
              <MdOutlineHelpOutline size={18} /> Support & Documentation
            </MenuItem>
            <Divider sx={{ my: 1, borderColor: 'var(--border-color)' }} />
            <MenuItem onClick={handleLogout} sx={{ borderRadius: '8px', py: 1, gap: 1.5, color: 'var(--danger)', fontSize: '0.875rem' }}>
              <MdLogout size={18} /> Logout Session
            </MenuItem>
          </Menu>

          {/* Notifications Menu */}
          <Menu
            anchorEl={notifAnchor}
            open={Boolean(notifAnchor)}
            onClose={handleNotifClose}
            PaperProps={{
              elevation: 0,
              sx: {
                mt: 1.5,
                width: 320,
                borderRadius: '16px',
                border: '1px solid var(--border-light)',
                backgroundColor: 'var(--bg-card)',
                color: 'var(--text-primary)',
                boxShadow: '0 12px 32px rgba(0,0,0,0.5)',
                p: 1.5
              }
            }}
            transformOrigin={{ horizontal: 'right', vertical: 'top' }}
            anchorOrigin={{ horizontal: 'right', vertical: 'bottom' }}
          >
            <Typography variant="subtitle2" fontWeight="700" sx={{ px: 1, mb: 1 }}>
              Emergency Notifications
            </Typography>
            <Divider sx={{ mb: 1, borderColor: 'var(--border-color)' }} />
            <Paper elevation={0} sx={{ p: 1.5, mb: 1, backgroundColor: 'rgba(239, 68, 68, 0.1)', borderRadius: '10px', border: '1px solid rgba(239, 68, 68, 0.2)' }}>
              <Typography variant="caption" fontWeight="700" color="error">CRITICAL ALERT - SOS #1042</Typography>
              <Typography variant="body2" sx={{ fontSize: '0.8rem', mt: 0.5 }}>Medical emergency triggered at Block A - 402.</Typography>
            </Paper>
            <Paper elevation={0} sx={{ p: 1.5, mb: 1, backgroundColor: 'rgba(245, 158, 11, 0.1)', borderRadius: '10px', border: '1px solid rgba(245, 158, 11, 0.2)' }}>
              <Typography variant="caption" fontWeight="700" color="warning.main">ESCALATION NOTICE</Typography>
              <Typography variant="body2" sx={{ fontSize: '0.8rem', mt: 0.5 }}>Level 2 Escalation sent to Secondary Guardians.</Typography>
            </Paper>
          </Menu>
        </Box>
      </Box>
    </Box>
  );
};

export default Navbar;
