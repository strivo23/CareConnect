import React from 'react';
import { NavLink } from 'react-router-dom';
import { Box, List, ListItem, ListItemIcon, ListItemText, Typography, Divider } from '@mui/material';
import { 
  MdDashboard, 
  MdLocationCity, 
  MdDomain, 
  MdMeetingRoom, 
  MdPeople, 
  MdAdminPanelSettings, 
  MdNotificationsActive, 
  MdAssessment, 
  MdSettings,
  MdPhone
} from 'react-icons/md';
import { FaHeartbeat } from 'react-icons/fa';

const menuItems = [
  { text: 'Dashboard', icon: <MdDashboard size={24} />, path: '/dashboard' },
  { text: 'Society', icon: <MdLocationCity size={24} />, path: '/society' },
  { text: 'Blocks / Towers', icon: <MdDomain size={24} />, path: '/block' },
  { text: 'Flats', icon: <MdMeetingRoom size={24} />, path: '/flat' },
  { text: 'Residents', icon: <MdPeople size={24} />, path: '/residents' },
  { text: 'Emergency Contacts', icon: <MdPhone size={24} />, path: '/emergency' },
  { text: 'Users', icon: <MdAdminPanelSettings size={24} />, path: '/users' },
  { text: 'Alerts', icon: <MdNotificationsActive size={24} />, path: '/alerts' },
  { text: 'Notification Templates', icon: <MdNotificationsActive size={24} />, path: '/notification-templates' },
  { text: 'Escalation Settings', icon: <MdSettings size={24} />, path: '/escalation-settings' },
  { text: 'Reports', icon: <MdAssessment size={24} />, path: '/reports' },
  { text: 'Settings', icon: <MdSettings size={24} />, path: '/settings' },
];

const Sidebar = () => {
  return (
    <Box sx={{
      width: 260,
      height: '100%',
      backgroundColor: 'var(--sidebar-bg)',
      color: 'var(--sidebar-text)',
      display: 'flex',
      flexDirection: 'column',
      borderRight: '1px solid var(--border-color)'
    }}>
      {/* Logo Area */}
      <Box sx={{ p: 3, display: 'flex', alignItems: 'center', gap: 2 }}>
        <FaHeartbeat size={32} color="var(--primary)" />
        <Typography variant="h6" fontWeight="bold" sx={{ letterSpacing: 1 }}>
          CareConnect
        </Typography>
      </Box>

      <Divider sx={{ borderColor: 'var(--sidebar-hover)' }} />

      {/* Navigation Links */}
      <List sx={{ flexGrow: 1, px: 2, py: 3, overflowY: 'auto' }}>
        {menuItems.map((item) => (
          <NavLink 
            key={item.text} 
            to={item.path}
            style={({ isActive }) => ({
              textDecoration: 'none',
              color: 'inherit',
              display: 'block',
              marginBottom: '8px',
              backgroundColor: isActive ? 'var(--sidebar-active)' : 'transparent',
              borderRadius: '8px',
              transition: 'background-color 0.2s',
            })}
          >
            {({ isActive }) => (
              <ListItem 
                button="true"
                sx={{ 
                  borderRadius: '8px',
                  '&:hover': {
                    backgroundColor: isActive ? 'var(--sidebar-active)' : 'var(--sidebar-hover)'
                  }
                }}
              >
                <ListItemIcon sx={{ color: isActive ? 'var(--primary)' : 'var(--sidebar-text)', minWidth: 40 }}>
                  {item.icon}
                </ListItemIcon>
                <ListItemText 
                  primary={item.text} 
                  slotProps={{
                    primary: {
                      sx: {
                        fontWeight: isActive ? 600 : 400,
                        fontSize: '0.95rem'
                      }
                    }
                  }} 
                />
              </ListItem>
            )}
          </NavLink>
        ))}
      </List>
      
      <Box sx={{ p: 2, textAlign: 'center' }}>
        <Typography variant="caption" sx={{ color: 'var(--text-secondary)' }}>
          Super Admin Portal v1.0
        </Typography>
      </Box>
    </Box>
  );
};

export default Sidebar;
