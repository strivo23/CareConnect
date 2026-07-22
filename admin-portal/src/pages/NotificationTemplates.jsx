import React, { useState, useEffect } from 'react';
import { Box, Typography, Button, Grid, Card, CardContent, TextField, Table, TableBody, TableCell, TableContainer, TableHead, TableRow, Paper, Dialog, DialogTitle, DialogContent, DialogActions } from '@mui/material';
import { MdAdd, MdEdit, MdDelete } from 'react-icons/md';
import apiClient from '../services/api';

const NotificationTemplates = () => {
  const [templates, setTemplates] = useState([]);
  const [loading, setLoading] = useState(true);
  const [open, setOpen] = useState(false);
  const [editItem, setEditItem] = useState(null);
  
  // Form fields
  const [name, setName] = useState('');
  const [titleTemplate, setTitleTemplate] = useState('');
  const [messageTemplate, setMessageTemplate] = useState('');
  const [category, setCategory] = useState('');

  const fetchTemplates = async () => {
    try {
      const res = await apiClient.get('/notifications/templates/');
      setTemplates(res.data);
    } catch (err) {
      console.error('Error fetching templates:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchTemplates();
  }, []);

  const handleOpen = (item = null) => {
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
    setOpen(true);
  };

  const handleClose = () => {
    setOpen(false);
  };

  const handleSave = async () => {
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
      handleClose();
    } catch (err) {
      console.error('Error saving template:', err);
    }
  };

  const handleDelete = async (id) => {
    if (window.confirm('Are you sure you want to delete this template?')) {
      try {
        await apiClient.delete(`/notifications/templates/${id}/`);
        fetchTemplates();
      } catch (err) {
        console.error('Error deleting template:', err);
      }
    }
  };

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 4 }}>
        <Typography variant="h5" fontWeight="bold">Notification Templates</Typography>
        <Button variant="contained" color="primary" startIcon={<MdAdd />} onClick={() => handleOpen()}>
          Add Template
        </Button>
      </Box>

      <TableContainer component={Paper} sx={{ backgroundColor: 'var(--bg-card)', color: 'var(--text-primary)', boxShadow: 'var(--shadow-sm)' }}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 'bold' }}>Name</TableCell>
              <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 'bold' }}>Title Template</TableCell>
              <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 'bold' }}>Message Template</TableCell>
              <TableCell sx={{ color: 'var(--text-secondary)', fontWeight: 'bold' }}>Category</TableCell>
              <TableCell align="right" sx={{ color: 'var(--text-secondary)', fontWeight: 'bold' }}>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {templates.map((row) => (
              <TableRow key={row.id}>
                <TableCell sx={{ color: 'var(--text-primary)' }}>{row.name}</TableCell>
                <TableCell sx={{ color: 'var(--text-primary)' }}>{row.title_template}</TableCell>
                <TableCell sx={{ color: 'var(--text-primary)' }}>{row.message_template}</TableCell>
                <TableCell sx={{ color: 'var(--text-primary)' }}>{row.category}</TableCell>
                <TableCell align="right">
                  <Button startIcon={<MdEdit />} color="primary" onClick={() => handleOpen(row)}>Edit</Button>
                  <Button startIcon={<MdDelete />} color="error" onClick={() => handleDelete(row.id)}>Delete</Button>
                </TableCell>
              </TableRow>
            ))}
            {templates.length === 0 && !loading && (
              <TableRow>
                <TableCell colSpan={5} align="center" sx={{ color: 'var(--text-secondary)', py: 3 }}>
                  No templates configured yet. Click 'Add Template' to create one.
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </TableContainer>

      <Dialog open={open} onClose={handleClose} maxWidth="sm" fullWidth>
        <DialogTitle>{editItem ? 'Edit Notification Template' : 'Add Notification Template'}</DialogTitle>
        <DialogContent>
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, pt: 1 }}>
            <TextField label="Template Identifier Name" value={name} onChange={(e) => setName(e.target.value)} fullWidth required />
            <TextField label="Title Template (e.g. SOS Alert from {user})" value={titleTemplate} onChange={(e) => setTitleTemplate(e.target.value)} fullWidth required />
            <TextField label="Message Template" value={messageTemplate} onChange={(e) => setMessageTemplate(e.target.value)} multiline rows={3} fullWidth required />
            <TextField label="Category (e.g. sos, general)" value={category} onChange={(e) => setCategory(e.target.value)} fullWidth required />
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleClose}>Cancel</Button>
          <Button onClick={handleSave} variant="contained" color="primary">Save</Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default NotificationTemplates;
