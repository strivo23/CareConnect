import React, { useState, useEffect } from 'react';
import {
  MdRssFeed,
  MdSend,
  MdAttachFile,
  MdLocationOn,
  MdWarning,
  MdSearch,
  MdShield,
  MdPerson,
  MdCheckCircle,
  MdLock,
  MdLocalHospital,
  MdDirectionsRun
} from 'react-icons/md';
import { sosService } from '../services/api';

export default function ResponseUpdatesPanel({ incident }) {
  const [updates, setUpdates] = useState([]);
  const [message, setMessage] = useState('');
  const [updateType, setUpdateType] = useState('NOTE');
  const [typeFilter, setTypeFilter] = useState('ALL');
  const [searchQuery, setSearchQuery] = useState('');
  const [loading, setLoading] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  const isClosed = ['CLOSED', 'Closed'].includes(incident?.current_status || incident?.status);

  useEffect(() => {
    if (incident?.id) {
      fetchUpdates();
    }
  }, [incident?.id, typeFilter]);

  const fetchUpdates = async () => {
    setLoading(true);
    try {
      const params = {};
      if (typeFilter !== 'ALL') params.update_type = typeFilter;
      if (searchQuery) params.search = searchQuery;

      const res = await sosService.getResponseUpdates(incident.id, params);
      const data = res.data?.results || res.data || [];
      setUpdates(data);
    } catch (err) {
      console.error('Error fetching response updates:', err);
    } finally {
      setLoading(false);
    }
  };

  const handlePostUpdate = async (e) => {
    e.preventDefault();
    if (!message.trim() || isClosed) return;

    setSubmitting(true);
    try {
      await sosService.createResponseUpdate(incident.id, {
        message,
        update_type: updateType,
        visibility: 'PUBLIC'
      });
      setMessage('');
      fetchUpdates();
    } catch (err) {
      alert(err.response?.data?.error || 'Failed to post response update.');
    } finally {
      setSubmitting(false);
    }
  };

  const getTypeBadge = (type) => {
    switch (type) {
      case 'ARRIVAL':
        return <span className="bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 px-2 py-0.5 rounded text-xs font-bold flex items-center gap-1"><MdDirectionsRun className="w-3.5 h-3.5" /> ARRIVAL</span>;
      case 'MEDICAL':
        return <span className="bg-red-500/20 text-red-400 border border-red-500/30 px-2 py-0.5 rounded text-xs font-bold flex items-center gap-1"><MdLocalHospital className="w-3.5 h-3.5" /> MEDICAL</span>;
      case 'SECURITY':
        return <span className="bg-purple-500/20 text-purple-400 border border-purple-500/30 px-2 py-0.5 rounded text-xs font-bold flex items-center gap-1"><MdShield className="w-3.5 h-3.5" /> SECURITY</span>;
      case 'STATUS':
        return <span className="bg-blue-500/20 text-blue-400 border border-blue-500/30 px-2 py-0.5 rounded text-xs font-bold flex items-center gap-1"><MdCheckCircle className="w-3.5 h-3.5" /> STATUS</span>;
      case 'SYSTEM':
        return <span className="bg-amber-500/20 text-amber-400 border border-amber-500/30 px-2 py-0.5 rounded text-xs font-bold flex items-center gap-1"><MdWarning className="w-3.5 h-3.5" /> SYSTEM</span>;
      default:
        return <span className="bg-slate-500/20 text-slate-300 border border-slate-500/30 px-2 py-0.5 rounded text-xs font-bold">NOTE</span>;
    }
  };

  const filteredUpdates = searchQuery
    ? updates.filter((u) => u.message?.toLowerCase().includes(searchQuery.toLowerCase()))
    : updates;

  return (
    <div className="bg-slate-900 border border-slate-800 rounded-xl p-4 mt-4 shadow-lg text-white">
      {/* Header */}
      <div className="flex items-center justify-between border-b border-slate-800 pb-3 mb-4">
        <div className="flex items-center space-x-2">
          <MdRssFeed className="w-5 h-5 text-red-500" />
          <h4 className="font-bold text-base">Incident Response Feed</h4>
          <span className="bg-slate-800 text-slate-300 text-xs px-2 py-0.5 rounded-full font-semibold">
            {updates.length} Updates
          </span>
        </div>

        {/* Filter Pills */}
        <div className="flex items-center space-x-1.5 overflow-x-auto text-xs">
          {['ALL', 'ARRIVAL', 'SECURITY', 'MEDICAL', 'NOTE', 'STATUS'].map((type) => (
            <button
              key={type}
              onClick={() => setTypeFilter(type)}
              className={`px-2.5 py-1 rounded-md font-semibold transition-all ${
                typeFilter === type
                  ? 'bg-red-600 text-white'
                  : 'bg-slate-800 text-slate-400 hover:text-white'
              }`}
            >
              {type}
            </button>
          ))}
        </div>
      </div>

      {/* Updates Stream */}
      <div className="max-h-72 overflow-y-auto space-y-3 pr-1">
        {loading ? (
          <div className="text-center py-6 text-slate-400 text-xs">Loading response updates...</div>
        ) : filteredUpdates.length === 0 ? (
          <div className="text-center py-6 text-slate-500 text-xs">No response updates posted yet.</div>
        ) : (
          filteredUpdates.map((item) => (
            <div key={item.id} className="bg-slate-850 border border-slate-800 rounded-lg p-3 relative hover:border-slate-700 transition-all">
              <div className="flex items-center justify-between mb-1.5">
                <div className="flex items-center space-x-2">
                  {getTypeBadge(item.update_type)}
                  <span className="text-xs font-bold text-slate-200">{item.author_name}</span>
                  <span className="text-[10px] uppercase font-extrabold px-1.5 py-0.2 rounded bg-slate-800 text-slate-400">
                    {item.role}
                  </span>
                </div>
                <span className="text-[10px] text-slate-500">
                  {new Date(item.created_at).toLocaleString()}
                </span>
              </div>

              <p className="text-xs text-slate-300 whitespace-pre-wrap">{item.message}</p>

              {item.latitude && item.longitude && (
                <a
                  href={`https://maps.google.com/?q=${item.latitude},${item.longitude}`}
                  target="_blank"
                  rel="noreferrer"
                  className="mt-2 inline-flex items-center gap-1 text-[11px] font-semibold text-amber-400 underline"
                >
                  <MdLocationOn className="w-3.5 h-3.5" /> View GPS Location ({item.latitude}, {item.longitude})
                </a>
              )}

              {item.attachment && (
                <div className="mt-2">
                  <a href={item.attachment} target="_blank" rel="noreferrer" className="inline-flex items-center gap-1 text-xs text-blue-400 underline">
                    <MdAttachFile className="w-3.5 h-3.5" /> Attachment Link
                  </a>
                </div>
              )}
            </div>
          ))
        )}
      </div>

      {/* Post Update Form */}
      {isClosed ? (
        <div className="mt-4 p-3 bg-slate-800/80 rounded-lg text-center text-xs font-semibold text-slate-400 flex items-center justify-center gap-2">
          <MdLock className="w-4 h-4 text-slate-500" /> Incident is Closed. Response feed is read-only.
        </div>
      ) : (
        <form onSubmit={handlePostUpdate} className="mt-4 pt-3 border-t border-slate-800 flex items-center space-x-2">
          <select
            value={updateType}
            onChange={(e) => setUpdateType(e.target.value)}
            className="bg-slate-800 border border-slate-700 text-xs rounded-lg px-2.5 py-2 text-white focus:outline-none focus:ring-1 focus:ring-red-500"
          >
            <option value="NOTE">NOTE</option>
            <option value="ARRIVAL">ARRIVAL</option>
            <option value="SECURITY">SECURITY</option>
            <option value="MEDICAL">MEDICAL</option>
            <option value="STATUS">STATUS</option>
          </select>

          <input
            type="text"
            placeholder="Post response update / coordination note..."
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            className="flex-1 bg-slate-800 border border-slate-700 text-xs rounded-lg px-3 py-2 text-white focus:outline-none focus:ring-1 focus:ring-red-500"
          />

          <button
            type="submit"
            disabled={!message.trim() || submitting}
            className="bg-red-600 hover:bg-red-700 disabled:opacity-50 text-white text-xs font-bold px-3 py-2 rounded-lg flex items-center gap-1 transition-all"
          >
            <MdSend className="w-3.5 h-3.5" /> Post
          </button>
        </form>
      )}
    </div>
  );
}
