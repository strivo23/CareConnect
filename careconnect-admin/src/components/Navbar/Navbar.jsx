import { useNavigate } from "react-router-dom";

import { clearAuth, getCurrentUser } from "../../services/api";

export default function Navbar() {
  const navigate = useNavigate();
  const user = getCurrentUser();

  const handleLogout = () => {
    clearAuth();
    navigate("/");
  };

  return (
    <div style={{
      height: "60px",
      background: "#fff",
      borderBottom: "1px solid #ddd",
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      padding: "0 20px"
    }}>
      <h3 style={{ margin: 0 }}>CareConnect Admin</h3>
      <div style={{ display: "flex", alignItems: "center", gap: "12px" }}>
        <span style={{ fontSize: "14px", color: "#555" }}>
          {user ? `${user.full_name} • ${user.role}` : "Connected to backend"}
        </span>
        <button
          type="button"
          onClick={handleLogout}
          style={{
            border: "none",
            background: "#ff7a00",
            color: "#fff",
            borderRadius: "8px",
            padding: "8px 14px",
            cursor: "pointer"
          }}
        >
          Logout
        </button>
      </div>
    </div>
  );
}