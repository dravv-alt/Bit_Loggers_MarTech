import React, { useState, useEffect } from 'react';
import { 
  X, 
  CheckCircle, 
  AlertCircle, 
  XCircle, 
  Calendar, 
  History, 
  MessageSquare, 
  ShieldCheck, 
  Lock, 
  Unlock, 
  Edit3, 
  Send, 
  Sparkles, 
  TrendingUp, 
  ArrowRight,
  Info,
  Clock,
  User,
  AlertTriangle,
  GitBranch
} from 'lucide-react';
import { api } from '../api.js';

export default function CampaignDetailModal({ 
  campaignId, 
  currentUser, 
  onClose, 
  onRefresh, 
  onEditCampaign,
  showToast 
}) {
  const [campaign, setCampaign] = useState(null);
  const [activeTab, setActiveTab] = useState('overview'); // 'overview' | 'versions' | 'review' | 'schedule' | 'discussions' | 'audit'
  const [loading, setLoading] = useState(true);

  // Review decision form state
  const [decisionType, setDecisionType] = useState('APPROVED');
  const [reason, setReason] = useState('');
  const [policyRef, setPolicyRef] = useState('');
  const [submittingDecision, setSubmittingDecision] = useState(false);

  // Schedule form state
  const [scheduleStart, setScheduleStart] = useState(new Date().toISOString().slice(0, 10));
  const [scheduleEnd, setScheduleEnd] = useState(new Date(Date.now() + 14 * 86400000).toISOString().slice(0, 10));
  const [scheduleChannel, setScheduleChannel] = useState('');
  const [submittingSchedule, setSubmittingSchedule] = useState(false);

  // Discussion state
  const [discussions, setDiscussions] = useState([]);
  const [commentText, setCommentText] = useState('');
  const [sendingComment, setSendingComment] = useState(false);

  // Concurrency lease state
  const [lockStatus, setLockStatus] = useState(null);
  const [lockingLoading, setLockingLoading] = useState(false);

  const fetchDetails = async () => {
    try {
      setLoading(true);
      const data = await api.getCampaign(campaignId, currentUser);
      setCampaign(data);
      setLockStatus(data.active_lock);
      setScheduleChannel(data.current_version?.channel || 'Social');
      
      const disc = await api.getDiscussions(campaignId, currentUser);
      setDiscussions(disc.messages || []);
    } catch (err) {
      showToast(err.message, 'error');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (campaignId) {
      fetchDetails();
    }
  }, [campaignId, currentUser?.id]);

  // Acquire or Release Edit Lock
  const handleToggleLock = async () => {
    setLockingLoading(true);
    try {
      if (lockStatus && lockStatus.holder_id === currentUser.id) {
        await api.releaseLock(campaignId, currentUser);
        setLockStatus(null);
        showToast('Edit lock released.', 'info');
      } else {
        const res = await api.acquireLock(campaignId, currentUser);
        setLockStatus(res);
        showToast('Edit lease acquired (5 minutes).', 'success');
      }
      onRefresh();
    } catch (err) {
      showToast(err.message, 'error');
    } finally {
      setLockingLoading(false);
    }
  };

  // Submit Reviewer Decision (Approve / Request Changes / Reject)
  const handleSubmitDecision = async () => {
    if (!reason.trim()) {
      showToast('Validation Error: Reason is mandatory for all review decisions (LLD Section 3).', 'error');
      return;
    }

    setSubmittingDecision(true);
    try {
      const endpoint = decisionType === 'APPROVED' 
        ? api.approveCampaign 
        : decisionType === 'CHANGES_REQUESTED' 
        ? api.requestChanges 
        : api.rejectCampaign;

      const res = await endpoint(campaignId, {
        version_id: campaign.current_version_id,
        reason: reason.trim(),
        policy_reference: policyRef.trim() || undefined
      }, currentUser);

      showToast(`Decision recorded: ${res.decision} for version v${campaign.current_version?.version_no}`, 'success');
      setReason('');
      setPolicyRef('');
      await fetchDetails();
      onRefresh();
      setActiveTab('overview');
    } catch (err) {
      showToast(err.message, 'error');
    } finally {
      setSubmittingDecision(false);
    }
  };

  // Schedule Campaign
  const handleScheduleCampaign = async () => {
    setSubmittingSchedule(true);
    try {
      const res = await api.scheduleCampaign(campaignId, {
        version_id: campaign.current_version_id,
        starts_at: new Date(scheduleStart).toISOString(),
        ends_at: new Date(scheduleEnd).toISOString(),
        channel: scheduleChannel
      }, currentUser);

      showToast(`Campaign scheduled on ${res.channel}! Flight dates validated.`, 'success');
      await fetchDetails();
      onRefresh();
      setActiveTab('overview');
    } catch (err) {
      showToast(err.message, 'error');
    } finally {
      setSubmittingSchedule(false);
    }
  };

  // Send Discussion Comment
  const handleSendComment = async (e) => {
    e.preventDefault();
    if (!commentText.trim()) return;

    setSendingComment(true);
    try {
      await api.postDiscussion(campaignId, { content: commentText.trim() }, currentUser);
      setCommentText('');
      const disc = await api.getDiscussions(campaignId, currentUser);
      setDiscussions(disc.messages || []);
      showToast('Comment posted.', 'info');
    } catch (err) {
      showToast(err.message, 'error');
    } finally {
      setSendingComment(false);
    }
  };

  if (loading) {
    return (
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm">
        <div className="glass-panel p-6 rounded-2xl flex items-center gap-3 text-cyan-400 font-semibold text-sm">
          <Clock className="w-5 h-5 animate-spin" />
          Loading campaign dossier...
        </div>
      </div>
    );
  }

  if (!campaign) return null;

  const curVer = campaign.current_version || {};
  const kpis = curVer.kpi_projected || {};
  const isOwner = currentUser?.id === campaign.owner_id;
  const isReviewer = currentUser?.role === 'reviewer';
  const hasLock = lockStatus && lockStatus.holder_id === currentUser?.id;
  const lockHeldByOther = lockStatus && lockStatus.holder_id !== currentUser?.id;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-2 sm:p-4 bg-black/80 backdrop-blur-md overflow-y-auto">
      <div className="glass-panel rounded-2xl w-full max-w-4xl max-h-[92vh] flex flex-col border border-slate-700/80 shadow-2xl overflow-hidden animate-in fade-in zoom-in-95 duration-150">
        
        {/* Header */}
        <div className="p-4 sm:p-5 border-b border-slate-800 flex items-start justify-between gap-4 bg-slate-900/60">
          <div>
            <div className="flex flex-wrap items-center gap-2 mb-1.5">
              <span className="px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider bg-cyan-500/20 text-cyan-300 border border-cyan-500/30">
                {campaign.status}
              </span>
              <span className="px-2 py-0.5 rounded-full text-[10px] font-mono font-bold bg-slate-800 text-slate-300 border border-slate-700">
                v{curVer.version_no || 1}
              </span>
              <span className="text-xs text-slate-400">
                Owner: <strong className="text-slate-200">{campaign.owner_name}</strong>
              </span>
            </div>
            <h2 className="text-lg sm:text-xl font-extrabold text-slate-100 tracking-tight">
              {campaign.title}
            </h2>
          </div>

          <div className="flex items-center gap-2">
            {/* Concurrency Lock Pill */}
            {lockHeldByOther ? (
              <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold bg-amber-500/15 text-amber-300 border border-amber-500/30">
                <Lock className="w-3.5 h-3.5 text-amber-400" />
                <span>Locked by {lockStatus.holder_name?.split(' ')[0]}</span>
              </div>
            ) : isOwner ? (
              <button
                onClick={handleToggleLock}
                disabled={lockingLoading}
                className={`flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold transition-colors border ${
                  hasLock 
                    ? 'bg-emerald-500/20 text-emerald-300 border-emerald-500/40 hover:bg-emerald-500/30' 
                    : 'bg-slate-800 text-slate-300 border-slate-700 hover:bg-slate-700'
                }`}
                title={hasLock ? "Click to release edit lease" : "Acquire exclusive edit lease for safe updates"}
              >
                {hasLock ? <Unlock className="w-3.5 h-3.5" /> : <Lock className="w-3.5 h-3.5" />}
                <span>{hasLock ? 'Lease Active' : 'Acquire Lease'}</span>
              </button>
            ) : null}

            {/* Edit Proposal Button for Owner */}
            {isOwner && (
              <button
                onClick={() => {
                  onClose();
                  onEditCampaign(campaign);
                }}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700"
              >
                <Edit3 className="w-3.5 h-3.5 text-cyan-400" />
                <span>Revise / Edit</span>
              </button>
            )}

            <button
              onClick={onClose}
              className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-400 hover:text-white transition-colors"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Navigation Tabs */}
        <div className="flex items-center gap-1 px-4 border-b border-slate-800 bg-slate-900/40 overflow-x-auto">
          {[
            { id: 'overview', label: 'Proposal Brief', icon: Info },
            { id: 'versions', label: `Versions (${campaign.versions?.length || 1})`, icon: History },
            ...(campaign.status === 'Submitted' && isReviewer ? [{ id: 'review', label: 'Review Decision', icon: ShieldCheck, alert: true }] : []),
            ...(campaign.status === 'Approved' && isOwner ? [{ id: 'schedule', label: 'Schedule Launch', icon: Calendar, alert: true }] : []),
            { id: 'discussions', label: `Discussions (${discussions.length})`, icon: MessageSquare },
            { id: 'audit', label: 'Audit Trail', icon: GitBranch }
          ].map(tab => {
            const Icon = tab.icon;
            const active = activeTab === tab.id;
            return (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={`flex items-center gap-2 px-3.5 py-2.5 text-xs font-semibold border-b-2 whitespace-nowrap transition-all ${
                  active 
                    ? 'border-cyan-500 text-cyan-400 bg-cyan-500/10' 
                    : 'border-transparent text-slate-400 hover:text-slate-200 hover:bg-slate-800/50'
                }`}
              >
                <Icon className="w-3.5 h-3.5" />
                <span>{tab.label}</span>
                {tab.alert && <span className="w-2 h-2 rounded-full bg-cyan-400 animate-pulse"></span>}
              </button>
            );
          })}
        </div>

        {/* Tab Content Body */}
        <div className="p-4 sm:p-6 overflow-y-auto flex-1 space-y-6">

          {/* TAB 1: OVERVIEW */}
          {activeTab === 'overview' && (
            <div className="space-y-6">
              {/* Channel and Budget Overview Cards */}
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div className="glass-card p-3.5 rounded-xl border border-slate-800">
                  <div className="text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-1">
                    Primary Channel
                  </div>
                  <div className="text-base font-bold text-slate-100 flex items-center gap-2">
                    <span className="w-2.5 h-2.5 rounded-full bg-cyan-400"></span>
                    {curVer.channel}
                  </div>
                </div>

                <div className="glass-card p-3.5 rounded-xl border border-slate-800">
                  <div className="text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-1">
                    Total Budget
                  </div>
                  <div className="text-base font-bold font-mono text-emerald-400">
                    ${(curVer.budget || 0).toLocaleString()} USD
                  </div>
                </div>

                <div className="glass-card p-3.5 rounded-xl border border-slate-800">
                  <div className="text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-1">
                    Workflow State
                  </div>
                  <div className="text-base font-bold text-cyan-300">
                    {campaign.status}
                  </div>
                </div>
              </div>

              {/* AI Strategy Summary (Pillar 4) */}
              {curVer.ai_summary && (
                <div className="p-4 rounded-xl bg-gradient-to-r from-cyan-950/40 via-blue-950/30 to-slate-900 border border-cyan-500/30">
                  <div className="flex items-center gap-2 text-xs font-bold text-cyan-300 uppercase tracking-wider mb-2">
                    <Sparkles className="w-4 h-4 text-cyan-400" />
                    AI Intelligence Summary (Gemini Argon)
                  </div>
                  <p className="text-xs text-slate-300 leading-relaxed italic">
                    "{curVer.ai_summary}"
                  </p>
                </div>
              )}

              {/* Strategic Objective & Target Audience */}
              <div className="space-y-4">
                <div>
                  <h4 className="text-xs font-bold text-slate-400 uppercase tracking-wider mb-1.5">
                    Strategic Objective
                  </h4>
                  <p className="text-sm text-slate-200 bg-slate-900/60 p-3 rounded-xl border border-slate-800 leading-relaxed">
                    {curVer.objective}
                  </p>
                </div>

                <div>
                  <h4 className="text-xs font-bold text-slate-400 uppercase tracking-wider mb-1.5">
                    Target Audience Persona
                  </h4>
                  <p className="text-sm text-slate-200 bg-slate-900/60 p-3 rounded-xl border border-slate-800 leading-relaxed">
                    {curVer.target_audience}
                  </p>
                </div>
              </div>

              {/* The 5 Mandatory KPIs Projected (Pillar 2) */}
              <div>
                <h4 className="text-xs font-bold text-slate-400 uppercase tracking-wider mb-3 flex items-center justify-between">
                  <span>5 Projected Campaign KPIs</span>
                  <span className="text-[11px] text-cyan-400 font-mono">Bound to v{curVer.version_no}</span>
                </h4>
                
                <div className="grid grid-cols-2 sm:grid-cols-5 gap-3 font-mono">
                  <div className="p-3 rounded-xl glass-card border border-slate-800 text-center">
                    <div className="text-[10px] text-slate-400 uppercase mb-1">Conversion Rate</div>
                    <div className="text-lg font-bold text-cyan-400">{kpis.conversionRate || 3.5}%</div>
                  </div>
                  <div className="p-3 rounded-xl glass-card border border-slate-800 text-center">
                    <div className="text-[10px] text-slate-400 uppercase mb-1">Click-Through Rate</div>
                    <div className="text-lg font-bold text-blue-400">{kpis.ctr || 4.2}%</div>
                  </div>
                  <div className="p-3 rounded-xl glass-card border border-slate-800 text-center">
                    <div className="text-[10px] text-slate-400 uppercase mb-1">ROI Multiplier</div>
                    <div className="text-lg font-bold text-emerald-400">{kpis.roi || 3.8}x</div>
                  </div>
                  <div className="p-3 rounded-xl glass-card border border-slate-800 text-center">
                    <div className="text-[10px] text-slate-400 uppercase mb-1">Cost Per Acq.</div>
                    <div className="text-lg font-bold text-amber-400">${kpis.cpa || 25.00}</div>
                  </div>
                  <div className="p-3 rounded-xl glass-card border border-slate-800 text-center col-span-2 sm:col-span-1">
                    <div className="text-[10px] text-slate-400 uppercase mb-1">Avg Order Value</div>
                    <div className="text-lg font-bold text-purple-400">${kpis.aov || 95.00}</div>
                  </div>
                </div>
              </div>

              {/* Recorded Decisions on this Campaign */}
              {campaign.decisions?.length > 0 && (
                <div>
                  <h4 className="text-xs font-bold text-slate-400 uppercase tracking-wider mb-2">
                    Review Decisions History
                  </h4>
                  <div className="space-y-2">
                    {campaign.decisions.map(dec => (
                      <div key={dec.decision_id} className="p-3 rounded-xl glass-card border border-slate-800 text-xs space-y-1">
                        <div className="flex items-center justify-between">
                          <span className={`font-bold px-2 py-0.5 rounded text-[10px] ${
                            dec.decision_type === 'APPROVED' ? 'bg-emerald-500/20 text-emerald-300' :
                            dec.decision_type === 'CHANGES_REQUESTED' ? 'bg-orange-500/20 text-orange-300' : 'bg-red-500/20 text-red-300'
                          }`}>
                            {dec.decision_type}
                          </span>
                          <span className="text-slate-500 text-[10px]">{new Date(dec.decided_at).toLocaleString()}</span>
                        </div>
                        <p className="text-slate-300 pt-1">
                          <strong className="text-slate-200">{dec.reviewer_name}:</strong> "{dec.reason}"
                        </p>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}

          {/* TAB 2: VERSIONS & IMMUTABLE DIFF VIEWER (Pillar 3, Section 5) */}
          {activeTab === 'versions' && (
            <div className="space-y-4">
              <div className="p-3 rounded-xl bg-slate-900/80 border border-slate-800 flex items-center gap-2 text-xs text-slate-300">
                <ShieldCheck className="w-4 h-4 text-cyan-400 shrink-0" />
                <span>
                  <strong>Governance Guarantee:</strong> All campaign versions are strictly immutable. Any modification to budget or audience automatically increments version numbers and requires fresh review.
                </span>
              </div>

              <div className="space-y-4">
                {campaign.versions?.map((ver, idx) => {
                  const prevVer = idx > 0 ? campaign.versions[idx - 1] : null;
                  const isCurrent = ver.version_id === campaign.current_version_id;
                  const verDecision = campaign.decisions?.find(d => d.version_id === ver.version_id);

                  return (
                    <div 
                      key={ver.version_id} 
                      className={`p-4 rounded-xl border transition-all ${
                        isCurrent 
                          ? 'glass-panel border-cyan-500/40 shadow-lg shadow-cyan-500/5' 
                          : 'glass-card border-slate-800 opacity-90'
                      }`}
                    >
                      <div className="flex items-start justify-between gap-3 mb-3">
                        <div className="flex items-center gap-2">
                          <span className="text-xs font-mono font-extrabold px-2 py-0.5 rounded bg-cyan-500/20 text-cyan-300 border border-cyan-500/40">
                            Version v{ver.version_no}
                          </span>
                          {isCurrent && (
                            <span className="text-[10px] uppercase font-bold px-2 py-0.5 rounded bg-emerald-500/20 text-emerald-300">
                              Active Current Version
                            </span>
                          )}
                          {verDecision && (
                            <span className={`text-[10px] uppercase font-bold px-2 py-0.5 rounded ${
                              verDecision.decision_type === 'APPROVED' ? 'bg-emerald-500/20 text-emerald-300' :
                              verDecision.decision_type === 'CHANGES_REQUESTED' ? 'bg-orange-500/20 text-orange-300' : 'bg-red-500/20 text-red-300'
                            }`}>
                              {verDecision.decision_type}
                            </span>
                          )}
                        </div>

                        <span className="text-[11px] text-slate-400">
                          {new Date(ver.created_at).toLocaleString()}
                        </span>
                      </div>

                      {/* Version Snapshot Diff Visualizer */}
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-3 text-xs">
                        <div className="p-3 rounded-lg bg-slate-900/60 border border-slate-800 space-y-1">
                          <div className="text-[10px] uppercase font-bold text-slate-400">Channel & Budget</div>
                          <div className="flex items-center gap-2">
                            <span className="text-slate-200">{ver.channel}</span>
                            <span className="text-slate-500">•</span>
                            <span className="font-mono font-bold text-emerald-400">${ver.budget?.toLocaleString()}</span>
                            {prevVer && prevVer.budget !== ver.budget && (
                              <span className="text-[10px] font-mono px-1 rounded bg-amber-500/20 text-amber-300">
                                {ver.budget > prevVer.budget ? `+$${ver.budget - prevVer.budget}` : `-$${prevVer.budget - ver.budget}`}
                              </span>
                            )}
                          </div>
                        </div>

                        <div className="p-3 rounded-lg bg-slate-900/60 border border-slate-800 space-y-1">
                          <div className="text-[10px] uppercase font-bold text-slate-400">Target Audience</div>
                          <div className="text-slate-300 line-clamp-2">
                            {ver.target_audience}
                          </div>
                        </div>
                      </div>

                      {/* Decision Details if reviewed */}
                      {verDecision && (
                        <div className="mt-3 p-2.5 rounded-lg bg-slate-900/40 border border-slate-800/80 text-xs">
                          <div className="text-[10px] font-bold text-slate-400 uppercase">
                            Decision Reason ({verDecision.reviewer_name}):
                          </div>
                          <p className="text-slate-300 italic pt-0.5">
                            "{verDecision.reason}"
                          </p>
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          {/* TAB 3: REVIEW CONSOLE (Reviewer only, LLD Section 2 & 3) */}
          {activeTab === 'review' && isReviewer && (
            <div className="space-y-5">
              <div className="p-4 rounded-xl bg-amber-500/10 border border-amber-500/30 text-xs text-amber-300">
                <strong>Reviewer Evaluation:</strong> You are deciding on Version <strong>v{curVer.version_no}</strong>. A detailed, written justification reason is mandatory by MarTech policy and cannot be left blank.
              </div>

              {/* Decision Choice Radio Cards */}
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                {[
                  { id: 'APPROVED', title: 'Approve Campaign', desc: 'Satisfies budget, audience, and ROI criteria. Makes version eligible for scheduling.', border: 'border-emerald-500/40 bg-emerald-500/10 text-emerald-300' },
                  { id: 'CHANGES_REQUESTED', title: 'Request Revisions', desc: 'Requires marketer to adjust budget, channel, or audience. Marketer revises as new version.', border: 'border-orange-500/40 bg-orange-500/10 text-orange-300' },
                  { id: 'REJECTED', title: 'Permanent Rejection', desc: 'Campaign cannot proceed due to policy violation or unviable parameters.', border: 'border-red-500/40 bg-red-500/10 text-red-300' }
                ].map(opt => (
                  <div
                    key={opt.id}
                    onClick={() => setDecisionType(opt.id)}
                    className={`p-3.5 rounded-xl border cursor-pointer transition-all ${
                      decisionType === opt.id ? opt.border + ' ring-2 ring-cyan-500/30' : 'glass-card border-slate-800 text-slate-400 hover:border-slate-700'
                    }`}
                  >
                    <div className="font-bold text-xs mb-1">{opt.title}</div>
                    <div className="text-[11px] leading-relaxed opacity-80">{opt.desc}</div>
                  </div>
                ))}
              </div>

              {/* Mandatory Reason Input */}
              <div className="space-y-1.5">
                <label className="text-xs font-bold text-slate-200 flex items-center justify-between">
                  <span>Mandatory Decision Justification Reason *</span>
                  <span className={`text-[11px] ${reason.trim().length > 0 ? 'text-emerald-400' : 'text-red-400'}`}>
                    {reason.trim().length > 0 ? 'Valid reason provided' : 'Required (non-empty)'}
                  </span>
                </label>
                <textarea
                  rows={4}
                  placeholder={
                    decisionType === 'APPROVED' 
                      ? 'Explain why the campaign is acceptable (e.g. Target audience aligns with objective, proposed budget is within allocated limits, and expected ROI is well supported).'
                      : decisionType === 'CHANGES_REQUESTED'
                      ? 'Specify what needs correction (e.g. The proposed audience is too broad. Narrow down segment and provide revised budget).'
                      : 'Specify why the proposal is declined (e.g. Violates organizational advertising guidelines).'
                  }
                  value={reason}
                  onChange={(e) => setReason(e.target.value)}
                  className="w-full p-3 bg-slate-900 border border-slate-700 rounded-xl text-xs text-slate-100 placeholder:text-slate-500 focus:outline-none focus:border-cyan-500"
                />
              </div>

              {/* Policy Reference Input */}
              <div className="space-y-1.5">
                <label className="text-xs font-bold text-slate-200">
                  Policy or Guideline Reference (Optional)
                </label>
                <input
                  type="text"
                  placeholder="e.g. MARTECH-POL-2026-Q4 or Compliance Standard §4.2"
                  value={policyRef}
                  onChange={(e) => setPolicyRef(e.target.value)}
                  className="w-full p-2.5 bg-slate-900 border border-slate-700 rounded-xl text-xs text-slate-100 placeholder:text-slate-500 focus:outline-none focus:border-cyan-500"
                />
              </div>

              {/* Action Buttons */}
              <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-800">
                <button
                  onClick={() => setActiveTab('overview')}
                  className="px-4 py-2 rounded-xl text-xs font-semibold text-slate-400 hover:text-white"
                >
                  Cancel
                </button>
                <button
                  onClick={handleSubmitDecision}
                  disabled={submittingDecision || !reason.trim()}
                  className="px-5 py-2.5 rounded-xl text-xs font-bold bg-gradient-to-r from-cyan-500 to-blue-600 hover:from-cyan-400 hover:to-blue-500 text-white shadow-lg shadow-cyan-500/25 disabled:opacity-50 transition-all flex items-center gap-2"
                >
                  {submittingDecision && <Clock className="w-3.5 h-3.5 animate-spin" />}
                  <span>Record {decisionType} Decision</span>
                </button>
              </div>
            </div>
          )}

          {/* TAB 4: SCHEDULE LAUNCH (Marketer only, LLD Section 7) */}
          {activeTab === 'schedule' && isOwner && (
            <div className="space-y-5">
              <div className="p-4 rounded-xl bg-emerald-500/10 border border-emerald-500/30 text-xs text-emerald-300">
                <strong>Launch Validation:</strong> Only campaigns with an APPROVED decision bound to the exact, current version (v{curVer.version_no}) are permitted to be scheduled into the internal calendar.
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs">
                <div>
                  <label className="font-bold text-slate-300 block mb-1">Flight Start Date</label>
                  <input
                    type="date"
                    value={scheduleStart}
                    onChange={(e) => setScheduleStart(e.target.value)}
                    className="w-full p-2.5 bg-slate-900 border border-slate-700 rounded-xl text-slate-100 text-xs"
                  />
                </div>

                <div>
                  <label className="font-bold text-slate-300 block mb-1">Flight End Date</label>
                  <input
                    type="date"
                    value={scheduleEnd}
                    onChange={(e) => setScheduleEnd(e.target.value)}
                    className="w-full p-2.5 bg-slate-900 border border-slate-700 rounded-xl text-slate-100 text-xs"
                  />
                </div>
              </div>

              <div>
                <label className="font-bold text-slate-300 block mb-1 text-xs">Scheduled Channel</label>
                <select
                  value={scheduleChannel}
                  onChange={(e) => setScheduleChannel(e.target.value)}
                  className="w-full p-2.5 bg-slate-900 border border-slate-700 rounded-xl text-slate-100 text-xs"
                >
                  <option value="Social">Social</option>
                  <option value="Email">Email</option>
                  <option value="Search">Search</option>
                  <option value="Display">Display</option>
                  <option value="Influencer">Influencer</option>
                  <option value="Video">Video</option>
                </select>
              </div>

              <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-800">
                <button
                  onClick={() => setActiveTab('overview')}
                  className="px-4 py-2 rounded-xl text-xs font-semibold text-slate-400 hover:text-white"
                >
                  Cancel
                </button>
                <button
                  onClick={handleScheduleCampaign}
                  disabled={submittingSchedule}
                  className="px-5 py-2.5 rounded-xl text-xs font-bold bg-gradient-to-r from-emerald-500 to-teal-600 hover:from-emerald-400 hover:to-teal-500 text-white shadow-lg shadow-emerald-500/25 transition-all flex items-center gap-2"
                >
                  {submittingSchedule && <Clock className="w-3.5 h-3.5 animate-spin" />}
                  <span>Confirm Flight Schedule</span>
                </button>
              </div>
            </div>
          )}

          {/* TAB 5: DISCUSSIONS (Pillar 4) */}
          {activeTab === 'discussions' && (
            <div className="space-y-4">
              <div className="space-y-3 max-h-[350px] overflow-y-auto pr-1">
                {discussions.length === 0 ? (
                  <div className="text-center py-8 text-xs text-slate-500">
                    No discussions yet. Start collaborating by leaving a comment below!
                  </div>
                ) : (
                  discussions.map(msg => (
                    <div key={msg.message_id} className="p-3 rounded-xl glass-card border border-slate-800 space-y-1 text-xs">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-2">
                          <span className="font-bold text-slate-200">{msg.author_name}</span>
                          <span className="text-[10px] px-1.5 py-0.2 rounded bg-slate-800 text-slate-400 uppercase font-semibold">
                            {msg.author_role}
                          </span>
                        </div>
                        <span className="text-[10px] text-slate-500">
                          {new Date(msg.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                        </span>
                      </div>
                      <p className="text-slate-300 leading-relaxed pt-1">
                        {msg.content}
                      </p>
                    </div>
                  ))
                )}
              </div>

              {/* Add Comment Input */}
              <form onSubmit={handleSendComment} className="flex gap-2 pt-2 border-t border-slate-800">
                <input
                  type="text"
                  placeholder="Type comment or mention (@marketer, @reviewer)..."
                  value={commentText}
                  onChange={(e) => setCommentText(e.target.value)}
                  className="flex-1 p-2.5 bg-slate-900 border border-slate-700 rounded-xl text-xs text-slate-100 placeholder:text-slate-500 focus:outline-none focus:border-cyan-500"
                />
                <button
                  type="submit"
                  disabled={sendingComment || !commentText.trim()}
                  className="px-4 py-2.5 rounded-xl bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-bold text-xs disabled:opacity-50 transition-colors flex items-center gap-1.5"
                >
                  <Send className="w-3.5 h-3.5" />
                  <span>Send</span>
                </button>
              </form>
            </div>
          )}

          {/* TAB 6: AUDIT TRAIL */}
          {activeTab === 'audit' && (
            <div className="space-y-3">
              <div className="text-xs text-slate-400 mb-2">
                Append-only immutable audit trail for campaign <code>{campaign.campaign_id}</code>:
              </div>
              
              <div className="space-y-2">
                {campaign.decisions?.concat(campaign.versions || []).length === 0 ? (
                  <div className="text-xs text-slate-500">No events found.</div>
                ) : (
                  <div className="p-3 rounded-xl bg-slate-900/60 border border-slate-800 font-mono text-[11px] space-y-2">
                    <div className="text-cyan-400 font-bold">[AUDIT TIMELINE]</div>
                    <div className="text-slate-400">• Created as Draft (v1) by {campaign.owner_name} at {new Date(campaign.created_at).toLocaleString()}</div>
                    {campaign.versions?.filter(v => v.version_no > 1).map(v => (
                      <div key={v.version_id} className="text-slate-400">
                        • Revision created: Version v{v.version_no} (Budget: ${v.budget?.toLocaleString()}) at {new Date(v.created_at).toLocaleString()}
                      </div>
                    ))}
                    {campaign.decisions?.map(d => (
                      <div key={d.decision_id} className="text-emerald-400">
                        • Decision {d.decision_type} on version by {d.reviewer_name} at {new Date(d.decided_at).toLocaleString()} (Reason: "{d.reason}")
                      </div>
                    ))}
                    {campaign.schedule && (
                      <div className="text-purple-400">
                        • Scheduled on {campaign.schedule.channel} flight from {campaign.schedule.starts_at?.slice(0, 10)} to {campaign.schedule.ends_at?.slice(0, 10)}
                      </div>
                    )}
                  </div>
                )}
              </div>
            </div>
          )}

        </div>

      </div>
    </div>
  );
}

