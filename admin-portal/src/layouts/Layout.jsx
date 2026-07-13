import React from 'react';
import { Outlet } from 'react-router-dom';
import Sidebar from '../components/Sidebar/Sidebar';
import Navbar from '../components/Navbar/Navbar';
import { Box, CssBaseline } from '@mui/material';

const Layout = () => {
  return (
    <Box sx={{ display: 'flex', minHeight: '100vh', backgroundColor: 'var(--bg-main)' }}>
      <CssBaseline />
      
      {/* Sidebar - fixed width on desktop */}
      <Box sx={{ width: { sm: 260 }, flexShrink: { sm: 0 } }}>
        <Sidebar />
      </Box>

      {/* Main Content Area */}
      <Box 
        component="main" 
        sx={{ 
          flexGrow: 1, 
          display: 'flex', 
          flexDirection: 'column',
          width: { sm: `calc(100% - 260px)` }
        }}
      >
        <Navbar />
        
        {/* Page Content */}
        <Box sx={{ p: 3, flexGrow: 1, overflowY: 'auto' }}>
          <Outlet />
        </Box>
      </Box>
    </Box>
  );
};

export default Layout;
