import { useEffect, useState } from "react";

import { getSocieties } from "../../services/api";

export default function Society() {
  const [societies, setSocieties] = useState([]);

  useEffect(() => {
    getSocieties().then(setSocieties).catch(() => setSocieties([]));
  }, []);

  return (
    <div>
      <h1>Society</h1>
      <table style={{ width: "100%", borderCollapse: "collapse", marginTop: "16px", background: "#fff" }}>
        <thead>
          <tr>
            <th style={{ textAlign: "left", padding: "12px", borderBottom: "1px solid #eee" }}>Name</th>
            <th style={{ textAlign: "left", padding: "12px", borderBottom: "1px solid #eee" }}>City</th>
            <th style={{ textAlign: "left", padding: "12px", borderBottom: "1px solid #eee" }}>Blocks</th>
            <th style={{ textAlign: "left", padding: "12px", borderBottom: "1px solid #eee" }}>Flats</th>
          </tr>
        </thead>
        <tbody>
          {societies.map((society) => (
            <tr key={society.id}>
              <td style={{ padding: "12px", borderBottom: "1px solid #f3f3f3" }}>{society.name}</td>
              <td style={{ padding: "12px", borderBottom: "1px solid #f3f3f3" }}>{society.city || "-"}</td>
              <td style={{ padding: "12px", borderBottom: "1px solid #f3f3f3" }}>{society.total_blocks ?? 0}</td>
              <td style={{ padding: "12px", borderBottom: "1px solid #f3f3f3" }}>{society.total_flats ?? 0}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}