import { useEffect, useState } from "react";

import { getBlocks, getFlats, getSocieties } from "../../services/api";

export default function Flat() {
  const [societies, setSocieties] = useState([]);
  const [blocks, setBlocks] = useState([]);
  const [selectedSociety, setSelectedSociety] = useState("");
  const [selectedBlock, setSelectedBlock] = useState("");
  const [flats, setFlats] = useState([]);

  useEffect(() => {
    getSocieties().then((items) => {
      setSocieties(items);
      if (items[0]) {
        setSelectedSociety(String(items[0].id));
      }
    }).catch(() => setSocieties([]));
  }, []);

  useEffect(() => {
    if (!selectedSociety) return;
    getBlocks({ society: selectedSociety }).then((items) => {
      setBlocks(items);
      setSelectedBlock(items[0] ? String(items[0].id) : "");
    }).catch(() => setBlocks([]));
  }, [selectedSociety]);

  useEffect(() => {
    if (!selectedSociety) return;
    getFlats({ society: selectedSociety, block: selectedBlock || undefined }).then(setFlats).catch(() => setFlats([]));
  }, [selectedSociety, selectedBlock]);

  return (
    <div>
      <h1>Flats</h1>
      <div style={{ display: "flex", gap: "12px", flexWrap: "wrap" }}>
        <label>
          <span style={{ display: "block", marginBottom: "8px" }}>Society</span>
          <select value={selectedSociety} onChange={(event) => setSelectedSociety(event.target.value)} style={{ padding: "10px", borderRadius: "10px" }}>
            {societies.map((society) => <option key={society.id} value={society.id}>{society.name}</option>)}
          </select>
        </label>
        <label>
          <span style={{ display: "block", marginBottom: "8px" }}>Block</span>
          <select value={selectedBlock} onChange={(event) => setSelectedBlock(event.target.value)} style={{ padding: "10px", borderRadius: "10px" }}>
            <option value="">All blocks</option>
            {blocks.map((block) => <option key={block.id} value={block.id}>{block.name}</option>)}
          </select>
        </label>
      </div>
      <ul style={{ marginTop: "20px", background: "#fff", borderRadius: "16px", border: "1px solid #eee", padding: "18px" }}>
        {flats.map((flat) => <li key={flat.id}>{flat.flat_number} • {flat.type || "Flat"} • {flat.occupied ? "Occupied" : "Vacant"}</li>)}
      </ul>
    </div>
  );
}
