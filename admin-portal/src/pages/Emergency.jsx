import React, { useState, useEffect, useCallback } from 'react';
import { 
  Box, Button, Typography, Dialog, DialogTitle, DialogContent, 
  DialogActions, TextField, MenuItem, Snackbar, Alert, CircularProgress, 
  Grid, Card, CardContent, CardActions, Chip, IconButton, FormControlLabel, Switch,
  Divider
} from '@mui/material';
import { MdAdd, MdEdit, MdDelete, MdPhone, MdVerified, MdOutlineVerified } from 'react-icons/md';
import SearchBar from '../components/SearchBar/SearchBar';
import { emergencyService, residentService } from '../services/api';

const Emergency = () => {
  const [contacts, setContacts] = useState([]);
  const [residents, setResidents] = useState([]);
  const [relationships, setRelationships] = useState([]);
  const [loading, setLoading] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');

  // Dialog State
  const [openForm, setOpenForm] = useState(false);
  const [openDelete, setOpenDelete] = useState(false);
  const [selectedContact, setSelectedContact] = useState(null);

  // Form State
  const [formData, setFormData] = useState({
    resident: '',
    name: '',
    phone: '',
    relationship: '',
    is_primary: false
  });

  // Snackbar State
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });

  // Fetch initial data
  useEffect(() => {
    const fetchDropdowns = async () => {
      try {
        const resRes = await residentService.getAll({ page_size: 100 });
        setResidents(resRes.data.results || []);

        const relRes = await emergencyService.getRelationships();
        setRelationships(relRes.data || []);
      } catch (err) {
        console.error(err);
      }
    };
    fetchDropdowns();
  }, []);

  // Fetch contacts
  const fetchContacts = useCallback(async () => {
    setLoading(true);
    try {
      const params = {
        search: searchTerm
      };
      const response = await emergencyService.getAllContacts(params);
      // Backend paginates if using DefaultPagination, check both structure
      const data = response.data.results !== undefined ? response.data.results : response.data;
      setContacts(data || []);
    } catch (err) {
      console.error(err);
      setSnackbar({ open: true, message: 'Failed to fetch emergency contacts.', severity: 'error' });
    } finally {
      setLoading(false);
    }
  }, [searchTerm]);

  useEffect(() => {
    fetchContacts();
  }, [fetchContacts]);

  const handleSearch = (val) => {
    setSearchTerm(val);
  };

  const handleOpenAdd = () => {
    setSelectedContact(null);
    setFormData({
      resident: residents.length > 0 ? residents[0].user.id : '',
      name: '',
      phone: '',
      relationship: relationships.length > 0 ? relationships[0].id : '',
      is_primary: false
    });
    setOpenForm(true);
  };

  const handleOpenEdit = (contact) => {
    setSelectedContact(contact);
    setFormData({
      resident: contact.resident,
      name: contact.name,
      phone: contact.phone,
      relationship: contact.relationship,
      is_primary: contact.is_primary
    });
    setOpenForm(true);
  };

  const handleOpenDelete = (contact) => {
    setSelectedContact(contact);
    setOpenDelete(true);
  };

  const handleCloseForm = () => {
    setOpenForm(false);
  };

  const handleCloseDelete = () => {
    setOpenDelete(false);
  };

  const handleFormChange = (e) => {
    const value = e.target.type === 'checkbox' ? e.target.checked : e.target.value;
    setFormData({ ...formData, [e.target.name]: value });
  };

  const handleFormSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      if (selectedContact) {
        await emergencyService.updateContact(selectedContact.id, formData);
        setSnackbar({ open: true, message: 'Emergency contact updated successfully!', severity: 'success' });
      } else {
        await emergencyService.createContact(formData);
        setSnackbar({ open: true, message: 'Emergency contact added successfully!', severity: 'success' });
      }
      setOpenForm(false);
      fetchContacts();
    } catch (err) {
      console.error(err);
      setSnackbar({ open: true, message: 'Failed to save emergency contact.', severity: 'error' });
    } finally {
      setLoading(false);
    }
  };

  const handleDeleteSubmit = async () => {
    setLoading(true);
    try {
      await emergencyService.deleteContact(selectedContact.id);
      setSnackbar({ open: true, message: 'Emergency contact deleted successfully!', severity: 'success' });
      setOpenDelete(false);
      fetchContacts();
    } catch (err) {
      console.error(err);
      setSnackbar({ open: true, message: 'Failed to delete contact.', severity: 'error' });
    } finally {
      setLoading(false);
    }
  };

  const handleVerify = async (id) => {
    setLoading(true);
    try {
      await emergencyService.verifyContact(id);
      setSnackbar({ open: true, message: 'Contact marked as Verified!', severity: 'success' });
      fetchContacts();
    } catch (err) {
      console.error(err);
      setSnackbar({ open: true, message: 'Failed to verify contact.', severity: 'error' });
    } finally {
      setLoading(false);
    }
  };

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 4 }}>
        <Typography variant="h5" fontWeight="bold">Emergency Contacts</Typography>
        <Button variant="contained" color="primary" startIcon={<MdAdd />} onClick={handleOpenAdd}>
          Add Contact
        </Button>
      </Box>

      <Box sx={{ mb: 4 }}>
        <SearchBar placeholder="Search by name, phone, or resident..." onSearch={handleSearch} />
      </Box>

      {loading && contacts.length === 0 ? (
        <Box sx={{ display: 'flex', justifyContent: 'center', py: 5 }}>
          <CircularProgress color="primary" />
        </Box>
      ) : (
        <Grid container spacing={3}>
          {contacts.map((contact) => (
            <Grid item xs={12} sm={6} md={4} key={contact.id}>
              <Card sx={{ 
                backgroundColor: 'var(--bg-card)', 
                color: 'var(--text-primary)', 
                boxShadow: 'var(--shadow-md)', 
                borderRadius: '12px',
                border: contact.is_primary ? '2px solid var(--primary)' : 'none',
                position: 'relative'
              }}>
                <CardContent>
                  <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', mb: 2 }}>
                    <Typography variant="h6" fontWeight="bold">
                      {contact.name}
                    </Typography>
                    {contact.is_primary && (
                      <Chip label="Primary" color="primary" size="small" sx={{ fontWeight: 'bold' }} />
                    )}
                  </Box>

                  <Typography variant="body2" sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1, color: 'var(--text-secondary)' }}>
                    <MdPhone /> {contact.phone}
                  </Typography>

                  <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap', mb: 2 }}>
                    <Chip label={contact.relationship_name || 'Relation'} size="small" variant="outlined" sx={{ color: 'var(--text-primary)' }} />
                    {contact.verified ? (
                      <Chip 
                        icon={<MdVerified style={{ color: 'var(--success)' }} />} 
                        label="Verified" 
                        size="small" 
                        sx={{ backgroundColor: 'var(--success)15', color: 'var(--success)', border: '1px solid var(--success)' }}
                      />
                    ) : (
                      <Chip 
                        icon={<MdOutlineVerified />} 
                        label="Unverified" 
                        size="small" 
                        sx={{ backgroundColor: 'var(--warning)15', color: 'var(--warning)', border: '1px solid var(--warning)' }}
                      />
                    )}
                  </Box>

                  <Divider sx={{ my: 1.5 }} />
                  <Typography variant="body2" color="textSecondary">
                    <strong>Resident:</strong> {contact.resident_details?.full_name || contact.resident_details?.email || 'Unknown'}
                  </Typography>
                </CardContent>

                <CardActions sx={{ justifyContent: 'space-between', px: 2, pb: 2 }}>
                  <Box>
                    <IconButton size="small" sx={{ color: 'var(--warning)' }} onClick={() => handleOpenEdit(contact)}>
                      <MdEdit />
                    </IconButton>
                    <IconButton size="small" sx={{ color: 'var(--danger)' }} onClick={() => handleOpenDelete(contact)}>
                      <MdDelete />
                    </IconButton>
                  </Box>
                  {!contact.verified && (
                    <Button 
                      size="small" 
                      variant="contained" 
                      color="success" 
                      onClick={() => handleVerify(contact.id)}
                      sx={{ textTransform: 'none', fontWeight: 'bold' }}
                    >
                      Verify
                    </Button>
                  )}
                </CardActions>
              </Card>
            </Grid>
          ))}
          {contacts.length === 0 && (
            <Grid item xs={12}>
              <Typography align="center" color="textSecondary" sx={{ py: 5 }}>
                No emergency contacts found.
              </Typography>
            </Grid>
          )}
        </Grid>
      )}

      {/* Add / Edit Form Dialog */}
      <Dialog open={openForm} onClose={handleCloseForm} maxWidth="xs" fullWidth>
        <DialogTitle>{selectedContact ? 'Edit Emergency Contact' : 'Add Emergency Contact'}</DialogTitle>
        <form onSubmit={handleFormSubmit}>
          <DialogContent sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
            <TextField
              name="resident"
              label="Associated Resident"
              select
              value={formData.resident}
              onChange={handleFormChange}
              fullWidth
              required
            >
              {residents.map((res) => (
                <MenuItem key={res.id} value={res.user.id}>
                  {res.user.full_name} ({res.user.email})
                </MenuItem>
              ))}
            </TextField>
            <TextField
              name="name"
              label="Contact Name"
              value={formData.name}
              onChange={handleFormChange}
              fullWidth
              required
            />
            <TextField
              name="phone"
              label="Phone Number"
              value={formData.phone}
              onChange={handleFormChange}
              fullWidth
              required
            />
            <TextField
              name="relationship"
              label="Relationship"
              select
              value={formData.relationship}
              onChange={handleFormChange}
              fullWidth
              required
            >
              {Array.isArray(relationships) && relationships.map((rel) => (
                <MenuItem key={rel.id} value={rel.id}>{rel.name}</MenuItem>
              ))}
            </TextField>
            <FormControlLabel
              control={
                <Switch
                  checked={formData.is_primary}
                  onChange={handleFormChange}
                  name="is_primary"
                  color="primary"
                />
              }
              label="Is Primary Contact"
            />
          </DialogContent>
          <DialogActions>
            <Button onClick={handleCloseForm}>Cancel</Button>
            <Button type="submit" variant="contained" disabled={loading}>
              {loading ? <CircularProgress size={20} color="inherit" /> : 'Save'}
            </Button>
          </DialogActions>
        </form>
      </Dialog>

      {/* Delete Confirmation Dialog */}
      <Dialog open={openDelete} onClose={handleCloseDelete}>
        <DialogTitle>Confirm Delete</DialogTitle>
        <DialogContent>
          Are you sure you want to delete emergency contact "{selectedContact?.name}"?
        </DialogContent>
        <DialogActions>
          <Button onClick={handleCloseDelete}>Cancel</Button>
          <Button onClick={handleDeleteSubmit} variant="contained" color="error" disabled={loading}>
            {loading ? <CircularProgress size={20} color="inherit" /> : 'Delete'}
          </Button>
        </DialogActions>
      </Dialog>

      {/* Snackbar for notifications */}
      <Snackbar 
        open={snackbar.open} 
        autoHideDuration={6000} 
        onClose={() => setSnackbar({ ...snackbar, open: false })}
      >
        <Alert severity={snackbar.severity} sx={{ width: '100%' }}>
          {snackbar.message}
        </Alert>
      </Snackbar>
    </Box>
  );
};

export default Emergency;
