import React, { useState, useEffect, useCallback } from 'react';
import { 
  Box, Button, Typography, Dialog, DialogTitle, DialogContent, 
  DialogActions, MenuItem, FormControl, InputLabel, Select,
  Snackbar, Alert, CircularProgress, Grid, Divider, IconButton
} from '@mui/material';
import { DataGrid } from '@mui/x-data-grid';
import { MdVisibility, MdCheck, MdClose } from 'react-icons/md';
import SearchBar from '../components/SearchBar/SearchBar';
import { residentService } from '../services/api';

const Residents = () => {
  const [residents, setResidents] = useState([]);
  const [loading, setLoading] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterStatus, setFilterStatus] = useState('All');

  // Pagination State
  const [paginationModel, setPaginationModel] = useState({
    page: 0,
    pageSize: 5,
  });
  const [totalCount, setTotalCount] = useState(0);

  // Dialog State
  const [selectedProfile, setSelectedProfile] = useState(null);
  const [openProfile, setOpenProfile] = useState(false);

  // Snackbar State
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });

  // Fetch Residents
  const fetchResidents = useCallback(async () => {
    setLoading(true);
    try {
      const params = {
        page: paginationModel.page + 1,
        page_size: paginationModel.pageSize,
        search: searchTerm,
      };
      if (filterStatus !== 'All') {
        params.status = filterStatus;
      }
      const response = await residentService.getAll(params);
      setResidents(response.data.results || []);
      setTotalCount(response.data.count || 0);
    } catch (err) {
      console.error(err);
      setSnackbar({ open: true, message: 'Failed to fetch residents directory.', severity: 'error' });
    } finally {
      setLoading(false);
    }
  }, [paginationModel, searchTerm, filterStatus]);

  useEffect(() => {
    fetchResidents();
  }, [fetchResidents]);

  const handleSearch = (val) => {
    setSearchTerm(val);
    setPaginationModel(prev => ({ ...prev, page: 0 }));
  };

  const handleStatusFilterChange = (e) => {
    setFilterStatus(e.target.value);
    setPaginationModel(prev => ({ ...prev, page: 0 }));
  };

  const handleApprove = async (id) => {
    setLoading(true);
    try {
      await residentService.approve(id);
      setSnackbar({ open: true, message: 'Resident application approved successfully!', severity: 'success' });
      fetchResidents();
      if (openProfile && selectedProfile?.id === id) {
        setOpenProfile(false);
      }
    } catch (err) {
      console.error(err);
      setSnackbar({ open: true, message: 'Failed to approve resident.', severity: 'error' });
    } finally {
      setLoading(false);
    }
  };

  const handleReject = async (id) => {
    setLoading(true);
    try {
      await residentService.reject(id);
      setSnackbar({ open: true, message: 'Resident application rejected.', severity: 'info' });
      fetchResidents();
      if (openProfile && selectedProfile?.id === id) {
        setOpenProfile(false);
      }
    } catch (err) {
      console.error(err);
      setSnackbar({ open: true, message: 'Failed to reject resident.', severity: 'error' });
    } finally {
      setLoading(false);
    }
  };

  const handleOpenProfile = (profile) => {
    setSelectedProfile(profile);
    setOpenProfile(true);
  };

  const handleCloseProfile = () => {
    setOpenProfile(false);
  };

  const columns = [
    { field: 'id', headerName: 'ID', width: 70 },
    { 
      field: 'name', 
      headerName: 'Resident Name', 
      width: 180,
      valueGetter: (value, row) => row.user?.full_name || 'N/A'
    },
    { 
      field: 'email', 
      headerName: 'Email Address', 
      width: 200,
      valueGetter: (value, row) => row.user?.email || 'N/A'
    },
    { field: 'society_name', headerName: 'Society', width: 180 },
    { field: 'block_name', headerName: 'Block / Tower', width: 120 },
    { field: 'flat_number', headerName: 'Flat No', width: 100 },
    { 
      field: 'status', 
      headerName: 'Status', 
      width: 120,
      renderCell: (params) => {
        const val = params.value;
        const color = val === 'Approved' ? 'var(--success)' : val === 'Rejected' ? 'var(--danger)' : 'var(--warning)';
        const bg = val === 'Approved' ? 'var(--success)15' : val === 'Rejected' ? 'var(--danger)15' : 'var(--warning)15';
        return (
          <Box sx={{ display: 'flex', alignItems: 'center', height: '100%' }}>
            <span style={{ 
              color,
              backgroundColor: bg,
              padding: '4px 8px',
              borderRadius: '12px',
              fontSize: '0.85rem',
              fontWeight: 'bold',
              display: 'inline-block'
            }}>
              {val}
            </span>
          </Box>
        );
      }
    },
    {
      field: 'actions',
      headerName: 'Actions',
      width: 150,
      sortable: false,
      renderCell: (params) => {
        const row = params.row;
        return (
          <Box sx={{ display: 'flex', gap: 1, alignItems: 'center', height: '100%' }}>
            <IconButton 
              size="small" 
              sx={{ color: 'var(--primary)' }} 
              onClick={() => handleOpenProfile(row)}
              title="View Profile"
            >
              <MdVisibility size={18} />
            </IconButton>
            {row.status === 'Pending' && (
              <>
                <IconButton 
                  size="small" 
                  sx={{ color: 'var(--success)' }} 
                  onClick={() => handleApprove(row.id)}
                  title="Approve"
                >
                  <MdCheck size={18} />
                </IconButton>
                <IconButton 
                  size="small" 
                  sx={{ color: 'var(--danger)' }} 
                  onClick={() => handleReject(row.id)}
                  title="Reject"
                >
                  <MdClose size={18} />
                </IconButton>
              </>
            )}
          </Box>
        );
      }
    }
  ];

  return (
    <Box sx={{ width: '100%' }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 4 }}>
        <Typography variant="h5" fontWeight="bold">Manage Residents</Typography>
      </Box>

      <Box sx={{ display: 'flex', gap: 2, mb: 3, flexWrap: 'wrap', alignItems: 'center' }}>
        <FormControl sx={{ minWidth: 150 }} size="small">
          <InputLabel>Status</InputLabel>
          <Select value={filterStatus} label="Status" onChange={handleStatusFilterChange}>
            <MenuItem value="All">All Statuses</MenuItem>
            <MenuItem value="Pending">Pending</MenuItem>
            <MenuItem value="Approved">Approved</MenuItem>
            <MenuItem value="Rejected">Rejected</MenuItem>
          </Select>
        </FormControl>

        <SearchBar placeholder="Search Residents..." onSearch={handleSearch} />
      </Box>

      <Box sx={{ height: 400, width: '100%', backgroundColor: 'var(--bg-card)', borderRadius: '8px', overflow: 'hidden', boxShadow: 'var(--shadow-sm)' }}>
        <DataGrid
          rows={residents}
          columns={columns}
          rowCount={totalCount}
          loading={loading}
          paginationModel={paginationModel}
          paginationMode="server"
          onPaginationModelChange={setPaginationModel}
          pageSizeOptions={[5, 10, 25]}
          sx={{
            border: 'none',
            color: 'var(--text-primary)',
            '& .MuiDataGrid-columnHeaders': {
              backgroundColor: 'var(--bg-main)',
              color: 'var(--text-primary)',
              fontWeight: 'bold',
              borderBottom: '1px solid var(--border-color)',
            },
            '& .MuiDataGrid-cell': {
              borderBottom: '1px solid var(--border-color)',
              color: 'var(--text-primary)',
            },
            '& .MuiDataGrid-footerContainer': {
              borderTop: '1px solid var(--border-color)',
              color: 'var(--text-primary)',
            },
            '& .MuiTablePagination-root': {
              color: 'var(--text-primary)',
            },
            '& .MuiIconButton-root': {
              color: 'var(--text-primary)',
            }
          }}
        />
      </Box>

      {/* Resident Profile Dialog */}
      <Dialog open={openProfile} onClose={handleCloseProfile} maxWidth="sm" fullWidth>
        <DialogTitle sx={{ fontWeight: 'bold' }}>Resident Profile Details</DialogTitle>
        <DialogContent dividers>
          {selectedProfile && (
            <Grid container spacing={2}>
              <Grid item xs={12}>
                <Typography variant="subtitle2" color="textSecondary">Account Information</Typography>
                <Typography variant="body1"><strong>Full Name:</strong> {selectedProfile.user?.full_name || 'N/A'}</Typography>
                <Typography variant="body1"><strong>Email Address:</strong> {selectedProfile.user?.email || 'N/A'}</Typography>
                <Typography variant="body1"><strong>Phone Number:</strong> {selectedProfile.user?.phone_number || 'N/A'}</Typography>
              </Grid>

              <Grid item xs={12}>
                <Divider sx={{ my: 1 }} />
                <Typography variant="subtitle2" color="textSecondary">Residential Information</Typography>
                <Typography variant="body1"><strong>Society:</strong> {selectedProfile.society_name || 'N/A'}</Typography>
                <Typography variant="body1"><strong>Block/Tower:</strong> {selectedProfile.block_name || 'N/A'}</Typography>
                <Typography variant="body1"><strong>Flat Number:</strong> {selectedProfile.flat_number || 'N/A'}</Typography>
              </Grid>

              <Grid item xs={12}>
                <Divider sx={{ my: 1 }} />
                <Typography variant="subtitle2" color="textSecondary">Verification Status</Typography>
                <Typography variant="body1"><strong>Status:</strong> {selectedProfile.status}</Typography>
                {selectedProfile.approved_by_name && (
                  <Typography variant="body1"><strong>Processed By:</strong> {selectedProfile.approved_by_name}</Typography>
                )}
                {selectedProfile.approved_at && (
                  <Typography variant="body1"><strong>Processed At:</strong> {new Date(selectedProfile.approved_at).toLocaleString()}</Typography>
                )}
              </Grid>
            </Grid>
          )}
        </DialogContent>
        <DialogActions>
          {selectedProfile && selectedProfile.status === 'Pending' && (
            <>
              <Button onClick={() => handleReject(selectedProfile.id)} color="error" variant="outlined">
                Reject
              </Button>
              <Button onClick={() => handleApprove(selectedProfile.id)} color="success" variant="contained">
                Approve
              </Button>
            </>
          )}
          <Button onClick={handleCloseProfile} color="primary">
            Close
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

export default Residents;
