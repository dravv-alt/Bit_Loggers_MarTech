import { useEffect, useState } from 'react';
import {
  RiCalendarCheckLine,
  RiCalendarLine,
  RiEyeLine,
  RiRefreshLine,
  RiShieldCheckLine,
} from '@remixicon/react';
import { Badge } from '@/components/base/badges/badge';
import { Chip } from '@/components/base/badges/chip';
import { StatusDot } from '@/components/base/badges/status-dot';
import { Button } from '@/components/base/buttons/button';
import {
  SegmentedControl,
  SegmentedControlItem,
} from '@/components/base/segmented-control/segmented-control';
import type { ScheduleEvent, WorkspaceUser } from './types';
import { channelChipColor, workspaceApi } from './workspaceApi';

const CHANNELS = ['All', 'Social', 'Search', 'Email', 'Display', 'Video'];

function formatDateRange(startIso: string, endIso: string): { label: string; days: number } {
  const s = new Date(startIso);
  const e = new Date(endIso);
  const fmt = new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric' });
  const days = Math.max(1, Math.round((e.getTime() - s.getTime()) / 86400000));
  return {
    label: `${fmt.format(s)} — ${fmt.format(e)}`,
    days,
  };
}

export function CalendarView({
  currentUser,
  onInspectCampaign,
}: {
  currentUser: WorkspaceUser;
  onInspectCampaign: (campaignId: string) => void;
}) {
  const [events, setEvents] = useState<ScheduleEvent[]>([]);
  const [channelFilter, setChannelFilter] = useState('All');
  const [loading, setLoading] = useState(true);

  const load = async () => {
    setLoading(true);
    try {
      const res = await workspaceApi.getCalendar(currentUser);
      setEvents(res);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, [currentUser.id]);

  const filtered = events.filter(
    (e) => channelFilter === 'All' || e.channel.toLowerCase() === channelFilter.toLowerCase(),
  );

  return (
    <div className="flex flex-col gap-5">
      {/* Toolbar */}
      <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-border-button-default bg-background-secondary-default p-3">
        <SegmentedControl
          aria-label="Filter calendar by channel"
          selectedKeys={[channelFilter]}
          onSelectionChange={(keys) => {
            const first = Array.from(keys)[0];
            if (first) setChannelFilter(String(first));
          }}
        >
          {CHANNELS.map((ch) => (
            <SegmentedControlItem key={ch} id={ch}>
              {ch === 'All' ? 'All lanes' : ch}
            </SegmentedControlItem>
          ))}
        </SegmentedControl>

        <div className="flex items-center gap-2">
          <Chip variant="bold" color="lime">
            <span className="inline-flex items-center gap-1.5">
              <RiShieldCheckLine className="size-3.5" aria-hidden />
              Overlap guard active
            </span>
          </Chip>
          <Button variant="secondary" size="small" leadingIcon={RiRefreshLine} onClick={load}>
            {loading ? 'Syncing…' : 'Refresh'}
          </Button>
        </div>
      </div>

      {/* Scheduled Flights */}
      {filtered.length === 0 ? (
        <div className="flex min-h-[240px] flex-col items-center justify-center gap-2 rounded-2xl border border-dashed border-border-button-default bg-background-secondary-default p-8 text-center">
          <RiCalendarLine className="size-8 text-foreground-icon-tertiary" aria-hidden />
          <h3 className="text-headline-medium text-text-primary">No active flights in this lane</h3>
          <p className="max-w-md text-body-regular text-text-secondary">
            Approved campaign proposals can be scheduled onto a conflict-free channel window from the Pipeline view.
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-3">
          {filtered.map((evt) => {
            const { label, days } = formatDateRange(evt.starts_at, evt.ends_at);
            return (
              <article
                key={evt.schedule_id}
                onClick={() => onInspectCampaign(evt.campaign_id)}
                className="flex cursor-pointer flex-col justify-between gap-4 rounded-2xl border border-border-button-default bg-background-primary-default p-4 shadow-card transition-colors hover:border-border-button-hover sm:flex-row sm:items-center"
              >
                <div className="flex flex-col gap-1.5">
                  <div className="flex flex-wrap items-center gap-2">
                    <Chip variant="caption" color={channelChipColor(evt.channel)}>
                      {evt.channel}
                    </Chip>
                    <Badge color="neutral">v{evt.version_no}</Badge>
                    <span className="inline-flex items-center gap-1.5 text-caption-1-medium text-text-secondary">
                      <StatusDot color="green" />
                      {evt.status}
                    </span>
                  </div>
                  <h3 className="text-title-3-semibold text-text-primary">{evt.title}</h3>
                  <p className="text-body-2-regular text-text-secondary">
                    Flight lock bound to exact approved version v{evt.version_no}
                  </p>
                </div>

                <div className="flex shrink-0 flex-wrap items-center gap-3">
                  <div className="rounded-xl bg-background-secondary-default px-3.5 py-2 text-end">
                    <span className="block text-caption-1-medium text-text-tertiary">
                      {days}-day window
                    </span>
                    <span className="inline-flex items-center gap-1.5 text-body-medium text-text-primary tabular-nums">
                      <RiCalendarCheckLine className="size-4 text-foreground-icon-secondary" aria-hidden />
                      {label}
                    </span>
                  </div>

                  <Button
                    size="small"
                    variant="secondary"
                    leadingIcon={RiEyeLine}
                    onClick={() => onInspectCampaign(evt.campaign_id)}
                  >
                    Open brief
                  </Button>
                </div>
              </article>
            );
          })}
        </div>
      )}
    </div>
  );
}

