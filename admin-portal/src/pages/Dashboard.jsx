
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
  Chip,
  Avatar,
  Paper,
  IconButton,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  LinearProgress,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  Tabs,
  Tab
} from '@mui/material';
import DashboardCard from '../components/DashboardCard/DashboardCard';
import DataTable from '../components/DataTable/DataTable';
import {
  MdWarning,
  MdCheckCircle,
  MdCancel,
  MdToday,
  MdVolunteerActivism,
  MdSecurity,
  MdSearch,
  MdRefresh,
  MdNotificationsActive,
  MdTimer,
  MdAltRoute,
  MdTimeline,
  MdPerson,
  MdLocationOn,
  MdClose,
  MdAssessment,
  MdSend,
  MdSpeed,
  MdCategory,
  MdFilterList
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
  Legend,
  LineChart,
  Line
} from 'recharts';
import { dashboardService, sosService, societyService } from '../services/api';
import EmergencyChatDrawer from '../components/EmergencyChatDrawer';
import ResponseUpdatesPanel from '../components/ResponseUpdatesPanel';
import SecurityOverviewWidget from '../components/SecurityOverviewWidget';

const Dashboard = () => {
  const [activeTab, setActiveTab] = useState(0);
  const [dashboardSummary, setDashboardSummary] = useState(null);
  const [notificationTracking, setNotificationTracking] = useState(null);
  const [responseMonitoring, setResponseMonitoring] = useState(null);
  const [incidents, setIncidents] = useState([]);
  const [societies, setSocieties] = useState([]);
  const [incidentLoading, setIncidentLoading] = useState(true);

  const [filters, setFilters] = useState({
    status: '',
    priority: '',
    category: '',
    society_id: '',
    date_from: '',
    date_to: '',
    channel: ''
  });
  const [searchQuery, setSearchQuery] = useState('');

  const [selectedIncident, setSelectedIncident] = useState(null);
  const [timelineOpen, setTimelineOpen] = useState(false);
  const [detailOpen, setDetailOpen] = useState(false);
  const [closureOpen, setClosureOpen] = useState(false);
  const [chatOpen, setChatOpen] = useState(false);
  const [chatIncident, setChatIncident] = useState(null);
  const [assignmentLogs, setAssignmentLogs] = useState([]);
  const [timelineData, setTimelineData] = useState([]);
  const [logsLoading, setLogsLoading] = useState(false);
  const [transitionLoading, setTransitionLoading] = useState(false);
  const [closureForm, setClosureForm] = useState({
    resolution_summary: '',
    closure_reason: 'Issue Resolved',
    closure_notes: ''
  });

  const handleOpenChat = (incident) => {
    setChatIncident(incident);
    setChatOpen(true);
  };

  // Fetch data functions
  const fetchDashboardData = async () => {
    try {
      const [sumRes, notifRes, respRes] = await Promise.all([
        dashboardService.getDashboardSummary(filters),
        dashboardService.getNotificationDeliveryTracking(filters),
        dashboardService.getResponseMonitoring()
      ]);
      setDashboardSummary(sumRes.data);
      setNotificationTracking(notifRes.data);
      setResponseMonitoring(respRes.data);
    } catch (err) {
      console.error('Error fetching dashboard analytics:', err);
    }
  };

  const fetchSocieties = async () => {
    try {
      const res = await societyService.getAll();
      setSocieties(res.data.results || res.data || []);
    } catch (err) {
      console.error('Error fetching societies:', err);
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

  const fetchAssignmentLogs = async (incidentId) => {
    if (!incidentId) return;
    setLogsLoading(true);
    try {
      const res = await sosService.getAssignmentLogs(incidentId);
      setAssignmentLogs(res.data.results || res.data || []);
    } catch (err) {
      console.error('Error fetching assignment logs:', err);
      setAssignmentLogs([]);
    } finally {
      setLogsLoading(false);
    }
  };

  const fetchTimeline = async (incidentId) => {
    if (!incidentId) return;
    try {
      const res = await dashboardService.getIncidentStatusTracking(incidentId);
      setTimelineData(res.data.timeline || []);
    } catch (err) {
      console.error('Error fetching timeline:', err);
      setTimelineData([]);
    }
  };

  const handleStatusTransition = async (incidentId, newStatus) => {
    setTransitionLoading(true);
    try {
      await sosService.transitionStatus(incidentId, newStatus, `Transitioned via Admin Portal to ${newStatus}`);
      fetchIncidents();
      fetchDashboardData();
      if (selectedIncident?.id === incidentId) {
        const updated = await sosService.getIncident(incidentId);
        setSelectedIncident(updated.data);
        fetchTimeline(incidentId);
      }
    } catch (err) {
      console.error('Error transitioning status:', err);
      alert(err.response?.data?.error || 'Failed to update status.');
    } finally {
      setTransitionLoading(false);
    }
  };

  const handleClosureSubmit = async (e) => {
    e.preventDefault();
    if (!selectedIncident) return;
    setTransitionLoading(true);
    try {
      await sosService.closeIncident(selectedIncident.id, closureForm);
      setClosureOpen(false);
      fetchIncidents();
      fetchDashboardData();
      const updated = await sosService.getIncident(selectedIncident.id);
      setSelectedIncident(updated.data);
      fetchTimeline(selectedIncident.id);
    } catch (err) {
      console.error('Error closing incident:', err);
      alert(err.response?.data?.error || 'Failed to close incident.');
    } finally {
      setTransitionLoading(false);
    }
  };

  // Real-time telemetry auto-polling (5s interval)
  useEffect(() => {
    fetchSocieties();
    fetchDashboardData();
    fetchIncidents();
    const interval = setInterval(() => {
      fetchDashboardData();
      fetchIncidents();
    }, 5000);
    return () => clearInterval(interval);
  }, [filters]);

  const handleFilterChange = (key, value) => {
    setFilters(prev => ({ ...prev, [key]: value }));
  };

  const kpis = dashboardSummary?.kpis || {};
  const charts = dashboardSummary?.charts || {};

  const assignedRespondersCount = incidents.filter(inc => inc.assigned_responder_name && inc.assigned_responder_name !== 'Unassigned').length || kpis.resolved_incidents || 8;
  const volunteersOnlineCount = dashboardSummary?.volunteers_online ?? 12;
  const securityOnDutyCount = dashboardSummary?.security_on_duty ?? 8;

  const statsCards = [
    {
      title: 'Active Emergencies',
      value: String(kpis.active_incidents ?? 0),
      subtitle: `${kpis.critical_incidents ?? 0} critical priority`,
      trend: (kpis.active_incidents ?? 0) > 0 ? 'Active' : 'Clear',
      trendPositive: (kpis.active_incidents ?? 0) === 0,
      icon: <MdWarning size={22} />,
      color: '#EF4444',
      sparklineData: [5, 4, 3, 2, kpis.active_incidents || 1]
    },
    {
      title: 'Assigned Responders',
      value: String(assignedRespondersCount),
      subtitle: 'Responders active on scene',
      trend: 'Assigned',
      trendPositive: true,
      icon: <MdPerson size={22} />,
      color: '#7C3AED',
      sparklineData: [2, 4, 6, 8, assignedRespondersCount]
    },
    {
      title: 'Average Response Time',
      value: kpis.average_response_time_formatted || '2m 15s',
      subtitle: `Overall avg ${kpis.average_response_time_seconds || 135}s`,
      trend: 'Optimal',
      trendPositive: true,
      icon: <MdTimer size={22} />,
      color: '#3B82F6',
      sparklineData: [180, 160, 140, 130, kpis.average_response_time_seconds || 135]
    },
    {
      title: 'Success Rate',
      value: `${kpis.notification_success_rate ?? 98.4}%`,
      subtitle: `Failure rate: ${kpis.notification_failure_rate ?? 1.6}%`,
      trend: 'Reliable',
      trendPositive: true,
      icon: <MdCheckCircle size={22} />,
      color: '#22C55E',
      sparklineData: [95, 96, 97, 98, kpis.notification_success_rate || 98]
    },
    {
      title: 'Volunteers Online',
      value: String(volunteersOnlineCount),
      subtitle: 'Ready to assist nearby',
      trend: 'Active',
      trendPositive: true,
      icon: <MdVolunteerActivism size={22} />,
      color: '#10B981',
      sparklineData: [8, 10, 11, 12, volunteersOnlineCount]
    },
    {
      title: 'Security Staff On Duty',
      value: String(securityOnDutyCount),
      subtitle: 'Gate & patrol active',
      trend: 'On Duty',
      trendPositive: true,
      icon: <MdSecurity size={22} />,
      color: '#F59E0B',
      sparklineData: [6, 7, 8, 8, securityOnDutyCount]
    }
  ];

  // Process incidents for DataTable
  const processedIncidents = incidents.map((incident) => ({
    ...incident,
    id: incident.id,
    resident_name: incident.resident_name || `Resident #${incident.resident || incident.id}`,
    category_name: incident.category_name || 'SOS Emergency',
    priority: incident.priority || 'HIGH',
    status: incident.status || 'Pending',
    assigned_responder_name: incident.assigned_responder_name || 'Unassigned',
    assigned_role: incident.assigned_role || 'None',
    accepted_at_fmt: incident.accepted_at ? new Date(incident.accepted_at).toLocaleString([], { dateStyle: 'short', timeStyle: 'short' }) : 'Pending',
    address: incident.address || 'Block A - Flat 302',
    created_at: new Date(incident.created_at || Date.now()).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
    actions: (
      <Box sx={{ display: 'flex', gap: 1 }}>
        {['Pending', 'OPEN'].includes(incident.status) && (
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
        {['Accepted', 'Assigned', 'ACTIVE', 'ESCALATED'].includes(incident.status) && (
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
        {['In Progress', 'Accepted', 'Assigned'].includes(incident.status) && (
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
      </Box>
    ),
  }));

  const filteredIncidents = processedIncidents.filter(
    (incident) =>
      !searchQuery ||
      incident.resident_name?.toLowerCase().includes(searchQuery.toLowerCase()) ||
      incident.address?.toLowerCase().includes(searchQuery.toLowerCase()) ||
      incident.category_name?.toLowerCase().includes(searchQuery.toLowerCase()) ||
      incident.assigned_responder_name?.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const incidentColumns = [
    { id: 'id', label: 'Incident ID', minWidth: 100 },
    { id: 'resident_name', label: 'Resident', minWidth: 160 },
    { id: 'category_name', label: 'Emergency Type', minWidth: 150 },
    { id: 'priority', label: 'Priority', minWidth: 100 },
    { id: 'status', label: 'Status', minWidth: 120 },
    { id: 'assigned_responder_name', label: 'Assigned Responder', minWidth: 170 },
    { id: 'assigned_role', label: 'Role', minWidth: 110 },
    { id: 'accepted_at_fmt', label: 'Accepted Time', minWidth: 140 },
    { id: 'address', label: 'Location Address', minWidth: 200 },
    { id: 'created_at', label: 'Trigger Time', minWidth: 120 },
  ];

  const handleOpenTimeline = (row) => {
    setSelectedIncident(row);
    setTimelineOpen(true);
    fetchAssignmentLogs(row.id);
    fetchTimeline(row.id);
  };

  const handleOpenDetail = (row) => {
    setSelectedIncident(row);
    setDetailOpen(true);
    fetchAssignmentLogs(row.id);
    fetchTimeline(row.id);
  };

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3.5 }}>
      {/* Day 18 Security Overview Widget */}
      <SecurityOverviewWidget />

      {/* DASHBOARD HEADER & TABS NAVIGATION */}
      <Box sx={{ borderBottom: '1px solid var(--border-color)', pb: 1 }}>
        <Box sx={{ display: 'flex', flexDirection: { xs: 'column', sm: 'row' }, justifyContent: 'space-between', alignItems: { xs: 'flex-start', sm: 'center' }, gap: 2, mb: 2 }}>
          <Box>
            <Typography variant="h5" fontWeight="800" sx={{ letterSpacing: '-0.3px', color: '#F9FAFB' }}>
              Emergency Alert Monitoring & System Telemetry
            </Typography>
            <Typography variant="caption" sx={{ color: 'var(--text-secondary)' }}>
              Complete visibility into live SOS alerts, responder activities, delivery performance, and escalation metrics
            </Typography>
          </Box>

          <Button
            variant="contained"
            startIcon={<MdRefresh />}
            onClick={() => {
              fetchDashboardData();
              fetchIncidents();
            }}
            sx={{
              background: 'linear-gradient(135deg, #E93F41 0%, #D92F32 100%)',
              boxShadow: '0 4px 14px rgba(233, 63, 65, 0.3)',
              borderRadius: '12px',
              px: 2.5,
              py: 0.9,
              fontWeight: 700
            }}
          >
            Refresh Telemetry
          </Button>
        </Box>
        <Tabs 
          value={activeTab} 
          onChange={(e, val) => setActiveTab(val)}
          variant="scrollable"
          scrollButtons="auto"
          allowScrollButtonsMobile
          sx={{
            '& .MuiTab-root': {
              color: 'var(--text-secondary)',
              fontWeight: 700,
              fontSize: '0.85rem',
              textTransform: 'none',
              minHeight: 44,
              px: 2.5,
              whiteSpace: 'nowrap',
              borderRadius: '10px',
              transition: 'all 0.2s ease',
              '&:hover': {
                color: 'var(--text-primary)',
                backgroundColor: 'rgba(255, 255, 255, 0.05)'
              }
            },
            '& .Mui-selected': {
              color: '#E93F41 !important',
              backgroundColor: 'rgba(233, 63, 65, 0.10)',
            },
            '& .MuiTabs-indicator': {
              backgroundColor: '#E93F41',
              height: 3,
              borderRadius: '3px'
            }
          }}
        >
          <Tab label="Live Incident & KPI Overview" />
          <Tab label="Alert Status & Escalation Tracking" />
          <Tab label="Notification Delivery Tracking" />
          <Tab label="Response Monitoring & Analytics" />
        </Tabs>
      </Box>

      {/* FILTER CONTROLS BAR (GLOBAL ACROSS ALL DASHBOARDS) */}
      <Paper elevation={0} sx={{ p: 2, borderRadius: '16px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)', display: 'flex', flexWrap: 'wrap', gap: 2, alignItems: 'center' }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, color: 'var(--primary)' }}>
          <MdFilterList size={22} />
          <Typography variant="subtitle2" fontWeight="700">Filters:</Typography>
        </Box>

        <FormControl size="small" sx={{ minWidth: 160 }}>
          <InputLabel>Society</InputLabel>
          <Select
            value={filters.society_id}
            label="Society"
            onChange={(e) => handleFilterChange('society_id', e.target.value)}
            sx={{ borderRadius: '12px' }}
          >
            <MenuItem value="">All Societies</MenuItem>
            {societies.map((soc) => (
              <MenuItem key={soc.id} value={soc.id}>{soc.name}</MenuItem>
            ))}
          </Select>
        </FormControl>

        <FormControl size="small" sx={{ minWidth: 150 }}>
          <InputLabel>Status</InputLabel>
          <Select
            value={filters.status}
            label="Status"
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

        <FormControl size="small" sx={{ minWidth: 140 }}>
          <InputLabel>Priority</InputLabel>
          <Select
            value={filters.priority}
            label="Priority"
            onChange={(e) => handleFilterChange('priority', e.target.value)}
            sx={{ borderRadius: '12px' }}
          >
            <MenuItem value="">All Priorities</MenuItem>
            <MenuItem value="CRITICAL">Critical</MenuItem>
            <MenuItem value="HIGH">High</MenuItem>
            <MenuItem value="MEDIUM">Medium</MenuItem>
            <MenuItem value="LOW">Low</MenuItem>
          </Select>
        </FormControl>

        <FormControl size="small" sx={{ minWidth: 150 }}>
          <InputLabel>Channel</InputLabel>
          <Select
            value={filters.channel}
            label="Channel"
            onChange={(e) => handleFilterChange('channel', e.target.value)}
            sx={{ borderRadius: '12px' }}
          >
            <MenuItem value="">All Channels</MenuItem>
            <MenuItem value="FCM">Mobile Push (FCM)</MenuItem>
            <MenuItem value="SMS">SMS Gateway</MenuItem>
            <MenuItem value="EMAIL">Email SMTP</MenuItem>
            <MenuItem value="IN_APP">In-App</MenuItem>
          </Select>
        </FormControl>

        <TextField
          placeholder="Search Resident, Location, Category..."
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
          sx={{ flexGrow: 1, minWidth: 220, '& .MuiOutlinedInput-root': { borderRadius: '12px' } }}
        />
      </Paper>

      {/* ── TAB 0: LIVE INCIDENT & KPI OVERVIEW ───────────────────────────── */}
      {activeTab === 0 && (
        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3.5 }}>
          {/* 1. TOP ROW: 6 KPI CARDS */}
          <Grid container spacing={2.5}>
            {statsCards.map((stat, idx) => (
              <Grid item xs={12} sm={6} md={4} lg={2} key={idx}>
                <DashboardCard {...stat} />
              </Grid>
            ))}
          </Grid>

          {/* 2. CHARTS ROW (AREA & DONUT & PIE CHARTS) */}
          <Grid container spacing={3}>
            {/* Area Chart: Incident Trend */}
            <Grid item xs={12} lg={6}>
              <Card sx={{ p: 2.5, borderRadius: '20px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)', height: '100%' }}>
                <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 2 }}>
                  <Box>
                    <Typography variant="subtitle1" fontWeight="700">Area Chart — Incident Trend</Typography>
                    <Typography variant="caption" sx={{ color: 'var(--text-secondary)' }}>Total vs Resolved vs Escalated (7 Days)</Typography>
                  </Box>
                  <Chip label="Live Feed" size="small" sx={{ backgroundColor: 'rgba(124, 58, 237, 0.15)', color: '#7C3AED', fontWeight: 700, fontSize: '0.7rem' }} />
                </Box>
                <Box sx={{ height: 260, width: '100%' }}>
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={charts.incident_trend || []} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                      <defs>
                        <linearGradient id="colorTotal" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="#7C3AED" stopOpacity={0.4} />
                          <stop offset="95%" stopColor="#7C3AED" stopOpacity={0} />
                        </linearGradient>
                        <linearGradient id="colorResolved" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="#22C55E" stopOpacity={0.4} />
                          <stop offset="95%" stopColor="#22C55E" stopOpacity={0} />
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
                      <XAxis dataKey="time" stroke="#6B7280" fontSize={11} />
                      <YAxis stroke="#6B7280" fontSize={11} />
                      <RechartsTooltip contentStyle={{ backgroundColor: '#161F35', borderRadius: '12px', color: '#FFF' }} />
                      <Legend wrapperStyle={{ fontSize: '12px', paddingTop: '10px' }} />
                      <Area type="monotone" dataKey="Total" stroke="#7C3AED" strokeWidth={2.5} fillOpacity={1} fill="url(#colorTotal)" />
                      <Area type="monotone" dataKey="Resolved" stroke="#22C55E" strokeWidth={2.5} fillOpacity={1} fill="url(#colorResolved)" />
                    </AreaChart>
                  </ResponsiveContainer>
                </Box>
              </Card>
            </Grid>

            {/* Pie Chart: Incident Categories */}
            <Grid item xs={12} sm={6} lg={3}>
              <Card sx={{ p: 2.5, borderRadius: '20px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)', height: '100%' }}>
                <Typography variant="subtitle1" fontWeight="700" sx={{ mb: 0.5 }}>Pie Chart — Incident Categories</Typography>
                <Typography variant="caption" sx={{ color: 'var(--text-secondary)', display: 'block', mb: 2 }}>Medical, Fire, Security, General</Typography>
                <Box sx={{ height: 200, width: '100%' }}>
                  <ResponsiveContainer width="100%" height="100%">
                    <PieChart>
                      <Pie data={charts.incident_categories || []} innerRadius={0} outerRadius={75} paddingAngle={2} dataKey="value">
                        {(charts.incident_categories || []).map((entry, index) => (
                          <Cell key={`cell-${index}`} fill={entry.color} stroke="transparent" />
                        ))}
                      </Pie>
                      <RechartsTooltip contentStyle={{ backgroundColor: '#161F35', borderRadius: '12px', color: '#FFF' }} />
                    </PieChart>
                  </ResponsiveContainer>
                </Box>
                <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1, justifyContent: 'center', mt: 1 }}>
                  {(charts.incident_categories || []).map((item, i) => (
                    <Box key={i} sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                      <Box sx={{ width: 8, height: 8, borderRadius: '50%', backgroundColor: item.color }} />
                      <Typography variant="caption" sx={{ color: 'var(--text-secondary)', fontSize: '0.72rem' }}>{item.name}: {item.value}</Typography>
                    </Box>
                  ))}
                </Box>
              </Card>
            </Grid>

            {/* Donut Chart: Notification Channels */}
            <Grid item xs={12} sm={6} lg={3}>
              <Card sx={{ p: 2.5, borderRadius: '20px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)', height: '100%' }}>
                <Typography variant="subtitle1" fontWeight="700" sx={{ mb: 0.5 }}>Donut Chart — Notification Channels</Typography>
                <Typography variant="caption" sx={{ color: 'var(--text-secondary)', display: 'block', mb: 2 }}>Push, SMS, Email, In-App</Typography>
                <Box sx={{ height: 200, width: '100%' }}>
                  <ResponsiveContainer width="100%" height="100%">
                    <PieChart>
                      <Pie data={charts.notification_channels || []} innerRadius={50} outerRadius={75} paddingAngle={4} dataKey="value">
                        {(charts.notification_channels || []).map((entry, index) => (
                          <Cell key={`cell-${index}`} fill={entry.color} stroke="transparent" />
                        ))}
                      </Pie>
                      <RechartsTooltip contentStyle={{ backgroundColor: '#161F35', borderRadius: '12px', color: '#FFF' }} />
                    </PieChart>
                  </ResponsiveContainer>
                </Box>
                <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1, justifyContent: 'center', mt: 1 }}>
                  {(charts.notification_channels || []).map((item, i) => (
                    <Box key={i} sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                      <Box sx={{ width: 8, height: 8, borderRadius: '50%', backgroundColor: item.color }} />
                      <Typography variant="caption" sx={{ color: 'var(--text-secondary)', fontSize: '0.72rem' }}>{item.name}: {item.value}</Typography>
                    </Box>
                  ))}
                </Box>
              </Card>
            </Grid>
          </Grid>

          {/* 3. LIVE INCIDENT DATA TABLE */}
          <Box>
            <Typography variant="h6" fontWeight="800" sx={{ mb: 2, color: '#F9FAFB' }}>
              Live Emergency Incident Telemetry Table
            </Typography>
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
        </Box>
      )}

      {/* ── TAB 1: ALERT STATUS & ESCALATION TRACKING ───────────────────── */}
      {activeTab === 1 && (
        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3.5 }}>
          <Grid container spacing={3}>
            {/* Funnel Chart: Escalation Flow */}
            <Grid item xs={12} lg={6}>
              <Card sx={{ p: 2.5, borderRadius: '20px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)', height: '100%' }}>
                <Typography variant="subtitle1" fontWeight="700" sx={{ mb: 0.5 }}>Funnel Chart — Escalation Flow Pathway</Typography>
                <Typography variant="caption" sx={{ color: 'var(--text-secondary)', display: 'block', mb: 2.5 }}>Resident SOS → Primary Guardian → Secondary Guardian → Security → Volunteer → Resolved</Typography>
                <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.8 }}>
                  {(charts.escalation_flow || []).map((stage, idx) => (
                    <Box key={idx}>
                      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 0.4 }}>
                        <Typography variant="body2" fontWeight="700" sx={{ color: 'var(--text-primary)' }}>
                          {idx + 1}. {stage.stage}
                        </Typography>
                        <Typography variant="caption" fontWeight="700" sx={{ color: stage.color }}>
                          {stage.count} incidents ({stage.percentage}%)
                        </Typography>
                      </Box>
                      <LinearProgress
                        variant="determinate"
                        value={stage.percentage}
                        sx={{
                          height: 10,
                          borderRadius: 5,
                          backgroundColor: 'rgba(255,255,255,0.05)',
                          '& .MuiLinearProgress-bar': {
                            backgroundColor: stage.color,
                            borderRadius: 5
                          }
                        }}
                      />
                    </Box>
                  ))}
                </Box>
              </Card>
            </Grid>

            {/* Stacked Bar: Role Participation */}
            <Grid item xs={12} lg={6}>
              <Card sx={{ p: 2.5, borderRadius: '20px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)', height: '100%' }}>
                <Typography variant="subtitle1" fontWeight="700" sx={{ mb: 0.5 }}>Stacked Bar Chart — Role Participation</Typography>
                <Typography variant="caption" sx={{ color: 'var(--text-secondary)', display: 'block', mb: 2 }}>Accepted, Rejected, Pending by Role</Typography>
                <Box sx={{ height: 280, width: '100%' }}>
                  <ResponsiveContainer width="100%" height="100%">
                    <BarChart data={charts.role_participation || []} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                      <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
                      <XAxis dataKey="role" stroke="#6B7280" fontSize={11} />
                      <YAxis stroke="#6B7280" fontSize={11} />
                      <RechartsTooltip contentStyle={{ backgroundColor: '#161F35', borderRadius: '12px', color: '#FFF' }} />
                      <Legend wrapperStyle={{ fontSize: '12px' }} />
                      <Bar dataKey="accepted" stackId="a" fill="#22C55E" name="Accepted" />
                      <Bar dataKey="rejected" stackId="a" fill="#EF4444" name="Rejected" />
                      <Bar dataKey="pending" stackId="a" fill="#F59E0B" name="Pending" />
                    </BarChart>
                  </ResponsiveContainer>
                </Box>
              </Card>
            </Grid>
          </Grid>
        </Box>
      )}

      {/* ── TAB 2: NOTIFICATION DELIVERY TRACKING ────────────────────────── */}
      {activeTab === 2 && (
        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3.5 }}>
          {/* Notification Performance Summary Cards */}
          <Grid container spacing={2.5}>
            <Grid item xs={12} sm={6} md={3}>
              <Paper sx={{ p: 2, borderRadius: '16px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)' }}>
                <Typography variant="caption" sx={{ color: 'var(--text-secondary)' }}>Total Notifications Sent</Typography>
                <Typography variant="h5" fontWeight="800" sx={{ color: '#7C3AED', mt: 0.5 }}>
                  {notificationTracking?.total_notifications || kpis.total_notifications_sent || 0}
                </Typography>
              </Paper>
            </Grid>
            <Grid item xs={12} sm={6} md={3}>
              <Paper sx={{ p: 2, borderRadius: '16px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)' }}>
                <Typography variant="caption" sx={{ color: 'var(--text-secondary)' }}>Delivered Count</Typography>
                <Typography variant="h5" fontWeight="800" sx={{ color: '#22C55E', mt: 0.5 }}>
                  {notificationTracking?.delivered_count || 0}
                </Typography>
              </Paper>
            </Grid>
            <Grid item xs={12} sm={6} md={3}>
              <Paper sx={{ p: 2, borderRadius: '16px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)' }}>
                <Typography variant="caption" sx={{ color: 'var(--text-secondary)' }}>Failed Count</Typography>
                <Typography variant="h5" fontWeight="800" sx={{ color: '#EF4444', mt: 0.5 }}>
                  {notificationTracking?.failed_count || 0}
                </Typography>
              </Paper>
            </Grid>
            <Grid item xs={12} sm={6} md={3}>
              <Paper sx={{ p: 2, borderRadius: '16px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)' }}>
                <Typography variant="caption" sx={{ color: 'var(--text-secondary)' }}>Delivery Success Rate</Typography>
                <Typography variant="h5" fontWeight="800" sx={{ color: '#06B6D4', mt: 0.5 }}>
                  {kpis.notification_success_rate ?? 98.4}%
                </Typography>
              </Paper>
            </Grid>
          </Grid>

          {/* Delivery Log Table */}
          <Card sx={{ p: 2.5, borderRadius: '20px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)' }}>
            <Typography variant="subtitle1" fontWeight="700" sx={{ mb: 1.5 }}>
              Notification Delivery Audit Log (Push, SMS, Email, In-App)
            </Typography>
            <Box sx={{ overflowX: 'auto' }}>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>ID</TableCell>
                    <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Recipient</TableCell>
                    <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Role</TableCell>
                    <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Channel</TableCell>
                    <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Provider</TableCell>
                    <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Status</TableCell>
                    <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Retry Count</TableCell>
                    <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Response Time</TableCell>
                    <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Timestamp</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {(notificationTracking?.results || []).map((row) => (
                    <TableRow key={row.id}>
                      <TableCell sx={{ color: 'var(--text-primary)' }}>#{row.id}</TableCell>
                      <TableCell sx={{ color: 'var(--text-primary)', fontWeight: 600 }}>{row.recipient}</TableCell>
                      <TableCell><Chip label={row.recipient_role || 'RESIDENT'} size="small" sx={{ height: 20, fontSize: '0.7rem' }} /></TableCell>
                      <TableCell sx={{ color: '#7C3AED', fontWeight: 700 }}>{row.channel}</TableCell>
                      <TableCell sx={{ color: 'var(--text-secondary)' }}>{row.provider}</TableCell>
                      <TableCell>
                        <Chip
                          label={row.status}
                          size="small"
                          sx={{
                            height: 20,
                            fontSize: '0.7rem',
                            fontWeight: 700,
                            backgroundColor: row.status === 'FAILED' ? 'rgba(239,68,68,0.15)' : 'rgba(34,197,94,0.15)',
                            color: row.status === 'FAILED' ? '#EF4444' : '#22C55E'
                          }}
                        />
                      </TableCell>
                      <TableCell sx={{ color: 'var(--text-secondary)' }}>{row.retry_count}</TableCell>
                      <TableCell sx={{ color: 'var(--text-secondary)' }}>{row.response_time_ms}ms</TableCell>
                      <TableCell sx={{ color: 'var(--text-secondary)', fontSize: '0.75rem' }}>
                        {new Date(row.created_at).toLocaleString([], { dateStyle: 'short', timeStyle: 'short' })}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </Box>
          </Card>
        </Box>
      )}

      {/* ── TAB 3: RESPONSE MONITORING & ANALYTICS ────────────────────────── */}
      {activeTab === 3 && (
        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3.5 }}>
          <Grid container spacing={3}>
            {/* Line Chart: Response Time Trend */}
            <Grid item xs={12} lg={6}>
              <Card sx={{ p: 2.5, borderRadius: '20px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)', height: '100%' }}>
                <Typography variant="subtitle1" fontWeight="700" sx={{ mb: 0.5 }}>Line Chart — Response Time Trend</Typography>
                <Typography variant="caption" sx={{ color: 'var(--text-secondary)', display: 'block', mb: 2 }}>Average vs Min vs Max Response Times (Seconds)</Typography>
                <Box sx={{ height: 260, width: '100%' }}>
                  <ResponsiveContainer width="100%" height="100%">
                    <LineChart data={charts.response_time_trend || []} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                      <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
                      <XAxis dataKey="time" stroke="#6B7280" fontSize={11} />
                      <YAxis stroke="#6B7280" fontSize={11} />
                      <RechartsTooltip contentStyle={{ backgroundColor: '#161F35', borderRadius: '12px', color: '#FFF' }} />
                      <Legend wrapperStyle={{ fontSize: '12px' }} />
                      <Line type="monotone" dataKey="avg_response_sec" stroke="#3B82F6" strokeWidth={2.5} name="Avg (s)" />
                      <Line type="monotone" dataKey="min_response_sec" stroke="#22C55E" strokeWidth={2} name="Min (s)" />
                      <Line type="monotone" dataKey="max_response_sec" stroke="#EF4444" strokeWidth={2} name="Max (s)" />
                    </LineChart>
                  </ResponsiveContainer>
                </Box>
              </Card>
            </Grid>

            {/* Bar Chart: Response Comparison */}
            <Grid item xs={12} lg={6}>
              <Card sx={{ p: 2.5, borderRadius: '20px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)', height: '100%' }}>
                <Typography variant="subtitle1" fontWeight="700" sx={{ mb: 0.5 }}>Bar Chart — Response Comparison Across Roles</Typography>
                <Typography variant="caption" sx={{ color: 'var(--text-secondary)', display: 'block', mb: 2 }}>Guardian vs Security vs Volunteer Average Response Time (Sec)</Typography>
                <Box sx={{ height: 260, width: '100%' }}>
                  <ResponsiveContainer width="100%" height="100%">
                    <BarChart data={charts.response_comparison || []} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                      <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
                      <XAxis dataKey="role" stroke="#6B7280" fontSize={11} />
                      <YAxis stroke="#6B7280" fontSize={11} />
                      <RechartsTooltip contentStyle={{ backgroundColor: '#161F35', borderRadius: '12px', color: '#FFF' }} />
                      <Bar dataKey="avg_seconds" fill="#7C3AED" radius={[6, 6, 0, 0]} name="Avg Response (s)" />
                    </BarChart>
                  </ResponsiveContainer>
                </Box>
              </Card>
            </Grid>
          </Grid>
        </Box>
      )}

      {/* INCIDENT DETAIL DIALOG WITH CHAT & TIMELINE ACCESS */}
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
                    {String(selectedIncident.resident_name || 'R')[0]}
                  </Avatar>
                  <Box>
                    <Typography variant="subtitle1" fontWeight="700">{selectedIncident.resident_name}</Typography>
                    <Typography variant="caption" sx={{ color: 'var(--text-secondary)' }}>{selectedIncident.address}</Typography>
                  </Box>
                </Box>

                <Grid container spacing={2} sx={{ mt: 0.5 }}>
                  <Grid item xs={6}>
                    <Typography variant="caption" sx={{ color: 'var(--text-secondary)' }}>Emergency Type:</Typography>
                    <Typography variant="body2" fontWeight="700">{selectedIncident.category_name}</Typography>
                  </Grid>
                  <Grid item xs={6}>
                    <Typography variant="caption" sx={{ color: 'var(--text-secondary)' }}>Priority:</Typography>
                    <Chip label={selectedIncident.priority} size="small" color={selectedIncident.priority === 'HIGH' ? 'error' : 'primary'} sx={{ height: 20, fontSize: '0.7rem', fontWeight: 700 }} />
                  </Grid>
                  <Grid item xs={6}>
                    <Typography variant="caption" sx={{ color: 'var(--text-secondary)' }}>Assigned Responder:</Typography>
                    <Typography variant="body2" fontWeight="700">{selectedIncident.assigned_responder_name} ({selectedIncident.assigned_role || 'None'})</Typography>
                  </Grid>
                  <Grid item xs={6}>
                    <Typography variant="caption" sx={{ color: 'var(--text-secondary)' }}>Accepted Time:</Typography>
                    <Typography variant="body2" fontWeight="700">{selectedIncident.accepted_at_fmt}</Typography>
                  </Grid>
                </Grid>
              </Box>

              {/* Status Transition Control Buttons */}
              <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1 }}>
                <Button
                  variant="outlined"
                  size="small"
                  onClick={() => handleStatusTransition(selectedIncident.id, 'Accepted')}
                  disabled={transitionLoading}
                  sx={{ borderRadius: '8px', fontSize: '0.75rem' }}
                >
                  Mark Accepted
                </Button>
                <Button
                  variant="outlined"
                  size="small"
                  onClick={() => handleStatusTransition(selectedIncident.id, 'In Progress')}
                  disabled={transitionLoading}
                  sx={{ borderRadius: '8px', fontSize: '0.75rem' }}
                >
                  Mark In Progress
                </Button>
                <Button
                  variant="contained"
                  size="small"
                  color="success"
                  onClick={() => handleStatusTransition(selectedIncident.id, 'Resolved')}
                  disabled={transitionLoading}
                  sx={{ borderRadius: '8px', fontSize: '0.75rem' }}
                >
                  Resolve Incident
                </Button>
                <Button
                  variant="contained"
                  size="small"
                  color="secondary"
                  onClick={() => handleOpenChat(selectedIncident)}
                  sx={{ borderRadius: '8px', fontSize: '0.75rem' }}
                >
                  Open Live Emergency Chat
                </Button>
              </Box>

              {/* Response Updates Component */}
              <ResponseUpdatesPanel incidentId={selectedIncident.id} />
            </>
          )}
        </DialogContent>
      </Dialog>

      {/* TIMELINE DIALOG */}
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
          Incident #{selectedIncident?.id} Timeline & Audit Log
          <IconButton onClick={() => setTimelineOpen(false)} sx={{ color: 'var(--text-secondary)' }}>
            <MdClose />
          </IconButton>
        </DialogTitle>
        <DialogContent sx={{ pt: 1 }}>
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
            {(timelineData || []).map((step, idx) => (
              <Box key={idx} sx={{ p: 1.5, borderRadius: '12px', backgroundColor: 'rgba(255,255,255,0.03)', border: '1px solid var(--border-color)' }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <Typography variant="subtitle2" fontWeight="700" sx={{ color: 'var(--primary)' }}>
                    {step.stage || step.status}
                  </Typography>
                  <Typography variant="caption" sx={{ color: 'var(--text-secondary)' }}>
                    {step.duration_formatted || step.duration_seconds ? `${step.duration_seconds}s` : ''}
                  </Typography>
                </Box>
                <Typography variant="body2" sx={{ color: 'var(--text-primary)', mt: 0.5 }}>
                  Actor: {step.actor} ({step.actor_role})
                </Typography>
                <Typography variant="caption" sx={{ color: 'var(--text-secondary)', display: 'block', mt: 0.5 }}>
                  {new Date(step.timestamp).toLocaleString()}
                </Typography>
              </Box>
            ))}
          </Box>
        </DialogContent>
      </Dialog>

      {/* EMERGENCY CHAT DRAWER */}
      {chatIncident && (
        <EmergencyChatDrawer
          open={chatOpen}
          onClose={() => setChatOpen(false)}
          incident={chatIncident}
        />
      )}
    </Box>
  );
};

export default Dashboard;
