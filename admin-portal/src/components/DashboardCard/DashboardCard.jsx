import React from 'react';
import { Card, CardContent, Typography, Box, Chip } from '@mui/material';
import { ResponsiveContainer, AreaChart, Area } from 'recharts';
import { motion } from 'framer-motion';
import { MdTrendingUp, MdTrendingDown } from 'react-icons/md';

const DashboardCard = ({ 
  title, 
  value, 
  icon, 
  color = '#7C3AED', 
  subtitle, 
  trend, 
  trendPositive = true, 
  sparklineData = [12, 18, 14, 22, 28, 24, 32],
  indicatorDot = false
}) => {
  const chartData = sparklineData.map((val, idx) => ({ idx, val }));

  const safeId = title.replace(/[^a-zA-Z0-9]/g, '');

  return (
    <motion.div
      whileHover={{ y: -6, transition: { duration: 0.2 } }}
      initial={{ opacity: 0, y: 15 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3 }}
    >
      <Card sx={{ 
        backgroundColor: 'var(--bg-card)', 
        color: 'var(--text-primary)',
        borderRadius: '20px',
        border: '1px solid var(--border-color)',
        boxShadow: '0 4px 20px rgba(0, 0, 0, 0.25)',
        position: 'relative',
        overflow: 'hidden',
        background: `linear-gradient(145deg, var(--bg-card) 0%, rgba(22, 31, 53, 0.95) 100%)`,
        '&:hover': {
          borderColor: 'var(--border-light)',
          boxShadow: `0 8px 30px ${color}25`
        }
      }}>
        {/* Subtle accent glow top border */}
        <Box sx={{ 
          position: 'absolute', 
          top: 0, 
          left: 0, 
          right: 0, 
          height: 3, 
          background: `linear-gradient(90deg, ${color} 0%, transparent 100%)` 
        }} />

        <CardContent sx={{ p: 2.5, '&:last-child': { pb: 2 } }}>
          {/* Header Row */}
          <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 1.5 }}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
              <Typography variant="subtitle2" fontWeight="600" sx={{ color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
                {title}
              </Typography>
              {indicatorDot && (
                <span className="pulse-dot-green" style={{ width: 8, height: 8 }} />
              )}
            </Box>

            <Box sx={{ 
              backgroundColor: `${color}18`, 
              color: color,
              p: 1.2, 
              borderRadius: '14px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              border: `1px solid ${color}30`
            }}>
              {icon}
            </Box>
          </Box>

          {/* Metric Value & Trend Row */}
          <Box sx={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', mb: 1 }}>
            <Typography variant="h4" fontWeight="800" sx={{ letterSpacing: '-0.5px' }}>
              {value}
            </Typography>

            {trend && (
              <Chip 
                icon={trendPositive ? <MdTrendingUp size={14} /> : <MdTrendingDown size={14} />}
                label={trend} 
                size="small"
                sx={{
                  height: 22,
                  fontSize: '0.72rem',
                  fontWeight: 700,
                  backgroundColor: trendPositive ? 'rgba(34, 197, 94, 0.15)' : 'rgba(239, 68, 68, 0.15)',
                  color: trendPositive ? '#22C55E' : '#EF4444',
                  border: trendPositive ? '1px solid rgba(34, 197, 94, 0.3)' : '1px solid rgba(239, 68, 68, 0.3)',
                  '& .MuiChip-icon': { color: 'inherit' }
                }}
              />
            )}
          </Box>

          {/* Subtitle / Details */}
          {subtitle && (
            <Typography variant="caption" sx={{ color: 'var(--text-muted)', fontSize: '0.75rem', display: 'block', mb: 1 }}>
              {subtitle}
            </Typography>
          )}

          {/* Mini Sparkline Graph */}
          <Box sx={{ height: 36, width: '100%', mt: 1 }}>
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={chartData} margin={{ top: 0, right: 0, left: 0, bottom: 0 }}>
                <defs>
                  <linearGradient id={`gradient-${safeId}`} x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor={color} stopOpacity={0.4} />
                    <stop offset="100%" stopColor={color} stopOpacity={0.0} />
                  </linearGradient>
                </defs>
                <Area 
                  type="monotone" 
                  dataKey="val" 
                  stroke={color} 
                  strokeWidth={2} 
                  fillOpacity={1} 
                  fill={`url(#gradient-${safeId})`} 
                />
              </AreaChart>
            </ResponsiveContainer>
          </Box>
        </CardContent>
      </Card>
    </motion.div>
  );
};

export default DashboardCard;
