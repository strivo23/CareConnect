import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import Layout from './layouts/Layout';

// Pages
import Login from './pages/Login';
import CreateSuperuser from './pages/CreateSuperuser';
import Dashboard from './pages/Dashboard';
import Society from './pages/Society';
import Block from './pages/Block';
import Flat from './pages/Flat';
import Residents from './pages/Residents';
import Users from './pages/Users';
import Alerts from './pages/Alerts';
import Reports from './pages/Reports';
import Settings from './pages/Settings';
import Emergency from './pages/Emergency';
import NotificationTemplates from './pages/NotificationTemplates';
import EscalationSettings from './pages/EscalationSettings';

const App = () => {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/create-superuser" element={<CreateSuperuser />} />
        
        {/* Protected Routes wrapped in Layout */}
        <Route path="/" element={<Layout />}>
          <Route index element={<Navigate to="/dashboard" replace />} />
          <Route path="dashboard" element={<Dashboard />} />
          <Route path="society" element={<Society />} />
          <Route path="block" element={<Block />} />
          <Route path="flat" element={<Flat />} />
          <Route path="residents" element={<Residents />} />
          <Route path="emergency" element={<Emergency />} />
          <Route path="users" element={<Users />} />
          <Route path="alerts" element={<Alerts />} />
          <Route path="reports" element={<Reports />} />
          <Route path="notification-templates" element={<NotificationTemplates />} />
          <Route path="escalation-settings" element={<EscalationSettings />} />
          <Route path="settings" element={<Settings />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
};

export default App;

