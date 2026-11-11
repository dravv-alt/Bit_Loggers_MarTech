import { useEffect, useState } from 'react';
import {
  RiCalendarLine,
  RiChat3Line,
  RiCheckDoubleLine,
  RiEditLine,
  RiErrorWarningFill,
  RiGitBranchLine,
  RiHistoryLine,
  RiLockLine,
  RiLockUnlockLine,
  RiSendPlaneLine,
  RiShieldCheckLine,
} from '@remixicon/react';
import { Avatar } from '@/components/base/avatar/avatar';
import { Badge } from '@/components/base/badges/badge';
import { Chip } from '@/components/base/badges/chip';
import { Button } from '@/components/base/buttons/button';
import { CloseButton } from '@/components/base/buttons/close-button';
import { Input } from '@/components/base/input/input';
import { Notification } from '@/components/base/notification/notification';
import {
  SegmentedControl,
  SegmentedControlItem,
} from '@/components/base/segmented-control/segmented-control';
import { Select, SelectItem } from '@/components/base/select/select';
import { Tab, TabList, TabPanel, Tabs } from '@/components/base/tabs/tabs';
import { Textarea } from '@/components/base/textarea/textarea';
import { evaluateCampaignCapabilities } from './stateMachine';
import type { Campaign, DiscussionMessage, WorkspaceUser } from './types';
import {
  STATUS_CHIP_COLOR,
  channelChipColor,
  formatMoney,
  formatRelativeTime,
  statusLabel,
  workspaceApi,
} from './workspaceApi';

const CHANNELS = ['Social', 'Search', 'Email', 'Display', 'Video', 'Influencer'];

export function CampaignDetailDrawer({
  campaignId,
  initialTab = 'overview',
  currentUser,
  onClose,
  onEditCampaign,
  onMutated,
  onNotify,
}: {
  campaignId: string | null;
  initialTab?: string;
  currentUser: WorkspaceUser;
  onClose: () => void;
  onEditCampaign: (campaign: Campaign) => void;
  onMutated: () => Promise<void>;
  onNotify: (title: string, description: string, status?: 'success' | 'error' | 'information') => void;
}) {
  const [campaign, setCampaign] = useState<Campaign | null>(null);
  const [discussions, setDiscussions] = useState<DiscussionMessage[]>([]);
  const [activeTab, setActiveTab] = useState(initialTab);
  const [loading, setLoading] = useState(false);

  // Decision state
  const [decisionType, setDecisionType] = useState<'APPROVED' | 'CHANGES_REQUESTED' | 'REJECTED'>(
    'APPROVED',
  );
  const [reason, setReason] = useState('');
  const [policyRef, setPolicyRef] = useState('');
  const [submittingDecision, setSubmittingDecision] = useState(false);

  // Schedule state
  const [schedChannel, setSchedChannel] = useState('Social');
  const [startDate, setStartDate] = useState(() => new Date().toISOString().slice(0, 10));
  const [endDate, setEndDate] = useState(() =>
    new Date(Date.now() + 10 * 86400000).toISOString().slice(0, 10),
  );
  const [submittingSchedule, setSubmittingSchedule] = useState(false);

  // Comment state
  const [commentText, setCommentText] = useState('');
  const [sendingComment, setSendingComment] = useState(false);
  const [togglingLock, setTogglingLock] = useState(false);

  const load = async (id: string) => {
    setLoading(true);
    try {
      const [camp, msgs] = await Promise.all([
        workspaceApi.getCampaign(id, currentUser),
        workspaceApi.getDiscussions(id, currentUser),
      ]);
      setCampaign(camp);
      setDiscussions(msgs);
      setSchedChannel(camp.current_version?.channel || camp.channel || 'Social');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    setActiveTab(initialTab);
  }, [initialTab, campaignId]);

  useEffect(() => {
    if (campaignId) load(campaignId);
  }, [campaignId, currentUser.id]);

  if (!campaignId) return null;

  const versions = [...(campaign?.versions || [])].sort((a, b) => a.version_no - b.version_no);
  const curVer = campaign?.current_version || versions[versions.length - 1];
  const prevVer = versions.length > 1 ? versions[versions.length - 2] : null;
  const caps = campaign ? evaluateCampaignCapabilities(campaign, currentUser) : null;
  const canEdit = Boolean(caps?.canEdit);
  const canApprove = Boolean(caps?.canReview);
  const isLockedByMe = caps?.lockInfo.status === 'held_by_me';

  const handleToggleLock = async () => {
    if (!campaign || togglingLock) return;
    setTogglingLock(true);
    try {
      if (isLockedByMe) {
        await workspaceApi.releaseLock(campaign.campaign_id, currentUser);
        onNotify('Edit lease released', 'Other authors can now revise this brief.', 'information');
      } else {
        const res = await workspaceApi.acquireLock(campaign.campaign_id, currentUser);
        if (res && res.granted === false) {
          onNotify(
            'Edit lease unavailable',
            res.holder_name ? `Held by ${res.holder_name}.` : 'Held by another editor.',
            'error',
          );
          return;
        }
        onNotify(
          '5-minute edit lease acquired',
          'Your draft edits are protected from concurrent overwrites.',
          'success',
        );
      }
      await load(campaign.campaign_id);
      await onMutated();
    } catch (err: unknown) {
      onNotify('Lease action failed', (err as Error).message, 'error');
    } finally {
      setTogglingLock(false);
    }
  };

  const handleSubmitForReview = async () => {
    if (!campaign) return;
    try {
      await workspaceApi.submitCampaign(campaign.campaign_id, currentUser);
      onNotify('Submitted for review', `${campaign.title} moved to reviewer queue.`, 'success');
      await load(campaign.campaign_id);
      await onMutated();
    } catch (err: unknown) {
      onNotify('Submission failed', (err as Error).message, 'error');
    }
  };

  const handleRecordDecision = async () => {
    if (!campaign || !curVer) return;
    if (!reason.trim()) {
      onNotify('Rationale required', 'Provide compliance or optimization feedback before saving a decision.', 'error');
      return;
    }
    setSubmittingDecision(true);
    try {
      await workspaceApi.makeDecision(
        campaign.campaign_id,
        decisionType,
        {
          version_id: curVer.version_id,
          reason: reason.trim(),
          policy_reference: policyRef.trim() || undefined,
        },
        currentUser,
      );
      setReason('');
      setPolicyRef('');
      onNotify('Review decision recorded', `Recorded ${decisionType.replaceAll('_', ' ')} on v${curVer.version_no}.`, 'success');
      await load(campaign.campaign_id);
      await onMutated();
      setActiveTab('overview');
    } catch (err: unknown) {
      onNotify('Decision blocked', (err as Error).message, 'error');
    } finally {
      setSubmittingDecision(false);
    }
  };

  const handleSchedule = async () => {
    if (!campaign || !curVer) return;
    setSubmittingSchedule(true);
    try {
      await workspaceApi.scheduleCampaign(
        campaign.campaign_id,
        {
          version_id: curVer.version_id,
          channel: schedChannel,
          starts_at: new Date(startDate).toISOString(),
          ends_at: new Date(endDate).toISOString(),
        },
        currentUser,
      );
      onNotify('Flight scheduled cleanly', `${campaign.title} locked on ${schedChannel}.`, 'success');
      await load(campaign.campaign_id);
      await onMutated();
      setActiveTab('overview');
    } catch (err: unknown) {
      onNotify('Schedule blocked', (err as Error).message, 'error');
    } finally {
      setSubmittingSchedule(false);
    }
  };

  const handleSendComment = async () => {
    if (!campaign || !commentText.trim()) return;
    setSendingComment(true);
    try {
      await workspaceApi.postDiscussion(campaign.campaign_id, commentText.trim(), currentUser);
      setCommentText('');
      await load(campaign.campaign_id);
      await onMutated();
    } finally {
      setSendingComment(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex justify-end bg-black/40 backdrop-blur-xs">
      <div
        role="dialog"
        aria-modal="true"
        aria-label={campaign?.title || 'Campaign detail'}
        className="flex h-full w-full max-w-3xl flex-col overflow-hidden border-s border-border-button-default bg-background-primary-default shadow-waitlist"
      >
        {/* Top Drawer Bar */}
        <header className="flex flex-wrap items-start justify-between gap-3 border-b border-separator-border px-6 py-4">
          <div className="flex min-w-0 flex-1 flex-col gap-1.5">
            <div className="flex flex-wrap items-center gap-2">
              {campaign && (
                <>
                  <Chip variant="bold" color={STATUS_CHIP_COLOR[campaign.status] || 'neutral'}>
                    {statusLabel(campaign.status)}
                  </Chip>
                  <Chip variant="caption" color={channelChipColor(campaign.channel)}>
                    {campaign.channel}
                  </Chip>
                  <Badge color="neutral">v{curVer?.version_no ?? 1}</Badge>
                </>
              )}
            </div>
            <h2 className="truncate text-title-1-semibold text-text-primary">
              {loading && !campaign ? 'Loading brief…' : campaign?.title}
            </h2>
            {campaign && (
              <p className="text-body-2-regular text-text-secondary">
                Owned by {campaign.owner_name || 'Alice Cooper'} · Updated{' '}
                {formatRelativeTime(campaign.updated_at)}
              </p>
            )}
          </div>

          <div className="flex shrink-0 items-center gap-2">
            {campaign && canEdit && (
              <>
                <Button
                  size="small"
                  variant="secondary"
                  leadingIcon={isLockedByMe ? RiLockUnlockLine : RiLockLine}
                  disabled={togglingLock}
                  onClick={handleToggleLock}
                >
                  {togglingLock
                    ? 'Updating…'
                    : isLockedByMe
                      ? 'Release lock'
                      : 'Lease edit'}
                </Button>
                <Button
                  size="small"
                  variant="secondary"
                  leadingIcon={RiEditLine}
                  onClick={() => {
                    onClose();
                    onEditCampaign(campaign);
                  }}
                >
                  Revise
                </Button>
              </>
            )}
            <CloseButton aria-label="Close detail" onClick={onClose} />
          </div>
        </header>

        {/* Scrollable Content */}
        {campaign && (
          <div className="flex min-h-0 flex-1 flex-col overflow-y-auto px-6 py-5">
            <Tabs selectedKey={activeTab} onSelectionChange={(key) => setActiveTab(String(key))}>
              <TabList aria-label="Campaign detail tabs" className="overflow-x-auto">
                <Tab id="overview" icon={RiShieldCheckLine}>
                  Overview
                </Tab>
                <Tab id="versions" icon={RiHistoryLine} count={versions.length}>
                  Versions
                </Tab>
                <Tab id="review" icon={RiCheckDoubleLine} count={campaign.decisions?.length || 0}>
                  Review gate
                </Tab>
                <Tab id="schedule" icon={RiCalendarLine}>
                  Flight window
                </Tab>
                <Tab id="discussions" icon={RiChat3Line} count={discussions.length}>
                  Discussion
                </Tab>
              </TabList>

              {/* TAB 1: OVERVIEW */}
              <TabPanel id="overview" className="flex flex-col gap-5 pt-2">
                {prevVer && curVer && (
                  <div className="flex flex-wrap items-center justify-between gap-2 rounded-2xl border border-border-button-default bg-background-secondary-default px-4 py-3">
                    <div className="flex items-center gap-2">
                      <RiGitBranchLine className="size-4 text-accent-600" aria-hidden />
                      <span className="text-body-medium text-text-primary">
                        Budget change from v{prevVer.version_no} → v{curVer.version_no}:
                      </span>
                    </div>
                    <Chip
                      variant="bold"
                      color={curVer.budget >= prevVer.budget ? 'yellow' : 'lime'}
                    >
                      {formatMoney(prevVer.budget)} → {formatMoney(curVer.budget)}
                    </Chip>
                  </div>
                )}

                <div className="grid grid-cols-2 gap-3 sm:grid-cols-5">
                  <div className="rounded-2xl border border-border-button-default bg-background-secondary-default p-3.5">
                    <span className="block text-caption-1-medium text-text-tertiary">Budget</span>
                    <span className="text-title-2-medium text-text-primary tabular-nums">
                      {formatMoney(curVer?.budget ?? campaign.budget)}
                    </span>
                  </div>
                  <div className="rounded-2xl border border-border-button-default bg-background-secondary-default p-3.5">
                    <span className="block text-caption-1-medium text-text-tertiary">Est. CVR</span>
                    <span className="text-title-2-medium text-text-primary tabular-nums">
                      {curVer?.kpi_projected?.conversionRate.toFixed(1) ?? '4.2'}%
                    </span>
                  </div>
                  <div className="rounded-2xl border border-border-button-default bg-background-secondary-default p-3.5">
                    <span className="block text-caption-1-medium text-text-tertiary">Est. CTR</span>
                    <span className="text-title-2-medium text-text-primary tabular-nums">
                      {curVer?.kpi_projected?.ctr.toFixed(1) ?? '4.8'}%
                    </span>
                  </div>
                  <div className="rounded-2xl border border-border-button-default bg-background-secondary-default p-3.5">
                    <span className="block text-caption-1-medium text-text-tertiary">Est. ROI</span>
                    <span className="text-title-2-medium text-text-primary tabular-nums">
                      {curVer?.kpi_projected?.roi.toFixed(1) ?? '4.6'}x
                    </span>
                  </div>
                  <div className="rounded-2xl border border-border-button-default bg-background-secondary-default p-3.5">
                    <span className="block text-caption-1-medium text-text-tertiary">CPA ceiling</span>
                    <span className="text-title-2-medium text-text-primary tabular-nums">
                      ${curVer?.kpi_projected?.cpa.toFixed(0) ?? '22'}
                    </span>
                  </div>
                </div>

                <div className="flex flex-col gap-4 rounded-2xl border border-border-button-default bg-background-secondary-default p-4">
                  <div>
                    <h4 className="text-caption-1-semibold text-text-tertiary">Campaign objective</h4>
                    <p className="mt-1 text-body-regular text-text-primary">
                      {curVer?.objective || campaign.objective}
                    </p>
                  </div>
                  <div className="border-t border-separator-border pt-3">
                    <h4 className="text-caption-1-semibold text-text-tertiary">Target audience</h4>
                    <p className="mt-1 text-body-regular text-text-primary">
                      {curVer?.target_audience || campaign.target_audience}
                    </p>
                  </div>
                  {curVer?.ai_summary && (
                    <div className="border-t border-separator-border pt-3">
                      <h4 className="text-caption-1-semibold text-text-tertiary">Governance note</h4>
                      <p className="mt-1 text-body-regular text-text-secondary">
                        {curVer.ai_summary}
                      </p>
                    </div>
                  )}
                </div>

                {caps?.canSubmit && (
                  <div className="flex justify-end">
                    <Button
                      variant="primary"
                      leadingIcon={RiSendPlaneLine}
                      onClick={handleSubmitForReview}
                    >
                      Submit v{curVer?.version_no ?? 1} for review
                    </Button>
                  </div>
                )}
              </TabPanel>

              {/* TAB 2: VERSION LINEAGE */}
              <TabPanel id="versions" className="flex flex-col gap-3 pt-2">
                {versions.map((v) => {
                  const decision = (campaign.decisions || []).find((d) => d.version_id === v.version_id);
                  const isHead = v.version_id === campaign.current_version_id;
                  return (
                    <div
                      key={v.version_id}
                      className="flex flex-col gap-2.5 rounded-2xl border border-border-button-default bg-background-secondary-default p-4"
                    >
                      <div className="flex flex-wrap items-center justify-between gap-2">
                        <div className="flex items-center gap-2">
                          <Badge color={isHead ? 'primary' : 'neutral'}>Version {v.version_no}</Badge>
                          <Chip variant="caption" color={channelChipColor(v.channel)}>
                            {v.channel}
                          </Chip>
                          <span className="text-body-medium text-text-primary tabular-nums">
                            {formatMoney(v.budget)}
                          </span>
                        </div>
                        <span className="text-caption-1-medium text-text-tertiary">
                          {formatRelativeTime(v.created_at)}
                        </span>
                      </div>

                      <p className="text-body-regular text-text-primary">{v.objective}</p>
                      <p className="text-body-2-regular text-text-secondary">
                        Audience: {v.target_audience}
                      </p>

                      {decision && (
                        <div className="flex items-start gap-2 rounded-xl border border-separator-border bg-background-inner-default px-3 py-2">
                          <Chip
                            variant="caption"
                            color={
                              decision.decision === 'APPROVED'
                                ? 'lime'
                                : decision.decision === 'CHANGES_REQUESTED'
                                  ? 'orange'
                                  : 'rose'
                            }
                          >
                            {decision.decision.replaceAll('_', ' ')}
                          </Chip>
                          <span className="text-body-2-regular text-text-secondary">
                            {decision.reviewer_name || 'Reviewer'}: {decision.reason}
                          </span>
                        </div>
                      )}
                    </div>
                  );
                })}
              </TabPanel>

              {/* TAB 3: REVIEW GATE */}
              <TabPanel id="review" className="flex flex-col gap-4 pt-2">
                {!caps?.canReview && (
                  <Notification
                    status="information"
                    title={
                      caps?.isOwner && !caps.isAdmin
                        ? 'Owner self-approval lock active'
                        : 'Review gate locked'
                    }
                    description={
                      caps?.reviewBlockedReason ||
                      'Separation of duties prevents campaign authors from approving their own brief.'
                    }
                    dismissible={false}
                    className="w-full max-w-none"
                  />
                )}

                <div className="flex flex-col gap-4 rounded-2xl border border-border-button-default bg-background-secondary-default p-4">
                  <div className="flex items-center justify-between">
                    <span className="text-body-medium text-text-primary">
                      Decision on v{curVer?.version_no ?? 1}
                    </span>
                    <SegmentedControl
                      aria-label="Decision type"
                      selectedKeys={[decisionType]}
                      onSelectionChange={(keys) => {
                        const val = Array.from(keys)[0] as
                          | 'APPROVED'
                          | 'CHANGES_REQUESTED'
                          | 'REJECTED';
                        if (val) setDecisionType(val);
                      }}
                    >
                      <SegmentedControlItem id="APPROVED">Approve</SegmentedControlItem>
                      <SegmentedControlItem id="CHANGES_REQUESTED">
                        Request changes
                      </SegmentedControlItem>
                      <SegmentedControlItem id="REJECTED">Reject</SegmentedControlItem>
                    </SegmentedControl>
                  </div>

                  <Textarea
                    label="Decision rationale"
                    placeholder="Explain policy compliance, CPA verification, or requested revisions…"
                    rows={3}
                    value={reason}
                    onChange={setReason}
                    isRequired
                  />

                  <Input
                    label="Policy reference (optional)"
                    placeholder="e.g. POL-CPA-2026"
                    value={policyRef}
                    onChange={setPolicyRef}
                  />

                  <div className="flex justify-end">
                    <Button
                      variant={decisionType === 'REJECTED' ? 'danger' : 'primary'}
                      leadingIcon={
                        decisionType === 'REJECTED' ? RiErrorWarningFill : RiCheckDoubleLine
                      }
                      disabled={!caps?.canReview || submittingDecision}
                      onClick={handleRecordDecision}
                    >
                      {submittingDecision
                        ? 'Recording…'
                        : `Record ${decisionType === 'APPROVED' ? 'approval' : decisionType === 'CHANGES_REQUESTED' ? 'change request' : 'rejection'}`}
                    </Button>
                  </div>
                </div>
              </TabPanel>

              {/* TAB 4: SCHEDULE */}
              <TabPanel id="schedule" className="flex flex-col gap-4 pt-2">
                {!caps?.canSchedule && (
                  <Notification
                    status="error"
                    title={
                      caps?.stage !== 'Approved' && caps?.stage !== 'Scheduled'
                        ? 'Approval required before scheduling'
                        : 'Schedule permission restricted'
                    }
                    description={
                      caps?.scheduleBlockedReason ||
                      'Only approved versions can lock a slot on the production channel calendar.'
                    }
                    dismissible={false}
                    className="w-full max-w-none"
                  />
                )}

                <div className="flex flex-col gap-4 rounded-2xl border border-border-button-default bg-background-secondary-default p-4">
                  <div className="flex flex-col gap-1.5">
                    <span className="text-body-2-medium text-text-primary">Channel lane</span>
                    <Select
                      aria-label="Schedule channel"
                      selectedKey={schedChannel}
                      onSelectionChange={(k) => setSchedChannel(String(k))}
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

                  <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                    <Input label="Start date" type="date" value={startDate} onChange={setStartDate} />
                    <Input label="End date" type="date" value={endDate} onChange={setEndDate} />
                  </div>

                  <div className="flex justify-end">
                    <Button
                      variant="primary"
                      leadingIcon={RiCalendarLine}
                      disabled={!caps?.canSchedule || submittingSchedule}
                      onClick={handleSchedule}
                    >
                      {submittingSchedule ? 'Checking collisions…' : 'Confirm flight window'}
                    </Button>
                  </div>
                </div>
              </TabPanel>

              {/* TAB 5: TEAM DISCUSSION */}
              <TabPanel id="discussions" className="flex flex-col gap-4 pt-2">
                <div className="flex flex-col gap-2.5">
                  {discussions.length === 0 ? (
                    <div className="rounded-2xl border border-dashed border-border-button-default bg-background-secondary-default p-6 text-center text-body-regular text-text-secondary">
                      No comments yet. Mention @Marcus Vance or @Alice Cooper to notify them cleanly.
                    </div>
                  ) : (
                    discussions.map((msg) => (
                      <div
                        key={msg.message_id}
                        className="flex gap-3 rounded-2xl border border-border-button-default bg-background-secondary-default p-3.5"
                      >
                        <Avatar
                          size="sm"
                          color="blue"
                          initials={(msg.author_name || 'A').slice(0, 1).toUpperCase()}
                        />
                        <div className="min-w-0 flex-1">
                          <div className="flex items-center justify-between gap-2">
                            <span className="text-body-medium text-text-primary">
                              {msg.author_name || 'Team member'}
                            </span>
                            <span className="text-caption-1-medium text-text-tertiary">
                              {formatRelativeTime(msg.created_at)}
                            </span>
                          </div>
                          <p className="mt-0.5 text-body-regular text-text-secondary">
                            {msg.content}
                          </p>
                        </div>
                      </div>
                    ))
                  )}
                </div>

                <div className="flex flex-col gap-2 rounded-2xl border border-border-button-default bg-background-secondary-default p-3">
                  <Textarea
                    placeholder="Add review note or @mention a teammate…"
                    rows={2}
                    value={commentText}
                    onChange={setCommentText}
                    aria-label="Discussion message"
                  />
                  <div className="flex justify-end">
                    <Button
                      size="small"
                      variant="primary"
                      leadingIcon={RiSendPlaneLine}
                      disabled={sendingComment || !commentText.trim()}
                      onClick={handleSendComment}
                    >
                      {sendingComment ? 'Sending…' : 'Post note'}
                    </Button>
                  </div>
                </div>
              </TabPanel>
            </Tabs>
          </div>
        )}
      </div>
    </div>
  );
}

