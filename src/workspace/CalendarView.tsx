import { useEffect, useMemo, useState } from 'react';
import {
  RiArrowLeftSLine,
  RiArrowRightSLine,
  RiCalendarCheckLine,
  RiCalendarLine,
  RiCloseLine,
  RiEyeLine,
  RiListCheck2,
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
import { cx } from '@/utils/cx';
import type { ScheduleEvent, WorkspaceUser } from './types';
import { channelChipColor, workspaceApi } from './workspaceApi';

const CHANNELS = ['All', 'Social', 'Search', 'Email', 'Display', 'Video'];
const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MAX_VISIBLE_TRACKS = 3;

interface FlightSpan {
  event: ScheduleEvent;
  startDay: Date;
  endDay: Date;
  spanDays: number;
}

interface WeekBarPlacement {
  flight: FlightSpan;
  startCol: number;
  endCol: number;
  track: number;
  clippedLeft: boolean;
  clippedRight: boolean;
}

function dayOnly(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

function addDays(d: Date, days: number): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate() + days);
}

function sameDay(a: Date, b: Date): boolean {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}

function diffDays(later: Date, earlier: Date): number {
  const ms = dayOnly(later).getTime() - dayOnly(earlier).getTime();
  return Math.round(ms / 86400000);
}

function monthOverlaps(monthFirst: Date, startDay: Date, endDay: Date): boolean {
  const monthEnd = new Date(monthFirst.getFullYear(), monthFirst.getMonth() + 1, 0);
  return endDay.getTime() >= monthFirst.getTime() && startDay.getTime() <= monthEnd.getTime();
}

function formatDateRange(startDay: Date, endDay: Date): { label: string; days: number } {
  const fmt = new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric' });
  const days = Math.max(1, diffDays(endDay, startDay));
  return {
    label: sameDay(startDay, endDay) ? fmt.format(startDay) : `${fmt.format(startDay)} — ${fmt.format(endDay)}`,
    days,
  };
}

function channelBarStyles(channel: string): { bar: string; dot: string } {
  const tone = channelChipColor(channel);
  switch (tone) {
    case 'blue':
      return {
        bar: 'bg-status-blue-background text-status-blue-text border-status-blue-text/25 hover:border-status-blue-text/70',
        dot: 'bg-status-blue-text',
      };
    case 'orange':
      return {
        bar: 'bg-status-orange-background text-status-orange-text border-status-orange-text/25 hover:border-status-orange-text/70',
        dot: 'bg-status-orange-text',
      };
    case 'purple':
      return {
        bar: 'bg-status-purple-background text-status-purple-text border-status-purple-text/25 hover:border-status-purple-text/70',
        dot: 'bg-status-purple-text',
      };
    case 'cyan':
      return {
        bar: 'bg-status-cyan-background text-status-cyan-text border-status-cyan-text/25 hover:border-status-cyan-text/70',
        dot: 'bg-status-cyan-text',
      };
    case 'rose':
      return {
        bar: 'bg-status-rose-background text-status-rose-text border-status-rose-text/25 hover:border-status-rose-text/70',
        dot: 'bg-status-rose-text',
      };
    default:
      return {
        bar: 'bg-status-lime-background text-status-lime-text border-status-lime-text/25 hover:border-status-lime-text/70',
        dot: 'bg-status-lime-text',
      };
  }
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
  const [viewMode, setViewMode] = useState<'month' | 'list'>('month');
  const [loading, setLoading] = useState(true);
  const [focusedMonth, setFocusedMonth] = useState<Date>(() => {
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), 1);
  });
  const [selectedDay, setSelectedDay] = useState<Date | null>(null);

  const parseSpans = (list: ScheduleEvent[]): FlightSpan[] => {
    const fallbackNow = dayOnly(new Date());
    const spans = list.map((evt) => {
      const sRaw = new Date(evt.starts_at);
      const eRaw = new Date(evt.ends_at);
      const startDay = Number.isNaN(sRaw.getTime()) ? fallbackNow : dayOnly(sRaw);
      const rawEnd = Number.isNaN(eRaw.getTime()) ? addDays(startDay, 4) : dayOnly(eRaw);
      const endDay = rawEnd.getTime() < startDay.getTime() ? startDay : rawEnd;
      const spanDays = Math.max(1, diffDays(endDay, startDay));
      return { event: evt, startDay, endDay, spanDays };
    });
    spans.sort((a, b) => {
      const cmp = a.startDay.getTime() - b.startDay.getTime();
      return cmp !== 0 ? cmp : b.spanDays - a.spanDays;
    });
    return spans;
  };

  const load = async () => {
    setLoading(true);
    try {
      const res = await workspaceApi.getCalendar(currentUser);
      setEvents(res);
      if (res.length > 0) {
        const spans = parseSpans(res);
        setFocusedMonth((cur) => {
          if (spans.some((s) => monthOverlaps(cur, s.startDay, s.endDay))) return cur;
          const first = spans[0].startDay;
          return new Date(first.getFullYear(), first.getMonth(), 1);
        });
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, [currentUser.id]);

  const filteredEvents = useMemo(
    () =>
      events.filter(
        (e) => channelFilter === 'All' || e.channel.toLowerCase() === channelFilter.toLowerCase(),
      ),
    [events, channelFilter],
  );

  const allSpans = useMemo(() => parseSpans(filteredEvents), [filteredEvents]);

  const monthSpans = useMemo(
    () => allSpans.filter((s) => monthOverlaps(focusedMonth, s.startDay, s.endDay)),
    [allSpans, focusedMonth],
  );

  const displayedSpans = useMemo(() => {
    if (viewMode === 'list') return allSpans;
    if (selectedDay) {
      const t = selectedDay.getTime();
      return allSpans.filter((s) => t >= s.startDay.getTime() && t <= s.endDay.getTime());
    }
    return monthSpans;
  }, [viewMode, selectedDay, allSpans, monthSpans]);

  const calendarWeeks = useMemo(() => {
    const year = focusedMonth.getFullYear();
    const month = focusedMonth.getMonth();
    const first = new Date(year, month, 1);
    const leading = first.getDay(); // Sun = 0
    const gridStart = addDays(first, -leading);
    const daysInMonth = new Date(year, month + 1, 0).getDate();
    const weekCount = Math.ceil((leading + daysInMonth) / 7);

    return Array.from({ length: weekCount }, (_, wIdx) => {
      const weekStart = addDays(gridStart, wIdx * 7);
      const weekEnd = addDays(weekStart, 6);
      const weekSpans = allSpans.filter(
        (s) =>
          s.endDay.getTime() >= weekStart.getTime() &&
          s.startDay.getTime() <= weekEnd.getTime(),
      );

      const placements: WeekBarPlacement[] = [];
      const trackEnds: number[] = [];

      for (const span of weekSpans) {
        const startCol = Math.max(0, Math.min(6, diffDays(span.startDay, weekStart)));
        const endCol = Math.max(0, Math.min(6, diffDays(span.endDay, weekStart)));

        let chosenTrack = trackEnds.findIndex((lastCol) => startCol > lastCol);
        if (chosenTrack === -1) {
          chosenTrack = trackEnds.length;
          trackEnds.push(endCol);
        } else {
          trackEnds[chosenTrack] = endCol;
        }

        placements.push({
          flight: span,
          startCol,
          endCol,
          track: chosenTrack,
          clippedLeft: span.startDay.getTime() < weekStart.getTime(),
          clippedRight: span.endDay.getTime() > weekEnd.getTime(),
        });
      }

      const overflowByCol: Record<number, number> = {};
      for (const pl of placements) {
        if (pl.track >= MAX_VISIBLE_TRACKS) {
          for (let col = pl.startCol; col <= pl.endCol; col++) {
            overflowByCol[col] = (overflowByCol[col] ?? 0) + 1;
          }
        }
      }

      return {
        weekStart,
        days: Array.from({ length: 7 }, (_, col) => addDays(weekStart, col)),
        visibleBars: placements.filter((pl) => pl.track < MAX_VISIBLE_TRACKS),
        overflowByCol,
      };
    });
  }, [focusedMonth, allSpans]);

  const today = dayOnly(new Date());
  const monthLabel = new Intl.DateTimeFormat('en-US', {
    month: 'long',
    year: 'numeric',
  }).format(focusedMonth);
  const shortMonthLabel = new Intl.DateTimeFormat('en-US', { month: 'long' }).format(
    focusedMonth,
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

        <div className="flex flex-wrap items-center gap-2">
          <Chip variant="bold" color="lime">
            <span className="inline-flex items-center gap-1.5">
              <RiShieldCheckLine className="size-3.5" aria-hidden />
              Overlap guard active
            </span>
          </Chip>

          <SegmentedControl
            aria-label="Calendar layout mode"
            selectedKeys={[viewMode]}
            onSelectionChange={(keys) => {
              const first = Array.from(keys)[0];
              if (first === 'month' || first === 'list') setViewMode(first);
            }}
          >
            <SegmentedControlItem id="month">
              <span className="inline-flex items-center gap-1.5">
                <RiCalendarLine className="size-3.5" aria-hidden />
                Month
              </span>
            </SegmentedControlItem>
            <SegmentedControlItem id="list">
              <span className="inline-flex items-center gap-1.5">
                <RiListCheck2 className="size-3.5" aria-hidden />
                Schedule
              </span>
            </SegmentedControlItem>
          </SegmentedControl>

          <Button variant="secondary" size="small" leadingIcon={RiRefreshLine} onClick={load}>
            {loading ? 'Syncing…' : 'Refresh'}
          </Button>
        </div>
      </div>

      {/* Interactive Month Grid */}
      {viewMode === 'month' && (
        <section className="overflow-hidden rounded-2xl border border-border-button-default bg-background-primary-default shadow-card">
          {/* Month Header */}
          <div className="flex flex-wrap items-center justify-between gap-3 px-4 py-3.5">
            <div className="flex flex-wrap items-center gap-2.5">
              <h2 className="text-title-2-semibold text-text-primary tabular-nums">
                {monthLabel}
              </h2>
              <Badge color="neutral" className="tabular-nums">
                {monthSpans.length} {monthSpans.length === 1 ? 'flight' : 'flights'}
              </Badge>
            </div>

            <div className="flex items-center gap-1.5">
              <Button
                variant="secondary"
                size="small"
                aria-label="Previous month"
                onClick={() => {
                  setFocusedMonth(
                    new Date(focusedMonth.getFullYear(), focusedMonth.getMonth() - 1, 1),
                  );
                  setSelectedDay(null);
                }}
              >
                <RiArrowLeftSLine className="size-4" aria-hidden />
              </Button>
              <Button
                variant="secondary"
                size="small"
                onClick={() => {
                  const nowDay = dayOnly(new Date());
                  setFocusedMonth(new Date(nowDay.getFullYear(), nowDay.getMonth(), 1));
                  setSelectedDay(nowDay);
                }}
              >
                Today
              </Button>
              <Button
                variant="secondary"
                size="small"
                aria-label="Next month"
                onClick={() => {
                  setFocusedMonth(
                    new Date(focusedMonth.getFullYear(), focusedMonth.getMonth() + 1, 1),
                  );
                  setSelectedDay(null);
                }}
              >
                <RiArrowRightSLine className="size-4" aria-hidden />
              </Button>
            </div>
          </div>

          {/* Weekday Row */}
          <div className="grid grid-cols-7 border-y border-border-button-default bg-background-secondary-default">
            {WEEKDAYS.map((day, idx) => (
              <div
                key={day}
                className={cx(
                  'py-2 text-center text-caption-1-semibold',
                  idx === 0 || idx === 6 ? 'text-text-tertiary' : 'text-text-secondary',
                )}
              >
                {day}
              </div>
            ))}
          </div>

          {/* Week Rows */}
          <div>
            {calendarWeeks.map((week, wIdx) => {
              const isLast = wIdx === calendarWeeks.length - 1;
              const maxTrackCount = week.visibleBars.reduce(
                (max, pl) => Math.max(max, pl.track + 1),
                0,
              );
              const desktopMinHeight = Math.max(
                104,
                40 + maxTrackCount * 26 + (Object.keys(week.overflowByCol).length ? 22 : 12),
              );

              return (
                <div
                  key={week.weekStart.toISOString()}
                  className={cx('relative', !isLast && 'border-b border-border-button-default')}
                >
                  {/* 7-column day cells */}
                  <div
                    className="grid grid-cols-7"
                    style={{ minHeight: `${desktopMinHeight}px` }}
                  >
                    {week.days.map((day, col) => {
                      const inMonth =
                        day.getMonth() === focusedMonth.getMonth() &&
                        day.getFullYear() === focusedMonth.getFullYear();
                      const isToday = sameDay(day, today);
                      const isSelected = selectedDay ? sameDay(day, selectedDay) : false;
                      const isWeekend = col === 0 || col === 6;
                      const dayLabel =
                        day.getDate() === 1
                          ? `${new Intl.DateTimeFormat('en-US', { month: 'short' }).format(day)} 1`
                          : String(day.getDate());
                      const activeTodaySpans = allSpans.filter(
                        (s) =>
                          day.getTime() >= s.startDay.getTime() &&
                          day.getTime() <= s.endDay.getTime(),
                      );

                      return (
                        <button
                          key={day.toISOString()}
                          type="button"
                          onClick={() =>
                            setSelectedDay((cur) => (cur && sameDay(cur, day) ? null : day))
                          }
                          className={cx(
                            'group relative flex min-h-[60px] flex-col justify-between p-1.5 text-end transition-colors sm:p-2',
                            col < 6 && 'border-r border-border-button-default',
                            isSelected
                              ? 'bg-accent-500/10'
                              : !inMonth
                                ? 'bg-background-secondary-default/70'
                                : isWeekend
                                  ? 'bg-background-secondary-default/35'
                                  : 'bg-background-primary-default hover:bg-background-secondary-default/40',
                          )}
                        >
                          <div className="flex justify-end">
                            <span
                              className={cx(
                                'inline-flex size-6 items-center justify-center rounded-full text-caption-1-medium tabular-nums',
                                isToday
                                  ? 'bg-accent-500 font-semibold text-white'
                                  : isSelected
                                    ? 'font-semibold text-accent-600 dark:text-accent-400'
                                    : inMonth
                                      ? 'text-text-secondary'
                                      : 'text-text-tertiary',
                              )}
                            >
                              {dayLabel}
                            </span>
                          </div>

                          {/* Compact color pills on narrow viewports (< sm) */}
                          <div className="mt-1 flex flex-wrap justify-center gap-0.5 sm:hidden">
                            {activeTodaySpans.slice(0, 3).map((s) => (
                              <span
                                key={s.event.schedule_id}
                                className={cx(
                                  'h-1 w-2.5 rounded-full',
                                  channelBarStyles(s.event.channel).dot,
                                )}
                              />
                            ))}
                          </div>
                        </button>
                      );
                    })}
                  </div>

                  {/* Continuous Multi-Day Spanning Event Bars (Desktop / Tablet >= sm) */}
                  <div className="pointer-events-none absolute inset-x-0 top-9 hidden sm:block">
                    {week.visibleBars.map((pl) => {
                      const evt = pl.flight.event;
                      const range = formatDateRange(pl.flight.startDay, pl.flight.endDay);
                      const styles = channelBarStyles(evt.channel);
                      const colSpan = pl.endCol - pl.startCol + 1;
                      const leftPct = (pl.startCol / 7) * 100;
                      const widthPct = (colSpan / 7) * 100;

                      return (
                        <button
                          key={`${evt.schedule_id}-${pl.startCol}`}
                          type="button"
                          title={`${evt.title} (${evt.channel} v${evt.version_no}) • ${range.label}`}
                          onClick={(e) => {
                            e.stopPropagation();
                            onInspectCampaign(evt.campaign_id);
                          }}
                          style={{
                            left: `calc(${leftPct}% + ${pl.clippedLeft ? 0 : 4}px)`,
                            width: `calc(${widthPct}% - ${(pl.clippedLeft ? 0 : 4) + (pl.clippedRight ? 0 : 4)}px)`,
                            top: `${pl.track * 26}px`,
                          }}
                          className={cx(
                            'pointer-events-auto absolute flex h-[22px] cursor-pointer items-center gap-1.5 border px-2 text-left transition-all hover:underline',
                            !pl.clippedLeft && 'rounded-l-md',
                            !pl.clippedRight && 'rounded-r-md',
                            styles.bar,
                          )}
                        >
                          {!pl.clippedLeft && (
                            <span
                              className={cx('size-1.5 shrink-0 rounded-full', styles.dot)}
                              aria-hidden
                            />
                          )}
                          <span className="truncate text-[11.5px] font-semibold tracking-tight tabular-nums">
                            {colSpan >= 2 ? `${evt.channel}: ${evt.title}` : evt.title}
                          </span>
                        </button>
                      );
                    })}
                  </div>
                </div>
              );
            })}
          </div>
        </section>
      )}

      {/* Section Heading for Flight Cards below calendar */}
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="flex items-center gap-2">
          <h3 className="text-headline-medium text-text-primary">
            {viewMode === 'month' && selectedDay
              ? `Flights on ${new Intl.DateTimeFormat('en-US', {
                  weekday: 'long',
                  month: 'short',
                  day: 'numeric',
                }).format(selectedDay)}`
              : viewMode === 'month'
                ? `${shortMonthLabel} flight schedule`
                : 'All scheduled channel flights'}
          </h3>
          <Badge color="neutral">{displayedSpans.length}</Badge>
        </div>

        {viewMode === 'month' && selectedDay && (
          <Button
            size="small"
            variant="ghost"
            leadingIcon={RiCloseLine}
            onClick={() => setSelectedDay(null)}
          >
            Clear day filter
          </Button>
        )}
      </div>

      {/* Scheduled Flights */}
      {displayedSpans.length === 0 ? (
        <div className="flex min-h-[180px] flex-col items-center justify-center gap-2 rounded-2xl border border-dashed border-border-button-default bg-background-secondary-default p-6 text-center">
          <RiCalendarLine className="size-7 text-foreground-icon-tertiary" aria-hidden />
          <h3 className="text-headline-medium text-text-primary">
            {selectedDay
              ? `No flights active on ${new Intl.DateTimeFormat('en-US', {
                  month: 'short',
                  day: 'numeric',
                }).format(selectedDay)}`
              : 'No active flights in this lane'}
          </h3>
          <p className="max-w-md text-body-regular text-text-secondary">
            {selectedDay
              ? 'Channel capacity is clear on this date. Pick another date cell or clear the filter.'
              : 'Approved campaign proposals can be scheduled onto a conflict-free channel window from the Pipeline view.'}
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-3">
          {displayedSpans.map(({ event: evt, startDay, endDay }) => {
            const { label, days } = formatDateRange(startDay, endDay);
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
                      <RiCalendarCheckLine
                        className="size-4 text-foreground-icon-secondary"
                        aria-hidden
                      />
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
