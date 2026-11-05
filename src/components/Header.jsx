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
  Cpu,
  Zap
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
          <div className="w-9 h-9 rounded-xl bg-cyan-500 flex items-center justify-center text-slate-950 font-black">
            <Zap className="w-5 h-5 fill-current" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <span className="font-extrabold text-base sm:text-lg text-white">
                Bit Loggers
              </span>
              <span className="hidden sm:inline-block px-2 py-0.5 text-[11px] font-medium bg-cyan-500/10 text-cyan-400 border border-cyan-500/20 rounded-md">
                MarTech platform
              </span>
            </div>
            <p className="text-[11px] text-slate-400 hidden sm:block">
              Intelligent, auditable and version-aware campaign platform
            </p>
          </div>
        </div>

        {/* Center / Action Toolbar */}
        <div className="flex items-center gap-2">
          {/* Mobile Viewport Toggle */}
          <button
            onClick={() => setIsMobileView(!isMobileView)}
            title={isMobileView ? "Switch to Desktop Responsive View" : "Simulate Mobile Device View"}
            className={`flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan-400 active:opacity-90 disabled:opacity-50 ${
              isMobileView 
                ? 'bg-cyan-500/20 text-cyan-300 border border-cyan-500/40' 
                : 'bg-slate-800/80 text-slate-300 hover:bg-slate-700 border border-slate-700'
            }`}
          >
            {isMobileView ? <Smartphone className="w-3.5 h-3.5" /> : <Monitor className="w-3.5 h-3.5" />}
            <span className="hidden md:inline">{isMobileView ? 'Mobile frame' : 'Desktop view'}</span>
          </button>

          {/* Architecture QA Tests Button */}
          <button
            onClick={onOpenTests}
            className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs font-semibold bg-emerald-500/15 text-emerald-400 border border-emerald-500/30 hover:bg-emerald-500/25 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-400 active:opacity-90 disabled:opacity-50"
            title="View & Run All 14 LLD Automated Architecture Tests (T-01 to T-14)"
          >
            <ShieldCheck className="w-3.5 h-3.5 text-emerald-400" />
            <span className="hidden md:inline">14/14 tests</span>
          </button>

          {/* Fault Simulation Menu Toggle */}
          <div className="relative">
            <button
              onClick={() => setShowSimMenu(!showSimMenu)}
              className={`p-1.5 rounded-lg text-xs font-medium border transition-colors flex items-center gap-1 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan-400 active:opacity-90 disabled:opacity-50 ${
                isEmailFailing || isGeminiFailing 
                  ? 'bg-amber-500/20 text-amber-300 border-amber-500/40 motion-safe:animate-pulse' 
                  : 'bg-slate-800/80 text-slate-400 hover:text-slate-200 border-slate-700'
              }`}
              title="Resilience & Fault Injections (T-12, T-13)"
            >
              <AlertTriangle className="w-3.5 h-3.5" />
              {(isEmailFailing || isGeminiFailing) && <span className="w-1.5 h-1.5 rounded-full bg-amber-400"></span>}
            </button>

            {showSimMenu && (
              <div className="absolute right-0 mt-2 w-64 glass-panel rounded-xl p-3 border border-slate-700/80 z-50">
                <div className="text-[11px] font-semibold text-slate-400 mb-2">
                  Fault injection and recovery
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
                    Simulate email outage
                  </span>
                  <span className={`px-1.5 py-0.5 rounded text-[10px] font-medium ${isEmailFailing ? 'bg-red-500 text-white' : 'bg-slate-700 text-slate-400'}`}>
                    {isEmailFailing ? 'Failing' : 'Healthy'}
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
                    Simulate Gemini outage
                  </span>
                  <span className={`px-1.5 py-0.5 rounded text-[10px] font-medium ${isGeminiFailing ? 'bg-red-500 text-white' : 'bg-slate-700 text-slate-400'}`}>
                    {isGeminiFailing ? 'Failing' : 'Healthy'}
                  </span>
                </button>
              </div>
            )}
          </div>

          {/* Notifications Bell */}
          <button
            onClick={onOpenNotifications}
            className="relative p-2 rounded-lg bg-slate-800/80 hover:bg-slate-700 text-slate-300 border border-slate-700 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan-400 active:opacity-90 disabled:opacity-50"
            title="Notifications & Outbox Alerts"
          >
            <Bell className="w-4 h-4" />
            {unreadCount > 0 && (
              <span className="absolute -top-1 -right-1 min-w-[18px] h-[18px] bg-cyan-500 text-slate-900 font-bold text-[10px] rounded-full flex items-center justify-center px-1">
                {unreadCount}
              </span>
            )}
          </button>

          {/* New Campaign Button (for Marketer) */}
          {currentUser?.role === 'marketer' && (
            <button
              onClick={onNewCampaign}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold bg-cyan-500 hover:bg-cyan-400 text-slate-950 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan-300 active:opacity-90 disabled:opacity-50"
            >
              <PlusCircle className="w-3.5 h-3.5" />
              <span>Create proposal</span>
            </button>
          )}
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

