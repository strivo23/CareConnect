import { useEffect, useState } from "react";

import { getResidents } from "../../services/api";

export default function Users() {
  const [users, setUsers] = useState([]);

  useEffect(() => {
    getResidents().then(setUsers).catch(() => setUsers([]));
  }, []);

  return (
    <div>
      <h1>Users</h1>
      <p style={{ color: "#666" }}>This admin portal is wired to resident/user data from the backend.</p>
      <ul style={{ background: "#fff", border: "1px solid #eee", borderRadius: "16px", padding: "18px", listStyle: "none" }}>
        {users.map((user) => (
          <li key={user.id} style={{ padding: "10px 0", borderBottom: "1px solid #f2f2f2" }}>
            <strong>{user.user?.full_name || user.user?.email || `User ${user.id}`}</strong>
            <div style={{ color: "#666" }}>{user.user?.phone_number || "No phone"} • {user.user?.role || "-"}</div>
          </li>
        ))}
      </ul>
    </div>
  );
}