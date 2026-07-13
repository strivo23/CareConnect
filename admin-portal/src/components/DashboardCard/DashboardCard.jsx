import React from 'react';
import { Card, CardContent, Typography, Box } from '@mui/material';

const DashboardCard = ({ title, value, icon, color }) => {
  return (
    <Card sx={{ 
      backgroundColor: 'var(--bg-card)', 
      color: 'var(--text-primary)',
      transition: 'transform 0.2s',
      '&:hover': { transform: 'translateY(-4px)' }
    }}>
      <CardContent sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <Box>
          <Typography variant="subtitle2" sx={{ color: 'var(--text-secondary)', mb: 1 }}>
            {title}
          </Typography>
          <Typography variant="h4" fontWeight="bold">
            {value}
          </Typography>
        </Box>
        <Box sx={{ 
          backgroundColor: `${color}15`, 
          color: color,
          p: 1.5, 
          borderRadius: '12px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center'
        }}>
          {icon}
        </Box>
      </CardContent>
    </Card>
  );
};

export default DashboardCard;
