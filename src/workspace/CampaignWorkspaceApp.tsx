import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  RiAddFill,
  RiBarChartBoxLine,
  RiCalendarLine,
  RiDashboardLine,
  RiKanbanView2,
  RiMenuLine,
  RiNotification3Line,
  RiShieldCheckLine,
} from '@remixicon/react';
import { NotificationBell } from '@/components/application/app-shell/notification-bell';
import {
  DashboardSidebar,
  type DashboardNavItem,
} from '@/components/application/dashboard/dashboard-sidebar';
import type { DashboardUserOption } from '@/components/application/dashboard/dashboard-user-menu';
import { Badge } from '@/components/base/badges/badge';
import { Breadcrumb, BreadcrumbItem } from '@/components/base/breadcrumb/breadcrumb';
import { Button } from '@/components/base/buttons/button';
import { IconButton } from '@/components/base/buttons/icon-button';
import {
  Notification,
  NotificationViewport,
  type NotificationStatus,
} from '@/components/base/notification/notification';
import { DirectionProvider } from '@/components/foundations/direction/direction';
import { AnalyticsView } from './AnalyticsView';
import { CalendarView } from './CalendarView';
import { CampaignDetailDrawer } from './CampaignDetailDrawer';
import { GovernanceView } from './GovernanceView';
import { NotificationsView, toBoardUINotification } from './NotificationsView';
import { PipelineView } from './PipelineView';
import { ProposalStudioModal } from './ProposalStudioModal';
import { canCreateCampaign } from './stateMachine';
import type { Campaign, WorkspaceNotification, WorkspaceUser } from './types';
import { workspaceApi } from './workspaceApi';

type SectionKey = 'pipeline' | 'calendar' | 'analytics' | 'notifications' | 'governance';

interface ToastBanner {
  id: string;
  title: string;
  description: string;
  status: NotificationStatus;
}

const SECTION_META: Record<SectionKey, { title: string; subtitle: string; icon: typeof RiKanbanView2 }> = {
  pipeline: {
    title: 'Pipeline',
    subtitle: 'Track versioned briefs across authoring, compliance review, and live flights.',
    icon: RiKanbanView2,
  },
  calendar: {
    title: 'Calendar',
    subtitle: 'Coordinate conflict-free channel windows bound to approved campaign versions.',
    icon: RiCalendarLine,
  },
  analytics: {
    title: 'Analytics',
    subtitle: 'Monitor projected vs actual ROI, conversion, and CPA performance across channels.',
    icon: RiBarChartBoxLine,
  },
  notifications: {
    title: 'Notifications',
    subtitle: 'Real-time review decisions, revision requests, and scheduled flight alerts.',
    icon: RiNotification3Line,
  },
  governance: {
    title: 'Governance & QA',
    subtitle: 'Inspect audit transitions, transactional outbox retries, diagnostics, and 14 checks.',
    icon: RiShieldCheckLine,
  },
};

export function CampaignWorkspaceApp({ onOpenOverview }: { onOpenOverview: () => void }) {
  const [navOpen, setNavOpen] = useState(false);
  const [activeSection, setActiveSection] = useState<SectionKey>('pipeline');

  const [users, setUsers] = useState<WorkspaceUser[]>([]);
  const [currentUser, setCurrentUser] = useState<WorkspaceUser>({
    id: 'usr-marketer-1',
    name: 'Alice Cooper',
    email: 'alice.marketer@bitloggers.com',
    role: 'marketer',
  });
  const [campaigns, setCampaigns] = useState<Campaign[]>([]);
  const [notifications, setNotifications] = useState<WorkspaceNotification[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);

  const [inspectId, setInspectId] = useState<string | null>(null);
  const [inspectTab, setInspectTab] = useState('overview');
  const [studioOpen, setStudioOpen] = useState(false);
  const [editingCampaign, setEditingCampaign] = useState<Campaign | null>(null);
  const [toasts, setToasts] = useState<ToastBanner[]>([]);

  const pushToast = useCallback(
    (title: string, description: string, status: NotificationStatus = 'information') => {
      const id = `toast-${Date.now()}-${Math.random().toString(16).slice(2, 6)}`;
      setToasts((prev) => [{ id, title, description, status }, ...prev].slice(0, 3));
    },
    [],
  );

  const loadWorkspace = useCallback(
    async (user: WorkspaceUser = currentUser) => {
      const [userList, campList, notifRes] = await Promise.all([
        workspaceApi.getUsers(),
        workspaceApi.getCampaigns(user),
        workspaceApi.getNotifications(user),
      ]);
      setUsers(userList);
      setCampaigns(campList);
      setNotifications(notifRes.notifications);
      setUnreadCount(notifRes.unreadCount);
    },
    [currentUser],
  );

  useEffect(() => {
    loadWorkspace(currentUser);
  }, [currentUser.id]);

  const handleSelectUser = (userId: string) => {
    const match = users.find((u) => u.id === userId);
    if (!match) return;
    setCurrentUser(match);
    pushToast(
      `Operating as ${match.name}`,
      `Active permissions switched to ${match.role} role.`,
      'information',
    );
  };

  const handleMarkRead = async (notificationId: string) => {
    await workspaceApi.markNotificationRead(notificationId, currentUser);
    await loadWorkspace(currentUser);
  };

  const handleMarkAllRead = async () => {
    await workspaceApi.markAllNotificationsRead(currentUser);
    await loadWorkspace(currentUser);
    pushToast('Notifications cleared', 'All workspace dispatches marked as read.', 'success');
  };

  const handleSubmitCampaign = async (campaignId: string) => {
    try {
      await workspaceApi.submitCampaign(campaignId, currentUser);
      await loadWorkspace(currentUser);
      pushToast('Submitted for review', 'Brief locked to current version for reviewer signoff.', 'success');
    } catch (err: unknown) {
      pushToast('Submission failed', (err as Error).message, 'error');
    }
  };

  const userOptions: DashboardUserOption[] = useMemo(
    () =>
      users.map((u, idx) => ({
        id: u.id,
        initials: u.name.slice(0, 1).toUpperCase(),
        color: idx === 0 ? 'neutral' : idx === 1 ? 'lime' : 'blue',
        name: u.name,
        roleLabel: u.role,
      })),
    [users],
  );

  const navItems: DashboardNavItem[] = useMemo(
    () => [
      {
        key: 'pipeline',
        label: 'Pipeline',
        icon: RiKanbanView2,
        badge: campaigns.length,
      },
      {
        key: 'calendar',
        label: 'Calendar',
        icon: RiCalendarLine,
      },
      {
        key: 'analytics',
        label: 'Analytics',
        icon: RiBarChartBoxLine,
      },
      {
        key: 'notifications',
        label: 'Notifications',
        icon: RiNotification3Line,
        badge: unreadCount > 0 ? unreadCount : undefined,
      },
      {
        key: 'governance',
        label: 'Governance & QA',
        icon: RiShieldCheckLine,
      },
    ],
    [campaigns.length, unreadCount],
  );

  const mappedNotifs = useMemo(
    () => notifications.map(toBoardUINotification),
    [notifications],
  );

  const meta = SECTION_META[activeSection];

  return (
    <DirectionProvider locale="en-US">
      <div className="relative flex h-dvh w-full gap-4 overflow-hidden bg-background-full p-3 text-text-primary">
        {/* Desktop Floating BoardUI Sidebar */}
        <DashboardSidebar
          items={navItems}
          selected={activeSection}
          onSelect={(key) => setActiveSection(key as SectionKey)}
          userName={currentUser.name}
          userInitials={currentUser.name.slice(0, 1).toUpperCase()}
          users={userOptions}
          selectedUserId={currentUser.id}
          onSelectUser={handleSelectUser}
          teamName="CampaignGrid v3"
          teamSubtitle={`${currentUser.role} · BoardUI`}
          onOpenOverview={onOpenOverview}
          onSupportClick={() => setActiveSection('governance')}
          className="hidden lg:flex"
        />

        {/* Mobile Drawer Sidebar */}
        {navOpen && (
          <div className="fixed inset-0 z-50 flex lg:hidden">
            <button
              type="button"
              aria-label="Close navigation"
              onClick={() => setNavOpen(false)}
              className="absolute inset-0 cursor-pointer bg-black/40"
            />
            <div className="relative flex h-full p-3">
              <DashboardSidebar
                mobile
                items={navItems}
                selected={activeSection}
                onSelect={(key) => setActiveSection(key as SectionKey)}
                onClose={() => setNavOpen(false)}
                userName={currentUser.name}
                userInitials={currentUser.name.slice(0, 1).toUpperCase()}
                users={userOptions}
                selectedUserId={currentUser.id}
                onSelectUser={handleSelectUser}
                teamName="CampaignGrid v3"
                teamSubtitle={`${currentUser.role} · BoardUI`}
                onOpenOverview={onOpenOverview}
                onSupportClick={() => setActiveSection('governance')}
                className="flex"
              />
            </div>
          </div>
        )}

        {/* Main BoardUI 1300px Canvas */}
        <main className="relative flex min-h-0 min-w-0 flex-1 justify-center overflow-x-hidden overflow-y-auto bg-background-full px-1 sm:px-2 sm:pt-3">
          <div className="flex w-full max-w-[1300px] flex-col gap-5 pb-10">
            {/* Header Breadcrumb & Toolbar */}
            <header className="flex w-full flex-col gap-2">
              <Breadcrumb>
                <BreadcrumbItem icon={RiDashboardLine} onClick={onOpenOverview}>
                  CampaignGrid v3
                </BreadcrumbItem>
                <BreadcrumbItem>{currentUser.name}</BreadcrumbItem>
                <BreadcrumbItem icon={meta.icon} current>
                  {meta.title}
                </BreadcrumbItem>
              </Breadcrumb>

              <div className="flex w-full flex-wrap items-center justify-between gap-3">
                <div className="flex min-w-0 items-center gap-2.5">
                  <IconButton
                    icon={RiMenuLine}
                    size="medium"
                    aria-label="Open navigation"
                    onClick={() => setNavOpen(true)}
                    className="lg:hidden"
                  />
                  <div className="flex min-w-0 flex-col">
                    <div className="flex items-center gap-2">
                      <h1 className="text-title-1-semibold text-text-primary">
                        {meta.title}
                      </h1>
                      <Badge color="primary">v3</Badge>
                    </div>
                    <p className="text-body-regular text-text-secondary">
                      {meta.subtitle}
                    </p>
                  </div>
                </div>

                <div className="flex shrink-0 items-center gap-2.5">
                  <Button variant="ghost" size="small" onClick={onOpenOverview}>
                    Showcase
                  </Button>
                  <NotificationBell
                    notifications={mappedNotifs}
                    onMarkAllRead={handleMarkAllRead}
                    onAction={(nid, aid) => {
                      const found = notifications.find((n) => n.notification_id === nid);
                      if (found && !found.is_read) handleMarkRead(nid);
                      if (aid === 'inspect' && found?.campaign_id) {
                        setInspectTab('overview');
                        setInspectId(found.campaign_id);
                      }
                    }}
                  />
                  {canCreateCampaign(currentUser) && (
                    <Button
                      variant="primary"
                      size="medium"
                      leadingIcon={RiAddFill}
                      onClick={() => {
                        setEditingCampaign(null);
                        setStudioOpen(true);
                      }}
                    >
                      New brief
                    </Button>
                  )}
                </div>
              </div>
            </header>

            {/* Active Workspace View */}
            {activeSection === 'pipeline' && (
              <PipelineView
                campaigns={campaigns}
                currentUser={currentUser}
                onInspectCampaign={(cid, tab = 'overview') => {
                  setInspectTab(tab);
                  setInspectId(cid);
                }}
                onEditCampaign={(camp) => {
                  setEditingCampaign(camp);
                  setStudioOpen(true);
                }}
                onSubmitCampaign={handleSubmitCampaign}
                onOpenSchedule={(cid) => {
                  setInspectTab('schedule');
                  setInspectId(cid);
                }}
              />
            )}

            {activeSection === 'calendar' && (
              <CalendarView
                currentUser={currentUser}
                onInspectCampaign={(cid) => {
                  setInspectTab('overview');
                  setInspectId(cid);
                }}
              />
            )}

            {activeSection === 'analytics' && <AnalyticsView currentUser={currentUser} />}

            {activeSection === 'notifications' && (
              <NotificationsView
                notifications={notifications}
                unreadCount={unreadCount}
                onMarkRead={handleMarkRead}
                onMarkAllRead={handleMarkAllRead}
                onInspectCampaign={(cid) => {
                  setInspectTab('overview');
                  setInspectId(cid);
                }}
                onRefresh={() => loadWorkspace(currentUser)}
              />
            )}

            {activeSection === 'governance' && (
              <GovernanceView
                currentUser={currentUser}
                onInspectCampaign={(cid) => {
                  setInspectTab('overview');
                  setInspectId(cid);
                }}
                onNotify={pushToast}
              />
            )}
          </div>
        </main>

        {/* Detail Drawer + Proposal Authoring Studio */}
        <CampaignDetailDrawer
          campaignId={inspectId}
          initialTab={inspectTab}
          currentUser={currentUser}
          onClose={() => setInspectId(null)}
          onEditCampaign={(camp) => {
            setEditingCampaign(camp);
            setStudioOpen(true);
          }}
          onMutated={() => loadWorkspace(currentUser)}
          onNotify={pushToast}
        />

        <ProposalStudioModal
          isOpen={studioOpen}
          campaign={editingCampaign}
          currentUser={currentUser}
          onClose={() => {
            setStudioOpen(false);
            setEditingCampaign(null);
          }}
          onSaved={() => loadWorkspace(currentUser)}
          onNotify={pushToast}
        />

        {/* Real-Time Viewport Toast Notifications (Genuine BoardUI Notification Stack) */}
        <NotificationViewport position="bottom-end">
          {toasts.map((t) => (
            <Notification
              key={t.id}
              title={t.title}
              description={t.description}
              status={t.status}
              autoDismissDuration={4500}
              onDismiss={() => setToasts((prev) => prev.filter((item) => item.id !== t.id))}
            />
          ))}
        </NotificationViewport>
      </div>
    </DirectionProvider>
  );
}
