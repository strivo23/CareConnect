import React, { useState, useEffect } from 'react';
import { 
  Box, Typography, Card, CardContent, TextField, Button, Grid, Table, 
  TableBody, TableCell, TableContainer, TableHead, TableRow, Paper, Divider, Alert, FormControlLabel, Switch, Chip
} from '@mui/material';
import { MdSettings, MdHistory, MdMonitor, MdSave } from 'react-icons/md';
import apiClient from '../services/api';

const EscalationSettings = () => {
  const [responseTimeMinutes, setResponseTimeMinutes] = useState(5);
  const [responseTimeWindow, setResponseTimeWindow] = useState(30);
  const [escalationEnabled, setEscalationEnabled] = useState(true);
  const [notifySecurity, setNotifySecurity] = useState(true);
  const [notifyVolunteers, setNotifyVolunteers] = useState(true);
  const [notifyAdmin, setNotifyAdmin] = useState(true);
  
  const [configId, setConfigId] = useState(null);
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState(null);

  const fetchConfig = async () => {
    try {
      const res = await apiClient.get('/sos/escalation/config');
      if (res.data) {
        setResponseTimeMinutes(res.data.response_time_minutes || 5);
        setResponseTimeWindow(res.data.response_time_window || 30);
        setEscalationEnabled(res.data.escalation_enabled ?? true);
        setNotifySecurity(res.data.notify_security ?? true);
        setNotifyVolunteers(res.data.notify_volunteers ?? true);
        setNotifyAdmin(res.data.notify_admin ?? true);
        setConfigId(res.data.id);
      }
    } catch (err) {
      console.error('Error fetching escalation config:', err);
      // Fallback
      try {
        const fallbackRes = await apiClient.get('/sos/escalation-config/');
        if (fallbackRes.data && fallbackRes.data.length > 0) {
          const cfg = fallbackRes.data[0];
          setResponseTimeMinutes(cfg.response_time_minutes || 5);
          setResponseTimeWindow(cfg.response_time_window || 30);
          setEscalationEnabled(cfg.escalation_enabled ?? true);
          setNotifySecurity(cfg.notify_security ?? true);
          setNotifyVolunteers(cfg.notify_volunteers ?? true);
          setNotifyAdmin(cfg.notify_admin ?? true);
          setConfigId(cfg.id);
        }
      } catch (e) {
        console.error('Fallback config fetch error:', e);
      }
    }
  };

  const fetchLogs = async () => {
    try {
      const res = await apiClient.get('/sos/escalation/logs');
      setLogs(res.data);
    } catch (err) {
      try {
        const fallbackLogs = await apiClient.get('/sos/escalation-logs/');
        setLogs(fallbackLogs.data);
      } catch (e) {
        console.error('Error fetching escalation logs:', e);
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchConfig();
    fetchLogs();
  }, []);

  const handleSaveConfig = async () => {
    try {
      const payload = {
        response_time_minutes: responseTimeMinutes,
        response_time_window: responseTimeWindow,
        escalation_enabled: escalationEnabled,
        notify_security: notifySecurity,
        notify_volunteers: notifyVolunteers,
        notify_admin: notifyAdmin,
      };

      await apiClient.put('/sos/escalation/config', payload);
      setMessage({ type: 'success', text: 'Escalation workflow configuration saved successfully.' });
    } catch (err) {
      console.error('Error saving escalation config:', err);
      setMessage({ type: 'error', text: 'Failed to save escalation configuration.' });
    }
  };

  const getStatusChip = (status) => {
    let color = 'default';
    if (status === 'TRIGGERED') color = 'warning';
    if (status === 'ACCEPTED') color = 'success';
    if (status === 'REJECTED') color = 'error';
    if (status === 'CANCELLED') color = 'default';
    return <Chip label={status} color={color} size="small" sx={{ fontWeight: 'bold' }} />;
  };

  return (
    <Box>
      <Typography variant="h5" fontWeight="bold" sx={{ mb: 4 }}>
        Guardian Escalation Workflow Management
      </Typography>

      {message && (
        <Alert severity={message.type} sx={{ mb: 3 }} onClose={() => setMessage(null)}>
          {message.text}
        </Alert>
      )}

      <Grid container spacing={3} sx={{ mb: 4 }}>
        {/* Escalation Configuration Card */}
        <Grid item xs={12} md={7}>
          <Card sx={{ backgroundColor: 'var(--bg-card)', color: 'var(--text-primary)', boxShadow: 'var(--shadow-sm)' }}>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
                <MdSettings size={22} color="var(--primary)" />
                <Typography variant="h6">Response & Notification Configuration</Typography>
              </Box>
              <Divider sx={{ mb: 3, borderColor: 'var(--border-color)' }} />
              
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2.5 }}>
                <FormControlLabel
                  control={
                    <Switch 
                      checked={escalationEnabled} 
                      onChange={(e) => setEscalationEnabled(e.target.checked)} 
                      color="primary" 
                    />
                  }
                  label={<Typography fontWeight="bold">Enable Auto Escalation</Typography>}
                />

                <Grid container spacing={2}>
                  <Grid item xs={12} sm={6}>
                    <TextField 
                      label="Response Time (Minutes)" 
                      type="number" 
                      value={responseTimeMinutes} 
                      onChange={(e) => {
                        const mins = parseInt(e.target.value) || 1;
                        setResponseTimeMinutes(mins);
                        setResponseTimeWindow(mins * 60);
                      }} 
                      fullWidth 
                    />
                  </Grid>
                  <Grid item xs={12} sm={6}>
                    <TextField 
                      label="Response Time Window (Seconds)" 
                      type="number" 
                      value={responseTimeWindow} 
                      onChange={(e) => setResponseTimeWindow(parseInt(e.target.value) || 30)} 
                      fullWidth 
                    />
                  </Grid>
                </Grid>

                <Typography variant="subtitle2" fontWeight="bold" sx={{ mt: 1 }}>
                  Escalation Target Groups:
                </Typography>
                
                <Box sx={{ display: 'flex', flexDirection: 'column', pl: 1 }}>
                  <FormControlLabel
                    control={
                      <Switch 
                        checked={notifySecurity} 
                        onChange={(e) => setNotifySecurity(e.target.checked)} 
                        color="primary" 
                      />
                    }
                    label="Notify Security Staff"
                  />
                  <FormControlLabel
                    control={
                      <Switch 
                        checked={notifyVolunteers} 
                        onChange={(e) => setNotifyVolunteers(e.target.checked)} 
                        color="primary" 
                      />
                    }
                    label="Notify Community Volunteers"
                  />
                  <FormControlLabel
                    control={
                      <Switch 
                        checked={notifyAdmin} 
                        onChange={(e) => setNotifyAdmin(e.target.checked)} 
                        color="primary" 
                      />
                    }
                    label="Notify Society Administrators"
                  />
                </Box>

                <Button 
                  variant="contained" 
                  color="primary" 
                  startIcon={<MdSave size={18} />}
                  sx={{ width: 'fit-content', mt: 1 }} 
                  onClick={handleSaveConfig}
                >
                  Save Configuration
                </Button>
              </Box>
            </CardContent>
          </Card>
        </Grid>

        {/* Escalation Workflow Rules Overview */}
        <Grid item xs={12} md={5}>
          <Card sx={{ backgroundColor: 'var(--bg-card)', color: 'var(--text-primary)', boxShadow: 'var(--shadow-sm)' }}>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
                <MdMonitor size={22} color="var(--primary)" />
                <Typography variant="h6">Escalation Flow Overview</Typography>
              </Box>
              <Divider sx={{ mb: 2, borderColor: 'var(--border-color)' }} />
              
              <Typography variant="body2" sx={{ color: 'var(--text-secondary)', mb: 2 }}>
                Sequential escalation process triggered when an SOS is created:
              </Typography>
              
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.5, pl: 1 }}>
                <Typography variant="body2">1. 🚨 <strong>Resident presses SOS</strong> → Primary Guardian notified</Typography>
                <Typography variant="body2">2. ⏳ <strong>Wait configured time</strong> ({responseTimeMinutes}m / {responseTimeWindow}s)</Typography>
                <Typography variant="body2">3. 👥 <strong>If no response</strong> → Secondary Guardian notified</Typography>
                <Typography variant="body2">4. 📞 <strong>Still no response</strong> → Verified Emergency Contacts notified</Typography>
                {notifySecurity && <Typography variant="body2">5. 👮 <strong>Escalate to Security</strong> → Assigned society guards notified</Typography>}
                {notifyVolunteers && <Typography variant="body2">6. 🤝 <strong>Escalate to Volunteers</strong> → Nearby volunteers notified</Typography>}
                {notifyAdmin && <Typography variant="body2">7. 👑 <strong>Escalate to Admin</strong> → System administrators notified</Typography>}
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Escalation Monitoring & Logs Table */}
      <Typography variant="h6" fontWeight="bold" sx={{ mb: 2 }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          <MdHistory size={22} />
          Escalation Incident Monitoring & Logs
        </Box>
      </Typography>

      <TableContainer component={Paper} sx={{ backgroundColor: 'var(--bg-card)', color: 'var(--text-primary)', boxShadow: 'var(--shadow-sm)' }}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 'bold' }}>Incident ID</TableCell>
              <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 'bold' }}>Resident</TableCell>
              <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 'bold' }}>Escalation Level</TableCell>
              <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 'bold' }}>Assignee / Recipient</TableCell>
              <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 'bold' }}>Scheduled At</TableCell>
              <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 'bold' }}>Triggered At</TableCell>
              <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 'bold' }}>Status</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {logs.map((row) => (
              <TableRow key={row.id}>
                <TableCell sx={{ color: 'var(--text-primary)', fontWeight: 'bold' }}>#{row.incident}</TableCell>
                <TableCell sx={{ color: 'var(--text-primary)' }}>{row.resident_name || 'Resident'}</TableCell>
                <TableCell sx={{ color: 'var(--text-primary)' }}>{row.escalation_level || row.step}</TableCell>
                <TableCell sx={{ color: 'var(--text-primary)' }}>{row.new_recipient || row.step}</TableCell>
                <TableCell sx={{ color: 'var(--text-primary)' }}>{new Date(row.scheduled_at).toLocaleString()}</TableCell>
                <TableCell sx={{ color: 'var(--text-primary)' }}>
                  {row.triggered_at ? new Date(row.triggered_at).toLocaleString() : '—'}
                </TableCell>
                <TableCell>{getStatusChip(row.status)}</TableCell>
              </TableRow>
            ))}
            {logs.length === 0 && !loading && (
              <TableRow>
                <TableCell colSpan={7} align="center" sx={{ color: 'var(--text-secondary)', py: 3 }}>
                  No escalation logs recorded yet.
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </TableContainer>
    </Box>
  );
};

export default EscalationSettings;
