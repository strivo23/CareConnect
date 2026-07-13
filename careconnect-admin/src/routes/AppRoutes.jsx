import { Navigate, Routes, Route } from "react-router-dom";

import Login from "../pages/Login/Login";
import Dashboard from "../pages/Dashboard/Dashboard";
import Society from "../pages/Society/Society";
import Block from "../pages/Block/Block";
import Flat from "../pages/Flat/Flat";
import Residents from "../pages/Residents/Residents";
import Users from "../pages/Users/Users";
import Alerts from "../pages/Alerts/Alerts";
import Reports from "../pages/Reports/Reports";
import Settings from "../pages/settings/Settings";

import Layout from "../components/Layout/Layout";
import { isAuthenticated } from "../services/api";

function RequireAuth({ children }) {
  if (!isAuthenticated()) {
    return <Navigate to="/" replace />;
  }

  return children;
}

export default function AppRoutes() {
  return (
    <Routes>
      <Route path="/" element={<Login />} />
      <Route path="/login" element={<Navigate to="/" replace />} />

      <Route
  path="/dashboard"
  element={
    <RequireAuth>
      <Layout>
        <Dashboard />
      </Layout>
    </RequireAuth>
  }
/>

      <Route
        path="/society"
        element={
          <RequireAuth>
            <Layout>
              <Society />
            </Layout>
          </RequireAuth>
        }
      />

      <Route
        path="/blocks"
        element={
          <RequireAuth>
            <Layout>
              <Block />
            </Layout>
          </RequireAuth>
        }
      />

      <Route
        path="/flats"
        element={
          <RequireAuth>
            <Layout>
              <Flat />
            </Layout>
          </RequireAuth>
        }
      />

      <Route
        path="/residents"
        element={
          <RequireAuth>
            <Layout>
              <Residents />
            </Layout>
          </RequireAuth>
        }
      />

      <Route
        path="/users"
        element={
          <RequireAuth>
            <Layout>
              <Users />
            </Layout>
          </RequireAuth>
        }
      />

      <Route
        path="/alerts"
        element={
          <RequireAuth>
            <Layout>
              <Alerts />
            </Layout>
          </RequireAuth>
        }
      />

      <Route
        path="/reports"
        element={
          <RequireAuth>
            <Layout>
              <Reports />
            </Layout>
          </RequireAuth>
        }
      />

      <Route
        path="/settings"
        element={
          <RequireAuth>
            <Layout>
              <Settings />
            </Layout>
          </RequireAuth>
        }
      />
    </Routes>
  );
}