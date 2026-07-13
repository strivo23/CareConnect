import React from 'react';
import { Box, InputBase, IconButton } from '@mui/material';
import { MdSearch, MdFilterList } from 'react-icons/md';

const SearchBar = ({ placeholder = "Search...", onSearch, onFilter }) => {
  return (
    <Box sx={{ 
      display: 'flex', 
      alignItems: 'center', 
      backgroundColor: 'var(--bg-card)', 
      borderRadius: '8px',
      px: 2,
      py: 0.5,
      border: '1px solid var(--border-color)',
      width: { xs: '100%', sm: '300px' },
      boxShadow: 'var(--shadow-sm)'
    }}>
      <MdSearch size={20} color="var(--text-secondary)" />
      <InputBase 
        placeholder={placeholder} 
        onChange={(e) => onSearch && onSearch(e.target.value)}
        sx={{ ml: 1, flex: 1, color: 'var(--text-primary)' }} 
      />
      {onFilter && (
        <IconButton size="small" onClick={onFilter} sx={{ ml: 1, color: 'var(--text-secondary)' }}>
          <MdFilterList size={20} />
        </IconButton>
      )}
    </Box>
  );
};

export default SearchBar;
