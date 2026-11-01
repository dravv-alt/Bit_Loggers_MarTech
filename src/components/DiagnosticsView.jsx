import React, { useState, useEffect } from 'react';
import { Terminal, Filter, RefreshCw, AlertCircle, CheckCircle, Info, ShieldAlert } from 'lucide-react';
import { api } from '../api.js';

export default function DiagnosticsView({ currentUser, showToast }) {
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [eventTypeFilter, setEventTypeFilter] = useState('');

  const fetchLogs = async () => {
    try {
      setLoading(true);
      const res = await api.getDiagnostics(currentUser, { event_type: eventTypeFilter || undefined });
      setLogs(res.logs || []);
    } catch (err) {
      showToast(err.message, 'error');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchLogs();
  }, [eventTypeFilter, currentUser?.id]);

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-4 p-4 glass-panel rounded-2xl border border-slate-800">
        <div>
          <div className="flex items-center gap-2">
            <Terminal className="w-5 h-5 text-cyan-400" />
            <h2 className="text-base font-extrabold text-slate-100 tracking-tight">
              Observability & Diagnostics Stream
            </h2>
          </div>
          <p className="text-xs text-slate-400 pt-0.5">
            LLD Section 13: Standard diagnostic vocabulary tracking all state mutations and failure boundaries.
          </p>
        </div>

        <div className="flex items-center gap-3">
          <select
            value={eventTypeFilter}
            onChange={(e) => setEventTypeFilter(e.target.value)}
            className="bg-slate-800 border border-slate-700 text-slate-200 text-xs rounded-xl px-3 py-1.5 focus:outline-none focus:border-cyan-500 font-mono"
          >
            <option value="">All Diagnostic Vocabulary</option>
            <option value="CAMPAIGN_SUBMITTED">CAMPAIGN_SUBMITTED</option>
            <option value="CAMPAIGN_APPROVED">CAMPAIGN_APPROVED</option>
            <option value="CHANGES_REQUESTED">CHANGES_REQUESTED</option>
            <option value="CAMPAIGN_REJECTED">CAMPAIGN_REJECTED</option>
            <option value="VERSION_CREATED">VERSION_CREATED</option>
            <option value="VERSION_CONFLICT">VERSION_CONFLICT</option>
            <option value="SCHEDULE_BLOCKED">SCHEDULE_BLOCKED</option>
            <option value="CAMPAIGN_SCHEDULED">CAMPAIGN_SCHEDULED</option>
            <option value="EDIT_LOCK_ACQUIRED">EDIT_LOCK_ACQUIRED</option>
            <option value="EDIT_LOCK_EXPIRED">EDIT_LOCK_EXPIRED</option>
            <option value="NOTIFICATION_RETRY">NOTIFICATION_RETRY</option>
            <option value="AI_REQUEST_FAILED">AI_REQUEST_FAILED</option>
          </select>

          <button
            onClick={fetchLogs}
            className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-400 hover:text-white transition-colors"
          >
            <RefreshCw className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* Logs Table */}
      <div className="glass-panel p-5 rounded-2xl border border-slate-800 font-mono text-xs">
        <div className="overflow-x-auto">
          <table className="w-full text-left">
            <thead className="bg-slate-900/80 border-b border-slate-800 text-[10px] uppercase font-bold text-slate-400">
              <tr>
                <th className="p-3">Time</th>
                <th className="p-3">Outcome</th>
                <th className="p-3">Event Type</th>
                <th className="p-3">Correlation ID</th>
                <th className="p-3">Diagnostic Message</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60 text-[11px]">
              {logs.length === 0 ? (
                <tr>
                  <td colSpan={5} className="p-6 text-center text-slate-500">
                    No diagnostic logs recorded yet.
                  </td>
                </tr>
              ) : (
                logs.map(log => (
                  <tr key={log.log_id} className="hover:bg-slate-800/40 transition-colors">
                    <td className="p-3 text-slate-400">
                      {new Date(log.timestamp).toLocaleTimeString()}
                    </td>
                    <td className="p-3">
                      <span className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                        log.outcome === 'SUCCESS' ? 'bg-emerald-500/20 text-emerald-300' :
                        log.outcome === 'FAILURE' ? 'bg-red-500/20 text-red-300' :
                        log.outcome === 'WARNING' ? 'bg-amber-500/20 text-amber-300' : 'bg-slate-800 text-slate-300'
                      }`}>
                        {log.outcome}
                      </span>
                    </td>
                    <td className="p-3 text-cyan-300 font-bold">
                      {log.event_type}
                    </td>
                    <td className="p-3 text-slate-400">
                      {log.correlation_id}
                    </td>
                    <td className="p-3 text-slate-300 font-sans max-w-md truncate" title={log.message}>
                      {log.message}
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

