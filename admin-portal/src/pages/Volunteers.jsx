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
  MdVolunteerActivism,
  MdSearch,
  MdRefresh,
  MdAdd,
  MdEdit,
  MdBlock,
  MdCheckCircle,
  MdAssignment
} from 'react-icons/md';
import { volunteerService, societyService, blockService } from '../services/api';

const Volunteers = () => {
  const [volunteers, setVolunteers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('All');

  // Societies & Blocks for assignment
  const [societies, setSocieties] = useState([]);
  const [blocks, setBlocks] = useState([]);

  // Assignment Modal
  const [assignDialogOpen, setAssignDialogOpen] = useState(false);
  const [selectedVolunteer, setSelectedVolunteer] = useState(null);
  const [selectedSociety, setSelectedSociety] = useState('');
  const [selectedBlock, setSelectedBlock] = useState('');

  const fetchVolunteers = async () => {
    setLoading(true);
    try {
      const res = await volunteerService.getAll();
      setVolunteers(res.data.results || res.data || []);
      const socRes = await societyService.getAll();
      setSocieties(socRes.data.results || socRes.data || []);
    } catch (err) {
      console.error('Failed to fetch volunteers:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchVolunteers();
  }, []);

  const handleOpenAssign = (vol) => {
    setSelectedVolunteer(vol);
    setSelectedSociety(vol.assigned_society || '');
    setSelectedBlock(vol.assigned_block || '');
    if (vol.assigned_society) {
      blockService.getAll({ society: vol.assigned_society }).then(res => {
        setBlocks(res.data.results || res.data || []);
      });
    }
    setAssignDialogOpen(true);
  };

  const handleSocietyChange = async (socId) => {
    setSelectedSociety(socId);
    setSelectedBlock('');
    if (socId) {
      const res = await blockService.getAll({ society: socId });
      setBlocks(res.data.results || res.data || []);
    } else {
      setBlocks([]);
    }
  };

  const handleSaveAssignment = async () => {
    if (!selectedVolunteer) return;
    try {
      await volunteerService.assign(selectedVolunteer.id, selectedSociety, selectedBlock);
      setAssignDialogOpen(false);
      fetchVolunteers();
    } catch (err) {
      console.error('Failed to assign volunteer:', err);
    }
  };

  const handleStatusAction = async (vol, action) => {
    try {
      await volunteerService.verify(vol.id, action, `Admin updated status to ${action}`);
      fetchVolunteers();
    } catch (err) {
      console.error('Failed to update status:', err);
    }
  };

  const filteredVolunteers = volunteers.filter(vol => {
    const statusMatch = statusFilter === 'All' || vol.status === statusFilter;
    const name = vol.user?.full_name?.toLowerCase() || '';
    const email = vol.user?.email?.toLowerCase() || '';
    const skills = vol.skills?.toLowerCase() || '';
    const searchMatch = !searchQuery || name.includes(searchQuery.toLowerCase()) || email.includes(searchQuery.toLowerCase()) || skills.includes(searchQuery.toLowerCase());
    return statusMatch && searchMatch;
  });

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 2 }}>
        <Box>
          <Typography variant="h5" fontWeight="800" sx={{ letterSpacing: '-0.5px', color: '#F9FAFB' }}>
            Volunteer Network Management
          </Typography>
          <Typography variant="body2" sx={{ color: 'var(--text-secondary)' }}>
            Manage community emergency responders, review skills, assign societies/blocks, and monitor active statuses.
          </Typography>
        </Box>
        <Button variant="outlined" startIcon={<MdRefresh size={20} />} onClick={fetchVolunteers} sx={{ borderRadius: '12px' }}>
          Refresh List
        </Button>
      </Box>

      {/* Filter Bar */}
      <Card sx={{ p: 2.5, borderRadius: '20px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)', display: 'flex', gap: 2, alignItems: 'center', flexWrap: 'wrap' }}>
        <TextField
          placeholder="Search volunteer by name, skills, email..."
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
          {['All', 'Pending', 'Approved', 'Rejected', 'Suspended'].map((status) => (
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
      ) : filteredVolunteers.length === 0 ? (
        <Paper sx={{ p: 6, textAlign: 'center', borderRadius: '20px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)' }}>
          <Typography variant="h6">No Volunteers Found</Typography>
        </Paper>
      ) : (
        <Grid container spacing={3}>
          {filteredVolunteers.map((vol) => {
            const user = vol.user || {};
            const statusColor = vol.status === 'Approved' ? '#22C55E' : vol.status === 'Suspended' ? '#EF4444' : '#F59E0B';

            return (
              <Grid item xs={12} md={6} lg={4} key={vol.id}>
                <Card sx={{ borderRadius: '20px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)', p: 3 }}>
                  <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 2 }}>
                    <Box sx={{ display: 'flex', gap: 2, alignItems: 'center' }}>
                      <Avatar src={vol.profile_photo} sx={{ width: 48, height: 48, backgroundColor: 'var(--primary)' }}>
                        {user.full_name?.charAt(0) || 'V'}
                      </Avatar>
                      <Box>
                        <Typography variant="subtitle1" fontWeight="800">{user.full_name || 'Volunteer'}</Typography>
                        <Typography variant="caption" sx={{ color: 'var(--text-secondary)' }}>{user.email}</Typography>
                      </Box>
                    </Box>
                    <Chip label={vol.status} size="small" sx={{ backgroundColor: `${statusColor}20`, color: statusColor, fontWeight: 800 }} />
                  </Box>

                  <Divider sx={{ my: 1.5 }} />

                  <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1, mb: 2 }}>
                    <Typography variant="body2"><strong>Skills:</strong> {vol.skills || 'First Aid, SOS Support'}</Typography>
                    <Typography variant="body2"><strong>Training:</strong> {vol.emergency_training || 'Standard Training'}</Typography>
                    <Typography variant="body2"><strong>Assigned Society:</strong> {vol.society_name || 'All Societies'}</Typography>
                    <Typography variant="body2"><strong>Assigned Block:</strong> {vol.block_name || 'All Blocks'}</Typography>
                  </Box>

                  <Box sx={{ display: 'flex', gap: 1 }}>
                    <Button variant="outlined" size="small" startIcon={<MdAssignment />} onClick={() => handleOpenAssign(vol)}>
                      Assign
                    </Button>
                    {vol.status !== 'Approved' && (
                      <Button variant="contained" color="success" size="small" onClick={() => handleStatusAction(vol, 'approve')}>
                        Approve
                      </Button>
                    )}
                    {vol.status !== 'Suspended' && (
                      <Button variant="outlined" color="error" size="small" onClick={() => handleStatusAction(vol, 'suspend')}>
                        Suspend
                      </Button>
                    )}
                  </Box>
                </Card>
              </Grid>
            );
          })}
        </Grid>
      )}

      {/* Assignment Modal */}
      <Dialog open={assignDialogOpen} onClose={() => setAssignDialogOpen(false)} PaperProps={{ sx: { borderRadius: '20px', p: 1, width: 420 } }}>
        <DialogTitle sx={{ fontWeight: 800 }}>Assign Volunteer to Society & Block</DialogTitle>
        <DialogContent sx={{ display: 'flex', flexDirection: 'column', gap: 2, pt: 1 }}>
          <TextField
            select
            label="Select Society"
            value={selectedSociety}
            onChange={(e) => handleSocietyChange(e.target.value)}
            fullWidth
            size="small"
          >
            <MenuItem value="">All Societies / Unassigned</MenuItem>
            {societies.map((s) => (
              <MenuItem key={s.id} value={s.id}>{s.name}</MenuItem>
            ))}
          </TextField>

          <TextField
            select
            label="Select Block / Wing"
            value={selectedBlock}
            onChange={(e) => setSelectedBlock(e.target.value)}
            fullWidth
            size="small"
          >
            <MenuItem value="">All Blocks</MenuItem>
            {blocks.map((b) => (
              <MenuItem key={b.id} value={b.id}>{b.name}</MenuItem>
            ))}
          </TextField>
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button onClick={() => setAssignDialogOpen(false)}>Cancel</Button>
          <Button variant="contained" onClick={handleSaveAssignment} sx={{ borderRadius: '10px' }}>
            Save Assignment
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default Volunteers;
