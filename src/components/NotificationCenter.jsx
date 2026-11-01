import React, { useState, useEffect } from 'react';
import { 
  Bell, 
  CheckCheck, 
  Mail, 
  Smartphone, 
  ExternalLink, 
  Clock, 
  ShieldAlert, 
  RefreshCw,
  Send
} from 'lucide-react';
import { api } from '../api.js';

export default function NotificationCenter({ currentUser, onSelectCampaign, showToast, onRefreshHeader }) {
  const [notifications, setNotifications] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('all'); // 'all' | 'unread'

  const fetchNotifications = async () => {
    try {
      setLoading(true);
      const res = await api.getNotifications(currentUser);
      setNotifications(res.notifications || []);
      if (onRefreshHeader) onRefreshHeader();
    } catch (err) {
      showToast(err.message, 'error');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchNotifications();
  }, [currentUser?.id]);

  const handleMarkAllRead = async () => {
    try {
      await api.markAllNotificationsRead(currentUser);
      showToast('All notifications marked as read.', 'success');
      fetchNotifications();
    } catch (err) {
      showToast(err.message, 'error');
    }
  };

  const handleMarkRead = async (id) => {
    try {
      await api.markNotificationRead(id, currentUser);
      fetchNotifications();
    } catch (err) {
      showToast(err.message, 'error');
    }
  };

  const filtered = notifications.filter(n => {
    if (filter === 'unread') return n.is_read === 0;
    return true;
  });

  return (
    <div className="space-y-6">
      {/* Top Header */}
      <div className="flex flex-wrap items-center justify-between gap-4 p-4 glass-panel rounded-2xl border border-slate-800">
        <div>
          <div className="flex items-center gap-2">
            <Bell className="w-5 h-5 text-cyan-400" />
            <h2 className="text-base font-extrabold text-slate-100 tracking-tight">
              Pillar 4: Multi-Channel Alerts & Notification Center
            </h2>
          </div>
          <p className="text-xs text-slate-400 pt-0.5">
            Durable notifications dispatched from Transactional Outbox (In-App, Push, Email).
          </p>
        </div>

        <div className="flex items-center gap-3">
          <div className="flex rounded-xl bg-slate-800 p-0.5 border border-slate-700 text-xs">
            <button
              onClick={() => setFilter('all')}
              className={`px-3 py-1 rounded-lg font-semibold transition-colors ${
                filter === 'all' ? 'bg-cyan-500 text-slate-950' : 'text-slate-400 hover:text-white'
              }`}
            >
              All Alerts
            </button>
            <button
              onClick={() => setFilter('unread')}
              className={`px-3 py-1 rounded-lg font-semibold transition-colors ${
                filter === 'unread' ? 'bg-cyan-500 text-slate-950' : 'text-slate-400 hover:text-white'
              }`}
            >
              Unread Only
            </button>
          </div>

          <button
            onClick={handleMarkAllRead}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold border border-slate-700 transition-colors"
          >
            <CheckCheck className="w-3.5 h-3.5 text-cyan-400" />
            <span>Mark All Read</span>
          </button>
        </div>
      </div>

      {/* Notifications List */}
      <div className="space-y-2.5">
        {loading ? (
          <div className="text-center py-12 text-xs text-cyan-400">Loading notifications...</div>
        ) : filtered.length === 0 ? (
          <div className="p-12 text-center glass-panel rounded-2xl border border-slate-800 text-xs text-slate-400 space-y-2">
            <Bell className="w-8 h-8 text-slate-600 mx-auto" />
            <p>No notifications match your current filter.</p>
          </div>
        ) : (
          filtered.map(notif => (
            <div
              key={notif.notification_id}
              onClick={() => {
                if (notif.campaign_id) onSelectCampaign(notif.campaign_id);
                if (!notif.is_read) handleMarkRead(notif.notification_id);
              }}
              className={`p-4 rounded-xl border transition-all cursor-pointer flex items-start justify-between gap-4 ${
                notif.is_read 
                  ? 'glass-card border-slate-800 opacity-80 hover:opacity-100' 
                  : 'glass-panel border-cyan-500/40 shadow-lg shadow-cyan-500/5 ring-1 ring-cyan-500/20'
              }`}
            >
              <div className="space-y-1">
                <div className="flex items-center gap-2">
                  <span className={`px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider ${
                    notif.channel === 'email' ? 'bg-blue-500/20 text-blue-300' :
                    notif.channel === 'push' ? 'bg-purple-500/20 text-purple-300' : 'bg-cyan-500/20 text-cyan-300'
                  }`}>
                    {notif.channel}
                  </span>

                  <span className={`px-1.5 py-0.5 rounded text-[10px] uppercase font-bold ${
                    notif.priority === 'high' ? 'bg-red-500/20 text-red-300' : 'bg-slate-800 text-slate-400'
                  }`}>
                    {notif.priority}
                  </span>

                  <span className="text-[11px] text-slate-500">
                    {new Date(notif.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                  </span>
                </div>

                <h4 className="font-bold text-xs text-slate-100 hover:text-cyan-400 transition-colors">
                  {notif.title}
                </h4>

                <p className="text-xs text-slate-300 leading-relaxed">
                  {notif.message}
                </p>
              </div>

              <div className="flex items-center gap-2 shrink-0">
                {!notif.is_read && (
                  <span className="w-2.5 h-2.5 rounded-full bg-cyan-400"></span>
                )}
                {notif.campaign_id && (
                  <ExternalLink className="w-4 h-4 text-slate-500 hover:text-cyan-400 transition-colors" />
                )}
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

