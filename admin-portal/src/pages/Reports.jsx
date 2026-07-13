import React from 'react';
import { Box, Typography, Button, Grid, Card, CardContent } from '@mui/material';
import { MdDownload } from 'react-icons/md';
import { Bar, Pie } from 'react-chartjs-2';
import {
  Chart as ChartJS, CategoryScale, LinearScale, BarElement, Title, Tooltip, Legend, ArcElement
} from 'chart.js';

ChartJS.register(CategoryScale, LinearScale, BarElement, Title, Tooltip, Legend, ArcElement);

const Reports = () => {
  const barData = {
    labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
    datasets: [{
      label: 'New Societies',
      data: [12, 19, 3, 5, 2, 3],
      backgroundColor: '#2563EB',
    }]
  };

  const pieData = {
    labels: ['Active', 'Inactive', 'Under Maintenance'],
    datasets: [{
      data: [300, 50, 100],
      backgroundColor: ['#22C55E', '#EF4444', '#F59E0B'],
    }]
  };

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 4 }}>
        <Typography variant="h5" fontWeight="bold">Reports & Analytics</Typography>
        <Box sx={{ display: 'flex', gap: 2 }}>
          <Button variant="outlined" startIcon={<MdDownload />}>Export PDF</Button>
          <Button variant="outlined" startIcon={<MdDownload />}>Export Excel</Button>
        </Box>
      </Box>

      <Grid container spacing={3}>
        <Grid xs={12} md={8}>
          <Card sx={{ backgroundColor: 'var(--bg-card)', boxShadow: 'var(--shadow-sm)' }}>
            <CardContent>
              <Typography variant="h6" sx={{ mb: 2, color: 'var(--text-primary)' }}>Societies Onboarded (Monthly)</Typography>
              <Box sx={{ height: 300 }}>
                <Bar data={barData} options={{ maintainAspectRatio: false }} />
              </Box>
            </CardContent>
          </Card>
        </Grid>
        <Grid xs={12} md={4}>
          <Card sx={{ backgroundColor: 'var(--bg-card)', boxShadow: 'var(--shadow-sm)' }}>
            <CardContent>
              <Typography variant="h6" sx={{ mb: 2, color: 'var(--text-primary)' }}>Society Status Distribution</Typography>
              <Box sx={{ height: 300 }}>
                <Pie data={pieData} options={{ maintainAspectRatio: false }} />
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
};

export default Reports;
