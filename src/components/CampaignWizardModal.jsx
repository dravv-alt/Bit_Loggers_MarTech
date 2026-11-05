import React, { useState } from 'react';
import { 
  X, 
  Sparkles, 
  ArrowRight, 
  DollarSign, 
  Layers, 
  Target, 
  BarChart3, 
  Send, 
  Clock, 
  CheckCircle2, 
  AlertTriangle,
  Lightbulb
} from 'lucide-react';
import { api } from '../api.js';

export default function CampaignWizardModal({ 
  campaign, 
  currentUser, 
  onClose, 
  onSuccess, 
  showToast 
}) {
  const isEditing = Boolean(campaign);
  const curVer = campaign?.current_version || {};
  const initialKpi = curVer.kpi_projected || {
    conversionRate: 3.5,
    ctr: 4.2,
    roi: 3.8,
    cpa: 25.0,
    aov: 95.0
  };

  const [title, setTitle] = useState(campaign?.title || '');
  const [channel, setChannel] = useState(curVer.channel || 'Social');
  const [budget, setBudget] = useState(curVer.budget || 12000);
  const [objective, setObjective] = useState(curVer.objective || '');
  const [targetAudience, setTargetAudience] = useState(curVer.target_audience || '');
  const [kpi, setKpi] = useState(initialKpi);
  const [aiSummary, setAiSummary] = useState(curVer.ai_summary || '');

  // AI Assist state
  const [aiPrompt, setAiPrompt] = useState('');
  const [isGeneratingAi, setIsGeneratingAi] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  // Gemini AI proposal generation
  const handleGenerateAi = async () => {
    setIsGeneratingAi(true);
    try {
      const res = await api.draftAI({
        prompt: aiPrompt || title || 'Q4 High-Growth Customer Acquisition Surge',
        title,
        channel,
        budget
      }, currentUser);

      setTitle(res.title || title);
      setObjective(res.objective || objective);
      setTargetAudience(res.target_audience || targetAudience);
      setChannel(res.channel || channel);
      setBudget(res.budget || budget);
      if (res.kpi_projected) setKpi(res.kpi_projected);
      if (res.ai_summary) setAiSummary(res.ai_summary);

      showToast('Gemini Argon proposal drafted! Review and customize below.', 'success');
    } catch (err) {
      showToast(err.message, 'error');
    } finally {
      setIsGeneratingAi(false);
    }
  };

  // Save as Draft or Submit
  const handleSave = async (submitDirectly = false) => {
    if (!title.trim()) {
      showToast('Please provide a campaign title.', 'error');
      return;
    }
    if (!objective.trim()) {
      showToast('Please provide a campaign objective.', 'error');
      return;
    }
    if (!targetAudience.trim()) {
      showToast('Please specify the target audience.', 'error');
      return;
    }

    setSubmitting(true);
    try {
      let savedCamp;
      const payload = {
        title: title.trim(),
        channel,
        budget: Number(budget),
        objective: objective.trim(),
        target_audience: targetAudience.trim(),
        kpi_projected: kpi,
        ai_summary: aiSummary
      };

      if (isEditing) {
        // Optimistic concurrency protection: expected_version
        savedCamp = await api.updateCampaign(
          campaign.campaign_id, 
          payload, 
          currentUser, 
          curVer.version_no
        );
        showToast(`Campaign updated successfully (Version v${savedCamp.current_version?.version_no}).`, 'success');
      } else {
        savedCamp = await api.createCampaign(payload, currentUser);
        showToast('Campaign proposal drafted (Version v1).', 'success');
      }

      if (submitDirectly) {
        const idemKey = 'submit-wizard-' + Date.now();
        await api.submitCampaign(savedCamp.campaign_id, currentUser, idemKey);
        showToast('Campaign submitted to reviewers with Idempotency Key protection.', 'success');
      }

      onSuccess();
    } catch (err) {
      showToast(err.message, 'error');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-2 sm:p-4 bg-black/80 backdrop-blur-md overflow-y-auto">
      <div className="glass-panel rounded-2xl w-full max-w-3xl max-h-[92vh] flex flex-col border border-slate-700/80 shadow-2xl overflow-hidden animate-in fade-in zoom-in-95 duration-150">
        
        {/* Modal Header */}
        <div className="p-4 sm:p-5 border-b border-slate-800 flex items-center justify-between bg-slate-900/60">
          <div>
            <div className="flex items-center gap-2">
              <span className="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-cyan-500/20 text-cyan-300 border border-cyan-500/30">
                {isEditing ? `Revise proposal (v${curVer.version_no})` : 'New proposal'}
              </span>
              <span className="text-xs text-slate-400">Pillar 4: Human-verified AI</span>
            </div>
            <h2 className="text-lg font-extrabold text-slate-100 tracking-tight">
              {isEditing ? 'Revise & Refine Campaign Proposal' : 'Author Campaign Proposal'}
            </h2>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-400 hover:text-white transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan-400 active:opacity-90 disabled:opacity-50"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Modal Body */}
        <div className="p-4 sm:p-6 overflow-y-auto flex-1 space-y-6">

          {/* AI Drafting Assistant (Pillar 4) */}
          <div className="p-4 rounded-xl bg-slate-900 border border-cyan-500/40 space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2 text-xs font-semibold text-cyan-300">
                <Sparkles className="w-4 h-4 text-cyan-400" />
                Gemini Argon AI proposal strategist
              </div>
              <span className="text-[10px] text-slate-400">LLM-assisted drafting</span>
            </div>

            <p className="text-xs text-slate-300">
              Enter your campaign concept or marketing goal. Gemini will structure the strategic objective, audience persona, and forecast the 5 core KPIs.
            </p>

            <div className="flex gap-2">
              <input
                type="text"
                placeholder="e.g. Q4 Black Friday early access blitz targeting high-value loyalty members…"
                value={aiPrompt}
                onChange={(e) => setAiPrompt(e.target.value)}
                className="flex-1 p-2.5 bg-slate-900 border border-slate-700 rounded-xl text-xs text-slate-100 placeholder:text-slate-500 focus:outline-none focus:border-cyan-400"
              />
              <button
                type="button"
                onClick={handleGenerateAi}
                disabled={isGeneratingAi}
                className="px-4 py-2.5 rounded-xl bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-semibold text-xs transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan-300 active:opacity-90 disabled:opacity-50 flex items-center gap-1.5 shrink-0"
              >
                {isGeneratingAi ? <Clock className="w-3.5 h-3.5 motion-safe:animate-spin" /> : <Sparkles className="w-3.5 h-3.5" />}
                <span>{isGeneratingAi ? 'Drafting…' : 'Generate AI brief'}</span>
              </button>
            </div>

            {/* Quick Prompt Starters */}
            <div className="flex flex-wrap gap-1.5 pt-1">
              {[
                'Summer Solar Flash Sale (Social)',
                'Black Friday VIP Early Access (Email)',
                'Enterprise AI Copilot Rollout (Search)'
              ].map(starter => (
                <button
                  key={starter}
                  type="button"
                  onClick={() => setAiPrompt(starter)}
                  className="px-2 py-0.5 rounded-md text-[10px] bg-slate-800 hover:bg-slate-700 text-slate-300 border border-slate-700 transition-colors"
                >
                  + {starter}
                </button>
              ))}
            </div>
          </div>

          {/* Form Fields */}
          <div className="space-y-4">
            {/* Title & Channel */}
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
              <div className="sm:col-span-2">
                <label className="block text-xs font-bold text-slate-300 mb-1">Campaign Title *</label>
                <input
                  type="text"
                  placeholder="e.g. Summer Solar Flash Sale"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  className="w-full p-2.5 bg-slate-900 border border-slate-700 rounded-xl text-xs text-slate-100 placeholder:text-slate-500 focus:outline-none focus:border-cyan-500"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-300 mb-1">Marketing Channel</label>
                <select
                  value={channel}
                  onChange={(e) => setChannel(e.target.value)}
                  className="w-full p-2.5 bg-slate-900 border border-slate-700 rounded-xl text-xs text-slate-100 focus:outline-none focus:border-cyan-500"
                >
                  <option value="Social">Social</option>
                  <option value="Email">Email</option>
                  <option value="Search">Search</option>
                  <option value="Display">Display</option>
                  <option value="Influencer">Influencer</option>
                  <option value="Video">Video</option>
                </select>
              </div>
            </div>

            {/* Total Budget */}
            <div>
              <label className="block text-xs font-bold text-slate-300 mb-1">
                Allocated Budget (USD $) *
                {isEditing && curVer.budget !== Number(budget) && (
                  <span className="text-[10px] text-amber-400 font-normal ml-2">
                    (Changing budget triggers a new immutable version v{curVer.version_no + 1})
                  </span>
                )}
              </label>
              <div className="relative">
                <DollarSign className="w-4 h-4 text-slate-500 absolute left-3 top-2.5" />
                <input
                  type="number"
                  min="500"
                  step="500"
                  value={budget}
                  onChange={(e) => setBudget(e.target.value)}
                  className="w-full pl-9 pr-3 py-2 bg-slate-900 border border-slate-700 rounded-xl text-xs font-mono font-bold text-slate-100 focus:outline-none focus:border-cyan-500"
                />
              </div>
            </div>

            {/* Strategic Objective */}
            <div>
              <label className="block text-xs font-bold text-slate-300 mb-1">Strategic Objective *</label>
              <textarea
                rows={3}
                placeholder="State the primary marketing and business conversion objective..."
                value={objective}
                onChange={(e) => setObjective(e.target.value)}
                className="w-full p-2.5 bg-slate-900 border border-slate-700 rounded-xl text-xs text-slate-100 placeholder:text-slate-500 focus:outline-none focus:border-cyan-500"
              />
            </div>

            {/* Target Audience */}
            <div>
              <label className="block text-xs font-bold text-slate-300 mb-1">
                Target Audience Persona *
                {isEditing && curVer.target_audience !== targetAudience && (
                  <span className="text-[10px] text-amber-400 font-normal ml-2">
                    (Modifying audience forces re-review per MarTech rules)
                  </span>
                )}
              </label>
              <textarea
                rows={2}
                placeholder="Demographics, segments, behavioral characteristics..."
                value={targetAudience}
                onChange={(e) => setTargetAudience(e.target.value)}
                className="w-full p-2.5 bg-slate-900 border border-slate-700 rounded-xl text-xs text-slate-100 placeholder:text-slate-500 focus:outline-none focus:border-cyan-500"
              />
            </div>

            {/* 5 Mandatory KPIs Projections (Pillar 2) */}
            <div className="p-4 rounded-xl bg-slate-900 border border-slate-800 space-y-3">
              <div className="flex items-center justify-between text-xs font-semibold text-slate-300">
                <span>Projected KPIs (Pillar 2 requirement)</span>
                <span className="text-[10px] text-slate-400 font-normal">5 required metrics</span>
              </div>

              <div className="grid grid-cols-2 sm:grid-cols-5 gap-2.5 text-xs font-mono">
                <div>
                  <label className="block text-[10px] text-slate-400 mb-1 font-sans">Conv. Rate (%)</label>
                  <input
                    type="number"
                    step="0.1"
                    value={kpi.conversionRate || 3.5}
                    onChange={(e) => setKpi({ ...kpi, conversionRate: parseFloat(e.target.value) || 0 })}
                    className="w-full p-1.5 bg-slate-800 border border-slate-700 rounded-lg text-cyan-400 font-bold"
                  />
                </div>

                <div>
                  <label className="block text-[10px] text-slate-400 mb-1 font-sans">CTR (%)</label>
                  <input
                    type="number"
                    step="0.1"
                    value={kpi.ctr || 4.2}
                    onChange={(e) => setKpi({ ...kpi, ctr: parseFloat(e.target.value) || 0 })}
                    className="w-full p-1.5 bg-slate-800 border border-slate-700 rounded-lg text-blue-400 font-bold"
                  />
                </div>

                <div>
                  <label className="block text-[10px] text-slate-400 mb-1 font-sans">ROI (x)</label>
                  <input
                    type="number"
                    step="0.1"
                    value={kpi.roi || 3.8}
                    onChange={(e) => setKpi({ ...kpi, roi: parseFloat(e.target.value) || 0 })}
                    className="w-full p-1.5 bg-slate-800 border border-slate-700 rounded-lg text-emerald-400 font-bold"
                  />
                </div>

                <div>
                  <label className="block text-[10px] text-slate-400 mb-1 font-sans">CPA ($)</label>
                  <input
                    type="number"
                    step="1"
                    value={kpi.cpa || 25}
                    onChange={(e) => setKpi({ ...kpi, cpa: parseFloat(e.target.value) || 0 })}
                    className="w-full p-1.5 bg-slate-800 border border-slate-700 rounded-lg text-amber-400 font-bold"
                  />
                </div>

                <div className="col-span-2 sm:col-span-1">
                  <label className="block text-[10px] text-slate-400 mb-1 font-sans">AOV ($)</label>
                  <input
                    type="number"
                    step="1"
                    value={kpi.aov || 95}
                    onChange={(e) => setKpi({ ...kpi, aov: parseFloat(e.target.value) || 0 })}
                    className="w-full p-1.5 bg-slate-800 border border-slate-700 rounded-lg text-purple-400 font-bold"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Modal Footer */}
        <div className="p-4 sm:p-5 border-t border-slate-800 flex items-center justify-between bg-slate-900/60">
          <button
            type="button"
            onClick={onClose}
            className="px-4 py-2 rounded-xl text-xs font-semibold text-slate-400 hover:text-white transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-400 active:opacity-90 disabled:opacity-50"
          >
            Cancel
          </button>

          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={() => handleSave(false)}
              disabled={submitting}
              className="px-4 py-2 rounded-xl text-xs font-semibold bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-400 active:opacity-90 disabled:opacity-50"
            >
              Save as draft
            </button>
            <button
              type="button"
              onClick={() => handleSave(true)}
              disabled={submitting}
              className="px-5 py-2 rounded-xl text-xs font-semibold bg-cyan-500 hover:bg-cyan-400 text-slate-950 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan-300 active:opacity-90 disabled:opacity-50 flex items-center gap-1.5 shadow-md shadow-cyan-500/20"
            >
              {submitting && <Clock className="w-3.5 h-3.5 motion-safe:animate-spin" />}
              <span>{isEditing ? 'Save and submit revision' : 'Submit for review'}</span>
              <ArrowRight className="w-3.5 h-3.5" />
            </button>
          </div>
        </div>

      </div>
    </div>
  );
}

