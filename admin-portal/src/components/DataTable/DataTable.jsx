import React from 'react';
import { 
  Table, TableBody, TableCell, TableContainer, TableHead, 
  TableRow, Paper, TablePagination, IconButton 
} from '@mui/material';
import { MdEdit, MdDelete, MdVisibility } from 'react-icons/md';

const DataTable = ({ 
  columns, 
  data, 
  onEdit, 
  onDelete, 
  onView,
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
    <Paper sx={{ width: '100%', overflow: 'hidden', backgroundColor: 'var(--bg-card)', color: 'var(--text-primary)', boxShadow: 'var(--shadow-sm)' }}>
      <TableContainer sx={{ maxHeight: 440 }}>
        <Table stickyHeader aria-label="sticky table">
          <TableHead>
            <TableRow>
              {columns.map((column) => (
                <TableCell
                  key={column.id}
                  align={column.align || 'left'}
                  style={{ minWidth: column.minWidth, backgroundColor: 'var(--bg-main)', color: 'var(--text-primary)', fontWeight: 'bold' }}
                >
                  {column.label}
                </TableCell>
              ))}
              <TableCell style={{ backgroundColor: 'var(--bg-main)', color: 'var(--text-primary)', fontWeight: 'bold' }} align="center">
                Actions
              </TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {displayedData.map((row, index) => {
                return (
                  <TableRow hover role="checkbox" tabIndex={-1} key={row.id || index}>
                    {columns.map((column) => {
                      const value = row[column.id];
                      return (
                        <TableCell key={column.id} align={column.align} sx={{ color: 'var(--text-primary)', borderBottomColor: 'var(--border-color)' }}>
                          {column.format ? column.format(value) : value}
                        </TableCell>
                      );
                    })}
                    <TableCell align="center" sx={{ borderBottomColor: 'var(--border-color)' }}>
                      {onView && (
                        <IconButton size="small" sx={{ color: 'var(--primary)' }} onClick={() => onView(row)}>
                          <MdVisibility size={18} />
                        </IconButton>
                      )}
                      {onEdit && (
                        <IconButton size="small" sx={{ color: 'var(--warning)' }} onClick={() => onEdit(row)}>
                          <MdEdit size={18} />
                        </IconButton>
                      )}
                      {onDelete && (
                        <IconButton size="small" sx={{ color: 'var(--danger)' }} onClick={() => onDelete(row)}>
                          <MdDelete size={18} />
                        </IconButton>
                      )}
                    </TableCell>
                  </TableRow>
                );
              })}
            {displayedData.length === 0 && (
              <TableRow>
                <TableCell colSpan={columns.length + 1} align="center" sx={{ py: 3, color: 'var(--text-secondary)' }}>
                  No records found
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
          color: 'var(--text-primary)',
          borderTop: '1px solid var(--border-color)',
          '.MuiTablePagination-selectIcon': { color: 'var(--text-primary)' },
        }}
      />
    </Paper>
  );
};

export default DataTable;
