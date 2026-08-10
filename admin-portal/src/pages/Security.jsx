import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Card,
  Grid,
  Button,
  Chip,
  Avatar,
  IconButton,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  MenuItem,
  CircularProgress,
  Paper,
  Divider,
  InputAdornment
} from '@mui/material';
import {
  MdSecurity,
  MdSearch,
  MdRefresh,
  MdBadge,
  MdCheckCircle,
  MdCancel,
  MdWork
} from 'react-icons/md';
import { securityService, societyService } from '../services/api';

const Security = () => {
  const [securityStaff, setSecurityStaff] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('All');

  const fetchSecurity = async () => {
    setLoading(true);
    try {
      const res = await securityService.getAll();
      setSecurityStaff(res.data.results || res.data || []);
    } catch (err) {
      console.error('Failed to fetch security staff:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchSecurity();
  }, []);

  const handleVerifyAction = async (sec, action) => {
    try {
      await securityService.verify(sec.id, action, `Updated status to ${action}`);
      fetchSecurity();
    } catch (err) {
      console.error('Failed to update security status:', err);
    }
  };

  const filteredSecurity = securityStaff.filter(sec => {
    const statusMatch = statusFilter === 'All' || sec.verification_status === statusFilter;
    const name = sec.user?.full_name?.toLowerCase() || '';
    const empId = sec.employee_id?.toLowerCase() || '';
    const searchMatch = !searchQuery || name.includes(searchQuery.toLowerCase()) || empId.includes(searchQuery.toLowerCase());
    return statusMatch && searchMatch;
  });

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 2 }}>
        <Box>
          <Typography variant="h5" fontWeight="800" sx={{ letterSpacing: '-0.5px', color: '#F9FAFB' }}>
            Security Staff Management
          </Typography>
          <Typography variant="body2" sx={{ color: 'var(--text-secondary)' }}>
            Monitor security personnel, employee IDs, assigned shifts, society assignments, and verification statuses.
          </Typography>
        </Box>
        <Button variant="outlined" startIcon={<MdRefresh size={20} />} onClick={fetchSecurity} sx={{ borderRadius: '12px' }}>
          Refresh List
        </Button>
      </Box>

      {/* Filter Bar */}
      <Card sx={{ p: 2.5, borderRadius: '20px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)', display: 'flex', gap: 2, alignItems: 'center', flexWrap: 'wrap' }}>
        <TextField
          placeholder="Search security by name, employee ID..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          size="small"
          sx={{ width: 340 }}
          InputProps={{
            startAdornment: (
              <InputAdornment position="start">
                <MdSearch size={20} color="var(--text-secondary)" />
              </InputAdornment>
            ),
          }}
        />

        <Box sx={{ display: 'flex', gap: 1 }}>
          {['All', 'Pending', 'Approved', 'Rejected'].map((status) => (
            <Chip
              key={status}
              label={status}
              clickable
              onClick={() => setStatusFilter(status)}
              color={statusFilter === status ? 'primary' : 'default'}
              sx={{ fontWeight: 700, borderRadius: '10px' }}
            />
          ))}
        </Box>
      </Card>

      {/* Grid */}
      {loading ? (
        <Box sx={{ display: 'flex', justifyContent: 'center', py: 8 }}>
          <CircularProgress color="primary" />
        </Box>
      ) : filteredSecurity.length === 0 ? (
        <Paper sx={{ p: 6, textAlign: 'center', borderRadius: '20px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)' }}>
          <Typography variant="h6">No Security Personnel Found</Typography>
        </Paper>
      ) : (
        <Grid container spacing={3}>
          {filteredSecurity.map((sec) => {
            const user = sec.user || {};
            const statusColor = sec.verification_status === 'Approved' ? '#22C55E' : sec.verification_status === 'Rejected' ? '#EF4444' : '#F59E0B';

            return (
              <Grid item xs={12} md={6} lg={4} key={sec.id}>
                <Card sx={{ borderRadius: '20px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)', p: 3 }}>
                  <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 2 }}>
                    <Box sx={{ display: 'flex', gap: 2, alignItems: 'center' }}>
                      <Avatar src={sec.profile_photo} sx={{ width: 48, height: 48, backgroundColor: 'var(--primary)' }}>
                        {user.full_name?.charAt(0) || 'S'}
                      </Avatar>
                      <Box>
                        <Typography variant="subtitle1" fontWeight="800">{user.full_name || 'Security Staff'}</Typography>
                        <Typography variant="caption" sx={{ color: 'var(--text-secondary)' }}>ID: {sec.employee_id || `SEC-${sec.id}`}</Typography>
                      </Box>
                    </Box>
                    <Chip label={sec.verification_status} size="small" sx={{ backgroundColor: `${statusColor}20`, color: statusColor, fontWeight: 800 }} />
                  </Box>

                  <Divider sx={{ my: 1.5 }} />

                  <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1, mb: 2 }}>
                    <Typography variant="body2"><strong>Shift:</strong> {sec.shift || 'Day Shift'}</Typography>
                    <Typography variant="body2"><strong>Assigned Society:</strong> {sec.society_name || 'Unassigned'}</Typography>
                    <Typography variant="body2"><strong>Assigned Block:</strong> {sec.block_name || 'All Blocks'}</Typography>
                    <Typography variant="body2"><strong>Employment Status:</strong> {sec.employment_status || 'Active'}</Typography>
                  </Box>

                  <Box sx={{ display: 'flex', gap: 1 }}>
                    {sec.verification_status !== 'Approved' && (
                      <Button variant="contained" color="success" size="small" fullWidth onClick={() => handleVerifyAction(sec, 'approve')}>
                        Approve Staff
                      </Button>
                    )}
                    {sec.verification_status !== 'Rejected' && (
                      <Button variant="outlined" color="error" size="small" fullWidth onClick={() => handleVerifyAction(sec, 'reject')}>
                        Reject
                      </Button>
                    )}
                  </Box>
                </Card>
              </Grid>
            );
          })}
        </Grid>
      )}
    </Box>
  );
};

export default Security;
