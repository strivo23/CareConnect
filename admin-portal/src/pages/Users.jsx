import React, { useState } from 'react';
import { Box, Button, Typography, MenuItem, Select, FormControl, InputLabel } from '@mui/material';
import { MdAdd } from 'react-icons/md';
import SearchBar from '../components/SearchBar/SearchBar';
import DataTable from '../components/DataTable/DataTable';

const Users = () => {
  const [searchTerm, setSearchTerm] = useState('');
  const [role, setRole] = useState('All');
  
  const users = [
    { id: 1, name: 'Admin One', email: 'admin1@careconnect.com', role: 'Super Admin', status: 'Active' },
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
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 4 }}>
        <Typography variant="h5" fontWeight="bold">Manage Users</Typography>
        <Button variant="contained" color="primary" startIcon={<MdAdd />}>Add User</Button>
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
