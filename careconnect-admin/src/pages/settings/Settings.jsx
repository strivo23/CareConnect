import { clearAuth, getCurrentUser } from "../../services/api";

export default function Settings() {
  const user = getCurrentUser();

  return (
    <div>
      <h1>Settings</h1>
      <div style={{ background: "#fff", border: "1px solid #eee", borderRadius: "16px", padding: "18px", marginTop: "16px" }}>
        <p><strong>Signed in as:</strong> {user?.full_name || user?.email || "Unknown user"}</p>
        <p><strong>Role:</strong> {user?.role || "-"}</p>
        <p><strong>Backend:</strong> http://127.0.0.1:8000/api</p>
        <button type="button" onClick={clearAuth} style={{ border: "none", borderRadius: "8px", padding: "10px 14px", background: "#ff7a00", color: "#fff" }}>
          Clear session
        </button>
      </div>
    </div>
  );
}
