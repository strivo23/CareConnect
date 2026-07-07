import { Routes, Route } from "react-router-dom";

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

export default function AppRoutes() {
  return (
    <Routes>
      <Route path="/" element={<Login />} />
      <Route path="/dashboard" element={<Layout><Dashboard /></Layout>} />
      <Route path="/society" element={<Layout><Society /></Layout>} />
      <Route path="/blocks" element={<Layout><Block /></Layout>} />
      <Route path="/flats" element={<Layout><Flat /></Layout>} />
      <Route path="/residents" element={<Layout><Residents /></Layout>} />
      <Route path="/users" element={<Layout><Users /></Layout>} />
      <Route path="/alerts" element={<Layout><Alerts /></Layout>} />
      <Route path="/reports" element={<Layout><Reports /></Layout>} />
      <Route path="/settings" element={<Layout><Settings /></Layout>} />
    </Routes>
  );
}