import React, { useState } from 'react';
import { 
  Sparkles, 
  Bell, 
  Smartphone, 
  Monitor, 
  UserCheck, 
  AlertTriangle, 
  PlusCircle, 
  ShieldCheck, 
  RefreshCw,
  Mail,
  Cpu
} from 'lucide-react';

export default function Header({ 
  users = [], 
  currentUser, 
  onSwitchUser, 
  isMobileView, 
  setIsMobileView, 
  notifications = [], 
  unreadCount = 0, 
  onOpenNotifications, 
  onNewCampaign,
  isEmailFailing,
  isGeminiFailing,
  onToggleEmailFailure,
  onToggleGeminiFailure,
  onOpenTests
}) {
  const [showSimMenu, setShowSimMenu] = useState(false);

  return (
    <header className="glass-panel sticky top-0 z-40 px-4 py-3 border-b border-slate-800/80">
      <div className="max-w-7xl mx-auto flex items-center justify-between gap-2 sm:gap-4">
        {/* Logo and Brand */}
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-cyan-500 to-blue-600 flex items-center justify-center shadow-lg shadow-cyan-500/20 text-white font-black text-xl tracking-tighter">
            ⚡
          </div>
          <div>
            <div className="flex items-center gap-2">
              <span className="font-extrabold text-base sm:text-lg tracking-tight bg-gradient-to-r from-white via-slate-100 to-slate-400 bg-clip-text text-transparent">
                Bit Loggers
              </span>
              <span className="hidden sm:inline-block px-2 py-0.5 text-[10px] font-semibold bg-cyan-500/10 text-cyan-400 border border-cyan-500/20 rounded-full uppercase tracking-wider">
                MarTech Platform
              </span>
            </div>
            <p className="text-[11px] text-slate-400 hidden sm:block">
              Intelligent, Auditable & Version-Aware Campaign Platform
            </p>
          </div>
        </div>

        {/* Center / Action Toolbar */}
        <div className="flex items-center gap-2">
          {/* Mobile Viewport Toggle */}
          <button
            onClick={() => setIsMobileView(!isMobileView)}
            title={isMobileView ? "Switch to Desktop Responsive View" : "Simulate Mobile Device View"}
            className={`flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs font-medium transition-all ${
              isMobileView 
                ? 'bg-cyan-500/20 text-cyan-300 border border-cyan-500/40 shadow-sm shadow-cyan-500/20' 
                : 'bg-slate-800/80 text-slate-300 hover:bg-slate-700 border border-slate-700'
            }`}
          >
            {isMobileView ? <Smartphone className="w-3.5 h-3.5" /> : <Monitor className="w-3.5 h-3.5" />}
            <span className="hidden md:inline">{isMobileView ? 'Mobile Frame' : 'Desktop View'}</span>
          </button>

          {/* Architecture QA Tests Button */}
          <button
            onClick={onOpenTests}
            className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs font-semibold bg-emerald-500/15 text-emerald-400 border border-emerald-500/30 hover:bg-emerald-500/25 transition-all"
            title="View & Run All 14 LLD Automated Architecture Tests (T-01 to T-14)"
          >
            <ShieldCheck className="w-3.5 h-3.5 text-emerald-400" />
            <span className="hidden md:inline">14/14 Tests</span>
          </button>

          {/* Fault Simulation Menu Toggle */}
          <div className="relative">
            <button
              onClick={() => setShowSimMenu(!showSimMenu)}
              className={`p-1.5 rounded-lg text-xs font-medium border transition-all flex items-center gap-1 ${
                isEmailFailing || isGeminiFailing 
                  ? 'bg-amber-500/20 text-amber-300 border-amber-500/40 animate-pulse' 
                  : 'bg-slate-800/80 text-slate-400 hover:text-slate-200 border-slate-700'
              }`}
              title="Resilience & Fault Injections (T-12, T-13)"
            >
              <AlertTriangle className="w-3.5 h-3.5" />
              {(isEmailFailing || isGeminiFailing) && <span className="w-1.5 h-1.5 rounded-full bg-amber-400"></span>}
            </button>

            {showSimMenu && (
              <div className="absolute right-0 mt-2 w-64 glass-panel rounded-xl shadow-2xl p-3 border border-slate-700/80 z-50 animate-in fade-in zoom-in-95">
                <div className="text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-2">
                  Fault Injection & Recovery
                </div>
                
                {/* Email Service Failure Toggle (T-12) */}
                <button
                  onClick={onToggleEmailFailure}
                  className={`w-full flex items-center justify-between p-2 rounded-lg text-xs font-medium transition-colors mb-1.5 ${
                    isEmailFailing ? 'bg-red-500/20 text-red-300 border border-red-500/30' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'
                  }`}
                >
                  <span className="flex items-center gap-2">
                    <Mail className="w-3.5 h-3.5" />
                    Simulate Email Outage
                  </span>
                  <span className={`px-1.5 py-0.5 rounded text-[10px] uppercase font-bold ${isEmailFailing ? 'bg-red-500 text-white' : 'bg-slate-700 text-slate-400'}`}>
                    {isEmailFailing ? 'FAILING' : 'HEALTHY'}
                  </span>
                </button>

                {/* Gemini Failure Toggle (T-13) */}
                <button
                  onClick={onToggleGeminiFailure}
                  className={`w-full flex items-center justify-between p-2 rounded-lg text-xs font-medium transition-colors ${
                    isGeminiFailing ? 'bg-red-500/20 text-red-300 border border-red-500/30' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'
                  }`}
                >
                  <span className="flex items-center gap-2">
                    <Cpu className="w-3.5 h-3.5" />
                    Simulate Gemini Outage
                  </span>
                  <span className={`px-1.5 py-0.5 rounded text-[10px] uppercase font-bold ${isGeminiFailing ? 'bg-red-500 text-white' : 'bg-slate-700 text-slate-400'}`}>
                    {isGeminiFailing ? 'FAILING' : 'HEALTHY'}
                  </span>
                </button>
              </div>
            )}
          </div>

          {/* Notifications Bell */}
          <button
            onClick={onOpenNotifications}
            className="relative p-2 rounded-lg bg-slate-800/80 hover:bg-slate-700 text-slate-300 border border-slate-700 transition-colors"
            title="Notifications & Outbox Alerts"
          >
            <Bell className="w-4 h-4" />
            {unreadCount > 0 && (
              <span className="absolute -top-1 -right-1 min-w-[18px] h-[18px] bg-cyan-500 text-slate-900 font-extrabold text-[10px] rounded-full flex items-center justify-center px-1 shadow-md shadow-cyan-500/50 animate-bounce">
                {unreadCount}
              </span>
            )}
          </button>

          {/* New Campaign Button (for Marketer) */}
          {currentUser?.role === 'marketer' && (
            <button
              onClick={onNewCampaign}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold bg-gradient-to-r from-cyan-500 to-blue-600 hover:from-cyan-400 hover:to-blue-500 text-white shadow-md shadow-cyan-500/25 transition-all"
            >
              <PlusCircle className="w-3.5 h-3.5" />
              <span>Create Proposal</span>
            </button>
          )}

          {/* Active User Switcher */}
          <div className="flex items-center gap-2 pl-2 border-l border-slate-800">
            <select
              value={currentUser?.id || ''}
              onChange={(e) => {
                const user = users.find(u => u.id === e.target.value);
                if (user) onSwitchUser(user);
              }}
              className="bg-slate-800 border border-slate-700 text-slate-200 text-xs font-medium rounded-lg px-2.5 py-1.5 focus:outline-none focus:border-cyan-500 cursor-pointer max-w-[150px] sm:max-w-[210px] truncate"
            >
              {users.map(u => (
                <option key={u.id} value={u.id}>
                  {u.name} ({u.role})
                </option>
              ))}
            </select>
          </div>
        </div>
      </div>
    </header>
  );
}
