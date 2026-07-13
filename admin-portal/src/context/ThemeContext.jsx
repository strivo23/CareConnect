import React, { createContext, useState, useEffect } from 'react';
import { ThemeProvider as MUIThemeProvider, createTheme } from '@mui/material/styles';

export const ThemeContext = createContext();

export const ThemeProvider = ({ children }) => {
  const [themeMode, setThemeMode] = useState('light');

  useEffect(() => {
    // Check local storage or system preference on load
    const savedTheme = localStorage.getItem('careconnect-theme');
    if (savedTheme) {
      setThemeMode(savedTheme);
      document.documentElement.setAttribute('data-theme', savedTheme);
    } else {
      const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
      setThemeMode(prefersDark ? 'dark' : 'light');
      document.documentElement.setAttribute('data-theme', prefersDark ? 'dark' : 'light');
    }
  }, []);

  const toggleTheme = () => {
    const newTheme = themeMode === 'light' ? 'dark' : 'light';
    setThemeMode(newTheme);
    localStorage.setItem('careconnect-theme', newTheme);
    document.documentElement.setAttribute('data-theme', newTheme);
  };

  const muiTheme = createTheme({
    palette: {
      mode: themeMode,
      primary: {
        main: '#FF3B30',
      },
      success: {
        main: '#22C55E',
      },
      warning: {
        main: '#F59E0B',
      },
      error: {
        main: '#EF4444',
      },
      background: {
        default: themeMode === 'light' ? '#F5F7FA' : '#111827',
        paper: themeMode === 'light' ? '#FFFFFF' : '#1F2937',
      },
    },
    typography: {
      fontFamily: "'Inter', sans-serif",
    },
    components: {
      MuiButton: {
        styleOverrides: {
          root: {
            textTransform: 'none',
            borderRadius: '8px',
          },
        },
      },
      MuiCard: {
        styleOverrides: {
          root: {
            borderRadius: '12px',
            boxShadow: themeMode === 'light' ? '0 1px 2px 0 rgba(0, 0, 0, 0.05)' : '0 1px 2px 0 rgba(0, 0, 0, 0.5)',
          },
        },
      },
    },
  });

  return (
    <ThemeContext.Provider value={{ themeMode, toggleTheme }}>
      <MUIThemeProvider theme={muiTheme}>
        {children}
      </MUIThemeProvider>
    </ThemeContext.Provider>
  );
};
