import React, { useState, useEffect, useCallback } from 'react';
import { 
  Box, Button, Typography, Dialog, DialogTitle, DialogContent, 
  DialogActions, TextField, MenuItem, FormControl, InputLabel, Select,
  Snackbar, Alert, CircularProgress, FormControlLabel, Switch
} from '@mui/material';
import { MdAdd } from 'react-icons/md';
import SearchBar from '../components/SearchBar/SearchBar';
import DataTable from '../components/DataTable/DataTable';
import { flatService, blockService, societyService } from '../services/api';

const Flat = () => {
  const [flats, setFlats] = useState([]);
  const [societies, setSocieties] = useState([]);
  const [blocks, setBlocks] = useState([]); // all blocks
  const [filteredBlocksForFilter, setFilteredBlocksForFilter] = useState([]);
  const [filteredBlocksForForm, setFilteredBlocksForForm] = useState([]);
  const [loading, setLoading] = useState(false);
  
  // Search and Filter State
  const [searchTerm, setSearchTerm] = useState('');
  const [filterSociety, setFilterSociety] = useState('All');
  const [filterBlock, setFilterBlock] = useState('All');

  // Pagination State
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(5);
  const [totalCount, setTotalCount] = useState(0);

  // Dialog State
  const [openForm, setOpenForm] = useState(false);
  const [openDelete, setOpenDelete] = useState(false);
  const [selectedFlat, setSelectedFlat] = useState(null);

  // Form State
  const [formSociety, setFormSociety] = useState('');
  const [formData, setFormData] = useState({
    block: '',
    flat_number: '',
    floor: '',
    type: '2 BHK',
    occupied: false
  });

  // Snackbar State
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });

  // Fetch societies and blocks on load
  useEffect(() => {
    const initData = async () => {
      try {
        const socRes = await societyService.getAll({ page_size: 100 });
        setSocieties(socRes.data.results || []);

        const blkRes = await blockService.getAll({ page_size: 200 });
        setBlocks(blkRes.data.results || []);
      } catch (err) {
        console.error(err);
      }
    };
    initData();
  }, []);

  // Update filter block options when filter society changes
  useEffect(() => {
    if (filterSociety === 'All') {
      setFilteredBlocksForFilter([]);
      setFilterBlock('All');
    } else {
      const filtered = blocks.filter(b => b.society == filterSociety);
      setFilteredBlocksForFilter(filtered);
      setFilterBlock('All');
    }
  }, [filterSociety, blocks]);

  // Update form block options when form society changes
  useEffect(() => {
    if (!formSociety) {
      setFilteredBlocksForForm([]);
    } else {
      const filtered = blocks.filter(b => b.society == formSociety);
      setFilteredBlocksForForm(filtered);
      // Auto-select first block if available
      if (filtered.length > 0 && !filtered.some(f => f.id == formData.block)) {
        setFormData(prev => ({ ...prev, block: filtered[0].id }));
      }
    }
  }, [formSociety, blocks, formData.block]);

  // Fetch flats
  const fetchFlats = useCallback(async () => {
    setLoading(true);
    try {
      const params = {
        page: page + 1,
        page_size: rowsPerPage,
        search: searchTerm
      };
      if (filterSociety !== 'All') {
        params.society = filterSociety;
      }
      if (filterBlock !== 'All') {
        params.block = filterBlock;
      }
      const response = await flatService.getAll(params);
      setFlats(response.data.results || []);
      setTotalCount(response.data.count || 0);
    } catch (err) {
      console.error(err);
      setSnackbar({ open: true, message: 'Failed to fetch flats.', severity: 'error' });
    } finally {
      setLoading(false);
    }
  }, [page, rowsPerPage, searchTerm, filterSociety, filterBlock]);

  useEffect(() => {
    fetchFlats();
  }, [fetchFlats]);

  const handleSearch = (val) => {
    setSearchTerm(val);
    setPage(0);
  };

  const handleFilterSocietyChange = (e) => {
    setFilterSociety(e.target.value);
    setPage(0);
  };

  const handleFilterBlockChange = (e) => {
    setFilterBlock(e.target.value);
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
    setSelectedFlat(null);
    const initialSocId = societies.length > 0 ? societies[0].id : '';
    setFormSociety(initialSocId);
    
    // Find initial block id for this society if any
    const firstBlock = blocks.find(b => b.society === initialSocId);
    
    setFormData({
      block: firstBlock ? firstBlock.id : '',
      flat_number: '',
      floor: '',
      type: '2 BHK',
      occupied: false
    });
    setOpenForm(true);
  };

  const handleOpenEdit = (flat) => {
    setSelectedFlat(flat);
    setFormSociety(flat.society_id);
    setFormData({
      block: flat.block,
      flat_number: flat.flat_number,
      floor: flat.floor,
      type: flat.type,
      occupied: flat.occupied
    });
    setOpenForm(true);
  };

  const handleOpenDelete = (flat) => {
    setSelectedFlat(flat);
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
      if (selectedFlat) {
        await flatService.update(selectedFlat.id, formData);
        setSnackbar({ open: true, message: 'Flat updated successfully!', severity: 'success' });
      } else {
        await flatService.create(formData);
        setSnackbar({ open: true, message: 'Flat created successfully!', severity: 'success' });
      }
      setOpenForm(false);
      fetchFlats();
    } catch (err) {
      console.error(err);
      const errors = err.response?.data;
      let errorMsg = 'Failed to save flat.';
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
      await flatService.delete(selectedFlat.id);
      setSnackbar({ open: true, message: 'Flat deleted successfully!', severity: 'success' });
      setOpenDelete(false);
      fetchFlats();
    } catch (err) {
      console.error(err);
      setSnackbar({ open: true, message: 'Failed to delete flat.', severity: 'error' });
    } finally {
      setLoading(false);
    }
  };

  const columns = [
    { id: 'society_name', label: 'Society', minWidth: 150 },
    { id: 'block_name', label: 'Block/Tower', minWidth: 120 },
    { id: 'flat_number', label: 'Flat No', minWidth: 100 },
    { id: 'floor', label: 'Floor', minWidth: 100 },
    { id: 'type', label: 'Type', minWidth: 100 },
    { 
      id: 'occupied', 
      label: 'Status', 
      minWidth: 100,
      format: (value) => (
        <span style={{ 
          color: value ? 'var(--primary)' : 'var(--success)',
          backgroundColor: value ? 'var(--primary)15' : 'var(--success)15',
          padding: '4px 8px',
          borderRadius: '12px',
          fontSize: '0.85rem',
          fontWeight: 'bold'
        }}>
          {value ? 'Occupied' : 'Vacant'}
        </span>
      )
    },
  ];

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 4 }}>
        <Typography variant="h5" fontWeight="bold">Manage Flats</Typography>
        <Button variant="contained" color="primary" startIcon={<MdAdd />} onClick={handleOpenAdd}>Add Flat</Button>
      </Box>

      <Box sx={{ display: 'flex', gap: 2, mb: 3, flexWrap: 'wrap', alignItems: 'center' }}>
        <FormControl sx={{ minWidth: 180 }} size="small">
          <InputLabel>Society</InputLabel>
          <Select value={filterSociety} label="Society" onChange={handleFilterSocietyChange}>
            <MenuItem value="All">All Societies</MenuItem>
            {societies.map((soc) => (
              <MenuItem key={soc.id} value={soc.id}>{soc.name}</MenuItem>
            ))}
          </Select>
        </FormControl>

        <FormControl sx={{ minWidth: 180 }} size="small" disabled={filterSociety === 'All'}>
          <InputLabel>Block / Tower</InputLabel>
          <Select value={filterBlock} label="Block / Tower" onChange={handleFilterBlockChange}>
            <MenuItem value="All">All Blocks</MenuItem>
            {filteredBlocksForFilter.map((blk) => (
              <MenuItem key={blk.id} value={blk.id}>{blk.name}</MenuItem>
            ))}
          </Select>
        </FormControl>
        
        <SearchBar placeholder="Search Flat No or Type..." onSearch={handleSearch} />
      </Box>

      {loading && !openForm && !openDelete ? (
        <Box sx={{ display: 'flex', justifyContent: 'center', py: 5 }}>
          <CircularProgress color="primary" />
        </Box>
      ) : (
        <DataTable 
          columns={columns} 
          data={flats}
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
      <Dialog open={openForm} onClose={handleCloseForm} maxWidth="xs" fullWidth>
        <DialogTitle>{selectedFlat ? 'Edit Flat' : 'Add New Flat'}</DialogTitle>
        <form onSubmit={handleFormSubmit}>
          <DialogContent sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
            <TextField
              name="society"
              label="Select Society"
              select
              value={formSociety}
              onChange={(e) => setFormSociety(e.target.value)}
              fullWidth
              required
            >
              {societies.map((soc) => (
                <MenuItem key={soc.id} value={soc.id}>{soc.name}</MenuItem>
              ))}
            </TextField>
            <TextField
              name="block"
              label="Select Block/Tower"
              select
              value={formData.block}
              onChange={handleFormChange}
              fullWidth
              required
              disabled={!formSociety}
            >
              {filteredBlocksForForm.map((blk) => (
                <MenuItem key={blk.id} value={blk.id}>{blk.name}</MenuItem>
              ))}
            </TextField>
            <TextField
              name="flat_number"
              label="Flat Number"
              value={formData.flat_number}
              onChange={handleFormChange}
              fullWidth
              required
            />
            <TextField
              name="floor"
              label="Floor Number"
              type="number"
              value={formData.floor}
              onChange={handleFormChange}
              fullWidth
              required
            />
            <TextField
              name="type"
              label="Flat Type"
              select
              value={formData.type}
              onChange={handleFormChange}
              fullWidth
              required
            >
              <MenuItem value="1 BHK">1 BHK</MenuItem>
              <MenuItem value="2 BHK">2 BHK</MenuItem>
              <MenuItem value="3 BHK">3 BHK</MenuItem>
              <MenuItem value="4 BHK">4 BHK</MenuItem>
              <MenuItem value="Studio">Studio</MenuItem>
              <MenuItem value="Penthouse">Penthouse</MenuItem>
            </TextField>
            <FormControlLabel
              control={
                <Switch
                  checked={formData.occupied}
                  onChange={handleFormChange}
                  name="occupied"
                  color="primary"
                />
              }
              label="Is Occupied"
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
          Are you sure you want to delete flat "{selectedFlat?.flat_number}"?
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

export default Flat;
