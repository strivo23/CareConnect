import React, { useState } from 'react';
import { Outlet } from 'react-router-dom';
import Sidebar from '../components/Sidebar/Sidebar';
import Navbar from '../components/Navbar/Navbar';
import { Box, CssBaseline, useMediaQuery, useTheme } from '@mui/material';

const Layout = () => {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  const toggleSidebar = () => {
    if (isMobile) {
      setMobileOpen(!mobileOpen);
    } else {
      setSidebarCollapsed(!sidebarCollapsed);
    }
  };

  const sidebarWidth = sidebarCollapsed ? 80 : 280;

  return (
    <Box sx={{ display: 'flex', minHeight: '100vh', backgroundColor: 'var(--bg-main)' }}>
      <CssBaseline />
      
      {/* Sidebar */}
      <Sidebar 
        collapsed={sidebarCollapsed} 
        mobileOpen={mobileOpen} 
        onClose={() => setMobileOpen(false)}
        width={sidebarWidth}
      />

      {/* Main Content Area */}
      <Box 
        component="main" 
        sx={{ 
          flexGrow: 1, 
          display: 'flex', 
          flexDirection: 'column',
          minWidth: 0,
          transition: 'margin 0.3s ease, width 0.3s ease',
          backgroundColor: 'var(--bg-main)',
          color: 'var(--text-primary)'
        }}
      >
        <Navbar onToggleSidebar={toggleSidebar} />
        
        {/* Page Content */}
        <Box sx={{ p: { xs: 2, sm: 3, md: 4 }, flexGrow: 1, overflowY: 'auto' }}>
          <Outlet />
        </Box>
      </Box>
    </Box>
  );
};

export default Layout;
