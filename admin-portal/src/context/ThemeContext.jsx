import React, { createContext, useState, useEffect } from 'react';
import { ThemeProvider as MUIThemeProvider, createTheme } from '@mui/material/styles';

export const ThemeContext = createContext();

export const ThemeProvider = ({ children }) => {
  const [themeMode, setThemeMode] = useState('dark');

  useEffect(() => {
    // Check local storage or default to dark
    const savedTheme = localStorage.getItem('careconnect-theme');
    if (savedTheme) {
      setThemeMode(savedTheme);
      document.documentElement.setAttribute('data-theme', savedTheme);
    } else {
      setThemeMode('dark');
      document.documentElement.setAttribute('data-theme', 'dark');
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
        main: '#E93F41',
        contrastText: '#FFFFFF',
      },
      secondary: {
        main: '#2563EB',
      },
      success: {
        main: themeMode === 'light' ? '#16A34A' : '#22C55E',
      },
      warning: {
        main: themeMode === 'light' ? '#D97706' : '#F59E0B',
      },
      error: {
        main: '#E93F41',
      },
      background: {
        default: themeMode === 'light' ? '#F5F7FB' : '#0B1220',
        paper: themeMode === 'light' ? '#FFFFFF' : '#1A2437',
      },
      text: {
        primary: themeMode === 'light' ? '#0F172A' : '#F8FAFC',
        secondary: themeMode === 'light' ? '#64748B' : '#94A3B8',
      },
    },
    typography: {
      fontFamily: "'Outfit', 'Inter', sans-serif",
    },
    shape: {
      borderRadius: 18,
    },
    components: {
      MuiButton: {
        styleOverrides: {
          root: {
            textTransform: 'none',
            borderRadius: '12px',
            fontWeight: 600,
            boxShadow: 'none',
          },
        },
      },
      MuiCard: {
        styleOverrides: {
          root: {
            borderRadius: '20px',
            backgroundColor: themeMode === 'light' ? '#FFFFFF' : '#161F35',
            backgroundImage: 'none',
            boxShadow: themeMode === 'light' ? '0 2px 8px rgba(0, 0, 0, 0.05)' : '0 4px 16px rgba(0, 0, 0, 0.35)',
            border: themeMode === 'light' ? '1px solid #E2E8F0' : '1px solid rgba(255, 255, 255, 0.08)',
          },
        },
      },
      MuiPaper: {
        styleOverrides: {
          root: {
            backgroundImage: 'none',
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
