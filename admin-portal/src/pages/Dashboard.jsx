import React, { useState, useEffect } from 'react';
import { Box, Typography, Grid, Button, CircularProgress } from '@mui/material';
import DashboardCard from '../components/DashboardCard/DashboardCard';
import DataTable from '../components/DataTable/DataTable';
import { 
  MdLocationCity, MdDomain, MdMeetingRoom, 
  MdPeople, MdAdminPanelSettings, MdNotificationsActive,
  MdAdd
} from 'react-icons/md';
import { dashboardService } from '../services/api';

const Dashboard = () => {
  const [realStats, setRealStats] = useState({
    total_societies: 0,
    total_blocks: 0,
    total_flats: 0,
    total_residents: 0,
    total_users: 0,
    total_alerts: 0
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchStats = async () => {
      try {
        const res = await dashboardService.getStats();
        setRealStats(res.data);
      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    };
    fetchStats();
  }, []);

  const stats = [
    { title: 'Total Societies', value: String(realStats.total_societies), icon: <MdLocationCity size={24} />, color: '#2563EB' },
    { title: 'Total Blocks', value: String(realStats.total_blocks), icon: <MdDomain size={24} />, color: '#22C55E' },
    { title: 'Total Flats', value: String(realStats.total_flats), icon: <MdMeetingRoom size={24} />, color: '#F59E0B' },
    { title: 'Total Residents', value: String(realStats.total_residents), icon: <MdPeople size={24} />, color: '#8B5CF6' },
    { title: 'Total Users', value: String(realStats.total_users), icon: <MdAdminPanelSettings size={24} />, color: '#EC4899' },
    { title: 'Total Alerts', value: String(realStats.total_alerts), icon: <MdNotificationsActive size={24} />, color: '#EF4444' },
  ];

  // Dummy recent activities (we can leave this or load it dynamically later)
  const recentActivities = [
    { id: 1, action: 'New Society Added', details: 'Green Valley Residency registered', date: '2026-07-08 10:30 AM', user: 'Admin' },
    { id: 2, action: 'Alert Triggered', details: 'Fire alarm at Tower B, Skyline Apts', date: '2026-07-08 09:15 AM', user: 'System' },
    { id: 3, action: 'User Created', details: 'Security Guard role created for John Doe', date: '2026-07-07 04:45 PM', user: 'Admin' },
    { id: 4, action: 'Resident Approved', details: 'Flat 101, Oakwood Society', date: '2026-07-07 02:20 PM', user: 'Manager' },
  ];

  const activityColumns = [
    { id: 'action', label: 'Action', minWidth: 150 },
    { id: 'details', label: 'Details', minWidth: 250 },
    { id: 'date', label: 'Date/Time', minWidth: 170 },
    { id: 'user', label: 'Performed By', minWidth: 120 },
  ];

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 4 }}>
        <Box>
          <Typography variant="h4" fontWeight="bold" sx={{ mb: 1 }}>
            Welcome back, Super Admin!
          </Typography>
          <Typography variant="body1" color="text.secondary">
            Here's what's happening across all registered societies today.
          </Typography>
        </Box>
        <Box sx={{ display: 'flex', gap: 2 }}>
          <Button variant="contained" color="primary" startIcon={<MdAdd />}>
            Add Society
          </Button>
          <Button variant="outlined" color="primary">
            View Reports
          </Button>
        </Box>
      </Box>

      {/* Stats Grid */}
      {loading ? (
        <Box sx={{ display: 'flex', justifyContent: 'center', py: 5 }}>
          <CircularProgress />
        </Box>
      ) : (
        <Grid container spacing={3} sx={{ mb: 4 }}>
          {stats.map((stat, index) => (
            <Grid item xs={12} sm={6} md={4} lg={2} key={index}>
              <DashboardCard {...stat} />
            </Grid>
          ))}
        </Grid>
      )}

      {/* System Overview & Recent Activities */}
      <Grid container spacing={3}>
        <Grid item xs={12} lg={8}>
          <Typography variant="h6" fontWeight="bold" sx={{ mb: 2 }}>
            Recent Activities
          </Typography>
          <DataTable 
            columns={activityColumns} 
            data={recentActivities} 
            onView={(row) => console.log('View', row)}
          />
        </Grid>
        <Grid item xs={12} lg={4}>
          <Typography variant="h6" fontWeight="bold" sx={{ mb: 2 }}>
            System Overview
          </Typography>
          <Box sx={{ p: 3, backgroundColor: 'var(--bg-card)', borderRadius: '12px', boxShadow: 'var(--shadow-sm)' }}>
             <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
               System Health: <strong style={{ color: 'var(--success)' }}>Good</strong>
             </Typography>
             <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
               Active Sessions: <strong>1,240</strong>
             </Typography>
             <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
               Server Load: <strong>34%</strong>
             </Typography>
             <Box sx={{ mt: 3, height: 150, backgroundColor: 'var(--bg-main)', borderRadius: '8px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <Typography color="text.secondary">Chart Placeholder</Typography>
             </Box>
          </Box>
        </Grid>
      </Grid>
    </Box>
  );
};

export default Dashboard;
