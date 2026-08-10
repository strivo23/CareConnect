import React, { useState, useEffect, useCallback } from 'react';
import { 
  Box, Button, Typography, Dialog, DialogTitle, DialogContent, 
  DialogActions, TextField, MenuItem, Snackbar, Alert, CircularProgress,
  Chip, Tooltip, IconButton
} from '@mui/material';
import { MdAdd, MdAssignmentInd, MdPerson, MdRefresh } from 'react-icons/md';
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

  // Dialog States
  const [openForm, setOpenForm] = useState(false);
  const [openDelete, setOpenDelete] = useState(false);
  const [openAssignManager, setOpenAssignManager] = useState(false);

  const [selectedSociety, setSelectedSociety] = useState(null);
  const [eligibleManagers, setEligibleManagers] = useState([]);
  const [selectedManagerId, setSelectedManagerId] = useState('');
  
  // Snackbar State
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });

  // Normalized Form State (Stores strictly society infrastructure details)
  const [formData, setFormData] = useState({
    name: '',
    code: '',
    address: '',
    city: '',
    state: '',
    pincode: '',
    country: 'India',
    description: '',
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

  const fetchEligibleManagers = async () => {
    try {
      const res = await societyService.getEligibleManagers();
      setEligibleManagers(res.data || []);
    } catch (err) {
      console.error('Failed to fetch eligible managers:', err);
    }
  };

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
      code: '',
      address: '',
      city: '',
      state: '',
      pincode: '',
      country: 'India',
      description: '',
      status: 'Active'
    });
    setOpenForm(true);
  };

  const handleOpenEdit = (society) => {
    setSelectedSociety(society);
    setFormData({
      name: society.name || '',
      code: society.code || '',
      address: society.address || '',
      city: society.city || '',
      state: society.state || '',
      pincode: society.pincode || '',
      country: society.country || 'India',
      description: society.description || '',
      status: society.status || 'Active'
    });
    setOpenForm(true);
  };

  const handleOpenDelete = (society) => {
    setSelectedSociety(society);
    setOpenDelete(true);
  };

  const handleOpenAssignManager = (society) => {
    setSelectedSociety(society);
    setSelectedManagerId(society.society_manager || '');
    fetchEligibleManagers();
    setOpenAssignManager(true);
  };

  const handleSaveManagerAssignment = async () => {
    if (!selectedSociety) return;
    setLoading(true);
    try {
      await societyService.assignManager(selectedSociety.id, selectedManagerId || null);
      setSnackbar({ open: true, message: 'Society Manager assigned successfully!', severity: 'success' });
      setOpenAssignManager(false);
      fetchSocieties();
    } catch (err) {
      console.error(err);
      setSnackbar({ open: true, message: 'Failed to assign Society Manager.', severity: 'error' });
    } finally {
      setLoading(false);
    }
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
    { id: 'code', label: 'Society Code', minWidth: 120, format: (val) => val || 'N/A' },
    { id: 'name', label: 'Society Name', minWidth: 180 },
    { id: 'city', label: 'City', minWidth: 110 },
    { id: 'state', label: 'State', minWidth: 110 },
    { id: 'country', label: 'Country', minWidth: 100, format: (val) => val || 'India' },
    { 
      id: 'society_manager_name', 
      label: 'Society Manager', 
      minWidth: 170,
      format: (val, row) => (
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          <Chip
            icon={<MdPerson size={16} />}
            label={val || 'Unassigned'}
            size="small"
            color={val ? 'primary' : 'default'}
            sx={{ fontWeight: 700, borderRadius: '8px' }}
          />
        </Box>
      )
    },
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
    {
      id: 'actions',
      label: 'Assign Manager',
      minWidth: 130,
      align: 'center',
      format: (val, row) => (
        <Button
          size="small"
          variant="outlined"
          startIcon={<MdAssignmentInd />}
          onClick={(e) => { e.stopPropagation(); handleOpenAssignManager(row); }}
          sx={{ borderRadius: '8px', fontSize: '0.75rem', textTransform: 'none', fontWeight: 700 }}
        >
          Assign
        </Button>
      )
    }
  ];

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Box>
          <Typography variant="h5" fontWeight="bold">
            Gated Society Infrastructure Management
          </Typography>
          <Typography variant="body2" color="text.secondary">
            Manage normalized society profiles, location parameters, and assign verified Society Managers.
          </Typography>
        </Box>
        <Button variant="contained" color="primary" startIcon={<MdAdd />} onClick={handleOpenAdd} sx={{ borderRadius: '12px' }}>
          Add Society
        </Button>
      </Box>

      <Box sx={{ mb: 3 }}>
        <SearchBar 
          placeholder="Search by society code, name, city, state, or country..." 
          onSearch={handleSearch}
        />
      </Box>

      {loading && !openForm && !openDelete && !openAssignManager ? (
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

      {/* Normalized Add / Edit Form Dialog (ONLY Society Infrastructure Details) */}
      <Dialog open={openForm} onClose={() => setOpenForm(false)} maxWidth="sm" fullWidth PaperProps={{ sx: { borderRadius: '20px', p: 1 } }}>
        <DialogTitle sx={{ fontWeight: 800 }}>{selectedSociety ? 'Edit Society Infrastructure' : 'Add New Gated Society'}</DialogTitle>
        <form onSubmit={handleFormSubmit}>
          <DialogContent sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
            <Box sx={{ display: 'flex', gap: 2 }}>
              <TextField
                name="name"
                label="Society Name"
                value={formData.name}
                onChange={handleFormChange}
                fullWidth
                required
                size="small"
              />
              <TextField
                name="code"
                label="Society Code (Unique)"
                placeholder="e.g. SOC-GR-01"
                value={formData.code}
                onChange={handleFormChange}
                fullWidth
                size="small"
              />
            </Box>

            <TextField
              name="address"
              label="Street Address"
              value={formData.address}
              onChange={handleFormChange}
              fullWidth
              multiline
              rows={2}
              required
              size="small"
            />

            <Box sx={{ display: 'flex', gap: 2 }}>
              <TextField
                name="city"
                label="City"
                value={formData.city}
                onChange={handleFormChange}
                fullWidth
                required
                size="small"
              />
              <TextField
                name="state"
                label="State"
                value={formData.state}
                onChange={handleFormChange}
                fullWidth
                required
                size="small"
              />
            </Box>

            <Box sx={{ display: 'flex', gap: 2 }}>
              <TextField
                name="pincode"
                label="Pincode"
                value={formData.pincode}
                onChange={handleFormChange}
                fullWidth
                required
                size="small"
              />
              <TextField
                name="country"
                label="Country"
                value={formData.country}
                onChange={handleFormChange}
                fullWidth
                required
                size="small"
              />
            </Box>

            <TextField
              name="description"
              label="Society Description / Amenities (Optional)"
              value={formData.description}
              onChange={handleFormChange}
              fullWidth
              multiline
              rows={2}
              size="small"
            />

            <TextField
              name="status"
              label="Status"
              select
              value={formData.status}
              onChange={handleFormChange}
              fullWidth
              required
              size="small"
            >
              <MenuItem value="Active">Active</MenuItem>
              <MenuItem value="Inactive">Inactive</MenuItem>
            </TextField>
          </DialogContent>
          <DialogActions sx={{ px: 3, pb: 2 }}>
            <Button onClick={() => setOpenForm(false)}>Cancel</Button>
            <Button type="submit" variant="contained" disabled={loading} sx={{ borderRadius: '10px', px: 3 }}>
              {loading ? <CircularProgress size={20} color="inherit" /> : 'Save Society'}
            </Button>
          </DialogActions>
        </form>
      </Dialog>

      {/* Dedicated Assign Society Manager Dialog */}
      <Dialog open={openAssignManager} onClose={() => setOpenAssignManager(false)} maxWidth="xs" fullWidth PaperProps={{ sx: { borderRadius: '20px', p: 1 } }}>
        <DialogTitle sx={{ fontWeight: 800 }}>
          Assign Society Manager
        </DialogTitle>
        <DialogContent sx={{ display: 'flex', flexDirection: 'column', gap: 2, pt: 1 }}>
          <Typography variant="body2" color="text.secondary">
            Select a verified user with the <strong>Society Manager</strong> or <strong>Admin</strong> role to manage <strong>{selectedSociety?.name}</strong>.
          </Typography>
          <TextField
            select
            label="Select Verified Society Manager"
            value={selectedManagerId}
            onChange={(e) => setSelectedManagerId(e.target.value)}
            fullWidth
            size="small"
          >
            <MenuItem value="">Unassigned (None)</MenuItem>
            {eligibleManagers.map((mgr) => (
              <MenuItem key={mgr.id} value={mgr.id}>
                {mgr.full_name} ({mgr.email}) — Role: {mgr.role}
              </MenuItem>
            ))}
          </TextField>
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button onClick={() => setOpenAssignManager(false)}>Cancel</Button>
          <Button variant="contained" onClick={handleSaveManagerAssignment} disabled={loading} sx={{ borderRadius: '10px', px: 3 }}>
            {loading ? <CircularProgress size={20} color="inherit" /> : 'Save Assignment'}
          </Button>
        </DialogActions>
      </Dialog>

      {/* Delete Confirmation Dialog */}
      <Dialog open={openDelete} onClose={() => setOpenDelete(false)}>
        <DialogTitle sx={{ fontWeight: 800 }}>Confirm Delete</DialogTitle>
        <DialogContent>
          Are you sure you want to delete society "{selectedSociety?.name}"? All associated blocks and flats will be permanently deleted.
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button onClick={() => setOpenDelete(false)}>Cancel</Button>
          <Button onClick={handleDeleteSubmit} variant="contained" color="error" disabled={loading} sx={{ borderRadius: '10px' }}>
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
