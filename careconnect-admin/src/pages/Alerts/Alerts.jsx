import { useEffect, useState } from "react";

import { getContacts, getResidents, verifyContact } from "../../services/api";

export default function Alerts() {
	const [pendingResidents, setPendingResidents] = useState([]);
	const [unverifiedContacts, setUnverifiedContacts] = useState([]);

	const loadAlerts = async () => {
		const [residents, contacts] = await Promise.all([getResidents(), getContacts()]);
		setPendingResidents(residents.filter((resident) => (resident.status || "").toLowerCase() !== "approved"));
		setUnverifiedContacts(contacts.filter((contact) => !contact.verified));
	};

	useEffect(() => {
		loadAlerts().catch(() => {
			setPendingResidents([]);
			setUnverifiedContacts([]);
		});
	}, []);

	const handleVerify = async (id) => {
		await verifyContact(id);
		await loadAlerts();
	};

	return (
		<div>
			<h1>Alerts</h1>
			<section style={{ marginTop: "20px" }}>
				<h2>Pending resident approvals</h2>
				{pendingResidents.length === 0 ? <p>No resident approvals pending.</p> : null}
				{pendingResidents.map((resident) => (
					<div key={resident.id} style={{ background: "#fff", border: "1px solid #eee", borderRadius: "14px", padding: "16px", marginBottom: "12px" }}>
						<strong>{resident.user?.full_name || resident.user?.email || `Resident ${resident.id}`}</strong>
						<div>Status: {resident.status}</div>
					</div>
				))}
			</section>

			<section style={{ marginTop: "24px" }}>
				<h2>Unverified emergency contacts</h2>
				{unverifiedContacts.length === 0 ? <p>No unverified contacts remaining.</p> : null}
				{unverifiedContacts.map((contact) => (
					<div key={contact.id} style={{ background: "#fff", border: "1px solid #eee", borderRadius: "14px", padding: "16px", marginBottom: "12px", display: "flex", justifyContent: "space-between", gap: "12px", alignItems: "center" }}>
						<div>
							<strong>{contact.name}</strong>
							<div>{contact.phone} • {contact.relationship_name || "Unknown relationship"}</div>
						</div>
						<button type="button" onClick={() => handleVerify(contact.id)} style={{ border: "none", borderRadius: "8px", padding: "8px 12px", background: "#ff7a00", color: "#fff" }}>
							Verify
						</button>
					</div>
				))}
			</section>
		</div>
	);
}
