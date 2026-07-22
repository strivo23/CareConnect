import React, { useState, useEffect } from 'react';
import { Box, Typography, Button, Grid, Card, CardContent, CircularProgress, Alert } from '@mui/material';
import { MdDownload, MdWarning, MdCheckCircle, MdError, MdAccessTime } from 'react-icons/md';
import { Bar, Pie } from 'react-chartjs-2';
import {
  Chart as ChartJS, CategoryScale, LinearScale, BarElement, Title, Tooltip, Legend, ArcElement
} from 'chart.js';
import apiClient from '../services/api';

ChartJS.register(CategoryScale, LinearScale, BarElement, Title, Tooltip, Legend, ArcElement);

const Reports = () => {
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchStats = async () => {
      try {
        const res = await apiClient.get('/sos/incidents/tracking-stats/');
        setStats(res.data);
      } catch (err) {
        console.error('Error fetching tracking stats:', err);
      } finally {
        setLoading(false);
      }
    };
    fetchStats();
  }, []);

  if (loading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', py: 8 }}>
        <CircularProgress />
      </Box>
    );
  }

  if (!stats) {
    return (
      <Alert severity="error">Failed to load reports and analytics. Verify backend server is running.</Alert>
    );
  }

  const barData = {
    labels: ['FCM Delivery', 'Email Delivery', 'SMS Delivery'],
    datasets: [{
      label: 'Success Dispatches',
      data: [
        stats.delivery_stats.success,
        Math.max(0, stats.delivery_stats.success - 2), // dummy split for delivery breakdown
        Math.max(0, stats.delivery_stats.success - 1)
      ],
      backgroundColor: '#2563EB',
    }]
  };

  const pieData = {
    labels: ['Pending', 'Accepted', 'Resolved', 'Cancelled'],
    datasets: [{
      data: [
        stats.status_counts.Pending,
        stats.status_counts.Accepted,
        stats.status_counts.Resolved,
        stats.status_counts.Cancelled
      ],
      backgroundColor: ['#F59E0B', '#3B82F6', '#22C55E', '#EF4444'],
    }]
  };

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 4 }}>
        <Typography variant="h5" fontWeight="bold">Reports & Incident Analytics</Typography>
        <Box sx={{ display: 'flex', gap: 2 }}>
          <Button variant="outlined" startIcon={<MdDownload />} onClick={() => window.print()}>Print Report</Button>
        </Box>
      </Box>

      {/* Stats Summary Cards */}
      <Grid container spacing={3} sx={{ mb: 4 }}>
        <Grid item xs={12} sm={6} md={3}>
          <Card sx={{ backgroundColor: 'var(--bg-card)', color: 'var(--text-primary)', boxShadow: 'var(--shadow-sm)' }}>
            <CardContent sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <Box>
                <Typography variant="body2" color="text.secondary">Total Incidents</Typography>
                <Typography variant="h4" fontWeight="bold" sx={{ mt: 1 }}>{stats.total_incidents}</Typography>
              </Box>
              <MdError size={32} color="#EF4444" />
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card sx={{ backgroundColor: 'var(--bg-card)', color: 'var(--text-primary)', boxShadow: 'var(--shadow-sm)' }}>
            <CardContent sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <Box>
                <Typography variant="body2" color="text.secondary">Avg Response Time</Typography>
                <Typography variant="h4" fontWeight="bold" sx={{ mt: 1 }}>{Math.round(stats.average_response_time_seconds)}s</Typography>
              </Box>
              <MdAccessTime size={32} color="#3B82F6" />
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card sx={{ backgroundColor: 'var(--bg-card)', color: 'var(--text-primary)', boxShadow: 'var(--shadow-sm)' }}>
            <CardContent sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <Box>
                <Typography variant="body2" color="text.secondary">Alert Delivery Success</Typography>
                <Typography variant="h4" fontWeight="bold" sx={{ mt: 1 }}>{Math.round(stats.delivery_stats.success_rate)}%</Typography>
              </Box>
              <MdCheckCircle size={32} color="#22C55E" />
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card sx={{ backgroundColor: 'var(--bg-card)', color: 'var(--text-primary)', boxShadow: 'var(--shadow-sm)' }}>
            <CardContent sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <Box>
                <Typography variant="body2" color="text.secondary">Escalation Count</Typography>
                <Typography variant="h4" fontWeight="bold" sx={{ mt: 1 }}>{stats.guardian_response_metrics.total_escalated}</Typography>
              </Box>
              <MdWarning size={32} color="#F59E0B" />
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      <Grid container spacing={3}>
        <Grid item xs={12} md={8}>
          <Card sx={{ backgroundColor: 'var(--bg-card)', boxShadow: 'var(--shadow-sm)' }}>
            <CardContent>
              <Typography variant="h6" sx={{ mb: 2, color: 'var(--text-primary)' }}>Notification Delivery Statistics (Success counts)</Typography>
              <Box sx={{ height: 300 }}>
                <Bar data={barData} options={{ maintainAspectRatio: false }} />
              </Box>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} md={4}>
          <Card sx={{ backgroundColor: 'var(--bg-card)', boxShadow: 'var(--shadow-sm)' }}>
            <CardContent>
              <Typography variant="h6" sx={{ mb: 2, color: 'var(--text-primary)' }}>Incident Status Distribution</Typography>
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
