import { useEffect, useState } from 'react';
import {
  RiSendPlaneLine,
  RiSparkling2Line,
  RiSaveLine,
} from '@remixicon/react';
import { AgentThinking } from '@/components/application/agent-thinking/agent-thinking';
import { Badge } from '@/components/base/badges/badge';
import { Button } from '@/components/base/buttons/button';
import { CloseButton } from '@/components/base/buttons/close-button';
import { Input } from '@/components/base/input/input';
import { Select, SelectItem } from '@/components/base/select/select';
import { Textarea } from '@/components/base/textarea/textarea';
import type { Campaign, KpiMetrics, WorkspaceUser } from './types';
import { workspaceApi } from './workspaceApi';

const CHANNELS = ['Social', 'Search', 'Email', 'Display', 'Video', 'Influencer'];

export function ProposalStudioModal({
  isOpen,
  campaign,
  currentUser,
  onClose,
  onSaved,
  onNotify,
}: {
  isOpen: boolean;
  campaign: Campaign | null;
  currentUser: WorkspaceUser;
  onClose: () => void;
  onSaved: () => Promise<void>;
  onNotify: (title: string, description: string, status?: 'success' | 'error' | 'information') => void;
}) {
  const isEditing = Boolean(campaign);
  const curVer = campaign?.current_version;

  const [title, setTitle] = useState('');
  const [channel, setChannel] = useState('Social');
  const [budget, setBudget] = useState('18000');
  const [objective, setObjective] = useState('');
  const [targetAudience, setTargetAudience] = useState('');
  const [aiPrompt, setAiPrompt] = useState('');
  const [aiSummary, setAiSummary] = useState('');
  const [kpi, setKpi] = useState<KpiMetrics>({
    conversionRate: 4.2,
    ctr: 4.8,
    roi: 4.6,
    cpa: 22.0,
    aov: 135.0,
  });
  const [generatingAi, setGeneratingAi] = useState(false);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!isOpen) return;
    setTitle(campaign?.title || '');
    setChannel(curVer?.channel || campaign?.channel || 'Social');
    setBudget(String(curVer?.budget ?? campaign?.budget ?? 18000));
    setObjective(curVer?.objective || campaign?.objective || '');
    setTargetAudience(curVer?.target_audience || campaign?.target_audience || '');
    setAiSummary(curVer?.ai_summary || '');
    setAiPrompt('');
    setKpi(
      curVer?.kpi_projected || {
        conversionRate: 4.2,
        ctr: 4.8,
        roi: 4.6,
        cpa: 22.0,
        aov: 135.0,
      },
    );
  }, [isOpen, campaign]);

  if (!isOpen) return null;

  const handleGenerateAi = async () => {
    setGeneratingAi(true);
    try {
      const draft = await workspaceApi.draftWithAI(
        {
          prompt: aiPrompt || title || 'Q4 Customer Acquisition Sprint',
          title,
          channel,
          budget: Number(budget) || 18000,
        },
        currentUser,
      );
      if (draft.title && !title.trim()) setTitle(draft.title);
      if (draft.objective) setObjective(draft.objective);
      if (draft.target_audience) setTargetAudience(draft.target_audience);
      if (draft.channel) setChannel(draft.channel);
      if (draft.budget) setBudget(String(draft.budget));
      if (draft.kpi_projected) setKpi(draft.kpi_projected);
      if (draft.ai_summary) setAiSummary(draft.ai_summary);
      onNotify('Proposal brief synthesized', 'Review generated targets and submit when ready.', 'success');
    } catch (err: unknown) {
      onNotify('AI assist failed', (err as Error).message, 'error');
    } finally {
      setGeneratingAi(false);
    }
  };

  const handleCommit = async (submitDirectly: boolean) => {
    if (!title.trim() || !objective.trim() || !targetAudience.trim()) {
      onNotify(
        'Missing required fields',
        'Title, objective, and target audience must all be filled out.',
        'error',
      );
      return;
    }

    setSaving(true);
    try {
      const payload = {
        title: title.trim(),
        channel,
        budget: Math.max(500, Number(budget) || 18000),
        objective: objective.trim(),
        target_audience: targetAudience.trim(),
        kpi_projected: kpi,
        ai_summary: aiSummary || undefined,
      };
      const saved =
        isEditing && campaign
          ? await workspaceApi.updateCampaign(
              campaign.campaign_id,
              payload,
              currentUser,
              curVer?.version_no,
            )
          : await workspaceApi.createCampaign(payload, currentUser);

      if (submitDirectly) {
        await workspaceApi.submitCampaign(saved.campaign_id, currentUser);
      }

      onNotify(
        submitDirectly ? 'Submitted for reviewer signoff' : 'Draft version saved',
        `${saved.title} · version v${saved.current_version?.version_no ?? 1}`,
        'success',
      );
      await onSaved();
      onClose();
    } catch (err: unknown) {
      onNotify('Could not save brief', (err as Error).message, 'error');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4 backdrop-blur-xs">
      <div
        role="dialog"
        aria-modal="true"
        aria-label={isEditing ? 'Revise campaign brief' : 'Author campaign proposal'}
        className="flex max-h-[90dvh] w-full max-w-2xl flex-col overflow-hidden rounded-3xl border border-border-button-default bg-background-primary-default shadow-waitlist"
      >
        {/* Header */}
        <div className="flex items-center justify-between border-b border-separator-border px-6 py-4">
          <div className="flex items-center gap-2.5">
            <h2 className="text-title-2-semibold text-text-primary">
              {isEditing ? `Revise ${campaign?.title}` : 'New campaign proposal'}
            </h2>
            <Badge color="neutral">
              {isEditing ? `Creates v${(curVer?.version_no ?? 1) + 1}` : 'Creates v1'}
            </Badge>
          </div>
          <CloseButton aria-label="Close proposal studio" onClick={onClose} />
        </div>

        {/* Body */}
        <div className="flex min-h-0 flex-1 flex-col gap-5 overflow-y-auto px-6 py-5">
          {/* Agentic AI Brief Assistant */}
          <div className="flex flex-col gap-3 rounded-2xl border border-border-button-default bg-background-secondary-default p-4">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div className="flex items-center gap-2">
                <RiSparkling2Line className="size-4 text-accent-600" aria-hidden />
                <span className="text-body-medium text-text-primary">AI brief assistant</span>
              </div>
              {generatingAi && (
                <AgentThinking variant="stars" label="Synthesizing KPI targets" showTimer />
              )}
            </div>
            <div className="flex flex-col gap-2 sm:flex-row">
              <div className="flex-1">
                <Input
                  placeholder="Describe launch goal, offer, or audience segment…"
                  value={aiPrompt}
                  onChange={setAiPrompt}
                  aria-label="AI brief prompt"
                />
              </div>
              <Button
                variant="secondary"
                size="medium"
                leadingIcon={RiSparkling2Line}
                onClick={handleGenerateAi}
                disabled={generatingAi}
              >
                {generatingAi ? 'Generating…' : 'Draft brief'}
              </Button>
            </div>
          </div>

          <Input
            label="Campaign title"
            placeholder="e.g. Q4 Enterprise Launch"
            value={title}
            onChange={setTitle}
            isRequired
          />

          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div className="flex flex-col gap-1.5">
              <span className="text-body-2-medium text-text-primary">Primary channel</span>
              <Select
                aria-label="Primary channel"
                selectedKey={channel}
                onSelectionChange={(key) => setChannel(String(key))}
                className="w-full"
                triggerClassName="w-full"
              >
                {CHANNELS.map((ch) => (
                  <SelectItem key={ch} id={ch} textValue={ch}>
                    {ch}
                  </SelectItem>
                ))}
              </Select>
            </div>

            <Input
              label="Total budget (USD)"
              type="number"
              value={budget}
              onChange={setBudget}
              isRequired
            />
          </div>

          <Textarea
            label="Campaign objective"
            placeholder="State measurable conversion goals, offer positioning, and guardrails…"
            rows={3}
            value={objective}
            onChange={setObjective}
            isRequired
          />

          <Textarea
            label="Target audience segment"
            placeholder="Specify buyer cohort, exclusions, and regional constraints…"
            rows={2}
            value={targetAudience}
            onChange={setTargetAudience}
            isRequired
          />

          {/* 5 Mandatory Projected KPIs */}
          <div className="flex flex-col gap-2.5 rounded-2xl border border-border-button-default bg-background-secondary-default p-4">
            <span className="text-body-medium text-text-primary">Projected KPI targets</span>
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-5">
              <Input
                label="CVR (%)"
                size="small"
                type="number"
                value={String(kpi.conversionRate)}
                onChange={(v) => setKpi({ ...kpi, conversionRate: Number(v) || 0 })}
              />
              <Input
                label="CTR (%)"
                size="small"
                type="number"
                value={String(kpi.ctr)}
                onChange={(v) => setKpi({ ...kpi, ctr: Number(v) || 0 })}
              />
              <Input
                label="ROI (x)"
                size="small"
                type="number"
                value={String(kpi.roi)}
                onChange={(v) => setKpi({ ...kpi, roi: Number(v) || 0 })}
              />
              <Input
                label="CPA ($)"
                size="small"
                type="number"
                value={String(kpi.cpa)}
                onChange={(v) => setKpi({ ...kpi, cpa: Number(v) || 0 })}
              />
              <Input
                label="AOV ($)"
                size="small"
                type="number"
                value={String(kpi.aov)}
                onChange={(v) => setKpi({ ...kpi, aov: Number(v) || 0 })}
              />
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="flex flex-wrap items-center justify-end gap-2.5 border-t border-separator-border px-6 py-4">
          <Button variant="ghost" onClick={onClose} disabled={saving}>
            Cancel
          </Button>
          <Button
            variant="secondary"
            leadingIcon={RiSaveLine}
            onClick={() => handleCommit(false)}
            disabled={saving || generatingAi}
          >
            Save draft
          </Button>
          <Button
            variant="primary"
            leadingIcon={RiSendPlaneLine}
            onClick={() => handleCommit(true)}
            disabled={saving || generatingAi}
          >
            {saving ? 'Submitting…' : generatingAi ? 'Drafting with AI…' : 'Save & submit for review'}
          </Button>
        </div>
      </div>
    </div>
  );
}

