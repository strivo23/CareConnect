import React, { useState, useEffect, useCallback } from 'react';
import {
  Box, Typography, Button, Grid, Card, CardContent, CircularProgress, Alert,
  Paper, Divider, Chip, MenuItem, Select, FormControl, InputLabel, TextField,
  Table, TableHead, TableRow, TableCell, TableBody, TableContainer, TablePagination, IconButton
} from '@mui/material';
import {
  MdDownload, MdWarning, MdCheckCircle, MdError, MdAccessTime, MdPictureAsPdf,
  MdTableChart, MdInsertDriveFile, MdFilterList, MdRefresh, MdSpeed, MdShield, MdTimeline
} from 'react-icons/md';
import { Bar, Line, Doughnut, Pie } from 'react-chartjs-2';
import {
  Chart as ChartJS, CategoryScale, LinearScale, BarElement, PointElement, LineElement, Title, Tooltip, Legend, ArcElement
} from 'chart.js';
import apiClient, { reportService, dashboardService, societyService, sosService } from '../services/api';

ChartJS.register(CategoryScale, LinearScale, BarElement, PointElement, LineElement, Title, Tooltip, Legend, ArcElement);

const Reports = () => {
  // State variables
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [lastUpdated, setLastUpdated] = useState(new Date().toLocaleTimeString());
  const [isExporting, setIsExporting] = useState(false);

  // Master data state
  const [societies, setSocieties] = useState([]);
  const [categories, setCategories] = useState([]);

  // Filter state
  const [timeframe, setTimeframe] = useState('7days');
  const [dateFrom, setDateFrom] = useState('');
  const [dateTo, setDateTo] = useState('');
  const [selectedSociety, setSelectedSociety] = useState('all');
  const [selectedCategory, setSelectedCategory] = useState('all');
  const [selectedPriority, setSelectedPriority] = useState('all');
  const [selectedStatus, setSelectedStatus] = useState('all');
  const [searchQuery, setSearchQuery] = useState('');

  // Table pagination
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(10);

  // Load Master Filters (Societies & Categories)
  useEffect(() => {
    const loadMasterData = async () => {
      try {
        const [socRes, catRes] = await Promise.all([
          societyService.getAll(),
          sosService.getCategories()
        ]);

        const socList = Array.isArray(socRes.data) ? socRes.data : (socRes.data?.results || []);
        const catList = Array.isArray(catRes.data) ? catRes.data : (catRes.data?.results || []);

        setSocieties(socList);
        setCategories(catList);
      } catch (err) {
        console.error('Error loading filter options:', err);
      }
    };
    loadMasterData();
  }, []);

  // Fetch Dashboard Summary
  const fetchDashboardData = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const params = {};
      if (timeframe && timeframe !== 'custom') params.timeframe = timeframe;
      if (timeframe === 'custom') {
        if (dateFrom) params.date_from = dateFrom;
        if (dateTo) params.date_to = dateTo;
      }
      if (selectedSociety && selectedSociety !== 'all') params.society_id = selectedSociety;
      if (selectedCategory && selectedCategory !== 'all') params.category = selectedCategory;
      if (selectedPriority && selectedPriority !== 'all') params.priority = selectedPriority;
      if (selectedStatus && selectedStatus !== 'all') params.status = selectedStatus;

      const res = await dashboardService.getDashboardSummary(params);
      setData(res.data);
      setLastUpdated(new Date().toLocaleTimeString());
    } catch (err) {
      console.error('Error loading reports analytics:', err);
      setError('Unable to load reports. Please verify network connection or try again.');
    } finally {
      setLoading(false);
    }
  }, [timeframe, dateFrom, dateTo, selectedSociety, selectedCategory, selectedPriority, selectedStatus]);

  useEffect(() => {
    fetchDashboardData();
  }, [fetchDashboardData]);

  // Handle Export Actions
  const handleExport = (format) => {
    setIsExporting(true);
    const filters = {};
    if (timeframe && timeframe !== 'custom') filters.timeframe = timeframe;
    if (timeframe === 'custom') {
      if (dateFrom) filters.date_from = dateFrom;
      if (dateTo) filters.date_to = dateTo;
    }
    if (selectedSociety && selectedSociety !== 'all') filters.society = selectedSociety;
    if (selectedCategory && selectedCategory !== 'all') filters.category = selectedCategory;
    if (selectedPriority && selectedPriority !== 'all') filters.priority = selectedPriority;
    if (selectedStatus && selectedStatus !== 'all') filters.status = selectedStatus;

    reportService.downloadReport('incidents', format, filters);
    setTimeout(() => setIsExporting(false), 2000);
  };

  const handleResetFilters = () => {
    setTimeframe('7days');
    setDateFrom('');
    setDateTo('');
    setSelectedSociety('all');
    setSelectedCategory('all');
    setSelectedPriority('all');
    setSelectedStatus('all');
    setSearchQuery('');
  };

  // Extract KPIs
  const kpis = data?.kpis || {};
  const charts = data?.charts || {};
  const societyStats = data?.society_statistics || [];
  const incidentsTable = data?.incidents_table || [];

  // Filtered Table Records
  const filteredTable = incidentsTable.filter((item) => {
    if (!searchQuery) return true;
    const q = searchQuery.toLowerCase();
    return (
      (item.resident_name || '').toLowerCase().includes(q) ||
      (item.society_name || '').toLowerCase().includes(q) ||
      (item.category_name || '').toLowerCase().includes(q) ||
      (item.status || '').toLowerCase().includes(q) ||
      `#${item.id}`.includes(q)
    );
  });

  // Chart 1: Incident Trend Line Chart
  const trendLabels = (charts.incident_trend || []).map(t => t.time);
  const trendTotalData = (charts.incident_trend || []).map(t => t.Total);
  const trendResolvedData = (charts.incident_trend || []).map(t => t.Resolved);
  const trendEscalatedData = (charts.incident_trend || []).map(t => t.Escalated);

  const trendChartData = {
    labels: trendLabels.length ? trendLabels : ['Day 1', 'Day 2', 'Day 3', 'Day 4', 'Day 5', 'Day 6', 'Day 7'],
    datasets: [
      {
        label: 'Total Incidents',
        data: trendTotalData.length ? trendTotalData : [0, 0, 0, 0, 0, 0, 0],
        borderColor: '#E93F41',
        backgroundColor: 'rgba(233, 63, 65, 0.1)',
        tension: 0.3,
        fill: true,
      },
      {
        label: 'Resolved',
        data: trendResolvedData.length ? trendResolvedData : [0, 0, 0, 0, 0, 0, 0],
        borderColor: '#22C55E',
        backgroundColor: 'rgba(34, 197, 94, 0.1)',
        tension: 0.3,
        fill: true,
      },
      {
        label: 'Escalated',
        data: trendEscalatedData.length ? trendEscalatedData : [0, 0, 0, 0, 0, 0, 0],
        borderColor: '#8B5CF6',
        backgroundColor: 'rgba(139, 92, 246, 0.1)',
        tension: 0.3,
        fill: true,
      }
    ]
  };

  // Chart 2: Incidents by Category Bar Chart
  const categoryLabels = (charts.incident_categories || []).map(c => c.name);
  const categoryValues = (charts.incident_categories || []).map(c => c.value);
  const categoryColors = (charts.incident_categories || []).map(c => c.color || '#E93F41');

  const categoryChartData = {
    labels: categoryLabels.length ? categoryLabels : ['Medical', 'Fire', 'Security', 'General'],
    datasets: [{
      label: 'Incidents Count',
      data: categoryValues.length ? categoryValues : [0, 0, 0, 0],
      backgroundColor: categoryColors.length ? categoryColors : ['#E93F41', '#F59E0B', '#3B82F6', '#10B981'],
      borderRadius: 8,
    }]
  };

  // Chart 3: Status Distribution Doughnut Chart
  const statusLabels = (charts.status_distribution || []).map(s => s.name);
  const statusValues = (charts.status_distribution || []).map(s => s.value);
  const statusColors = (charts.status_distribution || []).map(s => s.color || '#3B82F6');

  const statusChartData = {
    labels: statusLabels.length ? statusLabels : ['Open', 'Active', 'Escalated', 'Resolved', 'Closed'],
    datasets: [{
      data: statusValues.length ? statusValues : [0, 0, 0, 0, 0],
      backgroundColor: statusColors.length ? statusColors : ['#F59E0B', '#3B82F6', '#8B5CF6', '#22C55E', '#64748B'],
      borderWidth: 2,
      borderColor: 'var(--bg-card, #1A2437)'
    }]
  };

  // Chart 4: Priority Analytics Bar Chart
  const priorityLabels = (charts.priority_distribution || []).map(p => p.name);
  const priorityValues = (charts.priority_distribution || []).map(p => p.value);
  const priorityColors = (charts.priority_distribution || []).map(p => p.color || '#EF4444');

  const priorityChartData = {
    labels: priorityLabels.length ? priorityLabels : ['Critical', 'High', 'Medium', 'Low'],
    datasets: [{
      label: 'Priority Count',
      data: priorityValues.length ? priorityValues : [0, 0, 0, 0],
      backgroundColor: priorityColors.length ? priorityColors : ['#EF4444', '#F59E0B', '#3B82F6', '#10B981'],
      borderRadius: 8,
    }]
  };

  // Official Entity Download Modules
  const reportModules = [
    { title: 'Resident Community Report', type: 'residents', desc: 'Comprehensive report of registered residents, society, block, flat occupancy, and status.' },
    { title: 'Volunteer Network Report', type: 'volunteers', desc: 'Detailed log of active volunteers, emergency skills, availability, and assigned societies.' },
    { title: 'Security Staff Report', type: 'security', desc: 'Audit of security personnel, employee IDs, shifts, society assignments, and employment status.' },
    { title: 'Verification Audit Report', type: 'verifications', desc: 'Historical log of user verification requests, admin remarks, approval dates, and document audits.' },
    { title: 'Society & Infrastructure Report', type: 'societies', desc: 'Overview of registered gated societies, blocks, total flats, occupancy counts, and managers.' },
  ];

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3.5, pb: 6 }}>
      {/* Header Section */}
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 2 }}>
        <Box>
          <Typography variant="h5" fontWeight="800" sx={{ letterSpacing: '-0.5px', color: 'var(--text-primary, #F9FAFB)' }}>
            Reports & Emergency Analytics
          </Typography>
          <Typography variant="body2" sx={{ color: 'var(--text-secondary, #94A3B8)' }}>
            Platform-wide emergency response insights, telemetry trends, and official export center. Updated at {lastUpdated}.
          </Typography>
        </Box>
        <Box sx={{ display: 'flex', gap: 1.5, alignItems: 'center' }}>
          <Button
            variant="outlined"
            startIcon={<MdRefresh />}
            onClick={fetchDashboardData}
            disabled={loading}
            sx={{ borderRadius: '12px', textTransform: 'none', fontWeight: 600, borderColor: 'var(--border-color)' }}
          >
            Refresh
          </Button>
          <Button
            variant="contained"
            startIcon={<MdPictureAsPdf />}
            onClick={() => handleExport('pdf')}
            disabled={isExporting || loading}
            sx={{ backgroundColor: '#E93F41', color: '#FFF', borderRadius: '12px', textTransform: 'none', fontWeight: 700, '&:hover': { backgroundColor: '#D92F32' } }}
          >
            {isExporting ? 'Generating Report...' : 'Export PDF'}
          </Button>
          <Button
            variant="contained"
            startIcon={<MdTableChart />}
            onClick={() => handleExport('excel')}
            disabled={isExporting || loading}
            sx={{ backgroundColor: '#22C55E', color: '#FFF', borderRadius: '12px', textTransform: 'none', fontWeight: 700, '&:hover': { backgroundColor: '#16A34A' } }}
          >
            {isExporting ? 'Generating Report...' : 'Export Excel'}
          </Button>
        </Box>
      </Box>

      {/* Global Filter Bar */}
      <Paper sx={{ p: 2.5, borderRadius: '20px', backgroundColor: 'var(--bg-card, #1A2437)', border: '1px solid var(--border-color, #2A364F)' }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
          <MdFilterList style={{ fontSize: '1.4rem', color: '#E93F41' }} />
          <Typography variant="subtitle1" fontWeight="700" sx={{ color: 'var(--text-primary)' }}>
            Global Analytics Filters
          </Typography>
        </Box>

        <Grid container spacing={2} alignItems="center">
          <Grid item xs={12} sm={6} md={2.4}>
            <FormControl fullWidth size="small">
              <InputLabel>Date Range</InputLabel>
              <Select value={timeframe} label="Date Range" onChange={(e) => setTimeframe(e.target.value)}>
                <MenuItem value="today">Today</MenuItem>
                <MenuItem value="yesterday">Yesterday</MenuItem>
                <MenuItem value="7days">Last 7 Days</MenuItem>
                <MenuItem value="30days">Last 30 Days</MenuItem>
                <MenuItem value="90days">Last 90 Days</MenuItem>
                <MenuItem value="this_year">This Year</MenuItem>
                <MenuItem value="custom">Custom Range</MenuItem>
              </Select>
            </FormControl>
          </Grid>

          {timeframe === 'custom' && (
            <>
              <Grid item xs={12} sm={6} md={2}>
                <TextField
                  fullWidth
                  size="small"
                  type="date"
                  label="From Date"
                  value={dateFrom}
                  onChange={(e) => setDateFrom(e.target.value)}
                  InputLabelProps={{ shrink: true }}
                />
              </Grid>
              <Grid item xs={12} sm={6} md={2}>
                <TextField
                  fullWidth
                  size="small"
                  type="date"
                  label="To Date"
                  value={dateTo}
                  onChange={(e) => setDateTo(e.target.value)}
                  InputLabelProps={{ shrink: true }}
                />
              </Grid>
            </>
          )}

          <Grid item xs={12} sm={6} md={2.4}>
            <FormControl fullWidth size="small">
              <InputLabel>Society</InputLabel>
              <Select value={selectedSociety} label="Society" onChange={(e) => setSelectedSociety(e.target.value)}>
                <MenuItem value="all">All Societies</MenuItem>
                {societies.map((s) => (
                  <MenuItem key={s.id} value={s.id}>{s.name}</MenuItem>
                ))}
              </Select>
            </FormControl>
          </Grid>

          <Grid item xs={12} sm={6} md={2.4}>
            <FormControl fullWidth size="small">
              <InputLabel>Category</InputLabel>
              <Select value={selectedCategory} label="Category" onChange={(e) => setSelectedCategory(e.target.value)}>
                <MenuItem value="all">All Categories</MenuItem>
                {categories.map((c) => (
                  <MenuItem key={c.id} value={c.id}>{c.name}</MenuItem>
                ))}
              </Select>
            </FormControl>
          </Grid>

          <Grid item xs={12} sm={6} md={2.4}>
            <FormControl fullWidth size="small">
              <InputLabel>Priority</InputLabel>
              <Select value={selectedPriority} label="Priority" onChange={(e) => setSelectedPriority(e.target.value)}>
                <MenuItem value="all">All Priorities</MenuItem>
                <MenuItem value="CRITICAL">Critical</MenuItem>
                <MenuItem value="HIGH">High</MenuItem>
                <MenuItem value="MEDIUM">Medium</MenuItem>
                <MenuItem value="LOW">Low</MenuItem>
              </Select>
            </FormControl>
          </Grid>

          <Grid item xs={12} sm={6} md={2.4}>
            <FormControl fullWidth size="small">
              <InputLabel>Status</InputLabel>
              <Select value={selectedStatus} label="Status" onChange={(e) => setSelectedStatus(e.target.value)}>
                <MenuItem value="all">All Statuses</MenuItem>
                <MenuItem value="OPEN">Open</MenuItem>
                <MenuItem value="ACTIVE">Active</MenuItem>
                <MenuItem value="ESCALATED">Escalated</MenuItem>
                <MenuItem value="RESOLVED">Resolved</MenuItem>
                <MenuItem value="CLOSED">Closed</MenuItem>
              </Select>
            </FormControl>
          </Grid>

          <Grid item xs={12} sm={6} md={2.4} sx={{ display: 'flex', gap: 1 }}>
            <Button
              variant="contained"
              onClick={fetchDashboardData}
              sx={{ backgroundColor: '#E93F41', color: '#FFF', borderRadius: '10px', textTransform: 'none', fontWeight: 700, flex: 1 }}
            >
              Apply
            </Button>
            <Button
              variant="outlined"
              onClick={handleResetFilters}
              sx={{ borderRadius: '10px', textTransform: 'none', fontWeight: 600, borderColor: 'var(--border-color)' }}
            >
              Reset
            </Button>
          </Grid>
        </Grid>
      </Paper>

      {/* Error & Loading State Handlers */}
      {error && (
        <Alert severity="error" action={<Button color="inherit" size="small" onClick={fetchDashboardData}>Retry</Button>}>
          {error}
        </Alert>
      )}

      {loading ? (
        <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', py: 10 }}>
          <CircularProgress sx={{ color: '#E93F41' }} />
        </Box>
      ) : (
        <>
          {/* Empty State Banner */}
          {kpis.total_incidents === 0 && (
            <Alert severity="info" action={<Button color="inherit" size="small" onClick={handleResetFilters}>Reset Filters</Button>}>
              No emergency incidents available for the selected filters.
            </Alert>
          )}

          {/* Summary KPI Cards */}
          <Grid container spacing={2.5}>
            <Grid item xs={12} sm={6} md={4} lg={2}>
              <Card sx={{ p: 2, borderRadius: '16px', backgroundColor: 'var(--bg-card, #1A2437)', border: '1px solid var(--border-color, #2A364F)' }}>
                <Typography variant="caption" sx={{ color: 'var(--text-secondary, #94A3B8)', fontWeight: 700 }}>TOTAL INCIDENTS</Typography>
                <Typography variant="h4" fontWeight="800" sx={{ color: 'var(--text-primary, #F9FAFB)', my: 0.5 }}>
                  {kpis.total_incidents || 0}
                </Typography>
                <Typography variant="caption" sx={{ color: '#E93F41', fontWeight: 600 }}>Real-time Count</Typography>
              </Card>
            </Grid>

            <Grid item xs={12} sm={6} md={4} lg={2}>
              <Card sx={{ p: 2, borderRadius: '16px', backgroundColor: 'var(--bg-card, #1A2437)', border: '1px solid var(--border-color, #2A364F)' }}>
                <Typography variant="caption" sx={{ color: 'var(--text-secondary, #94A3B8)', fontWeight: 700 }}>RESOLUTION RATE</Typography>
                <Typography variant="h4" fontWeight="800" sx={{ color: '#22C55E', my: 0.5 }}>
                  {kpis.resolution_rate || 0}%
                </Typography>
                <Typography variant="caption" sx={{ color: 'var(--text-secondary)', fontWeight: 600 }}>Resolved / Closed</Typography>
              </Card>
            </Grid>

            <Grid item xs={12} sm={6} md={4} lg={2}>
              <Card sx={{ p: 2, borderRadius: '16px', backgroundColor: 'var(--bg-card, #1A2437)', border: '1px solid var(--border-color, #2A364F)' }}>
                <Typography variant="caption" sx={{ color: 'var(--text-secondary, #94A3B8)', fontWeight: 700 }}>AVG RESPONSE TIME</Typography>
                <Typography variant="h4" fontWeight="800" sx={{ color: '#3B82F6', my: 0.5 }}>
                  {kpis.average_response_time_formatted || 'N/A'}
                </Typography>
                <Typography variant="caption" sx={{ color: 'var(--text-secondary)', fontWeight: 600 }}>Creation to Accept</Typography>
              </Card>
            </Grid>

            <Grid item xs={12} sm={6} md={4} lg={2}>
              <Card sx={{ p: 2, borderRadius: '16px', backgroundColor: 'var(--bg-card, #1A2437)', border: '1px solid var(--border-color, #2A364F)' }}>
                <Typography variant="caption" sx={{ color: 'var(--text-secondary, #94A3B8)', fontWeight: 700 }}>AVG RESOLUTION TIME</Typography>
                <Typography variant="h4" fontWeight="800" sx={{ color: '#06B6D4', my: 0.5 }}>
                  {kpis.average_resolution_time_formatted || 'N/A'}
                </Typography>
                <Typography variant="caption" sx={{ color: 'var(--text-secondary)', fontWeight: 600 }}>Creation to Resolve</Typography>
              </Card>
            </Grid>

            <Grid item xs={12} sm={6} md={4} lg={2}>
              <Card sx={{ p: 2, borderRadius: '16px', backgroundColor: 'var(--bg-card, #1A2437)', border: '1px solid var(--border-color, #2A364F)' }}>
                <Typography variant="caption" sx={{ color: 'var(--text-secondary, #94A3B8)', fontWeight: 700 }}>ESCALATION RATE</Typography>
                <Typography variant="h4" fontWeight="800" sx={{ color: '#8B5CF6', my: 0.5 }}>
                  {kpis.escalation_rate || 0}%
                </Typography>
                <Typography variant="caption" sx={{ color: 'var(--text-secondary)', fontWeight: 600 }}>Escalated Incidents</Typography>
              </Card>
            </Grid>

            <Grid item xs={12} sm={6} md={4} lg={2}>
              <Card sx={{ p: 2, borderRadius: '16px', backgroundColor: 'var(--bg-card, #1A2437)', border: '1px solid var(--border-color, #2A364F)' }}>
                <Typography variant="caption" sx={{ color: 'var(--text-secondary, #94A3B8)', fontWeight: 700 }}>CRITICAL INCIDENTS</Typography>
                <Typography variant="h4" fontWeight="800" sx={{ color: '#EF4444', my: 0.5 }}>
                  {kpis.critical_incidents || 0}
                </Typography>
                <Typography variant="caption" sx={{ color: 'var(--text-secondary)', fontWeight: 600 }}>High / Critical Level</Typography>
              </Card>
            </Grid>
          </Grid>

          {/* Charts Grid */}
          <Grid container spacing={3}>
            {/* Chart 1: Incident Trends */}
            <Grid item xs={12} md={7}>
              <Card sx={{ p: 3, borderRadius: '20px', backgroundColor: 'var(--bg-card, #1A2437)', border: '1px solid var(--border-color, #2A364F)' }}>
                <Typography variant="subtitle1" fontWeight="700" sx={{ mb: 2, color: 'var(--text-primary)' }}>
                  Incident Trend Analytics (Time-Series)
                </Typography>
                <Box sx={{ height: 280 }}>
                  <Line data={trendChartData} options={{ maintainAspectRatio: false, plugins: { legend: { position: 'bottom' } } }} />
                </Box>
              </Card>
            </Grid>

            {/* Chart 2: Incidents by Emergency Category */}
            <Grid item xs={12} md={5}>
              <Card sx={{ p: 3, borderRadius: '20px', backgroundColor: 'var(--bg-card, #1A2437)', border: '1px solid var(--border-color, #2A364F)' }}>
                <Typography variant="subtitle1" fontWeight="700" sx={{ mb: 2, color: 'var(--text-primary)' }}>
                  Incidents by Emergency Category
                </Typography>
                <Box sx={{ height: 280 }}>
                  <Bar data={categoryChartData} options={{ maintainAspectRatio: false, plugins: { legend: { display: false } } }} />
                </Box>
              </Card>
            </Grid>

            {/* Chart 3: Incident Status Distribution */}
            <Grid item xs={12} md={4}>
              <Card sx={{ p: 3, borderRadius: '20px', backgroundColor: 'var(--bg-card, #1A2437)', border: '1px solid var(--border-color, #2A364F)' }}>
                <Typography variant="subtitle1" fontWeight="700" sx={{ mb: 2, color: 'var(--text-primary)' }}>
                  Incident Status Distribution
                </Typography>
                <Box sx={{ height: 240, display: 'flex', justifyContent: 'center' }}>
                  <Doughnut data={statusChartData} options={{ maintainAspectRatio: false, plugins: { legend: { position: 'bottom' } } }} />
                </Box>
              </Card>
            </Grid>

            {/* Chart 4: Priority Analytics */}
            <Grid item xs={12} md={4}>
              <Card sx={{ p: 3, borderRadius: '20px', backgroundColor: 'var(--bg-card, #1A2437)', border: '1px solid var(--border-color, #2A364F)' }}>
                <Typography variant="subtitle1" fontWeight="700" sx={{ mb: 2, color: 'var(--text-primary)' }}>
                  Priority Analytics Breakdown
                </Typography>
                <Box sx={{ height: 240 }}>
                  <Bar data={priorityChartData} options={{ maintainAspectRatio: false, plugins: { legend: { display: false } } }} />
                </Box>
              </Card>
            </Grid>

            {/* Chart 5: Society Performance Comparison */}
            <Grid item xs={12} md={4}>
              <Card sx={{ p: 3, borderRadius: '20px', backgroundColor: 'var(--bg-card, #1A2437)', border: '1px solid var(--border-color, #2A364F)', height: '100%' }}>
                <Typography variant="subtitle1" fontWeight="700" sx={{ mb: 1.5, color: 'var(--text-primary)' }}>
                  Society Performance Summary
                </Typography>
                <Box sx={{ overflowY: 'auto', maxHeight: 230 }}>
                  {societyStats.map((soc) => (
                    <Box key={soc.society_id} sx={{ py: 1, borderBottom: '1px solid var(--border-color)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <Box>
                        <Typography variant="subtitle2" fontWeight="700" sx={{ color: 'var(--text-primary)' }}>{soc.society_name}</Typography>
                        <Typography variant="caption" sx={{ color: 'var(--text-secondary)' }}>
                          Total: {soc.total_incidents} | Active: {soc.active_incidents} | Resolved: {soc.resolved_incidents}
                        </Typography>
                      </Box>
                      <Chip
                        label={`${soc.resolution_rate}%`}
                        size="small"
                        sx={{
                          fontWeight: 700,
                          backgroundColor: soc.resolution_rate >= 80 ? 'rgba(34, 197, 94, 0.15)' : 'rgba(245, 158, 11, 0.15)',
                          color: soc.resolution_rate >= 80 ? '#22C55E' : '#F59E0B'
                        }}
                      />
                    </Box>
                  ))}
                </Box>
              </Card>
            </Grid>
          </Grid>

          {/* Detailed Incident Table */}
          <Paper sx={{ p: 3, borderRadius: '20px', backgroundColor: 'var(--bg-card, #1A2437)', border: '1px solid var(--border-color, #2A364F)' }}>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2, flexWrap: 'wrap', gap: 2 }}>
              <Typography variant="h6" fontWeight="800" sx={{ color: 'var(--text-primary)' }}>
                Detailed Emergency Incident Report
              </Typography>
              <TextField
                size="small"
                placeholder="Search by resident, society, category..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                sx={{ width: 280 }}
              />
            </Box>

            <TableContainer>
              <Table size="small">
                <TableHead>
                  <TableRow sx={{ backgroundColor: 'rgba(0,0,0,0.04)' }}>
                    <TableCell sx={{ fontWeight: 700 }}>ID</TableCell>
                    <TableCell sx={{ fontWeight: 700 }}>Date & Time</TableCell>
                    <TableCell sx={{ fontWeight: 700 }}>Resident</TableCell>
                    <TableCell sx={{ fontWeight: 700 }}>Society</TableCell>
                    <TableCell sx={{ fontWeight: 700 }}>Category</TableCell>
                    <TableCell sx={{ fontWeight: 700 }}>Priority</TableCell>
                    <TableCell sx={{ fontWeight: 700 }}>Status</TableCell>
                    <TableCell sx={{ fontWeight: 700 }}>Response Time</TableCell>
                    <TableCell sx={{ fontWeight: 700 }}>Responder</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {filteredTable.length === 0 ? (
                    <TableRow>
                      <TableCell colSpan={9} align="center" sx={{ py: 3, color: 'var(--text-secondary)' }}>
                        No incident records match current criteria.
                      </TableCell>
                    </TableRow>
                  ) : (
                    filteredTable
                      .slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage)
                      .map((row) => (
                        <TableRow key={row.id} hover>
                          <TableCell sx={{ fontWeight: 700 }}>#{row.id}</TableCell>
                          <TableCell sx={{ fontSize: '0.8rem' }}>{new Date(row.created_at).toLocaleString()}</TableCell>
                          <TableCell sx={{ fontWeight: 600 }}>{row.resident_name}</TableCell>
                          <TableCell>{row.society_name}</TableCell>
                          <TableCell><Chip label={row.category_name} size="small" variant="outlined" /></TableCell>
                          <TableCell>
                            <Chip
                              label={row.priority}
                              size="small"
                              sx={{
                                fontWeight: 700,
                                fontSize: '0.7rem',
                                backgroundColor: row.priority === 'CRITICAL' ? 'rgba(239, 68, 68, 0.15)' : 'rgba(59, 130, 246, 0.15)',
                                color: row.priority === 'CRITICAL' ? '#EF4444' : '#3B82F6'
                              }}
                            />
                          </TableCell>
                          <TableCell>
                            <Chip
                              label={row.status}
                              size="small"
                              sx={{
                                fontWeight: 700,
                                fontSize: '0.75rem',
                                backgroundColor: row.status === 'RESOLVED' || row.status === 'CLOSED' ? 'rgba(34, 197, 94, 0.15)' : 'rgba(245, 158, 11, 0.15)',
                                color: row.status === 'RESOLVED' || row.status === 'CLOSED' ? '#22C55E' : '#F59E0B'
                              }}
                            />
                          </TableCell>
                          <TableCell sx={{ fontWeight: 600 }}>{row.response_time_formatted}</TableCell>
                          <TableCell sx={{ fontSize: '0.85rem' }}>{row.assigned_responder_name}</TableCell>
                        </TableRow>
                      ))
                  )}
                </TableBody>
              </Table>
            </TableContainer>

            <TablePagination
              rowsPerPageOptions={[5, 10, 25]}
              component="div"
              count={filteredTable.length}
              rowsPerPage={rowsPerPage}
              page={page}
              onPageChange={(e, newPage) => setPage(newPage)}
              onRowsPerPageChange={(e) => { setRowsPerPage(parseInt(e.target.value, 10)); setPage(0); }}
            />
          </Paper>
        </>
      )}

      {/* Official Downloads Section */}
      <Box sx={{ mt: 1 }}>
        <Typography variant="h6" fontWeight="800" sx={{ mb: 2, color: 'var(--text-primary)' }}>
          Download Official Entity Audit Reports
        </Typography>
        <Grid container spacing={2.5}>
          {reportModules.map((mod) => (
            <Grid item xs={12} md={6} lg={4} key={mod.type}>
              <Card sx={{ p: 2.5, borderRadius: '20px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)', height: '100%', display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
                <Box>
                  <Typography variant="subtitle1" fontWeight="800" sx={{ mb: 0.5, color: 'var(--text-primary)' }}>{mod.title}</Typography>
                  <Typography variant="body2" sx={{ color: 'var(--text-secondary)', fontSize: '0.85rem' }}>{mod.desc}</Typography>
                </Box>
                <Box sx={{ mt: 2, pt: 2, borderTop: '1px solid var(--border-color)', display: 'flex', gap: 1 }}>
                  <Button
                    size="small"
                    variant="contained"
                    startIcon={<MdPictureAsPdf />}
                    onClick={() => reportService.downloadReport(mod.type, 'pdf')}
                    sx={{ backgroundColor: '#E93F41', color: '#FFF', borderRadius: '8px', textTransform: 'none', fontWeight: 700 }}
                  >
                    PDF
                  </Button>
                  <Button
                    size="small"
                    variant="contained"
                    startIcon={<MdTableChart />}
                    onClick={() => reportService.downloadReport(mod.type, 'excel')}
                    sx={{ backgroundColor: '#22C55E', color: '#FFF', borderRadius: '8px', textTransform: 'none', fontWeight: 700 }}
                  >
                    Excel
                  </Button>
                  <Button
                    size="small"
                    variant="outlined"
                    startIcon={<MdInsertDriveFile />}
                    onClick={() => reportService.downloadReport(mod.type, 'csv')}
                    sx={{ borderRadius: '8px', textTransform: 'none', fontWeight: 700, borderColor: 'var(--border-color)', color: 'var(--text-primary)' }}
                  >
                    CSV
                  </Button>
                </Box>
              </Card>
            </Grid>
          ))}
        </Grid>
      </Box>
    </Box>
  );
};

export default Reports;
