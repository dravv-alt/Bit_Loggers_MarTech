import React, { useState, useEffect } from 'react';
import Header from './components/Header.jsx';
import KanbanBoard from './components/KanbanBoard.jsx';
import CampaignDetailModal from './components/CampaignDetailModal.jsx';
import CampaignWizardModal from './components/CampaignWizardModal.jsx';
import CalendarView from './components/CalendarView.jsx';
import AnalyticsDashboard from './components/AnalyticsDashboard.jsx';
import NotificationCenter from './components/NotificationCenter.jsx';
import OutboxMonitor from './components/OutboxMonitor.jsx';
import AuditTrailView from './components/AuditTrailView.jsx';
import DiagnosticsView from './components/DiagnosticsView.jsx';
import TestRunnerView from './components/TestRunnerView.jsx';
import { api } from './api.js';
import { 
  LayoutDashboard, 
  Calendar, 
  BarChart3, 
  Bell, 
  Send, 
  GitBranch, 
  Terminal, 
  ShieldCheck,
  Smartphone,
  Sparkles
} from 'lucide-react';

export default function App() {
  const [users, setUsers] = useState([]);
  const [currentUser, setCurrentUser] = useState(null);
  const [campaigns, setCampaigns] = useState([]);
  const [selectedCampaignId, setSelectedCampaignId] = useState(null);
  const [isWizardOpen, setIsWizardOpen] = useState(false);
  const [editingCampaign, setEditingCampaign] = useState(null);
  const [activeTab, setActiveTab] = useState('kanban'); // 'kanban' | 'calendar' | 'analytics' | 'notifications' | 'outbox' | 'audit' | 'diagnostics' | 'tests'
  const [isMobileView, setIsMobileView] = useState(false);

  // Outbox & Fault simulation indicators
  const [isEmailFailing, setIsEmailFailing] = useState(false);
  const [isGeminiFailing, setIsGeminiFailing] = useState(false);
  const [unreadCount, setUnreadCount] = useState(0);

  // Toast Notification state
  const [toasts, setToasts] = useState([]);

  const showToast = (message, type = 'info') => {
    const id = Date.now() + Math.random();
    setToasts(prev => [...prev, { id, message, type }]);
    setTimeout(() => {
      setToasts(prev => prev.filter(t => t.id !== id));
    }, 4500);
  };

  // Initial Load: Fetch Users & Campaigns
  const initApp = async () => {
    try {
      const uRes = await api.getUsers();
      setUsers(uRes.users || []);
      const defaultUser = uRes.currentUser || uRes.users?.[0];
      setCurrentUser(defaultUser);

      // Fetch Campaigns with current user
      const cRes = await api.getCampaigns({}, defaultUser);
      setCampaigns(cRes.campaigns || []);

      // Check notification unread count
      const nRes = await api.getNotifications(defaultUser);
      setUnreadCount(nRes.unreadCount || 0);

      // Check Outbox status
      const oRes = await api.getOutbox(defaultUser);
      setIsEmailFailing(Boolean(oRes.isEmailServiceFailing));
    } catch (err) {
      console.error('Init error:', err);
      showToast(err.message, 'error');
    }
  };

  const refreshCampaigns = async () => {
    if (!currentUser) return;
    try {
      const cRes = await api.getCampaigns({}, currentUser);
      setCampaigns(cRes.campaigns || []);
      const nRes = await api.getNotifications(currentUser);
      setUnreadCount(nRes.unreadCount || 0);
    } catch (err) {
      console.error('Refresh error:', err);
    }
  };

  useEffect(() => {
    initApp();
  }, []);

  const handleSwitchUser = async (user) => {
    setCurrentUser(user);
    showToast(`Switched active profile to ${user.name} (${user.role.toUpperCase()})`, 'info');
    try {
      const cRes = await api.getCampaigns({}, user);
      setCampaigns(cRes.campaigns || []);
      const nRes = await api.getNotifications(user);
      setUnreadCount(nRes.unreadCount || 0);
    } catch (err) {
      console.error(err);
    }
  };

  const handleSubmitCampaign = async (campaignId) => {
    try {
      const idemKey = 'submit-' + Date.now();
      const res = await api.submitCampaign(campaignId, currentUser, idemKey);
      showToast(res.message || 'Campaign submitted for review!', 'success');
      refreshCampaigns();
    } catch (err) {
      showToast(err.message, 'error');
    }
  };

  const handleToggleEmailFailure = async () => {
    try {
      const res = await api.toggleEmailFailure(!isEmailFailing, currentUser);
      setIsEmailFailing(res.isEmailServiceFailing);
      showToast(`Email simulated outage: ${res.isEmailServiceFailing ? 'ON (Failing)' : 'OFF (Healthy)'}`, 'info');
    } catch (err) {
      showToast(err.message, 'error');
    }
  };

  const handleToggleGeminiFailure = async () => {
    try {
      const res = await api.toggleGeminiFailure(!isGeminiFailing, currentUser);
      setIsGeminiFailing(res.isGeminiFailing);
      showToast(`Gemini simulated outage: ${res.isGeminiFailing ? 'ON (Failing)' : 'OFF (Healthy)'}`, 'info');
    } catch (err) {
      showToast(err.message, 'error');
    }
  };

  // Render main content area
  const renderContent = () => {
    switch (activeTab) {
      case 'kanban':
        return (
          <KanbanBoard
            campaigns={campaigns}
            currentUser={currentUser}
            onSelectCampaign={(id) => setSelectedCampaignId(id)}
            onNewCampaign={() => {
              setEditingCampaign(null);
              setIsWizardOpen(true);
            }}
            onSubmitCampaign={handleSubmitCampaign}
            onOpenScheduleModal={(camp) => setSelectedCampaignId(camp.campaign_id)}
          />
        );
      case 'calendar':
        return (
          <CalendarView
            currentUser={currentUser}
            onSelectCampaign={(id) => setSelectedCampaignId(id)}
            showToast={showToast}
          />
        );
      case 'analytics':
        return (
          <AnalyticsDashboard
            currentUser={currentUser}
            showToast={showToast}
          />
        );
      case 'notifications':
        return (
          <NotificationCenter
            currentUser={currentUser}
            onSelectCampaign={(id) => setSelectedCampaignId(id)}
            showToast={showToast}
            onRefreshHeader={refreshCampaigns}
          />
        );
      case 'outbox':
        return (
          <OutboxMonitor
            currentUser={currentUser}
            showToast={showToast}
          />
        );
      case 'audit':
        return (
          <AuditTrailView
            currentUser={currentUser}
            onSelectCampaign={(id) => setSelectedCampaignId(id)}
            showToast={showToast}
          />
        );
      case 'diagnostics':
        return (
          <DiagnosticsView
            currentUser={currentUser}
            showToast={showToast}
          />
        );
      case 'tests':
        return (
          <TestRunnerView
            currentUser={currentUser}
            showToast={showToast}
          />
        );
      default:
        return null;
    }
  };

  const mainView = (
    <div className="flex flex-col min-h-screen">
      <Header
        users={users}
        currentUser={currentUser}
        onSwitchUser={handleSwitchUser}
        isMobileView={isMobileView}
        setIsMobileView={setIsMobileView}
        unreadCount={unreadCount}
        onOpenNotifications={() => setActiveTab('notifications')}
        onNewCampaign={() => {
          setEditingCampaign(null);
          setIsWizardOpen(true);
        }}
        isEmailFailing={isEmailFailing}
        isGeminiFailing={isGeminiFailing}
        onToggleEmailFailure={handleToggleEmailFailure}
        onToggleGeminiFailure={handleToggleGeminiFailure}
        onOpenTests={() => setActiveTab('tests')}
      />

      {/* Main Navigation Subheader */}
      <nav className="glass-panel border-b border-slate-800/80 px-4 py-2 sticky top-[61px] z-30">
        <div className="max-w-7xl mx-auto flex items-center justify-between overflow-x-auto gap-2">
          <div className="flex items-center gap-1">
            {[
              { id: 'kanban', label: 'Kanban Board', icon: LayoutDashboard },
              { id: 'calendar', label: 'Marketing Calendar', icon: Calendar },
              { id: 'analytics', label: 'Analytics & 5 KPIs', icon: BarChart3 },
              { id: 'notifications', label: 'Notifications', icon: Bell, badge: unreadCount },
              { id: 'outbox', label: 'Transactional Outbox', icon: Send },
              { id: 'audit', label: 'Audit Trail', icon: GitBranch },
              { id: 'diagnostics', label: 'Diagnostics', icon: Terminal },
              { id: 'tests', label: '14/14 Tests', icon: ShieldCheck, highlight: true }
            ].map(tab => {
              const Icon = tab.icon;
              const active = activeTab === tab.id;
              return (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  className={`flex items-center gap-2 px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition-all ${
                    active 
                      ? 'bg-cyan-500/20 text-cyan-300 border border-cyan-500/40 shadow-sm shadow-cyan-500/20' 
                      : tab.highlight 
                      ? 'text-emerald-400 hover:bg-emerald-500/10' 
                      : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60'
                  }`}
                >
                  <Icon className="w-3.5 h-3.5" />
                  <span>{tab.label}</span>
                  {tab.badge > 0 && (
                    <span className="w-4 h-4 rounded-full bg-cyan-500 text-slate-950 text-[10px] font-extrabold flex items-center justify-center">
                      {tab.badge}
                    </span>
                  )}
                </button>
              );
            })}
          </div>
        </div>
      </nav>

      {/* Primary Content View */}
      <main className="flex-1 max-w-7xl w-full mx-auto p-4 sm:p-6">
        {renderContent()}
      </main>

      {/* Campaign Detail Modal */}
      {selectedCampaignId && (
        <CampaignDetailModal
          campaignId={selectedCampaignId}
          currentUser={currentUser}
          onClose={() => setSelectedCampaignId(null)}
          onRefresh={refreshCampaigns}
          onEditCampaign={(camp) => {
            setEditingCampaign(camp);
            setIsWizardOpen(true);
          }}
          showToast={showToast}
        />
      )}

      {/* Campaign Wizard Modal */}
      {isWizardOpen && (
        <CampaignWizardModal
          campaign={editingCampaign}
          currentUser={currentUser}
          onClose={() => {
            setIsWizardOpen(false);
            setEditingCampaign(null);
          }}
          onSuccess={() => {
            setIsWizardOpen(false);
            setEditingCampaign(null);
            refreshCampaigns();
          }}
          showToast={showToast}
        />
      )}

      {/* Global Toast Alerts */}
      <div className="fixed bottom-4 right-4 z-50 space-y-2 max-w-sm w-full pointer-events-none">
        {toasts.map(toast => (
          <div
            key={toast.id}
            className={`p-3 rounded-xl shadow-2xl border text-xs font-medium pointer-events-auto flex items-start gap-2.5 animate-in slide-in-from-bottom-2 ${
              toast.type === 'error' ? 'bg-red-950/90 text-red-200 border-red-500/40' :
              toast.type === 'success' ? 'bg-emerald-950/90 text-emerald-200 border-emerald-500/40' :
              'glass-panel text-slate-200 border-cyan-500/40'
            }`}
          >
            <div className="w-2 h-2 rounded-full mt-1.5 shrink-0 bg-current"></div>
            <div className="flex-1 leading-relaxed">{toast.message}</div>
          </div>
        ))}
      </div>
    </div>
  );

  // If Mobile Viewport simulator is active, render inside a device frame mockup
  if (isMobileView) {
    return (
      <div className="min-h-screen bg-slate-950 p-4 sm:p-8 flex flex-col items-center justify-center">
        <div className="text-center mb-4 space-y-1">
          <div className="flex items-center justify-center gap-2 text-cyan-400 font-extrabold text-sm">
            <Smartphone className="w-4 h-4" />
            <span>Mobile-First Presentation Mode</span>
          </div>
          <p className="text-xs text-slate-500">
            Simulating iPhone 15 Pro (390 x 844 px). Toggle above to switch back to desktop responsive layout.
          </p>
        </div>

        <div className="w-[390px] h-[844px] bg-slate-900 rounded-[50px] border-[10px] border-slate-800 shadow-2xl shadow-cyan-500/10 overflow-hidden relative flex flex-col">
          {/* Dynamic Island / Speaker notch */}
          <div className="w-32 h-5 bg-black rounded-full mx-auto mt-2 absolute top-2 left-1/2 -translate-x-1/2 z-50 flex items-center justify-center">
            <div className="w-3 h-3 rounded-full bg-slate-900 border border-slate-800 mr-2"></div>
            <div className="w-2 h-2 rounded-full bg-cyan-500/40"></div>
          </div>

          <div className="flex-1 overflow-y-auto pt-6">
            {mainView}
          </div>

          {/* Home indicator bar */}
          <div className="w-32 h-1 bg-slate-600 rounded-full mx-auto mb-2 shrink-0"></div>
        </div>
      </div>
    );
  }

  return mainView;
}

