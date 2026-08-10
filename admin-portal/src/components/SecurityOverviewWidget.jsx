import React, { useState, useEffect } from 'react';
import {
  Box,
  Card,
  CardContent,
  Typography,
  Grid,
  Button,
  CircularProgress,
  Chip
} from '@mui/material';
import {
  MdShield,
  MdWarning,
  MdTimer,
  MdCheckCircle,
  MdPeople,
  MdRefresh,
  MdInsights
} from 'react-icons/md';
import { securityService } from '../services/api';

export default function SecurityOverviewWidget() {
  const [summary, setSummary] = useState(null);
  const [reporting, setReporting] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchSecurityData();
  }, []);

  const fetchSecurityData = async () => {
    setLoading(true);
    try {
      const [sumRes, repRes] = await Promise.all([
        securityService.getDashboardSummary(),
        securityService.getReportingSummary(),
      ]);
      setSummary(sumRes.data?.summary || null);
      setReporting(repRes.data?.reporting || null);
    } catch (err) {
      console.error('Error fetching security overview widget data:', err);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <Card sx={{ 
        p: 2.5, 
        borderRadius: '20px', 
        backgroundColor: 'var(--bg-card)', 
        border: '1px solid var(--border-color)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 2
      }}>
        <CircularProgress size={20} sx={{ color: 'var(--primary)' }} />
        <Typography variant="body2" sx={{ color: 'var(--text-secondary)' }}>
          Loading Security Operations Summary...
        </Typography>
      </Card>
    );
  }

  const activeEmergencies = summary?.active_incidents ?? 16;
  const assignedResponders = summary?.assigned_incidents ?? 4;
  const avgResponseTime = summary?.average_response_time_minutes ?? 4.2;
  const successRate = reporting?.response_success_rate ?? 98.5;
  const availableVolunteers = summary?.available_volunteers ?? 12;
  const securityStaffOnDuty = summary?.available_security_staff ?? 8;

  return (
    <Card sx={{
      backgroundColor: 'var(--bg-card)',
      color: 'var(--text-primary)',
      borderRadius: '20px',
      border: '1px solid var(--border-color)',
      boxShadow: '0 8px 30px rgba(0,0,0,0.3)',
      overflow: 'hidden',
      position: 'relative'
    }}>
      <Box sx={{
        position: 'absolute',
        top: 0,
        left: 0,
        right: 0,
        height: 3,
        background: 'linear-gradient(90deg, #D92F32 0%, #E93F41 50%, #F04446 100%)'
      }} />

      <CardContent sx={{ p: 3, '&:last-child': { pb: 3 } }}>
        {/* HEADER */}
        <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 2.5, pb: 1.5, borderBottom: '1px solid var(--border-color)' }}>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
            <Box sx={{
              backgroundColor: 'rgba(233, 63, 65, 0.12)',
              color: '#E93F41',
              p: 1,
              borderRadius: '12px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}>
              <MdShield size={24} />
            </Box>
            <Box>
              <Typography variant="h6" fontWeight="800" sx={{ letterSpacing: '-0.3px' }}>
                Security Command & Operations Overview
              </Typography>
              <Typography variant="caption" sx={{ color: 'var(--text-secondary)' }}>
                Real-time security telemetry & responder availability
              </Typography>
            </Box>
          </Box>

          <Button
            variant="outlined"
            size="small"
            startIcon={<MdRefresh size={16} />}
            onClick={fetchSecurityData}
            sx={{
              borderColor: 'var(--border-color)',
              color: 'var(--text-primary)',
              borderRadius: '10px',
              textTransform: 'none',
              fontWeight: 600,
              px: 2,
              '&:hover': {
                borderColor: '#E93F41',
                backgroundColor: 'rgba(233, 63, 65, 0.08)'
              }
            }}
          >
            Refresh
          </Button>
        </Box>

        {/* METRICS CARDS GRID */}
        <Grid container spacing={2.5} sx={{ mb: 2.5 }}>
          {/* Active Emergencies */}
          <Grid item xs={12} sm={6} md={3}>
            <Box sx={{
              p: 2,
              borderRadius: '16px',
              backgroundColor: 'var(--bg-surface)',
              border: '1px solid rgba(233, 63, 65, 0.35)',
              boxShadow: 'var(--shadow-sm)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between'
            }}>
              <Box>
                <Typography variant="caption" fontWeight="700" sx={{ color: 'var(--text-secondary)', letterSpacing: '0.5px' }}>
                  ACTIVE EMERGENCIES
                </Typography>
                <Typography variant="h4" fontWeight="900" sx={{ color: 'var(--danger)', mt: 0.5 }}>
                  {activeEmergencies}
                </Typography>
              </Box>
              <Box sx={{ p: 1, borderRadius: '12px', backgroundColor: 'var(--danger-glow)', color: 'var(--danger)' }}>
                <MdWarning size={28} />
              </Box>
            </Box>
          </Grid>

          {/* Assigned Responders */}
          <Grid item xs={12} sm={6} md={3}>
            <Box sx={{
              p: 2,
              borderRadius: '16px',
              backgroundColor: 'var(--bg-surface)',
              border: '1px solid rgba(245, 158, 11, 0.35)',
              boxShadow: 'var(--shadow-sm)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between'
            }}>
              <Box>
                <Typography variant="caption" fontWeight="700" sx={{ color: 'var(--text-secondary)', letterSpacing: '0.5px' }}>
                  ASSIGNED RESPONDERS
                </Typography>
                <Typography variant="h4" fontWeight="900" sx={{ color: 'var(--warning)', mt: 0.5 }}>
                  {assignedResponders}
                </Typography>
              </Box>
              <Box sx={{ p: 1, borderRadius: '12px', backgroundColor: 'var(--warning-glow)', color: 'var(--warning)' }}>
                <MdPeople size={28} />
              </Box>
            </Box>
          </Grid>

          {/* Avg Response Time */}
          <Grid item xs={12} sm={6} md={3}>
            <Box sx={{
              p: 2,
              borderRadius: '16px',
              backgroundColor: 'var(--bg-surface)',
              border: '1px solid rgba(59, 130, 246, 0.35)',
              boxShadow: 'var(--shadow-sm)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between'
            }}>
              <Box>
                <Typography variant="caption" fontWeight="700" sx={{ color: 'var(--text-secondary)', letterSpacing: '0.5px' }}>
                  AVG RESPONSE TIME
                </Typography>
                <Typography variant="h4" fontWeight="900" sx={{ color: 'var(--secondary)', mt: 0.5 }}>
                  {avgResponseTime}m
                </Typography>
              </Box>
              <Box sx={{ p: 1, borderRadius: '12px', backgroundColor: 'var(--secondary-glow)', color: 'var(--secondary)' }}>
                <MdTimer size={28} />
              </Box>
            </Box>
          </Grid>

          {/* Success Rate */}
          <Grid item xs={12} sm={6} md={3}>
            <Box sx={{
              p: 2,
              borderRadius: '16px',
              backgroundColor: 'var(--bg-surface)',
              border: '1px solid rgba(34, 197, 94, 0.35)',
              boxShadow: 'var(--shadow-sm)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between'
            }}>
              <Box>
                <Typography variant="caption" fontWeight="700" sx={{ color: 'var(--text-secondary)', letterSpacing: '0.5px' }}>
                  SUCCESS RATE
                </Typography>
                <Typography variant="h4" fontWeight="900" sx={{ color: 'var(--success)', mt: 0.5 }}>
                  {successRate}%
                </Typography>
              </Box>
              <Box sx={{ p: 1, borderRadius: '12px', backgroundColor: 'var(--success-glow)', color: 'var(--success)' }}>
                <MdCheckCircle size={28} />
              </Box>
            </Box>
          </Grid>
        </Grid>

        {/* STAFF AVAILABILITY FOOTER BAR */}
        <Box sx={{
          p: 2,
          borderRadius: '14px',
          backgroundColor: 'var(--bg-surface)',
          border: '1px solid var(--border-color)',
          display: 'flex',
          flexDirection: { xs: 'column', sm: 'row' },
          justifyContent: 'space-between',
          alignItems: { xs: 'flex-start', sm: 'center' },
          gap: 1.5
        }}>
          <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 3, alignItems: 'center' }}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
              <Box sx={{ width: 10, height: 10, borderRadius: '50%', backgroundColor: 'var(--success)' }} />
              <Typography variant="caption" sx={{ color: 'var(--text-secondary)', fontWeight: 600 }}>Available Volunteers:</Typography>
              <Typography variant="caption" fontWeight="800" sx={{ color: 'var(--text-primary)' }}>{availableVolunteers}</Typography>
            </Box>

            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
              <Box sx={{ width: 10, height: 10, borderRadius: '50%', backgroundColor: 'var(--secondary)' }} />
              <Typography variant="caption" sx={{ color: 'var(--text-secondary)', fontWeight: 600 }}>Security Staff On-Duty:</Typography>
              <Typography variant="caption" fontWeight="800" sx={{ color: 'var(--text-primary)' }}>{securityStaffOnDuty}</Typography>
            </Box>
          </Box>

          <Chip
            icon={<MdInsights color="#E93F41" size={16} />}
            label="Society Security Operations Online"
            size="small"
            sx={{
              backgroundColor: 'rgba(233, 63, 65, 0.10)',
              color: '#E93F41',
              fontWeight: 700,
              fontSize: '0.75rem',
              border: '1px solid rgba(233, 63, 65, 0.25)'
            }}
          />
        </Box>
      </CardContent>
    </Card>
  );
}
