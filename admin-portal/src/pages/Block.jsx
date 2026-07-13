import React, { useState, useEffect, useCallback } from 'react';
import { 
  Box, Button, Typography, Dialog, DialogTitle, DialogContent, 
  DialogActions, TextField, MenuItem, FormControl, InputLabel, Select,
  Snackbar, Alert, CircularProgress
} from '@mui/material';
import { MdAdd } from 'react-icons/md';
import SearchBar from '../components/SearchBar/SearchBar';
import DataTable from '../components/DataTable/DataTable';
import { blockService, societyService } from '../services/api';

const Block = () => {
  const [blocks, setBlocks] = useState([]);
  const [societies, setSocieties] = useState([]);
  const [loading, setLoading] = useState(false);
  
  // Search and Filter State
  const [searchTerm, setSearchTerm] = useState('');
  const [filterSociety, setFilterSociety] = useState('All');

  // Pagination State
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(5);
  const [totalCount, setTotalCount] = useState(0);

  // Dialog State
  const [openForm, setOpenForm] = useState(false);
  const [openDelete, setOpenDelete] = useState(false);
  const [selectedBlock, setSelectedBlock] = useState(null);

  // Form State
  const [formData, setFormData] = useState({
    society: '',
    name: '',
    total_floors: ''
  });

  // Snackbar State
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });

  // Fetch societies for select dropdowns
  useEffect(() => {
    const fetchSocieties = async () => {
      try {
        const response = await societyService.getAll({ page_size: 100 });
        setSocieties(response.data.results || []);
      } catch (err) {
        console.error(err);
      }
    };
    fetchSocieties();
  }, []);

  // Fetch blocks
  const fetchBlocks = useCallback(async () => {
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
      const response = await blockService.getAll(params);
      setBlocks(response.data.results || []);
      setTotalCount(response.data.count || 0);
    } catch (err) {
      console.error(err);
      setSnackbar({ open: true, message: 'Failed to fetch blocks.', severity: 'error' });
    } finally {
      setLoading(false);
    }
  }, [page, rowsPerPage, searchTerm, filterSociety]);

  useEffect(() => {
    fetchBlocks();
  }, [fetchBlocks]);

  const handleSearch = (val) => {
    setSearchTerm(val);
    setPage(0);
  };

  const handleFilterSocietyChange = (e) => {
    setFilterSociety(e.target.value);
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
    setSelectedBlock(null);
    setFormData({
      society: societies.length > 0 ? societies[0].id : '',
      name: '',
      total_floors: ''
    });
    setOpenForm(true);
  };

  const handleOpenEdit = (block) => {
    setSelectedBlock(block);
    setFormData({
      society: block.society,
      name: block.name,
      total_floors: block.total_floors
    });
    setOpenForm(true);
  };

  const handleOpenDelete = (block) => {
    setSelectedBlock(block);
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
      if (selectedBlock) {
        await blockService.update(selectedBlock.id, formData);
        setSnackbar({ open: true, message: 'Block updated successfully!', severity: 'success' });
      } else {
        await blockService.create(formData);
        setSnackbar({ open: true, message: 'Block created successfully!', severity: 'success' });
      }
      setOpenForm(false);
      fetchBlocks();
    } catch (err) {
      console.error(err);
      const errors = err.response?.data;
      let errorMsg = 'Failed to save block.';
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
      await blockService.delete(selectedBlock.id);
      setSnackbar({ open: true, message: 'Block deleted successfully!', severity: 'success' });
      setOpenDelete(false);
      fetchBlocks();
    } catch (err) {
      console.error(err);
      setSnackbar({ open: true, message: 'Failed to delete block.', severity: 'error' });
    } finally {
      setLoading(false);
    }
  };

  const columns = [
    { id: 'society_name', label: 'Society Name', minWidth: 200 },
    { id: 'name', label: 'Block / Tower Name', minWidth: 150 },
    { id: 'total_floors', label: 'Total Floors', minWidth: 120, align: 'center' }
  ];

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 4 }}>
        <Typography variant="h5" fontWeight="bold">
          Manage Blocks / Towers
        </Typography>
        <Button variant="contained" color="primary" startIcon={<MdAdd />} onClick={handleOpenAdd}>
          Add Block
        </Button>
      </Box>

      <Box sx={{ display: 'flex', gap: 2, mb: 3, flexWrap: 'wrap', alignItems: 'center' }}>
        <FormControl sx={{ minWidth: 200 }} size="small">
          <InputLabel>Filter by Society</InputLabel>
          <Select
            value={filterSociety}
            label="Filter by Society"
            onChange={handleFilterSocietyChange}
          >
            <MenuItem value="All">All Societies</MenuItem>
            {societies.map((soc) => (
              <MenuItem key={soc.id} value={soc.id}>{soc.name}</MenuItem>
            ))}
          </Select>
        </FormControl>
        
        <SearchBar 
          placeholder="Search by Block Name..." 
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
          data={blocks}
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
        <DialogTitle>{selectedBlock ? 'Edit Block' : 'Add New Block'}</DialogTitle>
        <form onSubmit={handleFormSubmit}>
          <DialogContent sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
            <TextField
              name="society"
              label="Select Society"
              select
              value={formData.society}
              onChange={handleFormChange}
              fullWidth
              required
            >
              {societies.map((soc) => (
                <MenuItem key={soc.id} value={soc.id}>{soc.name}</MenuItem>
              ))}
            </TextField>
            <TextField
              name="name"
              label="Block/Tower Name"
              value={formData.name}
              onChange={handleFormChange}
              fullWidth
              required
            />
            <TextField
              name="total_floors"
              label="Total Floors"
              type="number"
              value={formData.total_floors}
              onChange={handleFormChange}
              fullWidth
              required
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
          Are you sure you want to delete block "{selectedBlock?.name}"? All associated flats and resident information under it will be permanently deleted.
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

export default Block;
