import React, { useContext } from 'react';
import { IconButton } from '@mui/material';
import { MdLightMode, MdDarkMode } from 'react-icons/md';
import { ThemeContext } from '../../context/ThemeContext';

const ThemeToggle = () => {
  const { themeMode, toggleTheme } = useContext(ThemeContext);

  return (
    <IconButton onClick={toggleTheme} color="inherit" sx={{ ml: 1 }}>
      {themeMode === 'light' ? <MdDarkMode size={22} /> : <MdLightMode size={22} />}
    </IconButton>
  );
};

export default ThemeToggle;
