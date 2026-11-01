import React, { useState, useEffect } from 'react';
import { GitBranch, Search, Filter, ShieldCheck, RefreshCw } from 'lucide-react';
import { api } from '../api.js';

export default function AuditTrailView({ currentUser, onSelectCampaign, showToast }) {
  const [auditList, setAuditList] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');

  const fetchAudit = async () => {
    try {
      setLoading(true);
      const res = await api.getAudit(null, currentUser);
      setAuditList(res.audit || []);
    } catch (err) {
      showToast(err.message, 'error');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAudit();
  }, [currentUser?.id]);

  const filtered = auditList.filter(item => {
    return (
      item.event_type?.toLowerCase().includes(search.toLowerCase()) ||
      item.actor_name?.toLowerCase().includes(search.toLowerCase()) ||
      item.campaign_id?.toLowerCase().includes(search.toLowerCase()) ||
      item.details?.toLowerCase().includes(search.toLowerCase())
    );
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-4 p-4 glass-panel rounded-2xl border border-slate-800">
        <div>
          <div className="flex items-center gap-2">
            <GitBranch className="w-5 h-5 text-cyan-400" />
            <h2 className="text-base font-extrabold text-slate-100 tracking-tight">
              Pillar 3: Immutable Append-Only Audit Trail
            </h2>
          </div>
          <p className="text-xs text-slate-400 pt-0.5">
            Tamper-resistant audit registry recording every state transition, actor ID, and correlation token.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <div className="relative">
            <Search className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-2.5" />
            <input
              type="text"
              placeholder="Search audit trail..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="pl-8 pr-3 py-1.5 bg-slate-800 border border-slate-700 rounded-xl text-xs text-slate-200 placeholder:text-slate-500 focus:outline-none focus:border-cyan-500"
            />
          </div>

          <button
            onClick={fetchAudit}
            className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-400 hover:text-white transition-colors"
          >
            <RefreshCw className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* Table */}
      <div className="glass-panel p-5 rounded-2xl border border-slate-800">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs font-mono">
            <thead className="bg-slate-900/80 border-b border-slate-800 text-[10px] uppercase font-bold text-slate-400">
              <tr>
                <th className="p-3">Timestamp</th>
                <th className="p-3">Event</th>
                <th className="p-3">Actor</th>
                <th className="p-3">Campaign</th>
                <th className="p-3">Transition</th>
                <th className="p-3">Details</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60 text-[11px]">
              {filtered.length === 0 ? (
                <tr>
                  <td colSpan={6} className="p-6 text-center text-slate-500">
                    No audit events recorded matching your query.
                  </td>
                </tr>
              ) : (
                filtered.map(evt => (
                  <tr key={evt.event_id} className="hover:bg-slate-800/40 transition-colors">
                    <td className="p-3 text-slate-400">
                      {new Date(evt.occurred_at).toLocaleTimeString()}
                    </td>
                    <td className="p-3">
                      <span className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                        evt.event_type.includes('APPROVED') ? 'bg-emerald-500/20 text-emerald-300' :
                        evt.event_type.includes('SCHEDULED') ? 'bg-purple-500/20 text-purple-300' :
                        evt.event_type.includes('SUBMITTED') ? 'bg-cyan-500/20 text-cyan-300' : 'bg-slate-800 text-slate-300'
                      }`}>
                        {evt.event_type}
                      </span>
                    </td>
                    <td className="p-3 text-slate-300">
                      {evt.actor_name || evt.actor_id}
                    </td>
                    <td className="p-3">
                      <button
                        onClick={() => evt.campaign_id && onSelectCampaign(evt.campaign_id)}
                        className="text-cyan-400 hover:underline"
                      >
                        {evt.campaign_id || 'N/A'}
                      </button>
                    </td>
                    <td className="p-3 text-slate-400">
                      {evt.previous_state || '—'} → <strong className="text-slate-200">{evt.new_state || '—'}</strong>
                    </td>
                    <td className="p-3 text-slate-300 max-w-sm truncate font-sans" title={evt.details}>
                      {evt.details}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
