import React, { useState } from 'react';
import { NavLink } from 'react-router-dom';
import {
  Box,
  List,
  ListItem,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Typography,
  Divider,
  Avatar,
  Button,
  Drawer,
  Tooltip,
  Chip,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  MenuItem
} from '@mui/material';
import {
  MdDashboard,
  MdVerifiedUser,
  MdLocationCity,
  MdDomain,
  MdMeetingRoom,
  MdPeople,
  MdVolunteerActivism,
  MdSecurity,
  MdWarning,
  MdTrendingUp,
  MdNotificationsActive,
  MdNotifications,
  MdAltRoute,
  MdAssessment,
  MdSettings,
  MdCampaign,
  MdDownload,
  MdCheckCircle,
  MdElectricBolt
} from 'react-icons/md';
import { FaHeartbeat } from 'react-icons/fa';

const menuItems = [
  { text: 'Dashboard', icon: <MdDashboard size={22} />, path: '/dashboard' },
  { text: 'Verification Center', icon: <MdVerifiedUser size={22} />, path: '/verification-center' },
  { text: 'Societies', icon: <MdLocationCity size={22} />, path: '/society' },
  { text: 'Blocks', icon: <MdDomain size={22} />, path: '/block' },
  { text: 'Flats', icon: <MdMeetingRoom size={22} />, path: '/flat' },
  { text: 'Residents', icon: <MdPeople size={22} />, path: '/residents' },
  { text: 'Volunteers', icon: <MdVolunteerActivism size={22} />, path: '/volunteers' },
  { text: 'Security Staff', icon: <MdSecurity size={22} />, path: '/security' },
  { text: 'Incidents', icon: <MdWarning size={22} />, path: '/emergency' },
  { text: 'Escalation', icon: <MdTrendingUp size={22} />, path: '/escalation' },
  { text: 'Alerts', icon: <MdNotificationsActive size={22} />, path: '/alerts' },
  { text: 'Reports', icon: <MdAssessment size={22} />, path: '/reports' },
  { text: 'Users', icon: <MdPeople size={22} />, path: '/users' },
  { text: 'Settings', icon: <MdSettings size={22} />, path: '/settings' },
];

const SidebarContent = ({ collapsed, onClose }) => {
  const [broadcastOpen, setBroadcastOpen] = useState(false);
  const [broadcastMsg, setBroadcastMsg] = useState('');
  const [broadcastCategory, setBroadcastCategory] = useState('General SOS');
  const [broadcastSent, setBroadcastSent] = useState(false);

  const handleSendBroadcast = () => {
    setBroadcastSent(true);
    setTimeout(() => {
      setBroadcastSent(false);
      setBroadcastOpen(false);
      setBroadcastMsg('');
    }, 1500);
  };

  const userStr = localStorage.getItem('user');
  const currentUser = userStr ? JSON.parse(userStr) : null;
  const userName = currentUser?.full_name || currentUser?.name || currentUser?.email || 'Super Admin';
  const userRole = currentUser?.role ? (currentUser.role.charAt(0).toUpperCase() + currentUser.role.slice(1).toLowerCase() + ' Administrator') : 'Super Administrator';

  return (
    <Box sx={{
      width: collapsed ? 80 : 280,
      height: '100%',
      backgroundColor: 'var(--bg-sidebar)',
      color: 'var(--text-primary)',
      display: 'flex',
      flexDirection: 'column',
      borderRight: '1px solid var(--border-color)',
      transition: 'width 0.3s ease',
      overflowX: 'hidden'
    }}>
      {/* Logo Area */}
      <Box sx={{
        p: 2.5,
        display: 'flex',
        alignItems: 'center',
        justifyContent: collapsed ? 'center' : 'space-between',
        borderBottom: '1px solid var(--border-color)'
      }}>
        {!collapsed && (
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
            <Box sx={{
              width: 36,
              height: 36,
              borderRadius: '10px',
              backgroundColor: 'var(--primary)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              boxShadow: '0 4px 12px rgba(124, 58, 237, 0.4)'
            }}>
              <FaHeartbeat size={22} color="#fff" />
            </Box>
            <Box>
              <Typography variant="h6" fontWeight="bold" sx={{ lineHeight: 1, fontSize: '1.1rem' }}>
                CareConnect
              </Typography>
              <Typography variant="caption" sx={{ color: 'var(--text-secondary)', fontSize: '0.7rem' }}>
                Admin Portal
              </Typography>
            </Box>
          </Box>
        )}
      </Box>

      {/* Navigation List */}
      <List sx={{ flexGrow: 1, px: collapsed ? 1 : 2, py: 2 }}>
        {menuItems.map((item) => (
          <ListItem
            key={item.text}
            disablePadding
            sx={{ mb: 0.5 }}
          >
            <Tooltip title={collapsed ? item.text : ''} placement="right">
              <NavLink
                to={item.path}
                onClick={onClose}
                style={{ textDecoration: 'none', color: 'inherit', width: '100%', display: 'block' }}
              >
                {({ isActive }) => (
                  <ListItemButton
                    sx={{
                      borderRadius: '12px',
                      py: 1.2,
                      px: collapsed ? 1.5 : 2,
                      justifyContent: collapsed ? 'center' : 'flex-start',
                      backgroundColor: isActive ? 'var(--primary)' : 'transparent',
                      color: isActive ? '#ffffff' : 'var(--text-secondary)',
                      fontWeight: isActive ? 'bold' : 'normal',
                      boxShadow: isActive ? '0 4px 12px rgba(233, 63, 65, 0.15)' : 'none',
                      '&:hover': {
                        backgroundColor: isActive ? 'var(--primary-hover)' : 'var(--primary-subtle)',
                        color: isActive ? '#ffffff' : 'var(--primary)',
                      },
                      transition: 'all 0.2s ease'
                    }}
                  >
                    <ListItemIcon sx={{
                      minWidth: 0,
                      mr: collapsed ? 0 : 1.8,
                      color: isActive ? '#ffffff' : 'var(--text-secondary)'
                    }}>
                      {item.icon}
                    </ListItemIcon>
                    {!collapsed && (
                      <ListItemText
                        primary={item.text}
                        primaryTypographyProps={{
                          fontSize: '0.9rem',
                          fontWeight: isActive ? 700 : 500
                        }}
                      />
                    )}
                  </ListItemButton>
                )}
              </NavLink>
            </Tooltip>
          </ListItem>
        ))}
      </List>

      {/* Quick Actions & System Info */}
      {!collapsed && (
        <Box sx={{ p: 2 }}>
          <Typography variant="caption" sx={{ color: 'var(--text-secondary)', px: 1, mb: 1, display: 'block', textTransform: 'uppercase', fontSize: '0.68rem', fontWeight: 700 }}>
            Quick Actions
          </Typography>

          <Button
            fullWidth
            variant="contained"
            color="primary"
            startIcon={<MdCampaign size={20} />}
            onClick={() => setBroadcastOpen(true)}
            sx={{
              mb: 1,
              py: 1,
              borderRadius: '12px',
              textTransform: 'none',
              fontWeight: 'bold',
              boxShadow: '0 4px 14px rgba(124, 58, 237, 0.3)'
            }}
          >
            Broadcast Alert
          </Button>

          <Button
            fullWidth
            variant="outlined"
            startIcon={<MdDownload size={18} />}
            sx={{
              mb: 2,
              py: 0.8,
              borderRadius: '12px',
              textTransform: 'none',
              color: 'var(--text-primary)',
              borderColor: 'var(--border-color)',
              fontSize: '0.82rem'
            }}
          >
            Export Report
          </Button>

          {/* System Status Pill */}
          <Box sx={{
            p: 1,
            borderRadius: '10px',
            backgroundColor: 'rgba(34, 197, 94, 0.08)',
            border: '1px solid rgba(34, 197, 94, 0.2)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            mb: 2
          }}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
              <Box sx={{ width: 8, height: 8, borderRadius: '50%', backgroundColor: '#22C55E' }} />
              <Typography variant="caption" fontWeight="600" sx={{ color: '#22C55E', fontSize: '0.75rem' }}>
                System Health
              </Typography>
            </Box>
            <Typography variant="caption" sx={{ color: 'var(--text-secondary)', fontSize: '0.7rem' }}>
              99.9% Operational
            </Typography>
          </Box>

          <Divider sx={{ my: 0.5, borderColor: 'var(--border-color)' }} />

          {/* Admin Profile Card */}
          <Box sx={{
            mt: 2,
            p: 1.5,
            borderRadius: '14px',
            backgroundColor: 'rgba(255, 255, 255, 0.04)',
            border: '1px solid var(--border-color)',
            display: 'flex',
            alignItems: 'center',
            gap: 1.5
          }}>
            <Box sx={{ position: 'relative' }}>
              <Avatar
                alt={userName}
                src="https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80"
                sx={{ width: 38, height: 38, border: '2px solid var(--primary)' }}
              />
              <Box sx={{
                width: 10,
                height: 10,
                borderRadius: '50%',
                backgroundColor: '#22C55E',
                border: '2px solid var(--bg-sidebar)',
                position: 'absolute',
                bottom: 0,
                right: 0
              }} />
            </Box>

            <Box sx={{ flexGrow: 1, overflow: 'hidden' }}>
              <Typography variant="subtitle2" fontWeight="700" noWrap sx={{ fontSize: '0.85rem' }}>
                {userName}
              </Typography>
              <Typography variant="caption" noWrap sx={{ color: 'var(--text-secondary)', display: 'block', fontSize: '0.72rem' }}>
                {userRole}
              </Typography>
            </Box>

            <MdElectricBolt size={18} color="var(--primary)" />
          </Box>
        </Box>
      )}

      {/* Broadcast Dialog */}
      <Dialog
        open={broadcastOpen}
        onClose={() => setBroadcastOpen(false)}
        PaperProps={{
          sx: {
            backgroundColor: 'var(--bg-card)',
            color: 'var(--text-primary)',
            borderRadius: '20px',
            border: '1px solid var(--border-light)',
            width: 480
          }
        }}
      >
        <DialogTitle sx={{ fontWeight: 800, pb: 1 }}>
          Broadcast Emergency Alert
        </DialogTitle>
        <DialogContent sx={{ display: 'flex', flexDirection: 'column', gap: 2, pt: 1 }}>
          <Typography variant="body2" sx={{ color: 'var(--text-secondary)' }}>
            Send an instant high-priority alert notification to all residents, guardians, and security personnel across registered blocks.
          </Typography>

          {broadcastSent ? (
            <Box sx={{ py: 3, textAlign: 'center' }}>
              <MdCheckCircle size={48} color="#22C55E" style={{ marginBottom: 8 }} />
              <Typography variant="h6" fontWeight="700" color="success.main">
                Broadcast Dispatched!
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Notification sent via Push, SMS, and Email channels.
              </Typography>
            </Box>
          ) : (
            <>
              <TextField
                select
                label="Alert Category"
                value={broadcastCategory}
                onChange={(e) => setBroadcastCategory(e.target.value)}
                fullWidth
                size="small"
              >
                <MenuItem value="General SOS">General SOS Emergency</MenuItem>
                <MenuItem value="Medical SOS">Medical Emergency</MenuItem>
                <MenuItem value="Fire SOS">Fire Safety Emergency</MenuItem>
                <MenuItem value="Security Alert">Security Incident</MenuItem>
              </TextField>

              <TextField
                label="Alert Message"
                multiline
                rows={3}
                placeholder="Enter alert message details..."
                value={broadcastMsg}
                onChange={(e) => setBroadcastMsg(e.target.value)}
                fullWidth
                size="small"
              />
            </>
          )}
        </DialogContent>
        {!broadcastSent && (
          <DialogActions sx={{ px: 3, pb: 2.5 }}>
            <Button onClick={() => setBroadcastOpen(false)} sx={{ color: 'var(--text-secondary)' }}>
              Cancel
            </Button>
            <Button
              variant="contained"
              disabled={!broadcastMsg.trim()}
              onClick={handleSendBroadcast}
              sx={{
                background: 'linear-gradient(135deg, #E93F41 0%, #D92F32 100%)',
                boxShadow: '0 4px 14px rgba(233, 63, 65, 0.3)',
                borderRadius: '10px',
                px: 3
              }}
            >
              Send Broadcast
            </Button>
          </DialogActions>
        )}
      </Dialog>
    </Box>
  );
};

const Sidebar = ({ collapsed = false, mobileOpen = false, onClose, width = 280 }) => {
  return (
    <>
      {/* Desktop Sidebar */}
      <Box sx={{ display: { xs: 'none', md: 'block' }, width, flexShrink: 0, height: '100vh', position: 'sticky', top: 0 }}>
        <SidebarContent collapsed={collapsed} />
      </Box>

      {/* Mobile Drawer */}
      <Drawer
        variant="temporary"
        open={mobileOpen}
        onClose={onClose}
        ModalProps={{ keepMounted: true }}
        sx={{
          display: { xs: 'block', md: 'none' },
          '& .MuiDrawer-paper': {
            boxSizing: 'border-box',
            width: 280,
            backgroundColor: 'var(--bg-sidebar)',
            borderRight: '1px solid var(--border-color)'
          },
        }}
      >
        <SidebarContent collapsed={false} onClose={onClose} />
      </Drawer>
    </>
  );
};

export default Sidebar;
