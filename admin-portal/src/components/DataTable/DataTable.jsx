import React from 'react';
import { 
  Table, 
  TableBody, 
  TableCell, 
  TableContainer, 
  TableHead, 
  TableRow, 
  Paper, 
  TablePagination, 
  IconButton, 
  Chip, 
  Avatar, 
  Box,
  Typography,
  Tooltip
} from '@mui/material';
import { MdEdit, MdDelete, MdVisibility, MdTimeline } from 'react-icons/md';

const priorityColors = {
  High: { bg: 'rgba(233, 63, 65, 0.15)', text: '#E93F41', border: 'rgba(233, 63, 65, 0.3)' },
  Medium: { bg: 'rgba(245, 158, 11, 0.15)', text: '#F59E0B', border: 'rgba(245, 158, 11, 0.3)' },
  Low: { bg: 'rgba(59, 130, 246, 0.15)', text: '#3B82F6', border: 'rgba(59, 130, 246, 0.3)' },
};

const statusColors = {
  Pending: { bg: 'rgba(245, 158, 11, 0.15)', text: '#F59E0B', border: 'rgba(245, 158, 11, 0.3)' },
  Accepted: { bg: 'rgba(233, 63, 65, 0.15)', text: '#E93F41', border: 'rgba(233, 63, 65, 0.3)' },
  'In Progress': { bg: 'rgba(59, 130, 246, 0.15)', text: '#3B82F6', border: 'rgba(59, 130, 246, 0.3)' },
  Resolved: { bg: 'rgba(34, 197, 94, 0.15)', text: '#22C55E', border: 'rgba(34, 197, 94, 0.3)' },
  Cancelled: { bg: 'rgba(107, 114, 128, 0.15)', text: '#9CA3AF', border: 'rgba(107, 114, 128, 0.3)' },
};

const DataTable = ({ 
  columns, 
  data, 
  onEdit, 
  onDelete, 
  onView,
  onTimeline,
  serverSide = false,
  count = 0,
  page = 0,
  rowsPerPage = 5,
  onPageChange,
  onRowsPerPageChange
}) => {
  const [localPage, setLocalPage] = React.useState(0);
  const [localRowsPerPage, setLocalRowsPerPage] = React.useState(5);

  const activePage = serverSide ? page : localPage;
  const activeRowsPerPage = serverSide ? rowsPerPage : localRowsPerPage;

  const handleChangePage = (event, newPage) => {
    if (serverSide) {
      if (onPageChange) onPageChange(event, newPage);
    } else {
      setLocalPage(newPage);
    }
  };

  const handleChangeRowsPerPage = (event) => {
    const val = +event.target.value;
    if (serverSide) {
      if (onRowsPerPageChange) onRowsPerPageChange(event);
    } else {
      setLocalRowsPerPage(val);
      setLocalPage(0);
    }
  };

  const displayedData = serverSide ? data : data.slice(activePage * activeRowsPerPage, activePage * activeRowsPerPage + activeRowsPerPage);
  const totalCount = serverSide ? count : data.length;

  return (
    <Paper 
      sx={{ 
        width: '100%', 
        overflow: 'hidden', 
        backgroundColor: 'var(--bg-card)', 
        color: 'var(--text-primary)', 
        borderRadius: '20px',
        border: '1px solid var(--border-color)',
        boxShadow: '0 8px 24px rgba(0, 0, 0, 0.3)' 
      }}
    >
      <TableContainer sx={{ maxHeight: 480 }}>
        <Table stickyHeader aria-label="emergency response data table">
          <TableHead>
            <TableRow>
              {columns.map((column) => (
                <TableCell
                  key={column.id}
                  align={column.align || 'left'}
                  style={{ 
                    minWidth: column.minWidth, 
                    backgroundColor: '#111827', 
                    color: 'var(--text-secondary)', 
                    fontWeight: '700',
                    fontSize: '0.8rem',
                    textTransform: 'uppercase',
                    letterSpacing: '0.6px',
                    borderBottom: '1px solid var(--border-color)'
                  }}
                >
                  {column.label}
                </TableCell>
              ))}
              <TableCell 
                style={{ 
                  backgroundColor: '#111827', 
                  color: 'var(--text-secondary)', 
                  fontWeight: '700',
                  fontSize: '0.8rem',
                  textTransform: 'uppercase',
                  letterSpacing: '0.6px',
                  borderBottom: '1px solid var(--border-color)'
                }} 
                align="center"
              >
                Actions
              </TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {displayedData.map((row, index) => {
              return (
                <TableRow 
                  hover 
                  tabIndex={-1} 
                  key={row.id || index}
                  sx={{
                    transition: 'background-color 0.2s ease',
                    '&:hover': {
                      backgroundColor: 'rgba(124, 58, 237, 0.04) !important',
                    },
                    '&:last-child td': {
                      borderBottom: 0
                    }
                  }}
                >
                  {columns.map((column) => {
                    const value = row[column.id];

                    // Custom rendering for priority
                    if (column.id === 'priority') {
                      const style = priorityColors[value] || priorityColors.Medium;
                      return (
                        <TableCell key={column.id} align={column.align} sx={{ borderBottomColor: 'var(--border-color)' }}>
                          <Chip 
                            label={value || 'Medium'} 
                            size="small" 
                            sx={{
                              height: 24,
                              fontWeight: 700,
                              fontSize: '0.72rem',
                              backgroundColor: style.bg,
                              color: style.text,
                              border: `1px solid ${style.border}`,
                              borderRadius: '8px'
                            }}
                          />
                        </TableCell>
                      );
                    }

                    // Custom rendering for status
                    if (column.id === 'status') {
                      const style = statusColors[value] || statusColors.Pending;
                      return (
                        <TableCell key={column.id} align={column.align} sx={{ borderBottomColor: 'var(--border-color)' }}>
                          <Chip 
                            label={value || 'Pending'} 
                            size="small" 
                            sx={{
                              height: 24,
                              fontWeight: 700,
                              fontSize: '0.72rem',
                              backgroundColor: style.bg,
                              color: style.text,
                              border: `1px solid ${style.border}`,
                              borderRadius: '8px'
                            }}
                          />
                        </TableCell>
                      );
                    }

                    // Custom rendering for resident name with Avatar
                    if (column.id === 'resident_name') {
                      return (
                        <TableCell key={column.id} align={column.align} sx={{ borderBottomColor: 'var(--border-color)' }}>
                          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
                            <Avatar 
                              src={`https://i.pravatar.cc/150?u=${row.id || index}`} 
                              sx={{ width: 32, height: 32, fontSize: '0.85rem', fontWeight: 700, backgroundColor: 'var(--primary)' }}
                            >
                              {String(value || 'R')[0]}
                            </Avatar>
                            <Typography variant="body2" fontWeight="600" sx={{ color: 'var(--text-primary)' }}>
                              {value}
                            </Typography>
                          </Box>
                        </TableCell>
                      );
                    }

                    return (
                      <TableCell key={column.id} align={column.align} sx={{ color: 'var(--text-primary)', borderBottomColor: 'var(--border-color)', fontSize: '0.875rem' }}>
                        {column.format ? column.format(value) : value}
                      </TableCell>
                    );
                  })}

                  {/* Actions column */}
                  <TableCell align="center" sx={{ borderBottomColor: 'var(--border-color)' }}>
                    <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 0.5 }}>
                      {/* Built-in item action buttons from row (e.g. Accept, In Progress, Resolve, Cancel) */}
                      {row.actions}

                      {onView && (
                        <Tooltip title="View Details">
                          <IconButton size="small" sx={{ color: 'var(--primary)', '&:hover': { backgroundColor: 'rgba(124, 58, 237, 0.1)' } }} onClick={() => onView(row)}>
                            <MdVisibility size={18} />
                          </IconButton>
                        </Tooltip>
                      )}
                      {onTimeline && (
                        <Tooltip title="Incident Timeline">
                          <IconButton size="small" sx={{ color: 'var(--secondary)', '&:hover': { backgroundColor: 'rgba(59, 130, 246, 0.1)' } }} onClick={() => onTimeline(row)}>
                            <MdTimeline size={18} />
                          </IconButton>
                        </Tooltip>
                      )}
                      {onEdit && (
                        <Tooltip title="Edit Record">
                          <IconButton size="small" sx={{ color: 'var(--warning)', '&:hover': { backgroundColor: 'rgba(245, 158, 11, 0.1)' } }} onClick={() => onEdit(row)}>
                            <MdEdit size={18} />
                          </IconButton>
                        </Tooltip>
                      )}
                      {onDelete && (
                        <Tooltip title="Delete Record">
                          <IconButton size="small" sx={{ color: 'var(--danger)', '&:hover': { backgroundColor: 'rgba(239, 68, 68, 0.1)' } }} onClick={() => onDelete(row)}>
                            <MdDelete size={18} />
                          </IconButton>
                        </Tooltip>
                      )}
                    </Box>
                  </TableCell>
                </TableRow>
              );
            })}

            {displayedData.length === 0 && (
              <TableRow>
                <TableCell colSpan={columns.length + 1} align="center" sx={{ py: 6, color: 'var(--text-secondary)' }}>
                  No active incidents recorded.
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </TableContainer>
      
      <TablePagination
        rowsPerPageOptions={[5, 10, 25]}
        component="div"
        count={totalCount}
        rowsPerPage={activeRowsPerPage}
        page={activePage}
        onPageChange={handleChangePage}
        onRowsPerPageChange={handleChangeRowsPerPage}
        sx={{
          color: 'var(--text-secondary)',
          borderTop: '1px solid var(--border-color)',
          backgroundColor: '#111827',
          '.MuiTablePagination-selectIcon': { color: 'var(--text-primary)' },
        }}
      />
    </Paper>
  );
};

export default DataTable;
