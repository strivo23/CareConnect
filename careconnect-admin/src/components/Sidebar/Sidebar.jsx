import {
  FaHome,
  FaBuilding,
  FaThLarge,
  FaDoorOpen,
  FaUsers,
  FaUserCog,
  FaBell,
  FaChartBar,
  FaCog,
} from "react-icons/fa";

import { NavLink } from "react-router-dom";
import "./Sidebar.css";

export default function Sidebar() {
  const menuItems = [
    { name: "Dashboard", path: "/dashboard", icon: <FaHome /> },
    { name: "Society", path: "/society", icon: <FaBuilding /> },
    { name: "Blocks / Towers", path: "/blocks", icon: <FaThLarge /> },
    { name: "Flats", path: "/flats", icon: <FaDoorOpen /> },
    { name: "Residents", path: "/residents", icon: <FaUsers /> },
    { name: "Users", path: "/users", icon: <FaUserCog /> },
    { name: "Alerts", path: "/alerts", icon: <FaBell /> },
    { name: "Reports", path: "/reports", icon: <FaChartBar /> },
    { name: "Settings", path: "/settings", icon: <FaCog /> },
  ];

  return (
    <div className="sidebar">
      <h2 className="logo">CareConnect</h2>

      {menuItems.map((item) => (
        <NavLink
          key={item.path}
          to={item.path}
          className={({ isActive }) =>
            isActive ? "menu active" : "menu"
          }
        >
          <span>{item.icon}</span>
          <span>{item.name}</span>
        </NavLink>
      ))}
    </div>
  );
}