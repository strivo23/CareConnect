import React, { useState } from 'react';
import { Box, Button, Typography, MenuItem, Select, FormControl, InputLabel, Alert, Snackbar } from '@mui/material';
import { MdAdd, MdAdminPanelSettings } from 'react-icons/md';
import { useNavigate } from 'react-router-dom';
import SearchBar from '../components/SearchBar/SearchBar';
import DataTable from '../components/DataTable/DataTable';
import { authService } from '../services/api';

const Users = () => {
  const navigate = useNavigate();
  const [searchTerm, setSearchTerm] = useState('');
  const [role, setRole] = useState('All');
  const [toast, setToast] = useState({ open: false, message: '', severity: 'success' });
  const [loading, setLoading] = useState(false);

  const handleCreateSuperuser = async () => {
    setLoading(true);
    try {
      const res = await authService.createSuperuser({
        email: 'admin@careconnect.com',
        password: 'password123',
        full_name: 'System Admin',
        role: 'ADMIN'
      });
      setToast({ open: true, message: res.message || 'Superuser created successfully!', severity: 'success' });
    } catch (err) {
      console.error(err);
      setToast({ open: true, message: err.response?.data?.message || 'Failed to create superuser.', severity: 'error' });
    } finally {
      setLoading(false);
    }
  };

  const users = [
    { id: 1, name: 'Admin One', email: 'admin@careconnect.com', role: 'Super Admin', status: 'Active' },
    { id: 2, name: 'Manager A', email: 'managerA@greenvalley.com', role: 'Society Admin', status: 'Active' },
    { id: 3, name: 'Guard B', email: 'guardB@skyline.com', role: 'Security', status: 'Inactive' },
  ];

  const columns = [
    { id: 'name', label: 'Name', minWidth: 150 },
    { id: 'email', label: 'Email', minWidth: 200 },
    { id: 'role', label: 'Role', minWidth: 120 },
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
      <Snackbar 
        open={toast.open} 
        autoHideDuration={4000} 
        onClose={() => setToast({ ...toast, open: false })}
        anchorOrigin={{ vertical: 'top', horizontal: 'center' }}
      >
        <Alert severity={toast.severity} onClose={() => setToast({ ...toast, open: false })}>
          {toast.message}
        </Alert>
      </Snackbar>

      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 4 }}>
        <Typography variant="h5" fontWeight="bold">Manage Users</Typography>
        <Box sx={{ display: 'flex', gap: 2 }}>
          <Button 
            variant="outlined" 
            color="secondary" 
            startIcon={<MdAdminPanelSettings />} 
            onClick={() => navigate('/create-superuser')}
          >
            Create Superuser
          </Button>
          <Button variant="contained" color="primary" startIcon={<MdAdd />}>Add User</Button>
        </Box>
      </Box>

      <Box sx={{ display: 'flex', gap: 2, mb: 3 }}>
        <FormControl sx={{ minWidth: 150 }} size="small">
          <InputLabel>Role</InputLabel>
          <Select value={role} label="Role" onChange={(e) => setRole(e.target.value)}>
            <MenuItem value="All">All Roles</MenuItem>
            <MenuItem value="Super Admin">Super Admin</MenuItem>
            <MenuItem value="Society Admin">Society Admin</MenuItem>
            <MenuItem value="Security">Security</MenuItem>
          </Select>
        </FormControl>
        <SearchBar placeholder="Search Users..." onSearch={setSearchTerm} />
      </Box>

      <DataTable 
        columns={columns} 
        data={users}
        onEdit={(row) => console.log('Edit', row)}
        onDelete={(row) => console.log('Delete', row)}
      />
    </Box>
  );
};

export default Users;
