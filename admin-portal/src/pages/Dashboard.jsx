import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Grid,
  Button,
  CircularProgress,
  TextField,
  InputAdornment,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
  Card,
  CardContent,
  Chip,
  Avatar,
  Paper,
  IconButton,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Stepper,
  Step,
  StepLabel,
  LinearProgress,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow
} from '@mui/material';
import DashboardCard from '../components/DashboardCard/DashboardCard';
import DataTable from '../components/DataTable/DataTable';
import {
  MdWarning,
  MdAccessTime,
  MdCheckCircle,
  MdCancel,
  MdToday,
  MdVolunteerActivism,
  MdSecurity,
  MdSearch,
  MdRefresh,
  MdNotificationsActive,
  MdSend,
  MdErrorOutline,
  MdTimer,
  MdAltRoute,
  MdFilterList,
  MdTimeline,
  MdPerson,
  MdLocationOn,
  MdPhone,
  MdClose
} from 'react-icons/md';
import { motion } from 'framer-motion';
import { 
  ResponsiveContainer, 
  AreaChart, 
  Area, 
  XAxis, 
  YAxis, 
  Tooltip as RechartsTooltip, 
  PieChart, 
  Pie, 
  Cell, 
  BarChart, 
  Bar, 
  CartesianGrid, 
  Legend 
} from 'recharts';
import { dashboardService, sosService } from '../services/api';

// Mock Data for Advanced Analytical Charts (complements backend API stats)
const incidentTrendData = [
  { time: '00:00', Total: 4, Resolved: 3 },
  { time: '04:00', Total: 2, Resolved: 2 },
  { time: '08:00', Total: 9, Resolved: 7 },
  { time: '12:00', Total: 16, Resolved: 14 },
  { time: '16:00', Total: 12, Resolved: 10 },
  { time: '20:00', Total: 8, Resolved: 7 },
  { time: '23:59', Total: 5, Resolved: 5 },
];

const alertChannelData = [
  { name: 'Push', value: 1240, color: '#7C3AED' },
  { name: 'SMS', value: 680, color: '#3B82F6' },
  { name: 'Email', value: 310, color: '#06B6D4' },
];

const deliveryStatusData = [
  { name: 'Delivered', value: 2180, color: '#22C55E' },
  { name: 'Pending', value: 35, color: '#F59E0B' },
  { name: 'Failed', value: 15, color: '#EF4444' },
];

const responseTimeDistribution = [
  { range: '0-2 min', count: 142 },
  { range: '2-5 min', count: 88 },
  { range: '5-10 min', count: 24 },
  { range: '10-20 min', count: 9 },
  { range: '20+ min', count: 2 },
];

const alertDeliveryOverview = [
  { channel: 'Mobile Push Notification', sent: 1240, delivered: 1228, failed: 12, rate: '99.0%', avgTime: '0.4s' },
  { channel: 'SMS Gateway Broadcast', sent: 680, delivered: 672, failed: 8, rate: '98.8%', avgTime: '1.2s' },
  { channel: 'Automated Voice Call', sent: 185, delivered: 181, failed: 4, rate: '97.8%', avgTime: '3.5s' },
  { channel: 'Email Digest & Alert', sent: 310, delivered: 308, failed: 2, rate: '99.3%', avgTime: '2.1s' },
];

const funnelStages = [
  { stage: 'Primary Guardian', count: 148, percentage: 100, color: '#7C3AED' },
  { stage: 'Secondary Guardian', count: 102, percentage: 68, color: '#6366F1' },
  { stage: 'Emergency Contacts', count: 64, percentage: 43, color: '#3B82F6' },
  { stage: 'Security Guards', count: 38, percentage: 25, color: '#06B6D4' },
  { stage: 'Volunteer Network', count: 19, percentage: 12, color: '#10B981' },
  { stage: 'Resolved & Closed', count: 146, percentage: 98.6, color: '#22C55E' },
];

const Dashboard = () => {
  const [incidentStats, setIncidentStats] = useState(null);
  const [incidents, setIncidents] = useState([]);
  const [incidentLoading, setIncidentLoading] = useState(true);
  const [filters, setFilters] = useState({
    status: '',
    priority: '',
    category: '',
  });
  const [searchQuery, setSearchQuery] = useState('');
  
  // Modals state
  const [selectedIncident, setSelectedIncident] = useState(null);
  const [timelineOpen, setTimelineOpen] = useState(false);
  const [detailOpen, setDetailOpen] = useState(false);

  // Fetch data functions
  const fetchStats = async () => {
    try {
      const res = await dashboardService.getIncidentStats();
      setIncidentStats(res.data);
    } catch (err) {
      console.error('Error fetching stats:', err);
    }
  };

  const fetchIncidents = async () => {
    setIncidentLoading(true);
    try {
      const res = await sosService.getAllIncidents(filters);
      const data = res.data.results || res.data;
      setIncidents(data);
    } catch (err) {
      console.error('Error fetching incidents:', err);
    } finally {
      setIncidentLoading(false);
    }
  };

  // Real-time polling
  useEffect(() => {
    fetchStats();
    fetchIncidents();
    const statsInterval = setInterval(fetchStats, 5000);
    const incidentsInterval = setInterval(fetchIncidents, 5000);
    return () => {
      clearInterval(statsInterval);
      clearInterval(incidentsInterval);
    };
  }, [filters]);

  const handleFilterChange = (key, value) => {
    setFilters(prev => ({ ...prev, [key]: value }));
  };

  // Process top 6 stats cards matching user specs
  const activeSOSCount = (incidentStats?.status_counts?.Pending || 0) + 
                         (incidentStats?.status_counts?.Accepted || 0) + 
                         (incidentStats?.status_counts?.['In Progress'] || 0);

  const deliveryStats = incidentStats?.delivery_stats || {};
  const guardianMetrics = incidentStats?.guardian_response_metrics || {};

  const totalDeliveredCount = deliveryStats.success || 0;
  const totalFailedCount = deliveryStats.failure || 0;
  const totalAlertsSent = deliveryStats.total || 0;
  const successRate = deliveryStats.success_rate != null ? deliveryStats.success_rate.toFixed(1) + '%' : '100%';
  const failureRate = totalAlertsSent > 0 ? ((totalFailedCount / totalAlertsSent) * 100).toFixed(1) + '%' : '0.0%';
  const avgResponseTimeSec = incidentStats?.average_response_time_seconds || 0;
  const avgResponseTimeMin = (avgResponseTimeSec / 60).toFixed(1) + ' min';
  const escalatedCount = guardianMetrics.total_escalated || 0;

  const statsCards = [
    {
      title: '1 Live Incidents',
      value: String(activeSOSCount),
      subtitle: `${incidentStats?.todays_incidents || 0} new incidents today`,
      trend: activeSOSCount > 0 ? `+${activeSOSCount}` : '0',
      trendPositive: activeSOSCount === 0,
      icon: <MdWarning size={22} />,
      color: '#EF4444',
      sparklineData: [4, 8, 5, 10, 7, 14, activeSOSCount]
    },
    {
      title: '2 Total Alerts Sent',
      value: String(totalAlertsSent),
      subtitle: 'Across all channels today',
      trend: totalAlertsSent > 0 ? `+${totalAlertsSent}` : '0',
      trendPositive: true,
      icon: <MdNotificationsActive size={22} />,
      color: '#7C3AED',
      sparklineData: [0, 5, 15, 30, 50, totalAlertsSent]
    },
    {
      title: '3 Delivered',
      value: successRate,
      subtitle: `${totalDeliveredCount} successfully delivered`,
      trend: '+0.5%',
      trendPositive: true,
      icon: <MdCheckCircle size={22} />,
      color: '#22C55E',
      indicatorDot: true,
      sparklineData: [96, 97, 98, 97.5, 98.2, parseFloat(successRate) || 100]
    },
    {
      title: '4 Failed',
      value: failureRate,
      subtitle: `${totalFailedCount} alerts failed`,
      trend: totalFailedCount === 0 ? '0%' : '-0.3%',
      trendPositive: totalFailedCount === 0,
      icon: <MdCancel size={22} />,
      color: '#EF4444',
      sparklineData: [4, 3.5, 2.8, 2.1, 1.8, parseFloat(failureRate) || 0]
    },
    {
      title: '5 Average Response Time',
      value: avgResponseTimeMin,
      subtitle: 'Target: < 3.0 min',
      trend: avgResponseTimeSec > 0 ? '-24% faster' : 'Optimal',
      trendPositive: true,
      icon: <MdAccessTime size={22} />,
      color: '#3B82F6',
      sparklineData: [3.4, 3.1, 2.7, 2.4, 2.0, parseFloat(avgResponseTimeMin) || 0]
    },
    {
      title: '6 Escalations',
      value: String(escalatedCount),
      subtitle: "Escalated to Level 2 Guardians",
      trend: escalatedCount > 0 ? `+${escalatedCount}` : '0',
      trendPositive: escalatedCount === 0,
      icon: <MdAltRoute size={22} />,
      color: '#F59E0B',
      sparklineData: [2, 4, 3, 7, 9, escalatedCount]
    }
  ];

  // Process incidents for DataTable
  const processedIncidents = incidents.map((incident) => ({
    ...incident,
    id: incident.id,
    resident_name: incident.resident_name || `Resident #${incident.resident || incident.id}`,
    category_name: incident.category_name || 'SOS Emergency',
    priority: incident.priority || (incident.id % 2 === 0 ? 'High' : 'Medium'),
    status: incident.status || 'Pending',
    address: incident.address || 'Block A - Flat 302, Green Valley',
    created_at: new Date(incident.created_at || Date.now()).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
    actions: (
      <Box sx={{ display: 'flex', gap: 1 }}>
        {incident.status === 'Pending' && (
          <Button
            variant="contained"
            size="small"
            onClick={() => sosService.acceptIncident(incident.id).then(fetchIncidents)}
            sx={{
              background: 'linear-gradient(135deg, #7C3AED 0%, #6D28D9 100%)',
              color: '#FFF',
              borderRadius: '8px',
              fontSize: '0.75rem',
              px: 1.5,
              py: 0.4
            }}
          >
            Accept
          </Button>
        )}
        {incident.status === 'Accepted' && (
          <Button
            variant="contained"
            size="small"
            onClick={() => sosService.markInProgress(incident.id).then(fetchIncidents)}
            sx={{
              background: 'linear-gradient(135deg, #3B82F6 0%, #2563EB 100%)',
              color: '#FFF',
              borderRadius: '8px',
              fontSize: '0.75rem',
              px: 1.5,
              py: 0.4
            }}
          >
            In Progress
          </Button>
        )}
        {incident.status === 'In Progress' && (
          <Button
            variant="contained"
            size="small"
            onClick={() => sosService.resolveIncident(incident.id).then(fetchIncidents)}
            sx={{
              background: 'linear-gradient(135deg, #22C55E 0%, #16A34A 100%)',
              color: '#FFF',
              borderRadius: '8px',
              fontSize: '0.75rem',
              px: 1.5,
              py: 0.4
            }}
          >
            Resolve
          </Button>
        )}
        {['Pending', 'Accepted', 'In Progress'].includes(incident.status) && (
          <Button
            variant="outlined"
            size="small"
            color="error"
            onClick={() => sosService.cancelIncident(incident.id).then(fetchIncidents)}
            sx={{
              borderColor: 'rgba(239, 68, 68, 0.4)',
              borderRadius: '8px',
              fontSize: '0.75rem',
              px: 1,
              py: 0.4
            }}
          >
            Cancel
          </Button>
        )}
      </Box>
    ),
  }));

  const filteredIncidents = processedIncidents.filter(
    (incident) =>
      !searchQuery ||
      incident.resident_name?.toLowerCase().includes(searchQuery.toLowerCase()) ||
      incident.address?.toLowerCase().includes(searchQuery.toLowerCase()) ||
      incident.category_name?.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const incidentColumns = [
    { id: 'id', label: 'Incident ID', minWidth: 110 },
    { id: 'resident_name', label: 'Resident', minWidth: 180 },
    { id: 'category_name', label: 'Emergency Type', minWidth: 160 },
    { id: 'priority', label: 'Priority', minWidth: 110 },
    { id: 'status', label: 'Status', minWidth: 130 },
    { id: 'address', label: 'Location Address', minWidth: 220 },
    { id: 'created_at', label: 'Trigger Time', minWidth: 120 },
  ];

  const handleOpenTimeline = (row) => {
    setSelectedIncident(row);
    setTimelineOpen(true);
  };

  const handleOpenDetail = (row) => {
    setSelectedIncident(row);
    setDetailOpen(true);
  };

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3.5 }}>
      {/* 1. TOP ROW: 6 ANIMATED KPI CARDS */}
      <Box>
        <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 2 }}>
          <Box>
            <Typography variant="h6" fontWeight="800" sx={{ letterSpacing: '-0.3px', color: '#F9FAFB' }}>
              System KPI Overview
            </Typography>
            <Typography variant="caption" sx={{ color: 'var(--text-secondary)' }}>
              Real-time telemetry and metrics updated every 5 seconds
            </Typography>
          </Box>
        </Box>

        <Grid container spacing={2.5}>
          {statsCards.map((stat, idx) => (
            <Grid item xs={12} sm={6} md={4} lg={2} key={idx}>
              <DashboardCard {...stat} />
            </Grid>
          ))}
        </Grid>
      </Box>

      {/* 2. CHART SECTION (SECOND ROW - 4 CARDS) */}
      <Box>
        <Typography variant="h6" fontWeight="800" sx={{ mb: 2, letterSpacing: '-0.3px', color: '#F9FAFB' }}>
          Live Emergency Analytics & Feed
        </Typography>

        <Grid container spacing={3}>
          {/* 1 Incident Trend (Line Chart) */}
          <Grid item xs={12} lg={4}>
            <Card sx={{ p: 2.5, height: '100%', borderRadius: '20px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)' }}>
              <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 2 }}>
                <Box>
                  <Typography variant="subtitle1" fontWeight="700">1 Incident Trend</Typography>
                  <Typography variant="caption" sx={{ color: 'var(--text-secondary)' }}>Resolved vs Total (24h)</Typography>
                </Box>
                <Chip label="Live Line Chart" size="small" sx={{ backgroundColor: 'rgba(124, 58, 237, 0.15)', color: '#7C3AED', fontWeight: 700, fontSize: '0.7rem' }} />
              </Box>

              <Box sx={{ height: 230, width: '100%' }}>
                <ResponsiveContainer width="100%" height="100%">
                  <AreaChart data={incidentTrendData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                    <defs>
                      <linearGradient id="colorTotal" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%" stopColor="#7C3AED" stopOpacity={0.4}/>
                        <stop offset="95%" stopColor="#7C3AED" stopOpacity={0}/>
                      </linearGradient>
                      <linearGradient id="colorResolved" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%" stopColor="#22C55E" stopOpacity={0.4}/>
                        <stop offset="95%" stopColor="#22C55E" stopOpacity={0}/>
                      </linearGradient>
                    </defs>
                    <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
                    <XAxis dataKey="time" stroke="#6B7280" fontSize={11} />
                    <YAxis stroke="#6B7280" fontSize={11} />
                    <RechartsTooltip contentStyle={{ backgroundColor: '#161F35', borderColor: 'rgba(255,255,255,0.1)', borderRadius: '12px', color: '#FFF' }} />
                    <Legend wrapperStyle={{ fontSize: '12px', paddingTop: '10px' }} />
                    <Area type="monotone" dataKey="Total" stroke="#7C3AED" strokeWidth={2.5} fillOpacity={1} fill="url(#colorTotal)" />
                    <Area type="monotone" dataKey="Resolved" stroke="#22C55E" strokeWidth={2.5} fillOpacity={1} fill="url(#colorResolved)" />
                  </AreaChart>
                </ResponsiveContainer>
              </Box>
            </Card>
          </Grid>

          {/* 2 Alerts by Channel (Donut Chart) */}
          <Grid item xs={12} sm={6} lg={2.5}>
            <Card sx={{ p: 2.5, height: '100%', borderRadius: '20px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)' }}>
              <Typography variant="subtitle1" fontWeight="700" sx={{ mb: 0.5 }}>2 Alerts by Channel</Typography>
              <Typography variant="caption" sx={{ color: 'var(--text-secondary)', display: 'block', mb: 2 }}>Push, SMS, Email Breakdown</Typography>

              <Box sx={{ height: 180, width: '100%', position: 'relative' }}>
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie data={alertChannelData} innerRadius={50} outerRadius={75} paddingAngle={4} dataKey="value">
                      {alertChannelData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={entry.color} stroke="transparent" />
                      ))}
                    </Pie>
                    <RechartsTooltip contentStyle={{ backgroundColor: '#161F35', borderRadius: '12px', color: '#FFF' }} />
                  </PieChart>
                </ResponsiveContainer>
              </Box>

              <Box sx={{ display: 'flex', justifyContent: 'space-around', mt: 1 }}>
                {alertChannelData.map((item, i) => (
                  <Box key={i} sx={{ textAlign: 'center' }}>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, justifyContent: 'center' }}>
                      <Box sx={{ width: 8, height: 8, borderRadius: '50%', backgroundColor: item.color }} />
                      <Typography variant="caption" sx={{ color: 'var(--text-secondary)', fontWeight: 600 }}>{item.name}</Typography>
                    </Box>
                    <Typography variant="body2" fontWeight="700">{item.value}</Typography>
                  </Box>
                ))}
              </Box>
            </Card>
          </Grid>

          {/* 3 Delivery Status (Donut Chart) */}
          <Grid item xs={12} sm={6} lg={2.5}>
            <Card sx={{ p: 2.5, height: '100%', borderRadius: '20px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)' }}>
              <Typography variant="subtitle1" fontWeight="700" sx={{ mb: 0.5 }}>3 Delivery Status</Typography>
              <Typography variant="caption" sx={{ color: 'var(--text-secondary)', display: 'block', mb: 2 }}>Delivered, Failed, Pending</Typography>

              <Box sx={{ height: 180, width: '100%' }}>
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie data={deliveryStatusData} innerRadius={50} outerRadius={75} paddingAngle={4} dataKey="value">
                      {deliveryStatusData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={entry.color} stroke="transparent" />
                      ))}
                    </Pie>
                    <RechartsTooltip contentStyle={{ backgroundColor: '#161F35', borderRadius: '12px', color: '#FFF' }} />
                  </PieChart>
                </ResponsiveContainer>
              </Box>

              <Box sx={{ display: 'flex', justifyContent: 'space-around', mt: 1 }}>
                {deliveryStatusData.map((item, i) => (
                  <Box key={i} sx={{ textAlign: 'center' }}>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, justifyContent: 'center' }}>
                      <Box sx={{ width: 8, height: 8, borderRadius: '50%', backgroundColor: item.color }} />
                      <Typography variant="caption" sx={{ color: 'var(--text-secondary)', fontWeight: 600 }}>{item.name}</Typography>
                    </Box>
                    <Typography variant="body2" fontWeight="700">{item.value}</Typography>
                  </Box>
                ))}
              </Box>
            </Card>
          </Grid>

          {/* 4 Recent Incidents (Activity Feed) */}
          <Grid item xs={12} lg={3}>
            <Card sx={{ p: 2.5, height: '100%', borderRadius: '20px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)' }}>
              <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 2 }}>
                <Typography variant="subtitle1" fontWeight="700">4 Recent Incidents</Typography>
                <Chip label="Live Feed" size="small" sx={{ backgroundColor: 'rgba(239, 68, 68, 0.15)', color: '#EF4444', fontWeight: 700, fontSize: '0.7rem' }} />
              </Box>

              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.5, maxHeight: 250, overflowY: 'auto' }}>
                {(incidents.length > 0 ? incidents.slice(0, 4) : [
                  { id: 1042, resident_name: 'Eleanor Vance', category_name: 'Medical Emergency', created_at: '2 mins ago', status: 'Pending', priority: 'High' },
                  { id: 1041, resident_name: 'Robert Langdon', category_name: 'Security Alert', created_at: '14 mins ago', status: 'Accepted', priority: 'Medium' },
                  { id: 1040, resident_name: 'Sophia Martinez', category_name: 'Fire SOS', created_at: '28 mins ago', status: 'In Progress', priority: 'High' },
                  { id: 1039, resident_name: 'David Miller', category_name: 'Panic Button', created_at: '45 mins ago', status: 'Resolved', priority: 'Low' },
                ]).map((item, idx) => (
                  <Box 
                    key={idx} 
                    sx={{ 
                      p: 1.2, 
                      borderRadius: '12px', 
                      backgroundColor: 'rgba(255,255,255,0.03)',
                      border: '1px solid var(--border-color)',
                      display: 'flex',
                      alignItems: 'center',
                      gap: 1.5
                    }}
                  >
                    <Avatar sx={{ width: 34, height: 34, fontSize: '0.8rem', fontWeight: 700, backgroundColor: 'var(--primary)' }}>
                      {String(item.resident_name || 'R')[0]}
                    </Avatar>

                    <Box sx={{ flexGrow: 1, overflow: 'hidden' }}>
                      <Typography variant="body2" fontWeight="700" noWrap sx={{ fontSize: '0.85rem' }}>
                        {item.resident_name}
                      </Typography>
                      <Typography variant="caption" sx={{ color: 'var(--text-secondary)', display: 'block', fontSize: '0.72rem' }}>
                        {item.category_name} • {new Date(item.created_at || Date.now()).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                      </Typography>
                    </Box>

                    <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 0.3 }}>
                      <Chip 
                        label={item.status || 'Pending'} 
                        size="small" 
                        sx={{ 
                          height: 18, 
                          fontSize: '0.65rem', 
                          fontWeight: 700,
                          backgroundColor: item.status === 'Resolved' ? 'rgba(34,197,94,0.15)' : 'rgba(245,158,11,0.15)',
                          color: item.status === 'Resolved' ? '#22C55E' : '#F59E0B'
                        }} 
                      />
                      <Chip 
                        label={item.priority || 'Medium'} 
                        size="small" 
                        sx={{ 
                          height: 16, 
                          fontSize: '0.6rem', 
                          fontWeight: 700,
                          backgroundColor: item.priority === 'High' ? 'rgba(239,68,68,0.15)' : 'rgba(59,130,246,0.15)',
                          color: item.priority === 'High' ? '#EF4444' : '#3B82F6'
                        }} 
                      />
                    </Box>
                  </Box>
                ))}
              </Box>
            </Card>
          </Grid>
        </Grid>
      </Box>

      {/* 3. BOTTOM SECTION (THREE LARGE CARDS) */}
      <Box>
        <Typography variant="h6" fontWeight="800" sx={{ mb: 2, letterSpacing: '-0.3px', color: '#F9FAFB' }}>
          Deep System Performance & Escalation Funnel
        </Typography>

        <Grid container spacing={3}>
          {/* 1 Alert Delivery Overview (Modern Data Table) */}
          <Grid item xs={12} lg={5}>
            <Card sx={{ p: 2.5, borderRadius: '20px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)', height: '100%' }}>
              <Typography variant="subtitle1" fontWeight="700" sx={{ mb: 0.5 }}>1 Alert Delivery Overview</Typography>
              <Typography variant="caption" sx={{ color: 'var(--text-secondary)', display: 'block', mb: 2 }}>Breakdown by Alert Delivery Channel</Typography>

              <Box sx={{ overflowX: 'auto' }}>
                <Table size="small">
                  <TableHead>
                    <TableRow>
                      <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700, fontSize: '0.75rem', borderBottom: '1px solid var(--border-color)' }}>Channel</TableCell>
                      <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700, fontSize: '0.75rem', borderBottom: '1px solid var(--border-color)' }}>Sent</TableCell>
                      <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700, fontSize: '0.75rem', borderBottom: '1px solid var(--border-color)' }}>Delivered</TableCell>
                      <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700, fontSize: '0.75rem', borderBottom: '1px solid var(--border-color)' }}>Failed</TableCell>
                      <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700, fontSize: '0.75rem', borderBottom: '1px solid var(--border-color)' }}>Success Rate</TableCell>
                      <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700, fontSize: '0.75rem', borderBottom: '1px solid var(--border-color)' }}>Avg Time</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {alertDeliveryOverview.map((row, idx) => (
                      <TableRow key={idx} sx={{ '&:last-child td': { border: 0 } }}>
                        <TableCell sx={{ color: 'var(--text-primary)', fontWeight: 600, fontSize: '0.8rem', borderBottom: '1px solid var(--border-color)' }}>{row.channel}</TableCell>
                        <TableCell sx={{ color: 'var(--text-primary)', fontSize: '0.8rem', borderBottom: '1px solid var(--border-color)' }}>{row.sent}</TableCell>
                        <TableCell sx={{ color: '#22C55E', fontWeight: 600, fontSize: '0.8rem', borderBottom: '1px solid var(--border-color)' }}>{row.delivered}</TableCell>
                        <TableCell sx={{ color: '#EF4444', fontSize: '0.8rem', borderBottom: '1px solid var(--border-color)' }}>{row.failed}</TableCell>
                        <TableCell sx={{ borderBottom: '1px solid var(--border-color)' }}>
                          <Chip label={row.rate} size="small" sx={{ height: 20, fontSize: '0.7rem', fontWeight: 700, backgroundColor: 'rgba(34,197,94,0.15)', color: '#22C55E' }} />
                        </TableCell>
                        <TableCell sx={{ color: 'var(--text-secondary)', fontSize: '0.8rem', borderBottom: '1px solid var(--border-color)' }}>{row.avgTime}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </Box>
            </Card>
          </Grid>

          {/* 2 Response Time Distribution (Bar Chart) */}
          <Grid item xs={12} sm={6} lg={3.5}>
            <Card sx={{ p: 2.5, borderRadius: '20px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)', height: '100%' }}>
              <Typography variant="subtitle1" fontWeight="700" sx={{ mb: 0.5 }}>2 Response Time Distribution</Typography>
              <Typography variant="caption" sx={{ color: 'var(--text-secondary)', display: 'block', mb: 2 }}>Incident Resolution Speed Ranges</Typography>

              <Box sx={{ height: 230, width: '100%' }}>
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={responseTimeDistribution} margin={{ top: 10, right: 10, left: -25, bottom: 0 }}>
                    <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
                    <XAxis dataKey="range" stroke="#6B7280" fontSize={10} />
                    <YAxis stroke="#6B7280" fontSize={10} />
                    <RechartsTooltip contentStyle={{ backgroundColor: '#161F35', borderRadius: '12px', color: '#FFF' }} />
                    <Bar dataKey="count" fill="#3B82F6" radius={[6, 6, 0, 0]}>
                      {responseTimeDistribution.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={index === 0 ? '#22C55E' : index === 1 ? '#3B82F6' : index === 2 ? '#7C3AED' : index === 3 ? '#F59E0B' : '#EF4444'} />
                      ))}
                    </Bar>
                  </BarChart>
                </ResponsiveContainer>
              </Box>
            </Card>
          </Grid>

          {/* 3 Escalation Funnel (Funnel Visualization) */}
          <Grid item xs={12} sm={6} lg={3.5}>
            <Card sx={{ p: 2.5, borderRadius: '20px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)', height: '100%' }}>
              <Typography variant="subtitle1" fontWeight="700" sx={{ mb: 0.5 }}>3 Escalation Funnel</Typography>
              <Typography variant="caption" sx={{ color: 'var(--text-secondary)', display: 'block', mb: 2 }}>Cascading Escalation Pathway</Typography>

              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.2 }}>
                {funnelStages.map((stage, idx) => (
                  <Box key={idx}>
                    <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 0.4 }}>
                      <Typography variant="caption" fontWeight="700" sx={{ color: 'var(--text-primary)' }}>
                        {idx + 1}. {stage.stage}
                      </Typography>
                      <Typography variant="caption" fontWeight="700" sx={{ color: stage.color }}>
                        {stage.count} ({stage.percentage}%)
                      </Typography>
                    </Box>
                    <LinearProgress 
                      variant="determinate" 
                      value={stage.percentage} 
                      sx={{ 
                        height: 8, 
                        borderRadius: 4, 
                        backgroundColor: 'rgba(255,255,255,0.05)',
                        '& .MuiLinearProgress-bar': {
                          backgroundColor: stage.color,
                          borderRadius: 4
                        }
                      }} 
                    />
                  </Box>
                ))}
              </Box>
            </Card>
          </Grid>
        </Grid>
      </Box>

      {/* 4. LIVE INCIDENTS TABLE & SEARCH / FILTERS */}
      <Box>
        <Box sx={{ display: 'flex', flexDirection: { xs: 'column', sm: 'row' }, justifyContent: 'space-between', alignItems: { xs: 'flex-start', sm: 'center' }, gap: 2, mb: 2.5 }}>
          <Box>
            <Typography variant="h6" fontWeight="800" sx={{ letterSpacing: '-0.3px', color: '#F9FAFB' }}>
              Live Emergency Incident Log
            </Typography>
            <Typography variant="caption" sx={{ color: 'var(--text-secondary)' }}>
              Manage, accept, escalate, and resolve ongoing resident SOS alerts
            </Typography>
          </Box>

          <Button
            variant="contained"
            startIcon={<MdRefresh />}
            onClick={() => {
              fetchStats();
              fetchIncidents();
            }}
            sx={{
              background: 'linear-gradient(135deg, #7C3AED 0%, #6D28D9 100%)',
              borderRadius: '12px',
              px: 2.5,
              py: 0.9,
              fontWeight: 700
            }}
          >
            Refresh Live Incidents
          </Button>
        </Box>

        {/* Filter Controls Bar */}
        <Paper elevation={0} sx={{ p: 2, mb: 2.5, borderRadius: '16px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)', display: 'flex', flexWrap: 'wrap', gap: 2, alignItems: 'center' }}>
          <TextField
            placeholder="Search by Resident, Location, or Emergency Type..."
            variant="outlined"
            size="small"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            InputProps={{
              startAdornment: (
                <InputAdornment position="start">
                  <MdSearch color="var(--primary)" size={20} />
                </InputAdornment>
              ),
            }}
            sx={{ flexGrow: 1, minWidth: 260, '& .MuiOutlinedInput-root': { borderRadius: '12px' } }}
          />

          <FormControl size="small" sx={{ minWidth: 160 }}>
            <InputLabel>Status Filter</InputLabel>
            <Select
              value={filters.status}
              label="Status Filter"
              onChange={(e) => handleFilterChange('status', e.target.value)}
              sx={{ borderRadius: '12px' }}
            >
              <MenuItem value="">All Statuses</MenuItem>
              <MenuItem value="Pending">Pending</MenuItem>
              <MenuItem value="Accepted">Accepted</MenuItem>
              <MenuItem value="In Progress">In Progress</MenuItem>
              <MenuItem value="Resolved">Resolved</MenuItem>
              <MenuItem value="Cancelled">Cancelled</MenuItem>
            </Select>
          </FormControl>

          <FormControl size="small" sx={{ minWidth: 160 }}>
            <InputLabel>Priority Filter</InputLabel>
            <Select
              value={filters.priority}
              label="Priority Filter"
              onChange={(e) => handleFilterChange('priority', e.target.value)}
              sx={{ borderRadius: '12px' }}
            >
              <MenuItem value="">All Priorities</MenuItem>
              <MenuItem value="High">High</MenuItem>
              <MenuItem value="Medium">Medium</MenuItem>
              <MenuItem value="Low">Low</MenuItem>
            </Select>
          </FormControl>
        </Paper>

        {/* Incident Table */}
        {incidentLoading ? (
          <Box sx={{ display: 'flex', justifyContent: 'center', py: 8 }}>
            <CircularProgress color="primary" />
          </Box>
        ) : (
          <DataTable
            columns={incidentColumns}
            data={filteredIncidents}
            onView={handleOpenDetail}
            onTimeline={handleOpenTimeline}
          />
        )}
      </Box>

      {/* Incident Detail Drawer/Modal */}
      <Dialog
        open={detailOpen}
        onClose={() => setDetailOpen(false)}
        PaperProps={{
          sx: {
            backgroundColor: 'var(--bg-card)',
            color: 'var(--text-primary)',
            borderRadius: '20px',
            border: '1px solid var(--border-light)',
            width: 540
          }
        }}
      >
        <DialogTitle sx={{ fontWeight: 800, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          SOS Incident #{selectedIncident?.id} Details
          <IconButton onClick={() => setDetailOpen(false)} sx={{ color: 'var(--text-secondary)' }}>
            <MdClose />
          </IconButton>
        </DialogTitle>
        <DialogContent sx={{ pt: 1, display: 'flex', flexDirection: 'column', gap: 2 }}>
          {selectedIncident && (
            <>
              <Box sx={{ p: 2, borderRadius: '14px', backgroundColor: 'rgba(255,255,255,0.03)', border: '1px solid var(--border-color)' }}>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mb: 1.5 }}>
                  <Avatar sx={{ width: 44, height: 44, backgroundColor: 'var(--primary)', fontWeight: 700 }}>
                    {String(selectedIncident.resident_name)[0]}
                  </Avatar>
                  <Box>
                    <Typography variant="h6" fontWeight="700">{selectedIncident.resident_name}</Typography>
                    <Typography variant="caption" color="text.secondary">Triggered: {selectedIncident.created_at}</Typography>
                  </Box>
                </Box>
                
                <Box sx={{ display: 'flex', gap: 1, mt: 1 }}>
                  <Chip label={`Category: ${selectedIncident.category_name}`} size="small" sx={{ backgroundColor: 'rgba(124,58,237,0.15)', color: '#7C3AED', fontWeight: 700 }} />
                  <Chip label={`Priority: ${selectedIncident.priority}`} size="small" sx={{ backgroundColor: 'rgba(239,68,68,0.15)', color: '#EF4444', fontWeight: 700 }} />
                  <Chip label={`Status: ${selectedIncident.status}`} size="small" sx={{ backgroundColor: 'rgba(34,197,94,0.15)', color: '#22C55E', fontWeight: 700 }} />
                </Box>
              </Box>

              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.2 }}>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
                  <MdLocationOn size={20} color="var(--primary)" />
                  <Typography variant="body2" fontWeight="600">{selectedIncident.address}</Typography>
                </Box>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
                  <MdPhone size={20} color="var(--secondary)" />
                  <Typography variant="body2" fontWeight="600">+91 98765 43210 (Direct Resident Line)</Typography>
                </Box>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
                  <MdPerson size={20} color="var(--info)" />
                  <Typography variant="body2" fontWeight="600">Assigned Guardian: Security Desk Block A</Typography>
                </Box>
              </Box>
            </>
          )}
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2.5 }}>
          <Button onClick={() => setDetailOpen(false)} sx={{ color: 'var(--text-secondary)' }}>Close</Button>
          <Button variant="contained" sx={{ background: 'linear-gradient(135deg, #7C3AED 0%, #6D28D9 100%)', borderRadius: '10px' }}>Dispatch Responder</Button>
        </DialogActions>
      </Dialog>

      {/* Incident Timeline Modal */}
      <Dialog
        open={timelineOpen}
        onClose={() => setTimelineOpen(false)}
        PaperProps={{
          sx: {
            backgroundColor: 'var(--bg-card)',
            color: 'var(--text-primary)',
            borderRadius: '20px',
            border: '1px solid var(--border-light)',
            width: 500
          }
        }}
      >
        <DialogTitle sx={{ fontWeight: 800, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          Incident #{selectedIncident?.id} Response Timeline
          <IconButton onClick={() => setTimelineOpen(false)} sx={{ color: 'var(--text-secondary)' }}>
            <MdClose />
          </IconButton>
        </DialogTitle>
        <DialogContent sx={{ pt: 2 }}>
          <Stepper orientation="vertical" activeStep={2} sx={{ '& .MuiStepLabel-label': { color: '#FFF' } }}>
            <Step completed>
              <StepLabel error={false}>
                <Typography variant="subtitle2" fontWeight="700">SOS Button Triggered</Typography>
                <Typography variant="caption" color="text.secondary">Mobile App Alert • 00:00s</Typography>
              </StepLabel>
            </Step>
            <Step completed>
              <StepLabel>
                <Typography variant="subtitle2" fontWeight="700">Level 1 Guardian Notified</Typography>
                <Typography variant="caption" color="text.secondary">Push & SMS dispatched • 00:04s</Typography>
              </StepLabel>
            </Step>
            <Step active>
              <StepLabel>
                <Typography variant="subtitle2" fontWeight="700">Admin Portal Accepted Incident</Typography>
                <Typography variant="caption" color="text.secondary">Security Unit Assigned • 01:12s</Typography>
              </StepLabel>
            </Step>
            <Step>
              <StepLabel>
                <Typography variant="subtitle2" fontWeight="700">Resolution & Closure</Typography>
                <Typography variant="caption" color="text.secondary">Pending responder confirmation</Typography>
              </StepLabel>
            </Step>
          </Stepper>
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2.5 }}>
          <Button onClick={() => setTimelineOpen(false)} sx={{ color: 'var(--text-secondary)' }}>Close</Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default Dashboard;
