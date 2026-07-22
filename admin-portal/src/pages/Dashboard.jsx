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
} from 'react-icons/md';
import { dashboardService, sosService } from '../services/api';

const Dashboard = () => {
  const [incidentStats, setIncidentStats] = useState(null);
  const [incidents, setIncidents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [incidentLoading, setIncidentLoading] = useState(true);
  const [filters, setFilters] = useState({
    status: '',
    priority: '',
    category: '',
  });
  const [searchQuery, setSearchQuery] = useState('');

  // Fetch data functions
  const fetchStats = async () => {
    try {
      const res = await dashboardService.getIncidentStats();
      setIncidentStats(res.data);
    } catch (err) {
      console.error(err);
    }
  };

  const fetchIncidents = async () => {
    setIncidentLoading(true);
    try {
      const res = await sosService.getAllIncidents(filters);
      const data = res.data.results || res.data;
      setIncidents(data);
    } catch (err) {
      console.error(err);
    } finally {
      setIncidentLoading(false);
    }
  };

  // Real-time polling (polling
  useEffect(() => {
    fetchStats();
    fetchIncidents();
    // Poll every 5 seconds
    const statsInterval = setInterval(fetchStats, 5000);
    const incidentsInterval = setInterval(fetchIncidents, 5000);
    return () => {
      clearInterval(statsInterval);
      clearInterval(incidentsInterval);
    };
  }, [filters]);

  // Filter change handler
  const handleFilterChange = (key, value) => {
    setFilters(prev => ({ ...prev, [key]: value }));
  };

  // Dashboard cards
  const statsCards = incidentStats
    ? [
        {
          title: 'Active SOS',
          value: String(
            incidentStats.status_counts?.Pending +
              incidentStats.status_counts?.Accepted +
              incidentStats.status_counts?.['In Progress'] || 0
          ),
          icon: <MdWarning size={24} />,
          color: '#EF4444',
        },
        {
          title: 'Pending',
          value: String(incidentStats.status_counts?.Pending || 0),
          icon: <MdAccessTime size={24} />,
          color: '#F59E0B',
        },
        {
          title: 'In Progress',
          value: String(incidentStats.status_counts?.['In Progress'] || 0),
          icon: <MdWarning size={24} />,
          color: '#3B82F6',
        },
        {
          title: 'Resolved',
          value: String(incidentStats.status_counts?.Resolved || 0),
          icon: <MdCheckCircle size={24} />,
          color: '#22C55E',
        },
        {
          title: 'Cancelled',
          value: String(incidentStats.status_counts?.Cancelled || 0),
          icon: <MdCancel size={24} />,
          color: '#6B7280',
        },
        {
          title: "Today's Incidents",
          value: String(incidentStats.todays_incidents || 0),
          icon: <MdToday size={24} />,
          color: '#8B5CF6',
        },
        {
          title: 'Volunteers Available',
          value: String(incidentStats.volunteers_available || 0),
          icon: <MdVolunteerActivism size={24} />,
          color: '#10B981',
        },
        {
          title: 'Security Online',
          value: String(incidentStats.security_online || 0),
          icon: <MdSecurity size={24} />,
          color: '#06B6D4',
        },
      ]
    : [];

  // Incident Table
  const incidentColumns = [
    { id: 'id', label: 'Incident ID', minWidth: 100 },
    { id: 'resident_name', label: 'Resident Name', minWidth: 150 },
    { id: 'category_name', label: 'Emergency Category', minWidth: 150 },
    { id: 'priority', label: 'Priority', minWidth: 100 },
    { id: 'status', label: 'Current Status', minWidth: 120 },
    { id: 'address', label: 'Address', minWidth: 200 },
    { id: 'created_at', label: 'Created Time', minWidth: 180 },
    { id: 'updated_at', label: 'Last Updated', minWidth: 180 },
    { id: 'actions', label: 'Actions', minWidth: 150 },
  ];

  // Process incidents for DataTable
  const processedIncidents = incidents.map((incident) => ({
    ...incident,
    id: incident.id,
    resident_name: incident.resident_name || 'Unknown',
    category_name: incident.category_name || 'SOS Emergency',
    priority: incident.priority || 'Medium',
    status: incident.status,
    address: incident.address || 'Address not available',
    created_at: new Date(incident.created_at).toLocaleString(),
    updated_at: new Date(incident.updated_at).toLocaleString(),
    actions: (
      <Box sx={{ display: 'flex', gap: 1 }}>
        {incident.status === 'Pending' && (
        <Button
          variant='outlined'
          size='small'
          onClick={() => sosService.acceptIncident(incident.id).then(fetchIncidents)}
        >
          Accept
        </Button>
      )}
      {incident.status === 'Accepted' && (
        <Button
          variant='outlined'
          size='small'
          onClick={() => sosService.markInProgress(incident.id).then(fetchIncidents)}
        >
          In Progress
        </Button>
      )}
      {incident.status === 'In Progress' && (
        <Button
          variant='outlined'
          size='small'
          onClick={() => sosService.resolveIncident(incident.id).then(fetchIncidents)}
        >
          Resolve
        </Button>
      )}
      {['Pending', 'Accepted', 'In Progress'].includes(incident.status) && (
        <Button
          variant='outlined'
          size='small'
          color='error'
          onClick={() => sosService.cancelIncident(incident.id).then(fetchIncidents)}
        >
          Cancel
        </Button>
      )}
    </Box>
    ),
  }));

  // Filter incidents with search
  const filteredIncidents = processedIncidents.filter(
    (incident) =>
      !searchQuery ||
      incident.resident_name?.toLowerCase().includes(searchQuery.toLowerCase()) ||
      incident.address?.toLowerCase().includes(searchQuery.toLowerCase())
  );

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 4 }}>
        <Box>
          <Typography variant='h4' fontWeight='bold' sx={{ mb: 1 }}>
            SOS Dashboard
          </Typography>
          <Typography variant='body1' color='text.secondary'>
            Real-time monitoring of all SOS incidents across all registered societies.
          </Typography>
        </Box>
        <Button
          variant='contained'
          color='primary'
          startIcon={<MdRefresh />}
          onClick={() => {
            fetchStats();
            fetchIncidents();
          }}
        >
          Refresh
        </Button>
      </Box>

      {/* Stats Grid */}
      {incidentStats ? (
        <Grid container spacing={3} sx={{ mb: 4 }}>
          {statsCards.map((stat, index) => (
            <Grid item xs={12} sm={6} md={4} lg={3} key={index}>
              <DashboardCard {...stat} />
            </Grid>
          ))}
        </Grid>
      ) : (
        <Box sx={{ display: 'flex', justifyContent: 'center', py: 5 }}>
          <CircularProgress />
        </Box>
      )}

      {/* Filters Section */}
      <Box sx={{ mb: 3, display: 'flex', flexWrap: 'wrap', gap: 2, alignItems: 'center' }}>
        <TextField
          label='Search'
          variant='outlined'
          size='small'
        value={searchQuery}
        onChange={(e) => setSearchQuery(e.target.value)}
        InputProps={{
          startAdornment: (
            <InputAdornment position='start'>
              <MdSearch />
            </InputAdornment>
          ),
        }}
        sx={{ minWidth: 250 }}
      />

      <FormControl size='small' sx={{ minWidth: 200 }}>
        <InputLabel>Status</InputLabel>
        <Select
          value={filters.status}
          label='Status'
          onChange={(e) => handleFilterChange('status', e.target.value)}
        >
          <MenuItem value=''>All</MenuItem>
          <MenuItem value='Pending'>Pending</MenuItem>
          <MenuItem value='Accepted'>Accepted</MenuItem>
          <MenuItem value='In Progress'>In Progress</MenuItem>
          <MenuItem value='Resolved'>Resolved</MenuItem>
          <MenuItem value='Cancelled'>Cancelled</MenuItem>
        </Select>
      </FormControl>

      <FormControl size='small' sx={{ minWidth: 200 }}>
        <InputLabel>Priority</InputLabel>
        <Select
          value={filters.priority}
          label='Priority'
          onChange={(e) => handleFilterChange('priority', e.target.value)}
        >
          <MenuItem value=''>All</MenuItem>
          <MenuItem value='High'>High</MenuItem>
          <MenuItem value='Medium'>Medium</MenuItem>
          <MenuItem value='Low'>Low</MenuItem>
        </Select>
      </FormControl>
    </Box>

      {/* Live Incident Table */}
      <Typography variant='h6' fontWeight='bold' sx={{ mb: 2 }}>
        Live Incidents
      </Typography>
      {incidentLoading ? (
        <Box sx={{ display: 'flex', justifyContent: 'center', py: 5 }}>
          <CircularProgress />
        </Box>
      ) : (
        <DataTable
          columns={incidentColumns}
          data={filteredIncidents}
          onView={(row) => console.log('View incident', row)}
        />
      )}
    </Box>
  );
};

export default Dashboard;
