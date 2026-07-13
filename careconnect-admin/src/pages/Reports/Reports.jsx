import { useEffect, useState } from "react";

import { getDashboardStats, getResidents } from "../../services/api";

export default function Reports() {
  const [summary, setSummary] = useState(null);

  useEffect(() => {
    const load = async () => {
      const [stats, residents] = await Promise.all([getDashboardStats(), getResidents()]);
      const approved = residents.filter((resident) => (resident.status || "").toLowerCase() === "approved").length;
      setSummary({ ...stats, approvedResidents: approved, pendingResidents: residents.length - approved });
    };

    load().catch(() => setSummary(null));
  }, []);

  return (
    <div>
      <h1>Reports</h1>
      {summary ? (
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(180px, 1fr))", gap: "16px", marginTop: "20px" }}>
          <div style={{ background: "#fff", border: "1px solid #eee", borderRadius: "14px", padding: "16px" }}>Approved residents: {summary.approvedResidents}</div>
          <div style={{ background: "#fff", border: "1px solid #eee", borderRadius: "14px", padding: "16px" }}>Pending residents: {summary.pendingResidents}</div>
          <div style={{ background: "#fff", border: "1px solid #eee", borderRadius: "14px", padding: "16px" }}>Total alerts: {summary.total_alerts ?? 0}</div>
        </div>
      ) : (
        <p>Loading report summary...</p>
      )}
    </div>
  );
}
