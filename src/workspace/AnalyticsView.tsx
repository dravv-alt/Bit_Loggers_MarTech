import { useEffect, useState } from 'react';
import {
  RiAwardFill,
  RiBarChartBoxLine,
  RiCoinsFill,
  RiCursorFill,
  RiLineChartFill,
  RiPercentFill,
  RiRefreshLine,
} from '@remixicon/react';
import { OrdersChartCard } from '@/components/application/dashboard/orders-chart-card';
import { RevenueChartCard } from '@/components/application/dashboard/revenue-chart-card';
import { StatCards, type Stat } from '@/components/application/dashboard/stat-cards';
import { Badge } from '@/components/base/badges/badge';
import { Chip } from '@/components/base/badges/chip';
import { Button } from '@/components/base/buttons/button';
import {
  SegmentedControl,
  SegmentedControlItem,
} from '@/components/base/segmented-control/segmented-control';
import {
  Table,
  TableBody,
  TableCell,
  TableColumn,
  TableHeader,
  TableRow,
} from '@/components/base/table/table';
import type { AnalyticsPayload, WorkspaceUser } from './types';
import { channelChipColor, formatMoney, workspaceApi } from './workspaceApi';

const CHANNELS = ['All', 'Search', 'Social', 'Email', 'Display'];

export function AnalyticsView({ currentUser }: { currentUser: WorkspaceUser }) {
  const [channelFilter, setChannelFilter] = useState('All');
  const [data, setData] = useState<AnalyticsPayload | null>(null);
  const [loading, setLoading] = useState(true);

  const load = async (ch = channelFilter) => {
    setLoading(true);
    try {
      const payload = await workspaceApi.getAnalytics(ch, currentUser);
      setData(payload);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load(channelFilter);
  }, [channelFilter, currentUser.id]);

  const kpis = data?.summary?.kpis;

  const kpiStats: Stat[] = kpis
    ? [
        {
          icon: RiPercentFill,
          label: 'Conversion rate',
          value: `${kpis.conversionRate.actual.toFixed(1)}%`,
          delta: `+${Math.max(0, ((kpis.conversionRate.actual - kpis.conversionRate.projected) / Math.max(0.1, kpis.conversionRate.projected)) * 100).toFixed(1)}%`,
          deltaColor:
            kpis.conversionRate.actual >= kpis.conversionRate.projected ? 'lime' : 'rose',
        },
        {
          icon: RiCursorFill,
          label: 'Click-through rate',
          value: `${kpis.ctr.actual.toFixed(1)}%`,
          delta: `${(((kpis.ctr.actual - kpis.ctr.projected) / Math.max(0.1, kpis.ctr.projected)) * 100).toFixed(1)}%`,
          deltaColor: kpis.ctr.actual >= kpis.ctr.projected ? 'lime' : 'rose',
        },
        {
          icon: RiAwardFill,
          label: 'Blended ROI',
          value: `${kpis.roi.actual.toFixed(1)}x`,
          delta: `+${Math.max(0, ((kpis.roi.actual - kpis.roi.projected) / Math.max(0.1, kpis.roi.projected)) * 100).toFixed(1)}%`,
          deltaColor: kpis.roi.actual >= kpis.roi.projected ? 'lime' : 'rose',
        },
        {
          icon: RiCoinsFill,
          label: 'Actual CPA',
          value: `$${kpis.cpa.actual.toFixed(1)}`,
          delta: `${(((kpis.cpa.actual - kpis.cpa.projected) / Math.max(0.1, kpis.cpa.projected)) * 100).toFixed(1)}%`,
          deltaColor: kpis.cpa.actual <= kpis.cpa.projected ? 'lime' : 'rose',
        },
      ]
    : [];

  const revenueSeries = (data?.trends || []).map((t) => ({
    label: t.date,
    current: t.actualRevenue,
    previous: t.projectedRevenue,
  }));

  const conversionSeries = (data?.trends || []).map((t) => ({
    label: t.date,
    current: t.actualConversions,
    previous: t.projectedConversions,
  }));

  return (
    <div className="flex flex-col gap-5">
      {/* Filter Header */}
      <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-border-button-default bg-background-secondary-default p-3">
        <div className="flex flex-wrap items-center gap-2">
          <SegmentedControl
            aria-label="Filter analytics channel"
            selectedKeys={[channelFilter]}
            onSelectionChange={(keys) => {
              const first = Array.from(keys)[0];
              if (first) setChannelFilter(String(first));
            }}
          >
            {CHANNELS.map((ch) => (
              <SegmentedControlItem key={ch} id={ch}>
                {ch === 'All' ? 'All channels' : ch}
              </SegmentedControlItem>
            ))}
          </SegmentedControl>
        </div>

        <div className="flex items-center gap-2.5">
          {kpis && (
            <Badge color="neutral">
              Avg order value: ${kpis.aov.actual.toFixed(0)} (est ${kpis.aov.projected.toFixed(0)})
            </Badge>
          )}
          <Button
            variant="secondary"
            size="small"
            leadingIcon={RiRefreshLine}
            onClick={() => load(channelFilter)}
          >
            {loading ? 'Refreshing…' : 'Refresh'}
          </Button>
        </div>
      </div>

      {/* 4 Primary MarTech KPIs via BoardUI Plain StatCards */}
      {kpiStats.length > 0 && <StatCards variant="plain" stats={kpiStats} />}

      {/* Interactive BoardUI Recharts Cards (Projected vs Actual) */}
      <div className="grid grid-cols-1 gap-4 xl:grid-cols-2">
        <RevenueChartCard
          title="Attributed revenue (actual vs target)"
          data={revenueSeries.length > 0 ? revenueSeries : undefined}
        />
        <OrdersChartCard
          title="Conversions (actual vs baseline)"
          data={conversionSeries.length > 0 ? conversionSeries : undefined}
        />
      </div>

      {/* Channel Efficiency Ledger */}
      <section className="flex flex-col gap-3 rounded-2xl border border-border-table bg-background-primary-default p-4 shadow-card">
        <div className="flex items-center justify-between gap-2">
          <div className="flex items-center gap-2">
            <RiBarChartBoxLine className="size-5 text-foreground-icon-secondary" aria-hidden />
            <h2 className="text-headline-medium text-text-primary">Channel performance breakdown</h2>
          </div>
          <span className="text-body-2-medium text-text-secondary">
            {data?.channelBreakdown.length || 0} active lanes
          </span>
        </div>

        <Table aria-label="Channel breakdown table" size="sm">
          <TableHeader>
            <TableColumn isRowHeader>Channel</TableColumn>
            <TableColumn>Flights</TableColumn>
            <TableColumn>Allocated spend</TableColumn>
            <TableColumn>Conversion rate</TableColumn>
            <TableColumn>Projected ROI</TableColumn>
            <TableColumn>Pacing</TableColumn>
          </TableHeader>
          <TableBody>
            {(data?.channelBreakdown || []).map((row) => (
              <TableRow key={row.channel}>
                <TableCell>
                  <Chip variant="caption" color={channelChipColor(row.channel)}>
                    {row.channel}
                  </Chip>
                </TableCell>
                <TableCell className="tabular-nums">{row.count}</TableCell>
                <TableCell className="tabular-nums">{formatMoney(row.budget)}</TableCell>
                <TableCell className="tabular-nums">{row.conv.toFixed(1)}%</TableCell>
                <TableCell className="tabular-nums">{row.roi.toFixed(1)}x</TableCell>
                <TableCell>
                  <Chip variant="bold" color={row.roi >= 4 ? 'lime' : 'yellow'}>
                    <span className="inline-flex items-center gap-1">
                      <RiLineChartFill className="size-3.5" aria-hidden />
                      {row.roi >= 4 ? 'Outperforming' : 'On watch'}
                    </span>
                  </Chip>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </section>
    </div>
  );
}

