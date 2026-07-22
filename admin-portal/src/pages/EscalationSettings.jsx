import React, { useState, useEffect } from 'react';
import { Box, Typography, Card, CardContent, TextField, Button, Grid, Table, TableBody, TableCell, TableContainer, TableHead, TableRow, Paper, Divider, Alert } from '@mui/material';
import { MdSettings, MdHistory } from 'react-icons/md';
import apiClient from '../services/api';

const EscalationSettings = () => {
  const [windowTime, setWindowTime] = useState(30);
  const [configId, setConfigId] = useState(null);
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState(null);

  const fetchConfig = async () => {
    try {
      const res = await apiClient.get('/sos/escalation-config/');
      if (res.data && res.data.length > 0) {
        setWindowTime(res.data[0].response_time_window);
        setConfigId(res.data[0].id);
      } else {
        // Create default config if empty
        const createRes = await apiClient.post('/sos/escalation-config/', { response_time_window: 30 });
        setWindowTime(createRes.data.response_time_window);
        setConfigId(createRes.data.id);
      }
    } catch (err) {
      console.error('Error fetching escalation config:', err);
    }
  };

  const fetchLogs = async () => {
    try {
      const res = await apiClient.get('/sos/escalation-logs/');
      setLogs(res.data);
    } catch (err) {
      console.error('Error fetching escalation logs:', err);
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
      if (configId) {
        await apiClient.put(`/sos/escalation-config/${configId}/`, { response_time_window: windowTime });
      } else {
        await apiClient.post('/sos/escalation-config/', { response_time_window: windowTime });
      }
      setMessage({ type: 'success', text: 'Escalation response time window saved successfully.' });
    } catch (err) {
      console.error('Error saving escalation config:', err);
      setMessage({ type: 'error', text: 'Failed to save escalation configuration.' });
    }
  };

  return (
    <Box>
      <Typography variant="h5" fontWeight="bold" sx={{ mb: 4 }}>Guardian Escalation Settings</Typography>

      {message && (
        <Alert severity={message.type} sx={{ mb: 3 }} onClose={() => setMessage(null)}>
          {message.text}
        </Alert>
      )}

      <Grid container spacing={3} sx={{ mb: 4 }}>
        <Grid item xs={12} md={6}>
          <Card sx={{ backgroundColor: 'var(--bg-card)', color: 'var(--text-primary)', boxShadow: 'var(--shadow-sm)' }}>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
                <MdSettings size={22} color="var(--primary)" />
                <Typography variant="h6">Configuration</Typography>
              </Box>
              <Divider sx={{ mb: 3, borderColor: 'var(--border-color)' }} />
              
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                <Typography variant="body2" sx={{ color: 'var(--text-secondary)' }}>
                  Set the response time window (in seconds) between each escalation step.
                  If a resident triggers an SOS, the system waits for this timeout before escalating to the next level.
                </Typography>
                <TextField 
                  label="Response Time Window (Seconds)" 
                  type="number" 
                  value={windowTime} 
                  onChange={(e) => setWindowTime(parseInt(e.target.value) || 0)} 
                  fullWidth 
                />
                <Button variant="contained" color="primary" sx={{ width: 'fit-content' }} onClick={handleSaveConfig}>
                  Save Configuration
                </Button>
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      <Typography variant="h6" fontWeight="bold" sx={{ mb: 2 }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          <MdHistory size={22} />
          Escalation Logs
        </Box>
      </Typography>

      <TableContainer component={Paper} sx={{ backgroundColor: 'var(--bg-card)', color: 'var(--text-primary)', boxShadow: 'var(--shadow-sm)' }}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 'bold' }}>Incident ID</TableCell>
              <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 'bold' }}>Escalation Step</TableCell>
              <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 'bold' }}>Status</TableCell>
              <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 'bold' }}>Scheduled At</TableCell>
              <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 'bold' }}>Triggered At</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {logs.map((row) => (
              <TableRow key={row.id}>
                <TableCell sx={{ color: 'var(--text-primary)' }}>#{row.incident}</TableCell>
                <TableCell sx={{ color: 'var(--text-primary)' }}>{row.step}</TableCell>
                <TableCell sx={{ color: 'var(--text-primary)' }}>{row.status}</TableCell>
                <TableCell sx={{ color: 'var(--text-primary)' }}>{new Date(row.scheduled_at).toLocaleString()}</TableCell>
                <TableCell sx={{ color: 'var(--text-primary)' }}>
                  {row.triggered_at ? new Date(row.triggered_at).toLocaleString() : '—'}
                </TableCell>
              </TableRow>
            ))}
            {logs.length === 0 && !loading && (
              <TableRow>
                <TableCell colSpan={5} align="center" sx={{ color: 'var(--text-secondary)', py: 3 }}>
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
