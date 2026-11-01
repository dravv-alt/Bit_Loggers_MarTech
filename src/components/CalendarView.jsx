import React, { useState, useEffect } from 'react';
import { 
  Calendar as CalendarIcon, 
  Clock, 
  AlertTriangle, 
  CheckCircle2, 
  Layers, 
  ChevronLeft, 
  ChevronRight,
  Filter
} from 'lucide-react';
import { api } from '../api.js';

const CHANNEL_COLORS = {
  Social: 'bg-pink-500/20 text-pink-300 border-pink-500/40',
  Email: 'bg-blue-500/20 text-blue-300 border-blue-500/40',
  Search: 'bg-amber-500/20 text-amber-300 border-amber-500/40',
  Display: 'bg-purple-500/20 text-purple-300 border-purple-500/40',
  Influencer: 'bg-emerald-500/20 text-emerald-300 border-emerald-500/40',
  Video: 'bg-red-500/20 text-red-300 border-red-500/40'
};

export default function CalendarView({ currentUser, onSelectCampaign, showToast }) {
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedChannel, setSelectedChannel] = useState('All');

  const fetchCalendar = async () => {
    try {
      setLoading(true);
      const res = await api.getCalendar(currentUser);
      setEvents(res.events || []);
    } catch (err) {
      showToast(err.message, 'error');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchCalendar();
  }, [currentUser?.id]);

  const filteredEvents = events.filter(e => {
    return selectedChannel === 'All' || e.channel === selectedChannel;
  });

  return (
    <div className="space-y-6">
      {/* Calendar Header Bar */}
      <div className="flex flex-wrap items-center justify-between gap-4 p-4 glass-panel rounded-2xl border border-slate-800">
        <div>
          <div className="flex items-center gap-2">
            <CalendarIcon className="w-5 h-5 text-cyan-400" />
            <h2 className="text-base font-extrabold text-slate-100 tracking-tight">
              Internal Marketing Calendar & Flight Schedule
            </h2>
          </div>
          <p className="text-xs text-slate-400 pt-0.5">
            Pillar 3 Governance: Real-time collision detection prevents overlapping campaign flights on identical channels.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <Filter className="w-3.5 h-3.5 text-slate-400" />
          <select
            value={selectedChannel}
            onChange={(e) => setSelectedChannel(e.target.value)}
            className="bg-slate-800 border border-slate-700 text-slate-200 text-xs rounded-xl px-3 py-1.5 focus:outline-none focus:border-cyan-500"
          >
            <option value="All">All Channels</option>
            <option value="Social">Social</option>
            <option value="Email">Email</option>
            <option value="Search">Search</option>
            <option value="Display">Display</option>
            <option value="Influencer">Influencer</option>
            <option value="Video">Video</option>
          </select>
        </div>
      </div>

      {/* Flight Schedule Timeline List */}
      <div className="space-y-3">
        {loading ? (
          <div className="text-center py-12 text-xs text-cyan-400">Loading flight calendar...</div>
        ) : filteredEvents.length === 0 ? (
          <div className="p-12 text-center glass-panel rounded-2xl border border-slate-800 text-xs text-slate-400 space-y-2">
            <CalendarIcon className="w-8 h-8 text-slate-600 mx-auto" />
            <p>No active scheduled campaign flights in this channel filter.</p>
            <p className="text-[11px] text-slate-500">Only approved campaigns can be scheduled by marketers.</p>
          </div>
        ) : (
          filteredEvents.map(evt => {
            const start = new Date(evt.starts_at);
            const end = new Date(evt.ends_at);
            const daysDuration = Math.max(1, Math.round((end - start) / (1000 * 60 * 60 * 24)));

            return (
              <div 
                key={evt.schedule_id}
                onClick={() => onSelectCampaign(evt.campaign_id)}
                className="glass-card p-4 rounded-xl border border-slate-800 hover:border-cyan-500/40 cursor-pointer transition-all flex flex-col sm:flex-row sm:items-center justify-between gap-4"
              >
                <div className="space-y-1.5">
                  <div className="flex items-center gap-2">
                    <span className={`px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider border ${CHANNEL_COLORS[evt.channel] || 'bg-slate-800 text-slate-300'}`}>
                      {evt.channel}
                    </span>
                    <span className="px-1.5 py-0.5 rounded text-[10px] font-mono bg-slate-800 text-cyan-300 border border-slate-700">
                      v{evt.version_no}
                    </span>
                    <span className="text-[11px] font-semibold text-emerald-400">
                      • {evt.status}
                    </span>
                  </div>

                  <h3 className="font-extrabold text-sm text-slate-100 hover:text-cyan-400 transition-colors">
                    {evt.title}
                  </h3>

                  <div className="text-xs text-slate-400 flex items-center gap-2">
                    <span>Flight Window: <strong className="text-slate-200">{start.toLocaleDateString()}</strong> to <strong className="text-slate-200">{end.toLocaleDateString()}</strong> ({daysDuration} days)</span>
                  </div>
                </div>

                <div className="flex sm:flex-col items-center sm:items-end justify-between border-t sm:border-t-0 pt-2 sm:pt-0 border-slate-800 text-xs font-mono">
                  <div className="text-slate-400">Budget Flight</div>
                  <div className="text-base font-bold text-emerald-400">
                    ${(evt.budget || 0).toLocaleString()}
                  </div>
                </div>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
}

