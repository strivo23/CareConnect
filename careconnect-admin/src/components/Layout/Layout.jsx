import Sidebar from "../Sidebar/Sidebar";
import Navbar from "../Navbar/Navbar";

export default function Layout({ children }) {
  return (
    <div style={{ display: "flex" }}>
      <Sidebar />

      <div style={{ flex: 1 }}>
        <Navbar />

        <div style={{ padding: "20px" }}>
          {children}
        </div>
      </div>
    </div>
  );
}