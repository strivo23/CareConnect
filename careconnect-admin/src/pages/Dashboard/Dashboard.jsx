import { useEffect, useState } from "react";

import { getDashboardStats, getSocieties, getResidents } from "../../services/api";

export default function Dashboard() {
  const [stats, setStats] = useState(null);
  const [previewSocieties, setPreviewSocieties] = useState([]);
  const [recentResidents, setRecentResidents] = useState([]);

  useEffect(() => {
    let active = true;

    const load = async () => {
      try {
        const [dashboardStats, societies, residents] = await Promise.all([
          getDashboardStats(),
          getSocieties(),
          getResidents({ ordering: "-id" }),
        ]);

        if (!active) return;

        setStats(dashboardStats);
        setPreviewSocieties(societies.slice(0, 5));
        setRecentResidents(residents.slice(0, 5));
      } catch (error) {
        if (!active) return;
        setStats({ error: error.response?.data?.message || "Failed to load dashboard" });
      }
    };

    load();

    return () => {
      active = false;
    };
  }, []);

  const cards = stats
    ? [
        { label: "Societies", value: stats.total_societies ?? 0 },
        { label: "Blocks", value: stats.total_blocks ?? 0 },
        { label: "Flats", value: stats.total_flats ?? 0 },
        { label: "Residents", value: stats.total_residents ?? 0 },
        { label: "Users", value: stats.total_users ?? 0 },
        { label: "Alerts", value: stats.total_alerts ?? 0 },
      ]
    : [];

  return (
    <div>
      <h1>Dashboard</h1>
      <p style={{ color: "#666" }}>Live data from the Django backend.</p>
      {stats?.error ? <p style={{ color: "#c0392b" }}>{stats.error}</p> : null}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(180px, 1fr))", gap: "16px", marginTop: "20px" }}>
        {cards.map((card) => (
          <div key={card.label} style={{ background: "#fff", border: "1px solid #eee", borderRadius: "16px", padding: "18px" }}>
            <div style={{ color: "#777", marginBottom: "6px" }}>{card.label}</div>
            <div style={{ fontSize: "32px", fontWeight: 700 }}>{card.value}</div>
          </div>
        ))}
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(320px, 1fr))", gap: "20px", marginTop: "24px" }}>
        <section style={{ background: "#fff", border: "1px solid #eee", borderRadius: "16px", padding: "18px" }}>
          <h2>Recent societies</h2>
          <ul style={{ paddingLeft: "18px" }}>
            {previewSocieties.map((society) => (
              <li key={society.id}>{society.name} - {society.city || "No city"}</li>
            ))}
          </ul>
        </section>

        <section style={{ background: "#fff", border: "1px solid #eee", borderRadius: "16px", padding: "18px" }}>
          <h2>Recent residents</h2>
          <ul style={{ paddingLeft: "18px" }}>
            {recentResidents.map((resident) => (
              <li key={resident.id}>{resident.user?.full_name || resident.user?.email || `Resident ${resident.id}`} - {resident.status}</li>
            ))}
          </ul>
        </section>
      </div>
    </div>
  );
}