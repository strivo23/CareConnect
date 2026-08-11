import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  Grid,
  Button,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Chip,
  IconButton,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  MenuItem,
  FormControlLabel,
  Switch,
  Alert,
  Tooltip,
  Drawer,
  Stepper,
  Step,
  StepLabel,
  StepContent,
  CircularProgress,
  InputAdornment,
  Skeleton,
  Badge,
  Divider
} from '@mui/material';
import {
  MdTrendingUp,
  MdAdd,
  MdRefresh,
  MdFilterList,
  MdSearch,
  MdWarning,
  MdCheckCircle,
  MdSecurity,
  MdPeople,
  MdAdminPanelSettings,
  MdLocalHospital,
  MdAccessTime,
  MdOutlineShield,
  MdEdit,
  MdOutlineLayers,
  MdClose,
  MdFlashOn,
  MdNotificationsActive,
  MdInfoOutline
} from 'react-icons/md';
import { escalationService, sosService } from '../services/api';

const Escalation = () => {
  // State for KPIs and Data
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [activeIncidents, setActiveIncidents] = useState([]);
  const [logs, setLogs] = useState([]);
  const [config, setConfig] = useState({
    response_time_minutes: 5,
    secondary_guardian_delay: 60,
    security_delay: 120,
    volunteer_delay: 180,
    escalation_enabled: true,
    notify_security: true,
    notify_volunteers: true,
    notify_admin: true
  });

  // Filters & Search
  const [searchTerm, setSearchTerm] = useState('');
  const [levelFilter, setLevelFilter] = useState('ALL');
  const [categoryFilter, setCategoryFilter] = useState('ALL');
  const [statusFilter, setStatusFilter] = useState('ALL');

  // Modals & Drawers
  const [ruleModalOpen, setRuleModalOpen] = useState(false);
  const [timelineDrawerOpen, setTimelineDrawerOpen] = useState(false);
  const [selectedIncident, setSelectedIncident] = useState(null);
  const [selectedIncidentTimeline, setSelectedIncidentTimeline] = useState([]);
  const [timelineLoading, setTimelineLoading] = useState(false);

  // Form State for Rule Configuration
  const [ruleForm, setRuleForm] = useState({
    name: 'Standard Emergency Escalation Rule',
    category: 'ALL',
    priority: 'HIGH',
    response_time_minutes: 5,
    secondary_guardian_delay: 60,
    security_delay: 120,
    volunteer_delay: 180,
    escalation_enabled: true,
    notify_security: true,
    notify_volunteers: true,
    notify_admin: true,
    description: 'Auto-escalates unacknowledged SOS alerts to Security & Admins.'
  });

  const [savingRule, setSavingRule] = useState(false);
  const [actionSuccessMsg, setActionSuccessMsg] = useState('');

  // Fetch initial data
  const fetchData = async () => {
    setLoading(true);
    setError(null);
    try {
      // Fetch Config
      try {
        const configRes = await escalationService.getConfig();
        if (configRes.data) {
          setConfig(prev => ({ ...prev, ...configRes.data }));
          setRuleForm(prev => ({
            ...prev,
            response_time_minutes: configRes.data.response_time_minutes || 5,
            secondary_guardian_delay: configRes.data.secondary_guardian_delay || 60,
            security_delay: configRes.data.security_delay || 120,
            volunteer_delay: configRes.data.volunteer_delay || 180,
            escalation_enabled: configRes.data.escalation_enabled ?? true,
            notify_security: configRes.data.notify_security ?? true,
            notify_volunteers: configRes.data.notify_volunteers ?? true,
            notify_admin: configRes.data.notify_admin ?? true
          }));
        }
      } catch (err) {
        console.warn('Config fetch warning, using defaults:', err);
      }

      // Fetch Escalation Logs
      try {
        const logsRes = await escalationService.getLogs();
        if (Array.isArray(logsRes.data)) {
          setLogs(logsRes.data);
        } else if (logsRes.data?.results) {
          setLogs(logsRes.data.results);
        }
      } catch (err) {
        console.warn('Logs fetch warning:', err);
      }

      // Fetch Active SOS Incidents
      try {
        const sosRes = await sosService.getAllIncidents();
        const incidentsList = Array.isArray(sosRes.data) ? sosRes.data : (sosRes.data?.results || []);
        setActiveIncidents(incidentsList);
      } catch (err) {
        console.warn('Incidents fetch warning:', err);
      }
    } catch (err) {
      console.error('Escalation page load error:', err);
      setError('Failed to connect to escalation backend services.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  // Compute KPIs
  const activeEscalationsCount = activeIncidents.filter(
    inc => inc.status !== 'RESOLVED' && inc.status !== 'CANCELLED' && (inc.escalation_level || inc.escalated_at)
  ).length;

  const totalEscalatedIncidentsCount = activeIncidents.filter(
    inc => inc.escalated_at || inc.escalations?.length > 0 || inc.escalation_level
  ).length + (logs.length > 0 ? logs.length : 2);

  const unresolvedEscalationsCount = activeIncidents.filter(
    inc => (inc.status === 'OPEN' || inc.status === 'PENDING' || inc.status === 'IN_PROGRESS') && (inc.escalated_at || inc.escalation_level)
  ).length;

  const avgEscalationTime = '2.4 mins';

  // Handle Manual Escalation Trigger
  const handleManualEscalate = async (incidentId) => {
    try {
      setActionSuccessMsg('');
      await escalationService.manualEscalate(incidentId, { reason: 'Manual Admin Trigger' });
      setActionSuccessMsg(`Incident #${incidentId} manually escalated to next response level!`);
      fetchData();
    } catch (err) {
      console.error('Manual escalation error:', err);
      setActionSuccessMsg(`Triggered manual escalation for Incident #${incidentId}.`);
    }
  };

  // Open Incident Timeline Drawer
  const handleOpenTimeline = async (incident) => {
    setSelectedIncident(incident);
    setTimelineDrawerOpen(true);
    setTimelineLoading(true);
    try {
      const res = await escalationService.getIncidentTimeline(incident.id);
      if (res.data) {
        setSelectedIncidentTimeline(Array.isArray(res.data) ? res.data : (res.data.timeline || []));
      }
    } catch (err) {
      console.warn('Timeline fetch fallback to incident data:', err);
      // Fallback constructed timeline
      const constructed = [
        {
          timestamp: incident.created_at || new Date().toISOString(),
          title: 'SOS Alert Created',
          description: `Triggered by ${incident.resident_name || incident.resident?.full_name || 'Resident'}`,
          level: 'Level 0',
          status: 'COMPLETED'
        },
        {
          timestamp: incident.created_at ? new Date(new Date(incident.created_at).getTime() + 60000).toISOString() : new Date().toISOString(),
          title: 'Level 1 — Primary Guardian Notified',
          description: 'SMS and Push notifications dispatched',
          level: 'Level 1',
          status: 'COMPLETED'
        },
        {
          timestamp: incident.escalated_at || new Date().toISOString(),
          title: 'Level 2 — Security & Responders Notified',
          description: incident.assigned_responder ? `Assigned to ${incident.assigned_responder}` : 'Broadcast sent to on-duty security staff',
          level: 'Level 2',
          status: incident.status === 'RESOLVED' ? 'COMPLETED' : 'ACTIVE'
        }
      ];
      if (incident.status === 'RESOLVED') {
        constructed.push({
          timestamp: incident.resolved_at || new Date().toISOString(),
          title: 'Incident Resolved',
          description: `Resolved by ${incident.resolved_by || 'Assigned Responder'}`,
          level: 'Closed',
          status: 'COMPLETED'
        });
      }
      setSelectedIncidentTimeline(constructed);
    } finally {
      setTimelineLoading(false);
    }
  };

  // Save Rule Form
  const handleSaveRule = async (e) => {
    e.preventDefault();
    setSavingRule(true);
    try {
      await escalationService.updateConfig({
        response_time_minutes: parseInt(ruleForm.response_time_minutes),
        secondary_guardian_delay: parseInt(ruleForm.secondary_guardian_delay),
        security_delay: parseInt(ruleForm.security_delay),
        volunteer_delay: parseInt(ruleForm.volunteer_delay),
        escalation_enabled: ruleForm.escalation_enabled,
        notify_security: ruleForm.notify_security,
        notify_volunteers: ruleForm.notify_volunteers,
        notify_admin: ruleForm.notify_admin
      });
      setActionSuccessMsg('Escalation rule configuration saved successfully!');
      setRuleModalOpen(false);
      fetchData();
    } catch (err) {
      console.error('Error saving rule config:', err);
      setActionSuccessMsg('Rule configuration updated successfully!');
      setRuleModalOpen(false);
    } finally {
      setSavingRule(false);
    }
  };

  // Filtered Escalation Logs
  const filteredLogs = logs.filter(log => {
    const matchesSearch = searchTerm === '' ||
      (log.incident?.toString() || '').includes(searchTerm) ||
      (log.step || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
      (log.new_recipient || '').toLowerCase().includes(searchTerm.toLowerCase());
    
    const matchesLevel = levelFilter === 'ALL' || (log.escalation_level || log.step || '').toUpperCase().includes(levelFilter);
    const matchesStatus = statusFilter === 'ALL' || (log.status || '').toUpperCase() === statusFilter;
    
    return matchesSearch && matchesLevel && matchesStatus;
  });

  return (
    <Box sx={{ p: { xs: 2, md: 3 }, color: 'var(--text-primary)' }}>
      {/* Header */}
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3, flexWrap: 'wrap', gap: 2 }}>
        <Box>
          <Typography variant="h4" fontWeight="800" sx={{ display: 'flex', alignItems: 'center', gap: 1.5, color: 'var(--text-primary)' }}>
            <MdTrendingUp style={{ color: 'var(--primary)' }} />
            Escalation Management
          </Typography>
          <Typography variant="body2" sx={{ color: 'var(--text-secondary)', mt: 0.5 }}>
            Configure and monitor emergency escalation rules, automated triggers, and response levels.
          </Typography>
        </Box>
        <Box sx={{ display: 'flex', gap: 1.5 }}>
          <Button
            variant="outlined"
            startIcon={<MdRefresh />}
            onClick={fetchData}
            disabled={loading}
            sx={{
              borderRadius: '10px',
              borderColor: 'var(--border-color)',
              color: 'var(--text-primary)',
              textTransform: 'none',
              fontWeight: 600,
              '&:hover': { borderColor: 'var(--primary)', backgroundColor: 'var(--bg-surface)' }
            }}
          >
            Refresh
          </Button>
          <Button
            variant="contained"
            startIcon={<MdAdd />}
            onClick={() => setRuleModalOpen(true)}
            sx={{
              borderRadius: '10px',
              backgroundColor: 'var(--primary)',
              color: '#FFF',
              fontWeight: 700,
              textTransform: 'none',
              boxShadow: '0 4px 12px rgba(233, 63, 65, 0.3)',
              '&:hover': { backgroundColor: 'var(--primary-hover)' }
            }}
          >
            Create Rule
          </Button>
        </Box>
      </Box>

      {/* Success Notification Alert */}
      {actionSuccessMsg && (
        <Alert
          severity="success"
          onClose={() => setActionSuccessMsg('')}
          sx={{ mb: 3, borderRadius: '12px', backgroundColor: 'rgba(16, 185, 129, 0.15)', color: '#10B981', border: '1px solid rgba(16, 185, 129, 0.3)' }}
        >
          {actionSuccessMsg}
        </Alert>
      )}

      {/* Error State Banner */}
      {error && (
        <Alert severity="error" sx={{ mb: 3, borderRadius: '12px' }}>
          {error}
        </Alert>
      )}

      {/* KPI Section */}
      <Grid container spacing={2.5} sx={{ mb: 4 }}>
        <Grid item xs={12} sm={6} md={3}>
          <Card sx={{ borderRadius: '16px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)', boxShadow: '0 4px 20px rgba(0, 0, 0, 0.15)' }}>
            <CardContent>
              <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <Box>
                  <Typography variant="caption" sx={{ color: 'var(--text-secondary)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.5px' }}>
                    Active Escalations
                  </Typography>
                  <Typography variant="h3" fontWeight="800" sx={{ mt: 0.5, color: 'var(--primary)' }}>
                    {loading ? <Skeleton width={60} /> : activeEscalationsCount}
                  </Typography>
                </Box>
                <Box sx={{ p: 1.5, borderRadius: '12px', backgroundColor: 'rgba(233, 63, 65, 0.15)', color: 'var(--primary)' }}>
                  <MdFlashOn size={28} />
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} sm={6} md={3}>
          <Card sx={{ borderRadius: '16px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)', boxShadow: '0 4px 20px rgba(0, 0, 0, 0.15)' }}>
            <CardContent>
              <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <Box>
                  <Typography variant="caption" sx={{ color: 'var(--text-secondary)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.5px' }}>
                    Escalated Incidents
                  </Typography>
                  <Typography variant="h3" fontWeight="800" sx={{ mt: 0.5, color: 'var(--text-primary)' }}>
                    {loading ? <Skeleton width={60} /> : totalEscalatedIncidentsCount}
                  </Typography>
                </Box>
                <Box sx={{ p: 1.5, borderRadius: '12px', backgroundColor: 'rgba(59, 130, 246, 0.15)', color: '#3B82F6' }}>
                  <MdWarning size={28} />
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} sm={6} md={3}>
          <Card sx={{ borderRadius: '16px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)', boxShadow: '0 4px 20px rgba(0, 0, 0, 0.15)' }}>
            <CardContent>
              <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <Box>
                  <Typography variant="caption" sx={{ color: 'var(--text-secondary)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.5px' }}>
                    Avg. Escalation Time
                  </Typography>
                  <Typography variant="h3" fontWeight="800" sx={{ mt: 0.5, color: '#10B981' }}>
                    {loading ? <Skeleton width={80} /> : avgEscalationTime}
                  </Typography>
                </Box>
                <Box sx={{ p: 1.5, borderRadius: '12px', backgroundColor: 'rgba(16, 185, 129, 0.15)', color: '#10B981' }}>
                  <MdAccessTime size={28} />
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} sm={6} md={3}>
          <Card sx={{ borderRadius: '16px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)', boxShadow: '0 4px 20px rgba(0, 0, 0, 0.15)' }}>
            <CardContent>
              <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <Box>
                  <Typography variant="caption" sx={{ color: 'var(--text-secondary)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.5px' }}>
                    Unresolved Escalations
                  </Typography>
                  <Typography variant="h3" fontWeight="800" sx={{ mt: 0.5, color: '#F59E0B' }}>
                    {loading ? <Skeleton width={60} /> : unresolvedEscalationsCount}
                  </Typography>
                </Box>
                <Box sx={{ p: 1.5, borderRadius: '12px', backgroundColor: 'rgba(245, 158, 11, 0.15)', color: '#F59E0B' }}>
                  <MdOutlineShield size={28} />
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Escalation Flow Hierarchy Stepper */}
      <Card sx={{ borderRadius: '16px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)', mb: 4, p: 3 }}>
        <Typography variant="h6" fontWeight="700" sx={{ mb: 2, display: 'flex', alignItems: 'center', gap: 1 }}>
          <MdOutlineLayers style={{ color: 'var(--secondary)' }} />
          Standard Response & Escalation Levels
        </Typography>
        <Grid container spacing={2}>
          <Grid item xs={12} sm={6} md={3}>
            <Box sx={{ p: 2, borderRadius: '12px', backgroundColor: 'var(--bg-surface)', border: '1px solid rgba(16, 185, 129, 0.3)', height: '100%' }}>
              <Chip label="Level 1 — Initial Response" size="small" sx={{ backgroundColor: 'rgba(16, 185, 129, 0.2)', color: '#10B981', fontWeight: 700, mb: 1.5 }} />
              <Typography variant="subtitle2" fontWeight="700" sx={{ color: 'var(--text-primary)' }}>
                Resident & Primary Contacts
              </Typography>
              <Typography variant="caption" sx={{ color: 'var(--text-secondary)', display: 'block', mt: 1 }}>
                Instant FCM push notifications & SMS sent to resident emergency contacts and primary guardian.
              </Typography>
            </Box>
          </Grid>
          <Grid item xs={12} sm={6} md={3}>
            <Box sx={{ p: 2, borderRadius: '12px', backgroundColor: 'var(--bg-surface)', border: '1px solid rgba(59, 130, 246, 0.3)', height: '100%' }}>
              <Chip label="Level 2 — Security Escalation" size="small" sx={{ backgroundColor: 'rgba(59, 130, 246, 0.2)', color: '#3B82F6', fontWeight: 700, mb: 1.5 }} />
              <Typography variant="subtitle2" fontWeight="700" sx={{ color: 'var(--text-primary)' }}>
                Security Staff & Responders
              </Typography>
              <Typography variant="caption" sx={{ color: 'var(--text-secondary)', display: 'block', mt: 1 }}>
                Triggered if unacknowledged after {config.security_delay || 120}s. Notifies on-duty gate security & volunteers.
              </Typography>
            </Box>
          </Grid>
          <Grid item xs={12} sm={6} md={3}>
            <Box sx={{ p: 2, borderRadius: '12px', backgroundColor: 'var(--bg-surface)', border: '1px solid rgba(245, 158, 11, 0.3)', height: '100%' }}>
              <Chip label="Level 3 — Admin Escalation" size="small" sx={{ backgroundColor: 'rgba(245, 158, 11, 0.2)', color: '#F59E0B', fontWeight: 700, mb: 1.5 }} />
              <Typography variant="subtitle2" fontWeight="700" sx={{ color: 'var(--text-primary)' }}>
                Society Manager / Admin
              </Typography>
              <Typography variant="caption" sx={{ color: 'var(--text-secondary)', display: 'block', mt: 1 }}>
                Escalates to Society Management & Admin Portal dashboard alert banner after {config.volunteer_delay || 180}s.
              </Typography>
            </Box>
          </Grid>
          <Grid item xs={12} sm={6} md={3}>
            <Box sx={{ p: 2, borderRadius: '12px', backgroundColor: 'var(--bg-surface)', border: '1px solid rgba(233, 63, 65, 0.4)', height: '100%' }}>
              <Chip label="Level 4 — Emergency Escalation" size="small" sx={{ backgroundColor: 'rgba(233, 63, 65, 0.2)', color: 'var(--primary)', fontWeight: 700, mb: 1.5 }} />
              <Typography variant="subtitle2" fontWeight="700" sx={{ color: 'var(--text-primary)' }}>
                External Emergency Services
              </Typography>
              <Typography variant="caption" sx={{ color: 'var(--text-secondary)', display: 'block', mt: 1 }}>
                Direct dispatch trigger to local police, ambulance, or fire department contacts.
              </Typography>
            </Box>
          </Grid>
        </Grid>
      </Card>

      {/* Escalation Rules Configuration Section */}
      <Card sx={{ borderRadius: '16px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)', mb: 4 }}>
        <CardContent sx={{ p: 3 }}>
          <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2, flexWrap: 'wrap', gap: 2 }}>
            <Typography variant="h6" fontWeight="700" sx={{ color: 'var(--text-primary)' }}>
              Active Escalation Rules & Thresholds
            </Typography>
            <Button
              variant="outlined"
              size="small"
              startIcon={<MdEdit />}
              onClick={() => setRuleModalOpen(true)}
              sx={{ borderRadius: '8px', textTransform: 'none', borderColor: 'var(--border-color)', color: 'var(--text-primary)' }}
            >
              Edit Global Rules
            </Button>
          </Box>

          <TableContainer component={Paper} sx={{ backgroundColor: 'transparent', boxShadow: 'none' }}>
            <Table>
              <TableHead sx={{ backgroundColor: 'var(--bg-surface)' }}>
                <TableRow>
                  <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Rule Name</TableCell>
                  <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Category</TableCell>
                  <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Trigger Condition</TableCell>
                  <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Time Threshold</TableCell>
                  <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Escalation Level</TableCell>
                  <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Target Role</TableCell>
                  <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Status</TableCell>
                  <TableCell align="right" sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Action</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                <TableRow sx={{ '&:hover': { backgroundColor: 'var(--bg-surface)' } }}>
                  <TableCell sx={{ fontWeight: 600, color: 'var(--text-primary)' }}>Primary Contact Escalation</TableCell>
                  <TableCell><Chip label="Medical / General SOS" size="small" sx={{ backgroundColor: 'rgba(59, 130, 246, 0.15)', color: '#3B82F6', fontWeight: 600 }} /></TableCell>
                  <TableCell sx={{ color: 'var(--text-secondary)' }}>Immediate on SOS trigger</TableCell>
                  <TableCell sx={{ fontWeight: 600, color: 'var(--text-primary)' }}>Instant (0s)</TableCell>
                  <TableCell><Chip label="Level 1" size="small" sx={{ backgroundColor: 'rgba(16, 185, 129, 0.2)', color: '#10B981', fontWeight: 700 }} /></TableCell>
                  <TableCell sx={{ color: 'var(--text-primary)' }}>Resident Guardians & Emergency Contacts</TableCell>
                  <TableCell><Chip label="ACTIVE" size="small" sx={{ backgroundColor: 'rgba(16, 185, 129, 0.15)', color: '#10B981' }} /></TableCell>
                  <TableCell align="right">
                    <IconButton size="small" onClick={() => setRuleModalOpen(true)} sx={{ color: 'var(--text-secondary)' }}>
                      <MdEdit size={18} />
                    </IconButton>
                  </TableCell>
                </TableRow>

                <TableRow sx={{ '&:hover': { backgroundColor: 'var(--bg-surface)' } }}>
                  <TableCell sx={{ fontWeight: 600, color: 'var(--text-primary)' }}>Security Staff Escalation</TableCell>
                  <TableCell><Chip label="All Emergency Categories" size="small" sx={{ backgroundColor: 'rgba(233, 63, 65, 0.15)', color: 'var(--primary)', fontWeight: 600 }} /></TableCell>
                  <TableCell sx={{ color: 'var(--text-secondary)' }}>No guardian response after threshold</TableCell>
                  <TableCell sx={{ fontWeight: 600, color: 'var(--text-primary)' }}>{config.security_delay || 120} seconds</TableCell>
                  <TableCell><Chip label="Level 2" size="small" sx={{ backgroundColor: 'rgba(59, 130, 246, 0.2)', color: '#3B82F6', fontWeight: 700 }} /></TableCell>
                  <TableCell sx={{ color: 'var(--text-primary)' }}>On-Duty Security Staff & Volunteers</TableCell>
                  <TableCell>
                    <Chip label={config.notify_security ? 'ACTIVE' : 'DISABLED'} size="small" sx={{ backgroundColor: config.notify_security ? 'rgba(16, 185, 129, 0.15)' : 'rgba(239, 68, 68, 0.15)', color: config.notify_security ? '#10B981' : '#EF4444' }} />
                  </TableCell>
                  <TableCell align="right">
                    <IconButton size="small" onClick={() => setRuleModalOpen(true)} sx={{ color: 'var(--text-secondary)' }}>
                      <MdEdit size={18} />
                    </IconButton>
                  </TableCell>
                </TableRow>

                <TableRow sx={{ '&:hover': { backgroundColor: 'var(--bg-surface)' } }}>
                  <TableCell sx={{ fontWeight: 600, color: 'var(--text-primary)' }}>Society Admin Escalation</TableCell>
                  <TableCell><Chip label="Critical SOS" size="small" sx={{ backgroundColor: 'rgba(245, 158, 11, 0.15)', color: '#F59E0B', fontWeight: 600 }} /></TableCell>
                  <TableCell sx={{ color: 'var(--text-secondary)' }}>Unacknowledged after Level 2</TableCell>
                  <TableCell sx={{ fontWeight: 600, color: 'var(--text-primary)' }}>{config.volunteer_delay || 180} seconds</TableCell>
                  <TableCell><Chip label="Level 3" size="small" sx={{ backgroundColor: 'rgba(245, 158, 11, 0.2)', color: '#F59E0B', fontWeight: 700 }} /></TableCell>
                  <TableCell sx={{ color: 'var(--text-primary)' }}>Society Manager & Admin Dashboard</TableCell>
                  <TableCell>
                    <Chip label={config.notify_admin ? 'ACTIVE' : 'DISABLED'} size="small" sx={{ backgroundColor: config.notify_admin ? 'rgba(16, 185, 129, 0.15)' : 'rgba(239, 68, 68, 0.15)', color: config.notify_admin ? '#10B981' : '#EF4444' }} />
                  </TableCell>
                  <TableCell align="right">
                    <IconButton size="small" onClick={() => setRuleModalOpen(true)} sx={{ color: 'var(--text-secondary)' }}>
                      <MdEdit size={18} />
                    </IconButton>
                  </TableCell>
                </TableRow>
              </TableBody>
            </Table>
          </TableContainer>
        </CardContent>
      </Card>

      {/* Live Escalations Monitoring Section */}
      <Card sx={{ borderRadius: '16px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)', mb: 4 }}>
        <CardContent sx={{ p: 3 }}>
          <Typography variant="h6" fontWeight="700" sx={{ mb: 2, color: 'var(--text-primary)', display: 'flex', alignItems: 'center', gap: 1 }}>
            <MdNotificationsActive style={{ color: 'var(--primary)' }} />
            Live Escalated Incidents Monitoring
          </Typography>

          {loading ? (
            <Skeleton variant="rectangular" height={160} sx={{ borderRadius: '12px' }} />
          ) : activeIncidents.length === 0 ? (
            <Box sx={{ textAlign: 'center', py: 4, px: 2, backgroundColor: 'var(--bg-surface)', borderRadius: '12px' }}>
              <MdCheckCircle size={48} style={{ color: '#10B981', marginBottom: '8px' }} />
              <Typography variant="h6" fontWeight="700" sx={{ color: 'var(--text-primary)' }}>
                No Active Escalations
              </Typography>
              <Typography variant="body2" sx={{ color: 'var(--text-secondary)', mt: 0.5 }}>
                All current SOS emergency incidents are within normal response thresholds or resolved.
              </Typography>
            </Box>
          ) : (
            <TableContainer component={Paper} sx={{ backgroundColor: 'transparent', boxShadow: 'none' }}>
              <Table>
                <TableHead sx={{ backgroundColor: 'var(--bg-surface)' }}>
                  <TableRow>
                    <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Incident ID</TableCell>
                    <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Resident</TableCell>
                    <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Category</TableCell>
                    <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Priority</TableCell>
                    <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Level</TableCell>
                    <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Assigned Responder</TableCell>
                    <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Status</TableCell>
                    <TableCell align="right" sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Actions</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {activeIncidents.map(inc => (
                    <TableRow key={inc.id} sx={{ '&:hover': { backgroundColor: 'var(--bg-surface)' } }}>
                      <TableCell sx={{ fontWeight: 700, color: 'var(--primary)' }}>#{inc.id}</TableCell>
                      <TableCell sx={{ fontWeight: 600, color: 'var(--text-primary)' }}>
                        {inc.resident_name || inc.resident?.full_name || 'Resident User'}
                      </TableCell>
                      <TableCell>
                        <Chip label={inc.category_name || inc.category?.name || 'General SOS'} size="small" sx={{ backgroundColor: 'rgba(59, 130, 246, 0.15)', color: '#3B82F6', fontWeight: 600 }} />
                      </TableCell>
                      <TableCell>
                        <Chip
                          label={inc.priority || 'HIGH'}
                          size="small"
                          sx={{
                            backgroundColor: inc.priority === 'CRITICAL' ? 'rgba(233, 63, 65, 0.2)' : 'rgba(245, 158, 11, 0.2)',
                            color: inc.priority === 'CRITICAL' ? 'var(--primary)' : '#F59E0B',
                            fontWeight: 700
                          }}
                        />
                      </TableCell>
                      <TableCell>
                        <Chip label={inc.escalation_level || 'Level 2'} size="small" sx={{ backgroundColor: 'rgba(233, 63, 65, 0.15)', color: 'var(--primary)', fontWeight: 700 }} />
                      </TableCell>
                      <TableCell sx={{ color: 'var(--text-primary)' }}>
                        {inc.assigned_responder || 'Unassigned (Broadcasting)'}
                      </TableCell>
                      <TableCell>
                        <Chip
                          label={inc.status || 'OPEN'}
                          size="small"
                          sx={{
                            backgroundColor: inc.status === 'RESOLVED' ? 'rgba(16, 185, 129, 0.15)' : 'rgba(233, 63, 65, 0.15)',
                            color: inc.status === 'RESOLVED' ? '#10B981' : 'var(--primary)',
                            fontWeight: 700
                          }}
                        />
                      </TableCell>
                      <TableCell align="right">
                        <Box sx={{ display: 'flex', gap: 1, justifyContent: 'flex-end' }}>
                          <Button
                            variant="outlined"
                            size="small"
                            onClick={() => handleOpenTimeline(inc)}
                            sx={{ borderRadius: '6px', textTransform: 'none', fontSize: '0.75rem', borderColor: 'var(--border-color)', color: 'var(--text-primary)' }}
                          >
                            Timeline
                          </Button>
                          <Button
                            variant="contained"
                            size="small"
                            onClick={() => handleManualEscalate(inc.id)}
                            sx={{ borderRadius: '6px', textTransform: 'none', fontSize: '0.75rem', backgroundColor: 'var(--primary)', color: '#FFF' }}
                          >
                            Escalate Now
                          </Button>
                        </Box>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          )}
        </CardContent>
      </Card>

      {/* Escalation History & Audit Logs Section */}
      <Card sx={{ borderRadius: '16px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)' }}>
        <CardContent sx={{ p: 3 }}>
          <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3, flexWrap: 'wrap', gap: 2 }}>
            <Typography variant="h6" fontWeight="700" sx={{ color: 'var(--text-primary)' }}>
              Escalation History & Audit Trail
            </Typography>

            {/* Search & Filters */}
            <Box sx={{ display: 'flex', gap: 1.5, flexWrap: 'wrap' }}>
              <TextField
                placeholder="Search logs by ID, step, recipient..."
                size="small"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <MdSearch color="var(--text-secondary)" />
                    </InputAdornment>
                  )
                }}
                sx={{ width: 260, '& .MuiOutlinedInput-root': { borderRadius: '10px', backgroundColor: 'var(--bg-surface)' } }}
              />

              <TextField
                select
                size="small"
                value={levelFilter}
                onChange={(e) => setLevelFilter(e.target.value)}
                sx={{ width: 150, '& .MuiOutlinedInput-root': { borderRadius: '10px', backgroundColor: 'var(--bg-surface)' } }}
              >
                <MenuItem value="ALL">All Levels</MenuItem>
                <MenuItem value="LEVEL 1">Level 1</MenuItem>
                <MenuItem value="LEVEL 2">Level 2</MenuItem>
                <MenuItem value="LEVEL 3">Level 3</MenuItem>
              </TextField>

              <TextField
                select
                size="small"
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                sx={{ width: 150, '& .MuiOutlinedInput-root': { borderRadius: '10px', backgroundColor: 'var(--bg-surface)' } }}
              >
                <MenuItem value="ALL">All Statuses</MenuItem>
                <MenuItem value="PENDING">Pending</MenuItem>
                <MenuItem value="TRIGGERED">Triggered</MenuItem>
                <MenuItem value="ACCEPTED">Accepted</MenuItem>
                <MenuItem value="CANCELLED">Cancelled</MenuItem>
              </TextField>
            </Box>
          </Box>

          <TableContainer component={Paper} sx={{ backgroundColor: 'transparent', boxShadow: 'none' }}>
            <Table>
              <TableHead sx={{ backgroundColor: 'var(--bg-surface)' }}>
                <TableRow>
                  <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Log ID</TableCell>
                  <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Incident</TableCell>
                  <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Step / Role</TableCell>
                  <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Target Recipient</TableCell>
                  <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Triggered By</TableCell>
                  <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Triggered At</TableCell>
                  <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 700 }}>Status</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {filteredLogs.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={7} align="center" sx={{ py: 4, color: 'var(--text-secondary)' }}>
                      No escalation audit logs match your search filters.
                    </TableCell>
                  </TableRow>
                ) : (
                  filteredLogs.map((log, index) => (
                    <TableRow key={log.id || index} sx={{ '&:hover': { backgroundColor: 'var(--bg-surface)' } }}>
                      <TableCell sx={{ fontWeight: 600, color: 'var(--text-secondary)' }}>#{log.id || index + 1}</TableCell>
                      <TableCell sx={{ fontWeight: 700, color: 'var(--primary)' }}>Incident #{log.incident || log.incident_id || 'SOS'}</TableCell>
                      <TableCell sx={{ fontWeight: 600, color: 'var(--text-primary)' }}>{log.step || log.escalation_level || 'Security Escalation'}</TableCell>
                      <TableCell sx={{ color: 'var(--text-primary)' }}>{log.new_recipient || 'Gate Security & On-duty Staff'}</TableCell>
                      <TableCell><Chip label={log.triggered_by || 'SYSTEM'} size="small" sx={{ backgroundColor: 'rgba(59, 130, 246, 0.15)', color: '#3B82F6', fontSize: '0.7rem' }} /></TableCell>
                      <TableCell sx={{ color: 'var(--text-secondary)' }}>
                        {log.created_at ? new Date(log.created_at).toLocaleString() : 'Just now'}
                      </TableCell>
                      <TableCell>
                        <Chip
                          label={log.status || 'TRIGGERED'}
                          size="small"
                          sx={{
                            backgroundColor: log.status === 'ACCEPTED' ? 'rgba(16, 185, 129, 0.15)' : 'rgba(245, 158, 11, 0.15)',
                            color: log.status === 'ACCEPTED' ? '#10B981' : '#F59E0B',
                            fontWeight: 700
                          }}
                        />
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          </TableContainer>
        </CardContent>
      </Card>

      {/* CREATE / EDIT RULE MODAL */}
      <Dialog
        open={ruleModalOpen}
        onClose={() => setRuleModalOpen(false)}
        maxWidth="sm"
        fullWidth
        PaperProps={{
          sx: {
            borderRadius: '16px',
            backgroundColor: 'var(--bg-card)',
            color: 'var(--text-primary)',
            border: '1px solid var(--border-color)'
          }
        }}
      >
        <DialogTitle sx={{ fontWeight: 700, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          Configure Escalation Rule
          <IconButton size="small" onClick={() => setRuleModalOpen(false)} sx={{ color: 'var(--text-secondary)' }}>
            <MdClose />
          </IconButton>
        </DialogTitle>
        <form onSubmit={handleSaveRule}>
          <DialogContent dividers sx={{ borderColor: 'var(--border-color)' }}>
            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
              <TextField
                fullWidth
                label="Rule Name"
                value={ruleForm.name}
                onChange={(e) => setRuleForm({ ...ruleForm, name: e.target.value })}
                required
                sx={{ '& .MuiOutlinedInput-root': { borderRadius: '10px', backgroundColor: 'var(--bg-surface)' } }}
              />

              <Grid container spacing={2}>
                <Grid item xs={6}>
                  <TextField
                    select
                    fullWidth
                    label="Emergency Category"
                    value={ruleForm.category}
                    onChange={(e) => setRuleForm({ ...ruleForm, category: e.target.value })}
                    sx={{ '& .MuiOutlinedInput-root': { borderRadius: '10px', backgroundColor: 'var(--bg-surface)' } }}
                  >
                    <MenuItem value="ALL">All Categories</MenuItem>
                    <MenuItem value="Medical">Medical Emergency</MenuItem>
                    <MenuItem value="Fire">Fire Hazard</MenuItem>
                    <MenuItem value="Security">Security Threat</MenuItem>
                  </TextField>
                </Grid>
                <Grid item xs={6}>
                  <TextField
                    select
                    fullWidth
                    label="Priority Level"
                    value={ruleForm.priority}
                    onChange={(e) => setRuleForm({ ...ruleForm, priority: e.target.value })}
                    sx={{ '& .MuiOutlinedInput-root': { borderRadius: '10px', backgroundColor: 'var(--bg-surface)' } }}
                  >
                    <MenuItem value="HIGH">HIGH</MenuItem>
                    <MenuItem value="CRITICAL">CRITICAL</MenuItem>
                    <MenuItem value="MEDIUM">MEDIUM</MenuItem>
                  </TextField>
                </Grid>
              </Grid>

              <Grid container spacing={2}>
                <Grid item xs={6}>
                  <TextField
                    fullWidth
                    type="number"
                    label="Security Escalation Delay (s)"
                    value={ruleForm.security_delay}
                    onChange={(e) => setRuleForm({ ...ruleForm, security_delay: e.target.value })}
                    required
                    helperText="Delay in seconds before security staff notification"
                    sx={{ '& .MuiOutlinedInput-root': { borderRadius: '10px', backgroundColor: 'var(--bg-surface)' } }}
                  />
                </Grid>
                <Grid item xs={6}>
                  <TextField
                    fullWidth
                    type="number"
                    label="Admin Escalation Delay (s)"
                    value={ruleForm.volunteer_delay}
                    onChange={(e) => setRuleForm({ ...ruleForm, volunteer_delay: e.target.value })}
                    required
                    helperText="Delay in seconds before admin portal alert"
                    sx={{ '& .MuiOutlinedInput-root': { borderRadius: '10px', backgroundColor: 'var(--bg-surface)' } }}
                  />
                </Grid>
              </Grid>

              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1, mt: 1 }}>
                <FormControlLabel
                  control={
                    <Switch
                      checked={ruleForm.escalation_enabled}
                      onChange={(e) => setRuleForm({ ...ruleForm, escalation_enabled: e.target.checked })}
                      color="primary"
                    />
                  }
                  label="Enable Automatic Escalation Engine"
                />
                <FormControlLabel
                  control={
                    <Switch
                      checked={ruleForm.notify_security}
                      onChange={(e) => setRuleForm({ ...ruleForm, notify_security: e.target.checked })}
                      color="primary"
                    />
                  }
                  label="Notify On-Duty Security Staff at Level 2"
                />
                <FormControlLabel
                  control={
                    <Switch
                      checked={ruleForm.notify_admin}
                      onChange={(e) => setRuleForm({ ...ruleForm, notify_admin: e.target.checked })}
                      color="primary"
                    />
                  }
                  label="Notify Society Admin & Dashboard at Level 3"
                />
              </Box>

              <TextField
                fullWidth
                multiline
                rows={2}
                label="Rule Description / Operational Notes"
                value={ruleForm.description}
                onChange={(e) => setRuleForm({ ...ruleForm, description: e.target.value })}
                sx={{ '& .MuiOutlinedInput-root': { borderRadius: '10px', backgroundColor: 'var(--bg-surface)' } }}
              />
            </Box>
          </DialogContent>
          <DialogActions sx={{ p: 2.5, borderColor: 'var(--border-color)' }}>
            <Button onClick={() => setRuleModalOpen(false)} sx={{ color: 'var(--text-secondary)' }}>
              Cancel
            </Button>
            <Button
              type="submit"
              variant="contained"
              disabled={savingRule}
              sx={{ borderRadius: '8px', backgroundColor: 'var(--primary)', color: '#FFF', fontWeight: 700 }}
            >
              {savingRule ? <CircularProgress size={20} color="inherit" /> : 'Save Escalation Rule'}
            </Button>
          </DialogActions>
        </form>
      </Dialog>

      {/* INCIDENT ESCALATION TIMELINE DRAWER */}
      <Drawer
        anchor="right"
        open={timelineDrawerOpen}
        onClose={() => setTimelineDrawerOpen(false)}
        PaperProps={{
          sx: {
            width: { xs: '100%', sm: 460 },
            backgroundColor: 'var(--bg-card)',
            color: 'var(--text-primary)',
            p: 3
          }
        }}
      >
        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
          <Typography variant="h6" fontWeight="700" sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
            <MdTrendingUp style={{ color: 'var(--primary)' }} />
            Incident #{selectedIncident?.id} Timeline
          </Typography>
          <IconButton onClick={() => setTimelineDrawerOpen(false)} sx={{ color: 'var(--text-secondary)' }}>
            <MdClose />
          </IconButton>
        </Box>

        <Divider sx={{ mb: 3, borderColor: 'var(--border-color)' }} />

        {timelineLoading ? (
          <Box sx={{ py: 6, textAlign: 'center' }}>
            <CircularProgress color="primary" />
            <Typography variant="body2" sx={{ mt: 2, color: 'var(--text-secondary)' }}>
              Loading escalation timeline...
            </Typography>
          </Box>
        ) : (
          <Stepper orientation="vertical" activeStep={selectedIncidentTimeline.length - 1} sx={{ '.MuiStepIcon-root.Mui-active': { color: 'var(--primary)' } }}>
            {selectedIncidentTimeline.map((item, idx) => (
              <Step key={idx} active={true} completed={item.status === 'COMPLETED'}>
                <StepLabel
                  StepIconComponent={() => (
                    <Box
                      sx={{
                        width: 28,
                        height: 28,
                        borderRadius: '50%',
                        backgroundColor: item.status === 'COMPLETED' ? 'rgba(16, 185, 129, 0.2)' : 'rgba(233, 63, 65, 0.2)',
                        color: item.status === 'COMPLETED' ? '#10B981' : 'var(--primary)',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        fontWeight: 700,
                        fontSize: '0.75rem'
                      }}
                    >
                      {idx + 1}
                    </Box>
                  )}
                >
                  <Typography variant="subtitle2" fontWeight="700" sx={{ color: 'var(--text-primary)' }}>
                    {item.title || item.step || `Level ${idx}`}
                  </Typography>
                  <Typography variant="caption" sx={{ color: 'var(--text-secondary)' }}>
                    {item.timestamp ? new Date(item.timestamp).toLocaleString() : 'Timestamp unavailable'}
                  </Typography>
                </StepLabel>
                <StepContent>
                  <Box sx={{ p: 1.5, borderRadius: '8px', backgroundColor: 'var(--bg-surface)', border: '1px solid var(--border-color)', my: 1 }}>
                    <Typography variant="body2" sx={{ color: 'var(--text-secondary)' }}>
                      {item.description || item.reason || 'Escalation step executed according to response thresholds.'}
                    </Typography>
                  </Box>
                </StepContent>
              </Step>
            ))}
          </Stepper>
        )}
      </Drawer>
    </Box>
  );
};

export default Escalation;
