import { useEffect, useState } from 'react';
import {
  RiCheckboxCircleLine,
  RiGitBranchLine,
  RiMailSendLine,
  RiPlayFill,
  RiRefreshLine,
  RiSearchLine,
  RiShieldCheckLine,
  RiTerminalBoxLine,
} from '@remixicon/react';
import { AgentThinking } from '@/components/application/agent-thinking/agent-thinking';
import { Badge } from '@/components/base/badges/badge';
import { Chip } from '@/components/base/badges/chip';
import { StatusDot } from '@/components/base/badges/status-dot';
import { Button } from '@/components/base/buttons/button';
import { InputBase } from '@/components/base/input/input';
import {
  SegmentedControl,
  SegmentedControlItem,
} from '@/components/base/segmented-control/segmented-control';
import { Switch } from '@/components/base/switch/switch';
import {
  Table,
  TableBody,
  TableCell,
  TableColumn,
  TableHeader,
  TableRow,
} from '@/components/base/table/table';
import { Tab, TabList, TabPanel, Tabs } from '@/components/base/tabs/tabs';
import type {
  AuditEventItem,
  DiagnosticLogItem,
  OutboxEventItem,
  TestReport,
  WorkspaceUser,
} from './types';
import { formatRelativeTime, workspaceApi } from './workspaceApi';

export function GovernanceView({
  currentUser,
  onInspectCampaign,
  onNotify,
}: {
  currentUser: WorkspaceUser;
  onInspectCampaign: (campaignId: string) => void;
  onNotify: (title: string, description: string, status?: 'success' | 'error' | 'information') => void;
}) {
  const [auditList, setAuditList] = useState<AuditEventItem[]>([]);
  const [outboxList, setOutboxList] = useState<OutboxEventItem[]>([]);
  const [isEmailFailing, setIsEmailFailing] = useState(false);
  const [diagList, setDiagList] = useState<DiagnosticLogItem[]>([]);
  const [diagFilter, setDiagFilter] = useState('ALL');
  const [searchQuery, setSearchQuery] = useState('');
  const [sweeping, setSweeping] = useState(false);
  const [runningTests, setRunningTests] = useState(false);
  const [report, setReport] = useState<TestReport | null>(null);

  const loadAll = async () => {
    const [aud, obx, diag] = await Promise.all([
      workspaceApi.getAudit(currentUser),
      workspaceApi.getOutbox(currentUser),
      workspaceApi.getDiagnostics(currentUser),
    ]);
    setAuditList(aud);
    setOutboxList(obx.events);
    setIsEmailFailing(obx.isEmailServiceFailing);
    setDiagList(diag);
  };

  useEffect(() => {
    loadAll();
  }, [currentUser.id]);

  const handleToggleEmailFailure = async (failing: boolean) => {
    const next = await workspaceApi.toggleEmailFailure(failing, currentUser);
    setIsEmailFailing(next);
    onNotify(
      next ? 'Email failure simulation active' : 'Email delivery restored',
      next
        ? 'Outbox dispatches will queue for retry with exponential backoff.'
        : 'Pending outbox messages can now deliver cleanly.',
      next ? 'information' : 'success',
    );
    await loadAll();
  };

  const handleSweep = async () => {
    setSweeping(true);
    try {
      const count = await workspaceApi.processOutbox(currentUser);
      onNotify('Outbox sweep finished', `${count} queued dispatch events processed.`, 'success');
      await loadAll();
    } finally {
      setSweeping(false);
    }
  };

  const handleRunTests = async () => {
    setRunningTests(true);
    try {
      const res = await workspaceApi.runTests(currentUser);
      setReport(res);
      onNotify(
        'Verification suite completed',
        `${res.passedCount}/${res.total} governance invariants passed.`,
        res.allPassed ? 'success' : 'error',
      );
    } finally {
      setRunningTests(false);
    }
  };

  const filteredAudit = auditList.filter((e) => {
    const q = searchQuery.trim().toLowerCase();
    if (!q) return true;
    return (
      e.event_type.toLowerCase().includes(q) ||
      (e.actor_name || '').toLowerCase().includes(q) ||
      e.summary.toLowerCase().includes(q) ||
      (e.campaign_id || '').toLowerCase().includes(q)
    );
  });

  const filteredDiag = diagList.filter((d) => diagFilter === 'ALL' || d.outcome === diagFilter);

  return (
    <div className="flex flex-col gap-5">
      <Tabs defaultSelectedKey="audit">
        <TabList aria-label="Governance sections">
          <Tab id="audit" icon={RiGitBranchLine} count={auditList.length}>
            Audit ledger
          </Tab>
          <Tab id="outbox" icon={RiMailSendLine} count={outboxList.length}>
            Delivery outbox
          </Tab>
          <Tab id="diagnostics" icon={RiTerminalBoxLine} count={diagList.length}>
            Diagnostics
          </Tab>
          <Tab id="tests" icon={RiShieldCheckLine} count={report?.total ?? 14}>
            Verification suite
          </Tab>
        </TabList>

        {/* TAB 1: AUDIT TRAIL */}
        <TabPanel id="audit" className="flex flex-col gap-4">
          <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-border-button-default bg-background-secondary-default p-3">
            <div className="w-full sm:w-80">
              <InputBase
                leadingIcon={RiSearchLine}
                placeholder="Filter events, actors, or briefs…"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                aria-label="Filter audit events"
              />
            </div>
            <Button variant="secondary" size="small" leadingIcon={RiRefreshLine} onClick={loadAll}>
              Refresh ledger
            </Button>
          </div>

          <div className="rounded-2xl border border-border-table bg-background-primary-default p-4 shadow-card">
            <Table aria-label="Audit trail table" size="sm">
              <TableHeader>
                <TableColumn isRowHeader>Event</TableColumn>
                <TableColumn>Actor</TableColumn>
                <TableColumn>Transition</TableColumn>
                <TableColumn>Summary</TableColumn>
                <TableColumn>Time</TableColumn>
              </TableHeader>
              <TableBody>
                {filteredAudit.map((evt) => {
                  const chipColor = evt.event_type.includes('APPROVED')
                    ? 'lime'
                    : evt.event_type.includes('SCHEDULED')
                      ? 'cyan'
                      : evt.event_type.includes('CHANGES') || evt.event_type.includes('REJECTED')
                        ? 'rose'
                        : 'yellow';
                  return (
                    <TableRow
                      key={evt.event_id}
                      onAction={() => evt.campaign_id && onInspectCampaign(evt.campaign_id)}
                      className={evt.campaign_id ? 'cursor-pointer' : undefined}
                    >
                      <TableCell>
                        <Chip variant="caption" color={chipColor}>
                          {evt.event_type.replaceAll('_', ' ')}
                        </Chip>
                      </TableCell>
                      <TableCell className="text-text-primary">
                        {evt.actor_name || evt.actor_id || 'System'}
                      </TableCell>
                      <TableCell className="text-text-secondary">
                        {evt.previous_state || '—'} → {evt.new_state || '—'}
                      </TableCell>
                      <TableCell className="max-w-md truncate text-text-secondary">
                        {evt.summary}
                      </TableCell>
                      <TableCell className="text-text-tertiary tabular-nums">
                        {formatRelativeTime(evt.occurred_at)}
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          </div>
        </TabPanel>

        {/* TAB 2: DELIVERY OUTBOX */}
        <TabPanel id="outbox" className="flex flex-col gap-4">
          <div className="flex flex-wrap items-center justify-between gap-4 rounded-2xl border border-border-button-default bg-background-secondary-default p-4">
            <div className="flex items-center gap-3">
              <Switch
                isSelected={isEmailFailing}
                onChange={handleToggleEmailFailure}
                aria-label="Simulate email delivery outage"
              >
                Simulate SMTP gateway outage
              </Switch>
              {isEmailFailing && (
                <Chip variant="caption" color="rose">
                  Retry backoff active
                </Chip>
              )}
            </div>

            <Button
              variant="primary"
              size="small"
              leadingIcon={RiRefreshLine}
              onClick={handleSweep}
              disabled={sweeping}
            >
              {sweeping ? 'Sweeping queue…' : 'Trigger outbox sweep'}
            </Button>
          </div>

          <div className="rounded-2xl border border-border-table bg-background-primary-default p-4 shadow-card">
            <Table aria-label="Outbox events table" size="sm">
              <TableHeader>
                <TableColumn isRowHeader>Event ID</TableColumn>
                <TableColumn>Dispatch type</TableColumn>
                <TableColumn>Status</TableColumn>
                <TableColumn>Attempts</TableColumn>
                <TableColumn>Last error</TableColumn>
                <TableColumn>Queued</TableColumn>
              </TableHeader>
              <TableBody>
                {outboxList.map((evt) => (
                  <TableRow key={evt.event_id}>
                    <TableCell className="font-mono text-text-secondary">{evt.event_id}</TableCell>
                    <TableCell className="text-text-primary">{evt.event_type}</TableCell>
                    <TableCell>
                      <Chip
                        variant="bold"
                        color={
                          evt.status === 'PROCESSED'
                            ? 'lime'
                            : evt.status === 'FAILED'
                              ? 'rose'
                              : 'yellow'
                        }
                      >
                        {evt.status}
                      </Chip>
                    </TableCell>
                    <TableCell className="tabular-nums">
                      {evt.attempts}/{evt.max_attempts ?? 3}
                    </TableCell>
                    <TableCell className="max-w-xs truncate text-text-secondary">
                      {evt.error_log || 'Delivered'}
                    </TableCell>
                    <TableCell className="text-text-tertiary tabular-nums">
                      {formatRelativeTime(evt.created_at)}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        </TabPanel>

        {/* TAB 3: DIAGNOSTICS */}
        <TabPanel id="diagnostics" className="flex flex-col gap-4">
          <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-border-button-default bg-background-secondary-default p-3">
            <SegmentedControl
              aria-label="Filter diagnostics outcome"
              selectedKeys={[diagFilter]}
              onSelectionChange={(keys) => {
                const first = Array.from(keys)[0];
                if (first) setDiagFilter(String(first));
              }}
            >
              <SegmentedControlItem id="ALL">All</SegmentedControlItem>
              <SegmentedControlItem id="SUCCESS">Success</SegmentedControlItem>
              <SegmentedControlItem id="WARNING">Warning</SegmentedControlItem>
              <SegmentedControlItem id="FAILURE">Failure</SegmentedControlItem>
            </SegmentedControl>

            <Button variant="secondary" size="small" leadingIcon={RiRefreshLine} onClick={loadAll}>
              Refresh logs
            </Button>
          </div>

          <div className="rounded-2xl border border-border-table bg-background-primary-default p-4 shadow-card">
            <Table aria-label="System diagnostics logs" size="sm">
              <TableHeader>
                <TableColumn isRowHeader>Check</TableColumn>
                <TableColumn>Outcome</TableColumn>
                <TableColumn>Correlation</TableColumn>
                <TableColumn>Details</TableColumn>
                <TableColumn>Time</TableColumn>
              </TableHeader>
              <TableBody>
                {filteredDiag.map((log) => (
                  <TableRow key={log.log_id}>
                    <TableCell className="text-text-primary">{log.event_type}</TableCell>
                    <TableCell>
                      <span className="inline-flex items-center gap-1.5">
                        <StatusDot
                          color={
                            log.outcome === 'SUCCESS'
                              ? 'green'
                              : log.outcome === 'WARNING'
                                ? 'yellow'
                                : 'indigo'
                          }
                        />
                        {log.outcome}
                      </span>
                    </TableCell>
                    <TableCell>
                      <Badge color="neutral">{log.correlation_id || 'local'}</Badge>
                    </TableCell>
                    <TableCell className="max-w-md truncate text-text-secondary">
                      {log.message}
                    </TableCell>
                    <TableCell className="text-text-tertiary tabular-nums">
                      {formatRelativeTime(log.occurred_at)}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        </TabPanel>

        {/* TAB 4: VERIFICATION SUITE */}
        <TabPanel id="tests" className="flex flex-col gap-4">
          <div className="flex flex-wrap items-center justify-between gap-4 rounded-2xl border border-border-button-default bg-background-secondary-default p-4">
            <div className="flex flex-col gap-0.5">
              <h3 className="text-headline-medium text-text-primary">
                Automated consistency & reliability scenarios
              </h3>
              <p className="text-body-regular text-text-secondary">
                Verifies approval lock isolation, idempotency, concurrency versions, and schedule collisions.
              </p>
            </div>

            <div className="flex items-center gap-3">
              {runningTests && <AgentThinking variant="wave" label="Running scenarios" showTimer />}
              <Button
                variant="primary"
                size="medium"
                leadingIcon={RiPlayFill}
                onClick={handleRunTests}
                disabled={runningTests}
              >
                {runningTests ? 'Running…' : 'Run 14 scenarios'}
              </Button>
            </div>
          </div>

          {report ? (
            <div className="grid grid-cols-1 gap-2.5 md:grid-cols-2">
              {report.results.map((item) => (
                <div
                  key={item.id}
                  className="flex items-center justify-between gap-3 rounded-2xl border border-border-button-default bg-background-primary-default p-3.5 shadow-card"
                >
                  <div className="flex min-w-0 items-center gap-2.5">
                    <RiCheckboxCircleLine
                      className="size-5 shrink-0 text-status-lime-text"
                      aria-hidden
                    />
                    <div className="min-w-0">
                      <div className="truncate text-body-medium text-text-primary">
                        {item.id} · {item.name}
                      </div>
                      <div className="truncate text-caption-1-regular text-text-secondary">
                        {item.note}
                      </div>
                    </div>
                  </div>
                  <Badge color="neutral">{item.durationMs}ms</Badge>
                </div>
              ))}
            </div>
          ) : (
            <div className="flex min-h-[160px] flex-col items-center justify-center gap-2 rounded-2xl border border-dashed border-border-button-default bg-background-secondary-default p-8 text-center">
              <RiShieldCheckLine className="size-8 text-foreground-icon-tertiary" aria-hidden />
              <p className="text-body-medium text-text-primary">Verification suite idle</p>
              <p className="text-body-regular text-text-secondary">
                Trigger “Run 14 scenarios” to validate backend invariants or offline fallbacks.
              </p>
            </div>
          )}
        </TabPanel>
      </Tabs>
    </div>
  );
}

