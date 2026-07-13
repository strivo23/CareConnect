import { useState } from "react";
import { useNavigate } from "react-router-dom";

import { login } from "../../services/api";

export default function Login() {
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const handleSubmit = async (event) => {
    event.preventDefault();
    setLoading(true);
    setError("");

    try {
      await login({ email, password });
      navigate("/dashboard");
    } catch (loginError) {
      setError(loginError.response?.data?.message || "Unable to sign in");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ minHeight: "100vh", display: "grid", placeItems: "center", background: "#fff7ef" }}>
      <form onSubmit={handleSubmit} style={{ width: "100%", maxWidth: "420px", background: "#fff", padding: "32px", borderRadius: "20px", boxShadow: "0 18px 40px rgba(0,0,0,0.08)" }}>
        <h1 style={{ marginTop: 0 }}>CareConnect Admin</h1>
        <p style={{ color: "#666" }}>Sign in to manage societies, residents, and alerts.</p>
        <label style={{ display: "block", marginBottom: "14px" }}>
          <span style={{ display: "block", marginBottom: "6px" }}>Email</span>
          <input value={email} onChange={(event) => setEmail(event.target.value)} type="email" required style={{ width: "100%", padding: "12px", borderRadius: "10px", border: "1px solid #ddd" }} />
        </label>
        <label style={{ display: "block", marginBottom: "14px" }}>
          <span style={{ display: "block", marginBottom: "6px" }}>Password</span>
          <input value={password} onChange={(event) => setPassword(event.target.value)} type="password" required style={{ width: "100%", padding: "12px", borderRadius: "10px", border: "1px solid #ddd" }} />
        </label>
        {error ? <p style={{ color: "#c0392b" }}>{error}</p> : null}
        <button type="submit" disabled={loading} style={{ width: "100%", border: "none", borderRadius: "10px", padding: "12px", background: "#ff7a00", color: "#fff", fontWeight: 600, cursor: "pointer" }}>
          {loading ? "Signing in..." : "Sign in"}
        </button>
      </form>
    </div>
  );
}