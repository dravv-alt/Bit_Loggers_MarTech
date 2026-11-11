import { useMemo, useState } from 'react';
import {
  RiCalendarCheckLine,
  RiCalendarLine,
  RiCheckboxCircleLine,
  RiCoinsFill,
  RiEditLine,
  RiEyeLine,
  RiKanbanView2,
  RiLayoutGridLine,
  RiLockLine,
  RiMegaphoneFill,
  RiSearchLine,
  RiSendPlaneLine,
  RiSparkling2Fill,
  RiTableLine,
  RiTimeLine,
} from '@remixicon/react';
import {
  StatCards,
  type Stat,
} from '@/components/application/dashboard/stat-cards';
import { Badge } from '@/components/base/badges/badge';
import { Chip } from '@/components/base/badges/chip';
import { StatusDot } from '@/components/base/badges/status-dot';
import { Button } from '@/components/base/buttons/button';
import { InputBase } from '@/components/base/input/input';
import { Pagination } from '@/components/base/pagination/pagination';
import {
  SegmentedControl,
  SegmentedControlItem,
} from '@/components/base/segmented-control/segmented-control';
import { Select, SelectItem } from '@/components/base/select/select';
import {
  Table,
  TableBody,
  TableCell,
  TableColumn,
  TableHeader,
  TableRow,
} from '@/components/base/table/table';
import { cx } from '@/utils/cx';
import { evaluateCampaignCapabilities, normalizeCampaignStage } from './stateMachine';
import type { Campaign, WorkspaceUser } from './types';
import {
  STATUS_CHIP_COLOR,
  channelChipColor,
  formatMoney,
  formatRelativeTime,
  statusLabel,
} from './workspaceApi';

const PIPELINE_COLUMNS = [
  { id: 'Draft', title: 'Drafts', dotColor: 'indigo' as const },
  { id: 'Submitted', title: 'Awaiting review', dotColor: 'yellow' as const },
  { id: 'ChangesRequested', title: 'Changes requested', dotColor: 'yellow' as const },
  { id: 'Approved', title: 'Approved', dotColor: 'green' as const },
  { id: 'Scheduled', title: 'Scheduled', dotColor: 'green' as const },
  { id: 'Rejected', title: 'Rejected', dotColor: 'yellow' as const },
];

const CHANNELS = ['All', 'Social', 'Search', 'Email', 'Display', 'Video', 'Influencer'];
const PAGE_SIZE = 6;

export function PipelineView({
  campaigns,
  currentUser,
  onInspectCampaign,
  onEditCampaign,
  onSubmitCampaign,
  onOpenSchedule,
}: {
  campaigns: Campaign[];
  currentUser: WorkspaceUser;
  onInspectCampaign: (campaignId: string, initialTab?: string) => void;
  onEditCampaign: (campaign: Campaign) => void;
  onSubmitCampaign: (campaignId: string) => void;
  onOpenSchedule: (campaignId: string) => void;
}) {
  const [searchQuery, setSearchQuery] = useState('');
  const [channelFilter, setChannelFilter] = useState('All');
  const [statusFilter, setStatusFilter] = useState('All');
  const [viewMode, setViewMode] = useState<'board' | 'table'>('board');
  const [page, setPage] = useState(1);

  const filtered = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    return campaigns.filter((c) => {
      const matchesQ =
        !q ||
        c.title.toLowerCase().includes(q) ||
        (c.objective || '').toLowerCase().includes(q) ||
        (c.owner_name || '').toLowerCase().includes(q);
      const matchesChannel = channelFilter === 'All' || c.channel === channelFilter;
      const matchesStatus =
        statusFilter === 'All' || normalizeCampaignStage(c.status) === statusFilter;
      return matchesQ && matchesChannel && matchesStatus;
    });
  }, [campaigns, searchQuery, channelFilter, statusFilter]);

  const totalBudget = useMemo(
    () => campaigns.reduce((sum, c) => sum + Number(c.budget || 0), 0),
    [campaigns],
  );
  const reviewCount = useMemo(
    () => campaigns.filter((c) => normalizeCampaignStage(c.status) === 'Submitted').length,
    [campaigns],
  );
  const approvedOrLiveCount = useMemo(
    () =>
      campaigns.filter((c) => {
        const st = normalizeCampaignStage(c.status);
        return st === 'Approved' || st === 'Scheduled';
      }).length,
    [campaigns],
  );
  const avgProjectedRoi = useMemo(() => {
    const rois = campaigns
      .map((c) => c.current_version?.kpi_projected?.roi ?? 0)
      .filter((r) => r > 0);
    if (!rois.length) return 4.6;
    return rois.reduce((s, r) => s + r, 0) / rois.length;
  }, [campaigns]);

  const stats: Stat[] = [
    {
      icon: RiCoinsFill,
      label: 'Committed pipeline',
      value: formatMoney(totalBudget),
      delta: '+12.4%',
      deltaColor: 'lime',
      tone: 'blue',
      caption: `${campaigns.length} active proposals`,
      hint: 'Sum of current-version campaign budgets across all pipeline stages.',
    },
    {
      icon: RiTimeLine,
      label: 'Awaiting review',
      value: String(reviewCount),
      delta: reviewCount > 0 ? 'Needs signoff' : 'Clear',
      deltaColor: reviewCount > 0 ? 'neutral' : 'lime',
      tone: 'orange',
      caption: '24h review SLA',
      hint: 'Proposals locked to a submitted version waiting for reviewer signoff.',
    },
    {
      icon: RiCheckboxCircleLine,
      label: 'Approved & live',
      value: String(approvedOrLiveCount),
      delta: `${Math.round((approvedOrLiveCount / Math.max(1, campaigns.length)) * 100)}% ready`,
      deltaColor: 'lime',
      tone: 'emerald',
      caption: 'Flight ready',
      hint: 'Approved briefs ready for calendar scheduling or already live.',
    },
    {
      icon: RiSparkling2Fill,
      label: 'Blended ROI target',
      value: `${avgProjectedRoi.toFixed(1)}x`,
      delta: '+0.4x',
      deltaColor: 'lime',
      tone: 'purple',
      caption: 'Projected return',
      hint: 'Weighted projected return across current proposal versions.',
    },
  ];

  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const safePage = Math.min(page, totalPages);
  const pagedRows = filtered.slice((safePage - 1) * PAGE_SIZE, safePage * PAGE_SIZE);

  return (
    <div className="flex flex-col gap-5">
      {/* KPI Overview Row (Genuine BoardUI Footer StatCards) */}
      <StatCards variant="footer" stats={stats} />

      {/* Toolbar */}
      <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-border-button-default bg-background-secondary-default p-3">
        <div className="flex min-w-0 flex-1 flex-wrap items-center gap-2.5">
          <div className="w-full min-w-[220px] sm:w-72">
            <InputBase
              leadingIcon={RiSearchLine}
              placeholder="Search briefs, owners, objectives…"
              value={searchQuery}
              onChange={(e) => {
                setSearchQuery(e.target.value);
                setPage(1);
              }}
              aria-label="Search campaigns"
            />
          </div>

          <Select
            aria-label="Filter by channel"
            selectedKey={channelFilter}
            onSelectionChange={(k) => {
              setChannelFilter(String(k));
              setPage(1);
            }}
          >
            {CHANNELS.map((ch) => (
              <SelectItem key={ch} id={ch} textValue={ch === 'All' ? 'All channels' : ch}>
                {ch === 'All' ? 'All channels' : ch}
              </SelectItem>
            ))}
          </Select>

          <Select
            aria-label="Filter by stage"
            selectedKey={statusFilter}
            onSelectionChange={(k) => {
              setStatusFilter(String(k));
              setPage(1);
            }}
          >
            <SelectItem id="All" textValue="All stages">
              All stages
            </SelectItem>
            {PIPELINE_COLUMNS.map((col) => (
              <SelectItem key={col.id} id={col.id} textValue={col.title}>
                <span className="flex items-center gap-2">
                  <StatusDot color={col.dotColor} />
                  {col.title}
                </span>
              </SelectItem>
            ))}
          </Select>
        </div>

        <div className="flex items-center gap-3">
          <span className="hidden text-body-2-medium text-text-secondary tabular-nums md:inline">
            {filtered.length} matching
          </span>
          <SegmentedControl
            aria-label="View layout"
            selectedKeys={[viewMode]}
            onSelectionChange={(keys) => {
              const first = Array.from(keys)[0];
              if (first === 'board' || first === 'table') setViewMode(first);
            }}
          >
            <SegmentedControlItem id="board">
              <span className="inline-flex items-center gap-1.5">
                <RiKanbanView2 className="size-4" aria-hidden />
                Board
              </span>
            </SegmentedControlItem>
            <SegmentedControlItem id="table">
              <span className="inline-flex items-center gap-1.5">
                <RiTableLine className="size-4" aria-hidden />
                Table
              </span>
            </SegmentedControlItem>
          </SegmentedControl>
        </div>
      </div>

      {/* Pipeline Board or Table */}
      {viewMode === 'board' ? (
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
          {PIPELINE_COLUMNS.map((col) => {
            const colItems = filtered.filter(
              (c) => normalizeCampaignStage(c.status) === col.id,
            );
            return (
              <section
                key={col.id}
                className="flex flex-col gap-3 rounded-2-5xl border border-border-button-default bg-background-secondary-default p-3"
              >
                <div className="flex items-center justify-between px-1 pt-0.5">
                  <div className="flex items-center gap-2">
                    <StatusDot color={col.dotColor} />
                    <h2 className="text-body-medium text-text-primary">{col.title}</h2>
                  </div>
                  <Badge color="neutral">{colItems.length}</Badge>
                </div>

                {colItems.length === 0 ? (
                  <div className="flex min-h-[120px] flex-col items-center justify-center gap-1.5 rounded-2xl border border-dashed border-border-button-default bg-background-inner-default/60 p-4 text-center">
                    <RiLayoutGridLine className="size-5 text-foreground-icon-tertiary" aria-hidden />
                    <p className="text-body-2-medium text-text-tertiary">No proposals in {col.title.toLowerCase()}</p>
                  </div>
                ) : (
                  <div className="flex flex-col gap-2.5">
                    {colItems.map((camp) => {
                      const ver = camp.current_version;
                      const roi = ver?.kpi_projected?.roi ?? 0;
                      const cpa = ver?.kpi_projected?.cpa ?? 0;
                      const caps = evaluateCampaignCapabilities(camp, currentUser);
                      const isLockedByOther = caps.lockInfo.status === 'held_by_other';

                      return (
                        <article
                          key={camp.campaign_id}
                          onClick={() => onInspectCampaign(camp.campaign_id)}
                          className={cx(
                            'group flex cursor-pointer flex-col gap-3 rounded-2xl border border-border-button-default bg-background-inner-default p-4 shadow-card transition-colors',
                            'hover:border-border-button-hover',
                          )}
                        >
                          <div className="flex items-center justify-between gap-2">
                            <div className="flex items-center gap-1.5">
                              <Chip variant="caption" color={channelChipColor(camp.channel)}>
                                {camp.channel}
                              </Chip>
                              <Badge color="neutral">v{ver?.version_no ?? 1}</Badge>
                            </div>
                            {isLockedByOther ? (
                              <Chip variant="caption" color="orange">
                                <span className="inline-flex items-center gap-1">
                                  <RiLockLine className="size-3" aria-hidden />
                                  Editing
                                </span>
                              </Chip>
                            ) : (
                              <span className="text-caption-1-medium text-text-tertiary">
                                {formatRelativeTime(camp.updated_at)}
                              </span>
                            )}
                          </div>

                          <div className="flex flex-col gap-1">
                            <h3 className="text-headline-medium text-text-primary transition-colors group-hover:text-accent-600">
                              {camp.title}
                            </h3>
                            <p className="line-clamp-2 text-body-2-regular text-text-secondary">
                              {camp.objective || ver?.objective || 'No objective recorded yet.'}
                            </p>
                          </div>

                          <div className="grid grid-cols-3 gap-2 rounded-xl bg-background-secondary-default px-3 py-2">
                            <div>
                              <span className="block text-caption-1-medium text-text-tertiary">Budget</span>
                              <span className="text-body-medium text-text-primary tabular-nums">
                                {formatMoney(camp.budget)}
                              </span>
                            </div>
                            <div>
                              <span className="block text-caption-1-medium text-text-tertiary">Est. ROI</span>
                              <span className="text-body-medium text-text-primary tabular-nums">
                                {roi.toFixed(1)}x
                              </span>
                            </div>
                            <div>
                              <span className="block text-caption-1-medium text-text-tertiary">CPA cap</span>
                              <span className="text-body-medium text-text-primary tabular-nums">
                                ${cpa.toFixed(0)}
                              </span>
                            </div>
                          </div>

                          <div
                            className="flex flex-wrap items-center justify-between gap-2 border-t border-separator-border pt-2.5"
                            onClick={(e) => e.stopPropagation()}
                          >
                            <span className="text-caption-1-medium text-text-secondary">
                              {camp.owner_name || 'Alice Cooper'}
                            </span>

                            <div className="flex items-center gap-1.5">
                              {caps.stage !== 'Approved' && caps.stage !== 'Scheduled' && caps.stage !== 'Completed' && caps.canEdit && (
                                <Button
                                  size="xs"
                                  variant="secondary"
                                  leadingIcon={RiEditLine}
                                  onClick={() => onEditCampaign(camp)}
                                >
                                  Edit
                                </Button>
                              )}

                              {caps.canSubmit && (
                                <Button
                                  size="xs"
                                  variant="primary"
                                  leadingIcon={RiSendPlaneLine}
                                  onClick={() => onSubmitCampaign(camp.campaign_id)}
                                >
                                  Submit
                                </Button>
                              )}

                              {caps.canReview && (
                                <Button
                                  size="xs"
                                  variant="primary"
                                  leadingIcon={RiCheckboxCircleLine}
                                  onClick={() => onInspectCampaign(camp.campaign_id, 'review')}
                                >
                                  Review
                                </Button>
                              )}

                              {caps.canSchedule && caps.stage === 'Approved' && (
                                <Button
                                  size="xs"
                                  variant="primary"
                                  leadingIcon={RiCalendarLine}
                                  onClick={() => onOpenSchedule(camp.campaign_id)}
                                >
                                  Schedule
                                </Button>
                              )}

                              {caps.stage === 'Scheduled' && (
                                <Button
                                  size="xs"
                                  variant="secondary"
                                  leadingIcon={RiCalendarCheckLine}
                                  onClick={() => onInspectCampaign(camp.campaign_id)}
                                >
                                  Flight live
                                </Button>
                              )}
                            </div>
                          </div>
                        </article>
                      );
                    })}
                  </div>
                )}
              </section>
            );
          })}
        </div>
      ) : (
        <div className="flex flex-col gap-4 rounded-2xl border border-border-table bg-background-primary-default p-4 shadow-card">
          <Table aria-label="Campaign governance table" size="md">
            <TableHeader>
              <TableColumn isRowHeader>Campaign</TableColumn>
              <TableColumn>Channel</TableColumn>
              <TableColumn>Stage</TableColumn>
              <TableColumn>Version</TableColumn>
              <TableColumn>Budget</TableColumn>
              <TableColumn>ROI</TableColumn>
              <TableColumn>Updated</TableColumn>
              <TableColumn>Action</TableColumn>
            </TableHeader>
            <TableBody>
              {pagedRows.map((camp) => (
                <TableRow
                  key={camp.campaign_id}
                  onAction={() => onInspectCampaign(camp.campaign_id)}
                  className="cursor-pointer"
                >
                  <TableCell>
                    <div className="flex items-center gap-2.5">
                      <span className="flex size-8 shrink-0 items-center justify-center rounded-lg bg-background-secondary-default text-foreground-icon-secondary">
                        <RiMegaphoneFill className="size-4" aria-hidden />
                      </span>
                      <div className="min-w-0">
                        <div className="truncate text-body-medium text-text-primary">{camp.title}</div>
                        <div className="truncate text-caption-1-regular text-text-secondary">
                          {camp.owner_name || 'Alice Cooper'}
                        </div>
                      </div>
                    </div>
                  </TableCell>
                  <TableCell>
                    <Chip variant="caption" color={channelChipColor(camp.channel)}>
                      {camp.channel}
                    </Chip>
                  </TableCell>
                  <TableCell>
                    <Chip variant="bold" color={STATUS_CHIP_COLOR[camp.status] || 'neutral'}>
                      {statusLabel(camp.status)}
                    </Chip>
                  </TableCell>
                  <TableCell>
                    <Badge color="neutral">v{camp.current_version?.version_no ?? 1}</Badge>
                  </TableCell>
                  <TableCell className="tabular-nums">{formatMoney(camp.budget)}</TableCell>
                  <TableCell className="tabular-nums">
                    {(camp.current_version?.kpi_projected?.roi ?? 0).toFixed(1)}x
                  </TableCell>
                  <TableCell className="text-text-secondary">
                    {formatRelativeTime(camp.updated_at)}
                  </TableCell>
                  <TableCell>
                    <Button
                      size="xs"
                      variant="secondary"
                      leadingIcon={RiEyeLine}
                      onClick={() => onInspectCampaign(camp.campaign_id)}
                    >
                      Inspect
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>

          <div className="flex items-center justify-between border-t border-separator-border pt-3">
            <span className="text-body-2-medium text-text-secondary tabular-nums">
              Showing {pagedRows.length} of {filtered.length} proposals
            </span>
            <Pagination page={safePage} totalPages={totalPages} onChange={setPage} />
          </div>
        </div>
      )}
    </div>
  );
}

