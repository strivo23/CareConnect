import { useEffect, useState } from "react";

import { approveResident, getResidents, rejectResident } from "../../services/api";

export default function Residents() {
	const [residents, setResidents] = useState([]);

	const loadResidents = async () => {
		const data = await getResidents();
		setResidents(data);
	};

	useEffect(() => {
		loadResidents().catch(() => setResidents([]));
	}, []);

	const handleAction = async (action, id) => {
		await action(id);
		await loadResidents();
	};

	return (
		<div>
			<h1>Residents</h1>
			<table style={{ width: "100%", borderCollapse: "collapse", marginTop: "16px", background: "#fff" }}>
				<thead>
					<tr>
						<th style={{ textAlign: "left", padding: "12px", borderBottom: "1px solid #eee" }}>Resident</th>
						<th style={{ textAlign: "left", padding: "12px", borderBottom: "1px solid #eee" }}>Society</th>
						<th style={{ textAlign: "left", padding: "12px", borderBottom: "1px solid #eee" }}>Status</th>
						<th style={{ textAlign: "left", padding: "12px", borderBottom: "1px solid #eee" }}>Actions</th>
					</tr>
				</thead>
				<tbody>
					{residents.map((resident) => (
						<tr key={resident.id}>
							<td style={{ padding: "12px", borderBottom: "1px solid #f3f3f3" }}>{resident.user?.full_name || resident.user?.email || `Resident ${resident.id}`}</td>
							<td style={{ padding: "12px", borderBottom: "1px solid #f3f3f3" }}>{resident.society_name || "-"}</td>
							<td style={{ padding: "12px", borderBottom: "1px solid #f3f3f3" }}>{resident.status}</td>
							<td style={{ padding: "12px", borderBottom: "1px solid #f3f3f3", display: "flex", gap: "8px" }}>
								<button type="button" onClick={() => handleAction(approveResident, resident.id)} style={{ border: "none", borderRadius: "8px", padding: "8px 12px", background: "#27ae60", color: "#fff" }}>Approve</button>
								<button type="button" onClick={() => handleAction(rejectResident, resident.id)} style={{ border: "none", borderRadius: "8px", padding: "8px 12px", background: "#e74c3c", color: "#fff" }}>Reject</button>
							</td>
						</tr>
					))}
				</tbody>
			</table>
		</div>
	);
}
