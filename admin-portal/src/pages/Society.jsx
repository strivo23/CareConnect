import React, { useState, useEffect, useCallback } from 'react';
import { 
  Box, Button, Typography, Dialog, DialogTitle, DialogContent, 
  DialogActions, TextField, MenuItem, Snackbar, Alert, CircularProgress
} from '@mui/material';
import { MdAdd } from 'react-icons/md';
import SearchBar from '../components/SearchBar/SearchBar';
import DataTable from '../components/DataTable/DataTable';
import { societyService } from '../services/api';

const Society = () => {
  const [societies, setSocieties] = useState([]);
  const [loading, setLoading] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  
  // Pagination State
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(5);
  const [totalCount, setTotalCount] = useState(0);

  // Dialog State
  const [openForm, setOpenForm] = useState(false);
  const [openDelete, setOpenDelete] = useState(false);
  const [selectedSociety, setSelectedSociety] = useState(null);
  
  // Snackbar State
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });

  // Form State
  const [formData, setFormData] = useState({
    name: '',
    address: '',
    city: '',
    state: '',
    pincode: '',
    contact_person: '',
    contact_number: '',
    email: '',
    status: 'Active'
  });

  const fetchSocieties = useCallback(async () => {
    setLoading(true);
    try {
      const response = await societyService.getAll({
        page: page + 1,
        page_size: rowsPerPage,
        search: searchTerm,
      });
      setSocieties(response.data.results || []);
      setTotalCount(response.data.count || 0);
    } catch (err) {
      console.error(err);
      setSnackbar({ open: true, message: 'Failed to fetch societies.', severity: 'error' });
    } finally {
      setLoading(false);
    }
  }, [page, rowsPerPage, searchTerm]);

  useEffect(() => {
    fetchSocieties();
  }, [fetchSocieties]);

  const handleSearch = (val) => {
    setSearchTerm(val);
    setPage(0);
  };

  const handlePageChange = (event, newPage) => {
    setPage(newPage);
  };

  const handleRowsPerPageChange = (event) => {
    setRowsPerPage(parseInt(event.target.value, 10));
    setPage(0);
  };

  const handleOpenAdd = () => {
    setSelectedSociety(null);
    setFormData({
      name: '',
      address: '',
      city: '',
      state: '',
      pincode: '',
      contact_person: '',
      contact_number: '',
      email: '',
      status: 'Active'
    });
    setOpenForm(true);
  };

  const handleOpenEdit = (society) => {
    setSelectedSociety(society);
    setFormData({
      name: society.name,
      address: society.address,
      city: society.city,
      state: society.state,
      pincode: society.pincode,
      contact_person: society.contact_person,
      contact_number: society.contact_number,
      email: society.email,
      status: society.status
    });
    setOpenForm(true);
  };

  const handleOpenDelete = (society) => {
    setSelectedSociety(society);
    setOpenDelete(true);
  };

  const handleCloseForm = () => {
    setOpenForm(false);
  };

  const handleCloseDelete = () => {
    setOpenDelete(false);
  };

  const handleFormChange = (e) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };

  const handleFormSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      if (selectedSociety) {
        await societyService.update(selectedSociety.id, formData);
        setSnackbar({ open: true, message: 'Society updated successfully!', severity: 'success' });
      } else {
        await societyService.create(formData);
        setSnackbar({ open: true, message: 'Society added successfully!', severity: 'success' });
      }
      setOpenForm(false);
      fetchSocieties();
    } catch (err) {
      console.error(err);
      const errors = err.response?.data;
      let errorMsg = 'Failed to save society.';
      if (errors && typeof errors === 'object') {
        errorMsg = Object.entries(errors)
          .map(([key, val]) => `${key}: ${Array.isArray(val) ? val.join(', ') : val}`)
          .join(' | ');
      }
      setSnackbar({ open: true, message: errorMsg, severity: 'error' });
    } finally {
      setLoading(false);
    }
  };

  const handleDeleteSubmit = async () => {
    setLoading(true);
    try {
      await societyService.delete(selectedSociety.id);
      setSnackbar({ open: true, message: 'Society deleted successfully!', severity: 'success' });
      setOpenDelete(false);
      fetchSocieties();
    } catch (err) {
      console.error(err);
      setSnackbar({ open: true, message: 'Failed to delete society.', severity: 'error' });
    } finally {
      setLoading(false);
    }
  };

  const columns = [
    { id: 'name', label: 'Society Name', minWidth: 200 },
    { id: 'contact_person', label: 'Contact Person', minWidth: 150 },
    { id: 'contact_number', label: 'Contact Number', minWidth: 120 },
    { id: 'email', label: 'Email', minWidth: 150 },
    { id: 'city', label: 'City', minWidth: 120 },
    { id: 'total_blocks', label: 'Blocks', minWidth: 80, align: 'center' },
    { id: 'total_flats', label: 'Flats', minWidth: 80, align: 'center' },
    { 
      id: 'status', 
      label: 'Status', 
      minWidth: 100,
      format: (value) => (
        <span style={{ 
          color: value === 'Active' ? 'var(--success)' : 'var(--danger)',
          backgroundColor: value === 'Active' ? 'var(--success)15' : 'var(--danger)15',
          padding: '4px 8px',
          borderRadius: '12px',
          fontSize: '0.85rem',
          fontWeight: 'bold'
        }}>
          {value}
        </span>
      )
    },
  ];

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 4 }}>
        <Typography variant="h5" fontWeight="bold">
          Manage Societies
        </Typography>
        <Button variant="contained" color="primary" startIcon={<MdAdd />} onClick={handleOpenAdd}>
          Add Society
        </Button>
      </Box>

      <Box sx={{ mb: 3 }}>
        <SearchBar 
          placeholder="Search by name, city, state, or contact..." 
          onSearch={handleSearch}
        />
      </Box>

      {loading && !openForm && !openDelete ? (
        <Box sx={{ display: 'flex', justifyContent: 'center', py: 5 }}>
          <CircularProgress color="primary" />
        </Box>
      ) : (
        <DataTable 
          columns={columns} 
          data={societies}
          serverSide
          count={totalCount}
          page={page}
          rowsPerPage={rowsPerPage}
          onPageChange={handlePageChange}
          onRowsPerPageChange={handleRowsPerPageChange}
          onEdit={handleOpenEdit}
          onDelete={handleOpenDelete}
        />
      )}

      {/* Add / Edit Form Dialog */}
      <Dialog open={openForm} onClose={handleCloseForm} maxWidth="sm" fullWidth>
        <DialogTitle>{selectedSociety ? 'Edit Society' : 'Add New Society'}</DialogTitle>
        <form onSubmit={handleFormSubmit}>
          <DialogContent sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
            <TextField
              name="name"
              label="Society Name"
              value={formData.name}
              onChange={handleFormChange}
              fullWidth
              required
            />
            <TextField
              name="address"
              label="Address"
              value={formData.address}
              onChange={handleFormChange}
              fullWidth
              multiline
              rows={2}
              required
            />
            <Box sx={{ display: 'flex', gap: 2 }}>
              <TextField
                name="city"
                label="City"
                value={formData.city}
                onChange={handleFormChange}
                fullWidth
                required
              />
              <TextField
                name="state"
                label="State"
                value={formData.state}
                onChange={handleFormChange}
                fullWidth
                required
              />
              <TextField
                name="pincode"
                label="Pincode"
                value={formData.pincode}
                onChange={handleFormChange}
                fullWidth
                required
              />
            </Box>
            <TextField
              name="contact_person"
              label="Contact Person"
              value={formData.contact_person}
              onChange={handleFormChange}
              fullWidth
              required
            />
            <TextField
              name="contact_number"
              label="Contact Number"
              value={formData.contact_number}
              onChange={handleFormChange}
              fullWidth
              required
            />
            <TextField
              name="email"
              label="Email"
              type="email"
              value={formData.email}
              onChange={handleFormChange}
              fullWidth
              required
            />
            <TextField
              name="status"
              label="Status"
              select
              value={formData.status}
              onChange={handleFormChange}
              fullWidth
              required
            >
              <MenuItem value="Active">Active</MenuItem>
              <MenuItem value="Inactive">Inactive</MenuItem>
            </TextField>
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
          Are you sure you want to delete society "{selectedSociety?.name}"? All associated blocks and flats will be permanently deleted.
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

export default Society;
