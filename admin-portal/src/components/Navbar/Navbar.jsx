import React from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { Box, Typography, IconButton, InputBase, Badge, Avatar, Menu, MenuItem } from '@mui/material';
import { MdSearch, MdNotifications, MdLogout } from 'react-icons/md';
import ThemeToggle from '../ThemeToggle/ThemeToggle';

const Navbar = () => {
  const location = useLocation();
  const navigate = useNavigate();
  const [anchorEl, setAnchorEl] = React.useState(null);

  // Capitalize first letter of path to show as Title
  const getPageTitle = () => {
    const path = location.pathname.split('/')[1];
    if (!path) return 'Dashboard';
    return path.charAt(0).toUpperCase() + path.slice(1);
  };

  const handleMenuOpen = (event) => {
    setAnchorEl(event.currentTarget);
  };

  const handleMenuClose = () => {
    setAnchorEl(null);
  };

  const handleLogout = () => {
    handleMenuClose();
    navigate('/login');
  };

  return (
    <Box sx={{ 
      height: 70, 
      display: 'flex', 
      alignItems: 'center', 
      justifyContent: 'space-between',
      px: 3,
      backgroundColor: 'var(--bg-card)',
      borderBottom: '1px solid var(--border-color)',
      color: 'var(--text-primary)'
    }}>
      <Typography variant="h5" fontWeight="bold">
        {getPageTitle()}
      </Typography>

      <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
        {/* Search Box */}
        <Box sx={{ 
          display: 'flex', 
          alignItems: 'center', 
          backgroundColor: 'var(--bg-main)', 
          borderRadius: 2,
          px: 2,
          py: 0.5,
          width: 300,
          border: '1px solid var(--border-color)'
        }}>
          <MdSearch size={20} color="var(--text-secondary)" />
          <InputBase 
            placeholder="Search..." 
            sx={{ ml: 1, flex: 1, color: 'var(--text-primary)' }} 
          />
        </Box>

        <IconButton color="inherit">
          <Badge badgeContent={4} color="error">
            <MdNotifications size={24} />
          </Badge>
        </IconButton>

        <ThemeToggle />

        {/* Profile Avatar */}
        <IconButton onClick={handleMenuOpen} sx={{ p: 0, ml: 1 }}>
          <Avatar alt="Super Admin" src="https://i.pravatar.cc/150?img=11" />
        </IconButton>

        <Menu
          anchorEl={anchorEl}
          open={Boolean(anchorEl)}
          onClose={handleMenuClose}
          PaperProps={{
            elevation: 0,
            sx: {
              mt: 1.5,
              border: '1px solid var(--border-color)',
              boxShadow: 'var(--shadow-md)',
              backgroundColor: 'var(--bg-card)',
              color: 'var(--text-primary)'
            }
          }}
          transformOrigin={{ horizontal: 'right', vertical: 'top' }}
          anchorOrigin={{ horizontal: 'right', vertical: 'bottom' }}
        >
          <MenuItem onClick={handleMenuClose}>Profile Settings</MenuItem>
          <MenuItem onClick={handleLogout} sx={{ color: 'var(--danger)' }}>
            <MdLogout style={{ marginRight: 8 }} /> Logout
          </MenuItem>
        </Menu>
      </Box>
    </Box>
  );
};

export default Navbar;
