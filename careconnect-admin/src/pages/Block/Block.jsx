import { useEffect, useState } from "react";

import { getBlocks, getSocieties } from "../../services/api";

export default function Block() {
	const [societies, setSocieties] = useState([]);
	const [selectedSociety, setSelectedSociety] = useState("");
	const [blocks, setBlocks] = useState([]);

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
		getBlocks({ society: selectedSociety }).then(setBlocks).catch(() => setBlocks([]));
	}, [selectedSociety]);

	return (
		<div>
			<h1>Blocks / Towers</h1>
			<label>
				<span style={{ display: "block", marginBottom: "8px" }}>Society</span>
				<select value={selectedSociety} onChange={(event) => setSelectedSociety(event.target.value)} style={{ padding: "10px", borderRadius: "10px" }}>
					{societies.map((society) => <option key={society.id} value={society.id}>{society.name}</option>)}
				</select>
			</label>
			<ul style={{ marginTop: "20px", background: "#fff", borderRadius: "16px", border: "1px solid #eee", padding: "18px" }}>
				{blocks.map((block) => <li key={block.id}>{block.name} • {block.total_floors} floors</li>)}
			</ul>
		</div>
	);
}
