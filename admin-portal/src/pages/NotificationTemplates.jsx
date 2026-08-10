import React, { useState, useEffect } from 'react';
import {
  Box, Typography, Button, Grid, Card, CardContent, TextField, Table, TableBody, TableCell,
  TableContainer, TableHead, TableRow, Paper, Dialog, DialogTitle, DialogContent, DialogActions,
  Tabs, Tab, Chip, IconButton, Tooltip, Select, MenuItem, FormControl, InputLabel
} from '@mui/material';
import { MdAdd, MdEdit, MdDelete, MdRefresh, MdSearch, MdErrorOutline, MdCheckCircle } from 'react-icons/md';
import apiClient from '../services/api';

const NotificationTemplates = () => {
  const [activeTab, setActiveTab] = useState(0);

  // Templates state
  const [templates, setTemplates] = useState([]);
  const [loadingTemplates, setLoadingTemplates] = useState(true);
  const [openDialog, setOpenDialog] = useState(false);
  const [editItem, setEditItem] = useState(null);

  // Form fields
  const [name, setName] = useState('');
  const [titleTemplate, setTitleTemplate] = useState('');
  const [messageTemplate, setMessageTemplate] = useState('');
  const [category, setCategory] = useState('');

  // Delivery Logs state
  const [logs, setLogs] = useState([]);
  const [loadingLogs, setLoadingLogs] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [channelFilter, setChannelFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [retryingId, setRetryingId] = useState(null);

  const fetchTemplates = async () => {
    setLoadingTemplates(true);
    try {
      const res = await apiClient.get('/notifications/templates/');
      setTemplates(res.data);
    } catch (err) {
      console.error('Error fetching templates:', err);
    } finally {
      setLoadingTemplates(false);
    }
  };

  const fetchLogs = async () => {
    setLoadingLogs(true);
    try {
      let url = '/notifications/logs/?page_size=50';
      if (channelFilter !== 'all') url += `&channel=${channelFilter}`;
      if (statusFilter !== 'all') url += `&status=${statusFilter}`;
      if (searchQuery) url += `&search=${encodeURIComponent(searchQuery)}`;
      
      const res = await apiClient.get(url);
      const logData = res.data.results || res.data;
      setLogs(logData);
    } catch (err) {
      console.error('Error fetching delivery logs:', err);
    } finally {
      setLoadingLogs(false);
    }
  };

  useEffect(() => {
    fetchTemplates();
    fetchLogs();
  }, []);

  useEffect(() => {
    if (activeTab === 1) {
      fetchLogs();
    }
  }, [activeTab, channelFilter, statusFilter, searchQuery]);

  const handleOpenDialog = (item = null) => {
    if (item) {
      setEditItem(item);
      setName(item.name);
      setTitleTemplate(item.title_template);
      setMessageTemplate(item.message_template);
      setCategory(item.category);
    } else {
      setEditItem(null);
      setName('');
      setTitleTemplate('');
      setMessageTemplate('');
      setCategory('');
    }
    setOpenDialog(true);
  };

  const handleCloseDialog = () => {
    setOpenDialog(false);
  };

  const handleSaveTemplate = async () => {
    const data = {
      name,
      title_template: titleTemplate,
      message_template: messageTemplate,
      category,
    };
    try {
      if (editItem) {
        await apiClient.put(`/notifications/templates/${editItem.id}/`, data);
      } else {
        await apiClient.post('/notifications/templates/', data);
      }
      fetchTemplates();
      handleCloseDialog();
    } catch (err) {
      console.error('Error saving template:', err);
    }
  };

  const handleDeleteTemplate = async (id) => {
    if (window.confirm('Are you sure you want to delete this template?')) {
      try {
        await apiClient.delete(`/notifications/templates/${id}/`);
        fetchTemplates();
      } catch (err) {
        console.error('Error deleting template:', err);
      }
    }
  };

  const handleRetryNotification = async (logId) => {
    setRetryingId(logId);
    try {
      await apiClient.post(`/notifications/logs/${logId}/retry/`);
      alert('Notification retry initiated successfully!');
      fetchLogs();
    } catch (err) {
      console.error('Error retrying notification:', err);
      alert('Failed to retry notification delivery.');
    } finally {
      setRetryingId(null);
    }
  };

  const handleRetryAllFailed = async () => {
    if (window.confirm('Retry all failed notification dispatches?')) {
      try {
        const res = await apiClient.post('/notifications/logs/retry-failed/');
        alert(`Retried notifications: ${res.data.success_count} succeeded!`);
        fetchLogs();
      } catch (err) {
        console.error('Error batch retrying failed notifications:', err);
      }
    }
  };

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Box>
          <Typography variant="h5" fontWeight="bold">Notification Engine Management</Typography>
          <Typography variant="body2" sx={{ color: 'var(--text-secondary)' }}>
            Configure notification templates, monitor channel delivery logs, and retry failed dispatches.
          </Typography>
        </Box>
        {activeTab === 0 ? (
          <Button variant="contained" color="primary" startIcon={<MdAdd />} onClick={() => handleOpenDialog()}>
            Add Template
          </Button>
        ) : (
          <Button variant="outlined" color="warning" startIcon={<MdRefresh />} onClick={handleRetryAllFailed}>
            Retry Failed Dispatches
          </Button>
        )}
      </Box>

      <Box sx={{ borderBottom: 1, borderColor: 'divider', mb: 3 }}>
        <Tabs value={activeTab} onChange={(e, val) => setActiveTab(val)}>
          <Tab label="Notification Templates" />
          <Tab label="Delivery History & Audit Logs" />
        </Tabs>
      </Box>

      {/* Tab 0: Templates Configuration */}
      {activeTab === 0 && (
        <TableContainer component={Paper} sx={{ backgroundColor: 'var(--bg-card)', color: 'var(--text-primary)', boxShadow: 'var(--shadow-sm)' }}>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 'bold' }}>Template Name</TableCell>
                <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 'bold' }}>Category</TableCell>
                <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 'bold' }}>Title Template</TableCell>
                <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 'bold' }}>Message Template</TableCell>
                <TableCell align="right" sx={{ color: 'var(--text-secondary)', fontWeight: 'bold' }}>Actions</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {templates.map((row) => (
                <TableRow key={row.id}>
                  <TableCell sx={{ color: 'var(--text-primary)', fontWeight: 'bold' }}>{row.name}</TableCell>
                  <TableCell>
                    <Chip label={row.category || 'general'} size="small" color="primary" variant="outlined" />
                  </TableCell>
                  <TableCell sx={{ color: 'var(--text-primary)' }}>{row.title_template}</TableCell>
                  <TableCell sx={{ color: 'var(--text-primary)', maxWidth: 300 }}>{row.message_template}</TableCell>
                  <TableCell align="right">
                    <Button startIcon={<MdEdit />} color="primary" onClick={() => handleOpenDialog(row)}>Edit</Button>
                    <Button startIcon={<MdDelete />} color="error" onClick={() => handleDeleteTemplate(row.id)}>Delete</Button>
                  </TableCell>
                </TableRow>
              ))}
              {templates.length === 0 && !loadingTemplates && (
                <TableRow>
                  <TableCell colSpan={5} align="center" sx={{ color: 'var(--text-secondary)', py: 3 }}>
                    No notification templates configured yet. Click 'Add Template' to create one.
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </TableContainer>
      )}

      {/* Tab 1: Delivery History & Logs */}
      {activeTab === 1 && (
        <Box>
          <Grid container spacing={2} sx={{ mb: 3 }}>
            <Grid item xs={12} sm={4}>
              <TextField
                fullWidth
                size="small"
                placeholder="Search recipient, message, title..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                InputProps={{
                  startAdornment: <MdSearch style={{ marginRight: 8, color: 'var(--text-secondary)' }} />
                }}
              />
            </Grid>
            <Grid item xs={6} sm={4}>
              <FormControl fullWidth size="small">
                <InputLabel>Channel Filter</InputLabel>
                <Select value={channelFilter} label="Channel Filter" onChange={(e) => setChannelFilter(e.target.value)}>
                  <MenuItem value="all">All Channels</MenuItem>
                  <MenuItem value="FCM">Push (FCM)</MenuItem>
                  <MenuItem value="EMAIL">Email (SMTP)</MenuItem>
                  <MenuItem value="SMS">SMS Gateway</MenuItem>
                  <MenuItem value="IN_APP">In-App Notification</MenuItem>
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={6} sm={4}>
              <FormControl fullWidth size="small">
                <InputLabel>Status Filter</InputLabel>
                <Select value={statusFilter} label="Status Filter" onChange={(e) => setStatusFilter(e.target.value)}>
                  <MenuItem value="all">All Statuses</MenuItem>
                  <MenuItem value="SUCCESS">Success</MenuItem>
                  <MenuItem value="FAILURE">Failure</MenuItem>
                </Select>
              </FormControl>
            </Grid>
          </Grid>

          <TableContainer component={Paper} sx={{ backgroundColor: 'var(--bg-card)', color: 'var(--text-primary)', boxShadow: 'var(--shadow-sm)' }}>
            <Table>
              <TableHead>
                <TableRow>
                  <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 'bold' }}>Timestamp</TableCell>
                  <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 'bold' }}>Channel</TableCell>
                  <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 'bold' }}>Recipient</TableCell>
                  <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 'bold' }}>Status</TableCell>
                  <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 'bold' }}>Title & Message</TableCell>
                  <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 'bold' }}>Retry Count</TableCell>
                  <TableCell align="right" sx={{ color: 'var(--text-secondary)', fontWeight: 'bold' }}>Action</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {logs.map((log) => (
                  <TableRow key={log.id}>
                    <TableCell sx={{ color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
                      {new Date(log.created_at).toLocaleString()}
                    </TableCell>
                    <TableCell>
                      <Chip
                        label={log.channel}
                        size="small"
                        color={log.channel === 'FCM' ? 'info' : log.channel === 'SMS' ? 'warning' : log.channel === 'EMAIL' ? 'secondary' : 'default'}
                      />
                    </TableCell>
                    <TableCell sx={{ color: 'var(--text-primary)', fontWeight: 500 }}>{log.recipient}</TableCell>
                    <TableCell>
                      <Chip
                        icon={log.status === 'SUCCESS' ? <MdCheckCircle /> : <MdErrorOutline />}
                        label={log.status}
                        size="small"
                        color={log.status === 'SUCCESS' ? 'success' : 'error'}
                      />
                    </TableCell>
                    <TableCell sx={{ color: 'var(--text-primary)', maxWidth: 280 }}>
                      <Typography variant="subtitle2" fontWeight="bold" noWrap>{log.title || 'Notification'}</Typography>
                      <Typography variant="caption" display="block" color="text.secondary" noWrap>{log.message}</Typography>
                      {log.error_message && (
                        <Typography variant="caption" color="error.main" display="block" sx={{ mt: 0.5 }}>
                          Error: {log.error_message}
                        </Typography>
                      )}
                    </TableCell>
                    <TableCell sx={{ color: 'var(--text-primary)' }}>{log.retry_count || 0}</TableCell>
                    <TableCell align="right">
                      {log.status === 'FAILURE' ? (
                        <Button
                          size="small"
                          variant="outlined"
                          color="warning"
                          startIcon={<MdRefresh />}
                          disabled={retryingId === log.id}
                          onClick={() => handleRetryNotification(log.id)}
                        >
                          Retry
                        </Button>
                      ) : (
                        <Typography variant="caption" color="success.main">Delivered</Typography>
                      )}
                    </TableCell>
                  </TableRow>
                ))}
                {logs.length === 0 && !loadingLogs && (
                  <TableRow>
                    <TableCell colSpan={7} align="center" sx={{ color: 'var(--text-secondary)', py: 4 }}>
                      No notification logs found matching the filter criteria.
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          </TableContainer>
        </Box>
      )}

      {/* Edit/Add Dialog */}
      <Dialog open={openDialog} onClose={handleCloseDialog} maxWidth="sm" fullWidth>
        <DialogTitle>{editItem ? 'Edit Notification Template' : 'Add Notification Template'}</DialogTitle>
        <DialogContent>
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, pt: 1 }}>
            <TextField label="Template Identifier Name (e.g. SOS_CREATED)" value={name} onChange={(e) => setName(e.target.value)} fullWidth required />
            <TextField label="Title Template (e.g. SOS Alert from {resident_name})" value={titleTemplate} onChange={(e) => setTitleTemplate(e.target.value)} fullWidth required />
            <TextField label="Message Template (e.g. Emergency at {location})" value={messageTemplate} onChange={(e) => setMessageTemplate(e.target.value)} multiline rows={3} fullWidth required />
            <TextField label="Category (e.g. sos, guardian, general)" value={category} onChange={(e) => setCategory(e.target.value)} fullWidth required />
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleCloseDialog}>Cancel</Button>
          <Button onClick={handleSaveTemplate} variant="contained" color="primary">Save</Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default NotificationTemplates;
