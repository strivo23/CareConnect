import React from 'react';
import { Box, Typography, Card, CardContent, Divider, Switch, FormGroup, FormControlLabel, Button, TextField } from '@mui/material';

const Settings = () => {
  return (
    <Box sx={{ maxWidth: 800 }}>
      <Typography variant="h5" fontWeight="bold" sx={{ mb: 4 }}>Settings</Typography>

      <Card sx={{ mb: 3, backgroundColor: 'var(--bg-card)', color: 'var(--text-primary)', boxShadow: 'var(--shadow-sm)' }}>
        <CardContent>
          <Typography variant="h6" sx={{ mb: 2 }}>Profile Settings</Typography>
          <Divider sx={{ mb: 3, borderColor: 'var(--border-color)' }} />
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
            <TextField label="Full Name" defaultValue="Super Admin" variant="outlined" fullWidth />
            <TextField label="Email Address" defaultValue="admin@careconnect.com" variant="outlined" fullWidth />
            <Button variant="contained" sx={{ width: 'fit-content' }}>Save Profile</Button>
          </Box>
        </CardContent>
      </Card>

      <Card sx={{ mb: 3, backgroundColor: 'var(--bg-card)', color: 'var(--text-primary)', boxShadow: 'var(--shadow-sm)' }}>
        <CardContent>
          <Typography variant="h6" sx={{ mb: 2 }}>Password Change</Typography>
          <Divider sx={{ mb: 3, borderColor: 'var(--border-color)' }} />
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
            <TextField label="Current Password" type="password" variant="outlined" fullWidth />
            <TextField label="New Password" type="password" variant="outlined" fullWidth />
            <TextField label="Confirm New Password" type="password" variant="outlined" fullWidth />
            <Button variant="contained" color="primary" sx={{ width: 'fit-content' }}>Update Password</Button>
          </Box>
        </CardContent>
      </Card>

      <Card sx={{ backgroundColor: 'var(--bg-card)', color: 'var(--text-primary)', boxShadow: 'var(--shadow-sm)' }}>
        <CardContent>
          <Typography variant="h6" sx={{ mb: 2 }}>Notification Settings</Typography>
          <Divider sx={{ mb: 3, borderColor: 'var(--border-color)' }} />
          <FormGroup>
            <FormControlLabel control={<Switch defaultChecked />} label="Email Notifications for Critical Alerts" />
            <FormControlLabel control={<Switch defaultChecked />} label="Daily Summary Reports" />
            <FormControlLabel control={<Switch />} label="SMS Alerts (Requires configuration)" />
          </FormGroup>
        </CardContent>
      </Card>
    </Box>
  );
};

export default Settings;
