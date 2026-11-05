import React, { useState, useEffect } from 'react';
import { 
  Send, 
  RotateCcw, 
  AlertTriangle, 
  CheckCircle, 
  Clock, 
  Mail, 
  ShieldCheck, 
  RefreshCw 
} from 'lucide-react';
import { api } from '../api.js';

export default function OutboxMonitor({ currentUser, showToast }) {
  const [events, setEvents] = useState([]);
  const [isEmailFailing, setIsEmailFailing] = useState(false);
  const [loading, setLoading] = useState(true);
  const [processing, setProcessing] = useState(false);

  const fetchOutbox = async () => {
    try {
      setLoading(true);
      const res = await api.getOutbox(currentUser);
      setEvents(res.events || []);
      setIsEmailFailing(Boolean(res.isEmailServiceFailing));
    } catch (err) {
      showToast(err.message, 'error');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchOutbox();
    const interval = setInterval(fetchOutbox, 4000);
    return () => clearInterval(interval);
  }, [currentUser?.id]);

  const handleToggleEmailFailure = async () => {
    try {
      const res = await api.toggleEmailFailure(!isEmailFailing, currentUser);
      setIsEmailFailing(res.isEmailServiceFailing);
      showToast(`Email simulation outage: ${res.isEmailServiceFailing ? 'ON (Failing)' : 'OFF (Healthy)'}`, 'info');
      fetchOutbox();
    } catch (err) {
      showToast(err.message, 'error');
    }
  };

  const handleProcessNow = async () => {
    setProcessing(true);
    try {
      const res = await api.processOutbox(currentUser);
      showToast(`Outbox sweep completed: ${res.processed?.length || 0} events dispatched.`, 'success');
      fetchOutbox();
    } catch (err) {
      showToast(err.message, 'error');
    } finally {
      setProcessing(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-4 p-4 glass-panel rounded-2xl border border-slate-800">
        <div>
          <div className="flex items-center gap-2">
            <Send className="w-5 h-5 text-cyan-400" />
            <h2 className="text-base font-extrabold text-slate-100 tracking-tight">
              Transactional Outbox Engine & Resilience Worker
            </h2>
          </div>
          <p className="text-xs text-slate-400 pt-0.5">
            LLD Section 10: Decisions commit atomically with outbox events. Delivery is handled with duplicate-safe retry.
          </p>
        </div>

        <div className="flex items-center gap-3">
          {/* Email Outage Simulation Toggle (T-12) */}
          <button
            onClick={handleToggleEmailFailure}
            className={`flex items-center gap-2 px-3 py-1.5 rounded-xl text-xs font-semibold transition-colors border focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-red-400 active:opacity-90 disabled:opacity-50 ${
              isEmailFailing 
                ? 'bg-red-500/20 text-red-300 border-red-500/40 motion-safe:animate-pulse' 
                : 'bg-slate-800 text-slate-300 hover:bg-slate-700 border-slate-700'
            }`}
          >
            <Mail className="w-3.5 h-3.5" />
            <span>Simulate email outage: {isEmailFailing ? 'Active' : 'Off'}</span>
          </button>

          <button
            onClick={handleProcessNow}
            disabled={processing}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-cyan-500 hover:bg-cyan-400 text-slate-950 text-xs font-semibold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan-300 active:opacity-90 disabled:opacity-50 shadow-md shadow-cyan-500/20"
          >
            <RotateCcw className={`w-3.5 h-3.5 ${processing ? 'animate-spin' : ''}`} />
            <span>Trigger outbox sweep</span>
          </button>
        </div>
      </div>

      {/* Events Table */}
      <div className="glass-panel p-5 rounded-2xl border border-slate-800 space-y-3">
        <h3 className="text-xs font-semibold text-slate-400">
          Pending and dispatched outbox messages ({events.length})
        </h3>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-900/80 border-b border-slate-800 text-xs font-semibold text-slate-400">
              <tr>
                <th className="p-3">Event ID</th>
                <th className="p-3">Type</th>
                <th className="p-3">Status</th>
                <th className="p-3">Attempts</th>
                <th className="p-3">Error / Backoff</th>
                <th className="p-3 text-right">Available At</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60 text-xs">
              {events.length === 0 ? (
                <tr>
                  <td colSpan={6} className="p-6 text-center text-slate-500">
                    Outbox is empty. All messages processed.
                  </td>
                </tr>
              ) : (
                events.map(evt => (
                  <tr key={evt.event_id} className="hover:bg-slate-800/40 transition-colors">
                    <td className="p-3 font-mono font-bold text-slate-300">
                      {evt.event_id}
                    </td>
                    <td className="p-3 text-cyan-400">
                      {evt.event_type}
                    </td>
                    <td className="p-3">
                      <span className={`px-2 py-0.5 rounded text-[10px] font-semibold ${
                        evt.status === 'PROCESSED' ? 'bg-emerald-500/20 text-emerald-300' :
                        evt.status === 'FAILED' ? 'bg-red-500/20 text-red-300' : 'bg-amber-500/20 text-amber-300'
                      }`}>
                        {evt.status}
                      </span>
                    </td>
                    <td className="p-3 text-slate-300">
                      {evt.attempts} / 3
                    </td>
                    <td className="p-3 text-red-400 truncate max-w-xs" title={evt.last_error}>
                      {evt.last_error || 'None (Normal delivery)'}
                    </td>
                    <td className="p-3 text-right text-slate-400">
                      {new Date(evt.available_at).toLocaleTimeString()}
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

