import React from 'react';
import { Box, Typography, Card, CardContent, Chip } from '@mui/material';
import { MdWarning, MdError, MdInfo } from 'react-icons/md';

const Alerts = () => {
  const alerts = [
    { id: 1, type: 'Critical', message: 'Fire alarm triggered at Block A, Green Valley', time: '10 mins ago', icon: <MdError color="var(--danger)" size={24} /> },
    { id: 2, type: 'Warning', message: 'Maintenance fee overdue for 50 flats in Skyline', time: '2 hours ago', icon: <MdWarning color="var(--warning)" size={24} /> },
    { id: 3, type: 'Info', message: 'System update scheduled at 2 AM', time: '1 day ago', icon: <MdInfo color="var(--primary)" size={24} /> },
  ];

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 4 }}>
        <Typography variant="h5" fontWeight="bold">System Alerts</Typography>
      </Box>

      <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
        {alerts.map((alert) => (
          <Card key={alert.id} sx={{ backgroundColor: 'var(--bg-card)', boxShadow: 'var(--shadow-sm)' }}>
            <CardContent sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                {alert.icon}
                <Box>
                  <Typography variant="subtitle1" fontWeight="bold" sx={{ color: 'var(--text-primary)' }}>
                    {alert.message}
                  </Typography>
                  <Typography variant="body2" sx={{ color: 'var(--text-secondary)' }}>
                    {alert.time}
                  </Typography>
                </Box>
              </Box>
              <Chip 
                label={alert.type} 
                size="small"
                sx={{ 
                  backgroundColor: alert.type === 'Critical' ? 'var(--danger)15' : 
                                   alert.type === 'Warning' ? 'var(--warning)15' : 'var(--primary)15',
                  color: alert.type === 'Critical' ? 'var(--danger)' : 
                         alert.type === 'Warning' ? 'var(--warning)' : 'var(--primary)',
                  fontWeight: 'bold'
                }} 
              />
            </CardContent>
          </Card>
        ))}
      </Box>
    </Box>
  );
};

export default Alerts;
