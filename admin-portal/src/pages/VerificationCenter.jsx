import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  Tabs,
  Tab,
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
  CircularProgress,
  Tooltip,
  Paper,
  Divider,
  InputAdornment
} from '@mui/material';
import {
  MdVerifiedUser,
  MdCheckCircle,
  MdCancel,
  MdPendingActions,
  MdSearch,
  MdRefresh,
  MdVisibility,
  MdAssignmentInd,
  MdDescription,
  MdPerson,
  MdShield,
  MdVolunteerActivism,
  MdPeople
} from 'react-icons/md';
import { verificationService, residentService, volunteerService, securityService, guardianService } from '../services/api';

const VerificationCenter = () => {
  const [activeTab, setActiveTab] = useState(0); // 0: Residents, 1: Guardians, 2: Volunteers, 3: Security
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState({
    residents: [],
    guardians: [],
    volunteers: [],
    security: []
  });
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('All'); // All, Pending, Approved, Rejected

  // Action Dialog state
  const [selectedUser, setSelectedUser] = useState(null);
  const [actionType, setActionType] = useState('approve'); // approve, reject, info
  const [remarks, setRemarks] = useState('');
  const [dialogOpen, setDialogOpen] = useState(false);
  const [documentPreviewOpen, setDocumentPreviewOpen] = useState(false);

  const fetchData = async () => {
    setLoading(true);
    try {
      const res = await verificationService.getCenterData();
      setData({
        residents: res.data.residents || [],
        guardians: res.data.guardians || [],
        volunteers: res.data.volunteers || [],
        security: res.data.security || []
      });
    } catch (err) {
      console.error('Failed to fetch verification center data:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  const handleTabChange = (event, newValue) => {
    setActiveTab(newValue);
    setSearchQuery('');
  };

  const handleOpenAction = (user, type) => {
    setSelectedUser(user);
    setActionType(type);
    setRemarks('');
    setDialogOpen(true);
  };

  const handleExecuteAction = async () => {
    if (!selectedUser) return;

    try {
      if (activeTab === 0) { // Resident
        if (actionType === 'approve') await residentService.approve(selectedUser.id);
        else if (actionType === 'reject') await residentService.reject(selectedUser.id);
      } else if (activeTab === 1) { // Guardian
        await guardianService.verify(selectedUser.id, actionType, remarks);
      } else if (activeTab === 2) { // Volunteer
        await volunteerService.verify(selectedUser.id, actionType, remarks);
      } else if (activeTab === 3) { // Security
        await securityService.verify(selectedUser.id, actionType, remarks);
      }
      setDialogOpen(false);
      fetchData();
    } catch (err) {
      console.error('Failed to update verification status:', err);
    }
  };

  const getFilteredList = () => {
    let list = [];
    if (activeTab === 0) list = data.residents;
    else if (activeTab === 1) list = data.guardians;
    else if (activeTab === 2) list = data.volunteers;
    else if (activeTab === 3) list = data.security;

    return list.filter(item => {
      const statusMatch = statusFilter === 'All' || (item.status || item.verification_status) === statusFilter;
      const name = item.user?.full_name?.toLowerCase() || '';
      const email = item.user?.email?.toLowerCase() || '';
      const phone = item.user?.phone_number?.toLowerCase() || '';
      const searchMatch = !searchQuery || name.includes(searchQuery.toLowerCase()) || email.includes(searchQuery.toLowerCase()) || phone.includes(searchQuery.toLowerCase());
      return statusMatch && searchMatch;
    });
  };

  const currentList = getFilteredList();

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
      {/* Header */}
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 2 }}>
        <Box>
          <Typography variant="h5" fontWeight="800" sx={{ letterSpacing: '-0.5px', color: '#F9FAFB' }}>
            User Verification Center
          </Typography>
          <Typography variant="body2" sx={{ color: 'var(--text-secondary)' }}>
            Review document submissions, approve new profiles, and manage verification statuses across all community roles.
          </Typography>
        </Box>

        <Button
          variant="outlined"
          startIcon={<MdRefresh size={20} />}
          onClick={fetchData}
          sx={{ borderRadius: '12px', borderColor: 'var(--border-color)', color: 'var(--text-primary)' }}
        >
          Refresh Feed
        </Button>
      </Box>

      {/* Navigation Tabs */}
      <Card sx={{ borderRadius: '20px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)' }}>
        <Tabs
          value={activeTab}
          onChange={handleTabChange}
          indicatorColor="primary"
          textColor="primary"
          sx={{
            px: 2,
            borderBottom: '1px solid var(--border-color)',
            '& .MuiTab-root': { fontWeight: 700, fontSize: '0.95rem', py: 2 }
          }}
        >
          <Tab icon={<MdPeople size={20} />} iconPosition="start" label={`Residents (${data.residents.length})`} />
          <Tab icon={<MdVerifiedUser size={20} />} iconPosition="start" label={`Guardians (${data.guardians.length})`} />
          <Tab icon={<MdVolunteerActivism size={20} />} iconPosition="start" label={`Volunteers (${data.volunteers.length})`} />
          <Tab icon={<MdShield size={20} />} iconPosition="start" label={`Security (${data.security.length})`} />
        </Tabs>

        {/* Filter Bar */}
        <Box sx={{ p: 2.5, display: 'flex', gap: 2, alignItems: 'center', flexWrap: 'wrap' }}>
          <TextField
            placeholder="Search by name, email, phone..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            size="small"
            sx={{ width: 320 }}
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
                sx={{
                  fontWeight: 700,
                  borderRadius: '10px',
                  backgroundColor: statusFilter === status ? 'var(--primary)' : 'rgba(255,255,255,0.05)'
                }}
              />
            ))}
          </Box>
        </Box>
      </Card>

      {/* User Profiles Grid */}
      {loading ? (
        <Box sx={{ display: 'flex', justifyContent: 'center', py: 8 }}>
          <CircularProgress color="primary" />
        </Box>
      ) : currentList.length === 0 ? (
        <Paper sx={{ p: 6, textAlign: 'center', borderRadius: '20px', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)' }}>
          <MdCheckCircle size={56} color="#22C55E" style={{ marginBottom: 12 }} />
          <Typography variant="h6" fontWeight="700">All Quiet!</Typography>
          <Typography variant="body2" sx={{ color: 'var(--text-secondary)' }}>
            No profiles match the selected status or search filter.
          </Typography>
        </Paper>
      ) : (
        <Grid container spacing={3}>
          {currentList.map((item) => {
            const user = item.user || {};
            const statusVal = item.status || item.verification_status || 'Pending';
            const statusColor = statusVal === 'Approved' ? '#22C55E' : statusVal === 'Rejected' ? '#EF4444' : '#F59E0B';

            return (
              <Grid item xs={12} md={6} lg={4} key={item.id}>
                <Card sx={{
                  borderRadius: '20px',
                  backgroundColor: 'var(--bg-card)',
                  border: '1px solid var(--border-color)',
                  position: 'relative',
                  overflow: 'hidden'
                }}>
                  <Box sx={{ height: 6, backgroundColor: statusColor }} />
                  <CardContent sx={{ p: 3 }}>
                    <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', mb: 2 }}>
                      <Box sx={{ display: 'flex', gap: 2, alignItems: 'center' }}>
                        <Avatar
                          src={item.profile_photo || user.avatar}
                          sx={{ width: 48, height: 48, backgroundColor: 'var(--primary)', fontWeight: 700 }}
                        >
                          {user.full_name?.charAt(0) || 'U'}
                        </Avatar>
                        <Box>
                          <Typography variant="subtitle1" fontWeight="800">
                            {user.full_name || 'User Profile'}
                          </Typography>
                          <Typography variant="caption" sx={{ color: 'var(--text-secondary)', display: 'block' }}>
                            {user.email}
                          </Typography>
                        </Box>
                      </Box>
                      <Chip
                        label={statusVal}
                        size="small"
                        sx={{
                          backgroundColor: `${statusColor}20`,
                          color: statusColor,
                          fontWeight: 800,
                          borderRadius: '8px'
                        }}
                      />
                    </Box>

                    <Divider sx={{ my: 1.5, borderColor: 'var(--border-color)' }} />

                    <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1, mb: 2.5 }}>
                      <Typography variant="body2">
                        <strong>Phone:</strong> {user.phone_number || 'N/A'}
                      </Typography>
                      {activeTab === 0 && (
                        <Typography variant="body2">
                          <strong>Residence:</strong> {item.society_name || 'Society'} — {item.block_name || 'Block'}, Flat {item.flat_number || 'N/A'}
                        </Typography>
                      )}
                      {activeTab === 2 && (
                        <>
                          <Typography variant="body2"><strong>Skills:</strong> {item.skills || 'General Support'}</Typography>
                          <Typography variant="body2"><strong>Training:</strong> {item.emergency_training || 'Standard'}</Typography>
                        </>
                      )}
                      {activeTab === 3 && (
                        <>
                          <Typography variant="body2"><strong>Employee ID:</strong> {item.employee_id || 'SEC-01'}</Typography>
                          <Typography variant="body2"><strong>Shift:</strong> {item.shift || 'Day Shift'}</Typography>
                        </>
                      )}
                      {item.remarks && (
                        <Typography variant="caption" sx={{ color: 'orange', fontStyle: 'italic' }}>
                          Remarks: "{item.remarks}"
                        </Typography>
                      )}
                    </Box>

                    <Box sx={{ display: 'flex', gap: 1 }}>
                      {statusVal === 'Pending' && (
                        <>
                          <Button
                            fullWidth
                            variant="contained"
                            color="success"
                            size="small"
                            onClick={() => handleOpenAction(item, 'approve')}
                            sx={{ borderRadius: '10px', fontWeight: 700 }}
                          >
                            Approve
                          </Button>
                          <Button
                            fullWidth
                            variant="outlined"
                            color="error"
                            size="small"
                            onClick={() => handleOpenAction(item, 'reject')}
                            sx={{ borderRadius: '10px', fontWeight: 700 }}
                          >
                            Reject
                          </Button>
                        </>
                      )}
                      <Button
                        variant="outlined"
                        size="small"
                        startIcon={<MdDescription size={16} />}
                        onClick={() => { setSelectedUser(item); setDocumentPreviewOpen(true); }}
                        sx={{ borderRadius: '10px', color: 'var(--text-primary)', borderColor: 'var(--border-color)' }}
                      >
                        Docs
                      </Button>
                    </Box>
                  </CardContent>
                </Card>
              </Grid>
            );
          })}
        </Grid>
      )}

      {/* Approve / Reject Dialog */}
      <Dialog
        open={dialogOpen}
        onClose={() => setDialogOpen(false)}
        PaperProps={{
          sx: {
            backgroundColor: 'var(--bg-card)',
            color: 'var(--text-primary)',
            borderRadius: '20px',
            border: '1px solid var(--border-light)',
            width: 440
          }
        }}
      >
        <DialogTitle sx={{ fontWeight: 800 }}>
          {actionType === 'approve' ? 'Approve Verification' : 'Reject Verification'}
        </DialogTitle>
        <DialogContent sx={{ display: 'flex', flexDirection: 'column', gap: 2, pt: 1 }}>
          <Typography variant="body2" sx={{ color: 'var(--text-secondary)' }}>
            Confirm {actionType} for <strong>{selectedUser?.user?.full_name}</strong>. An automated push & email notification will be dispatched to the user.
          </Typography>
          <TextField
            label="Verification Remarks / Reason"
            multiline
            rows={3}
            placeholder="Add optional notes or instructions for the user..."
            value={remarks}
            onChange={(e) => setRemarks(e.target.value)}
            fullWidth
            size="small"
          />
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2.5 }}>
          <Button onClick={() => setDialogOpen(false)}>Cancel</Button>
          <Button
            variant="contained"
            color={actionType === 'approve' ? 'success' : 'error'}
            onClick={handleExecuteAction}
            sx={{ borderRadius: '10px', px: 3, fontWeight: 700 }}
          >
            Confirm {actionType.toUpperCase()}
          </Button>
        </DialogActions>
      </Dialog>

      {/* Document Preview Modal */}
      <Dialog
        open={documentPreviewOpen}
        onClose={() => setDocumentPreviewOpen(false)}
        PaperProps={{
          sx: {
            backgroundColor: 'var(--bg-card)',
            color: 'var(--text-primary)',
            borderRadius: '20px',
            width: 540
          }
        }}
      >
        <DialogTitle sx={{ fontWeight: 800 }}>
          Verification Documents: {selectedUser?.user?.full_name}
        </DialogTitle>
        <DialogContent>
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, pt: 1 }}>
            <Paper sx={{ p: 2, backgroundColor: 'rgba(255,255,255,0.03)', borderRadius: '12px' }}>
              <Typography variant="subtitle2" fontWeight="700">Profile Photo & Identity Proof</Typography>
              <Typography variant="caption" sx={{ color: 'var(--text-secondary)' }}>Uploaded during registration</Typography>
              <Box sx={{ mt: 2, display: 'flex', gap: 2, alignItems: 'center' }}>
                <Avatar src={selectedUser?.profile_photo} sx={{ width: 64, height: 64 }} />
                <Box>
                  <Typography variant="body2">Aadhaar / ID Card: Verified</Typography>
                  <Chip label="Verified System Attachment" size="small" color="success" sx={{ mt: 0.5 }} />
                </Box>
              </Box>
            </Paper>
          </Box>
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button onClick={() => setDocumentPreviewOpen(false)}>Close Preview</Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default VerificationCenter;
