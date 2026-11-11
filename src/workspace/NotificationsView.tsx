import { useMemo } from 'react';
import {
  RiCalendarCheckLine,
  RiErrorWarningFill,
  RiMailCheckLine,
  RiRefreshLine,
} from '@remixicon/react';
import {
  NotificationCenter,
  type NotificationCenterItem,
} from '@/components/application/notification-center/notification-center';
import { Button } from '@/components/base/buttons/button';
import type { WorkspaceNotification } from './types';
import { formatRelativeTime } from './workspaceApi';

export function toBoardUINotification(n: WorkspaceNotification): NotificationCenterItem {
  const lower = `${n.title} ${n.message}`.toLowerCase();
  const isFlight = lower.includes('schedul') || lower.includes('flight');
  const isRevision =
    lower.includes('revis') || lower.includes('change') || lower.includes('reject');

  return {
    id: n.notification_id,
    category: isFlight ? 'system' : 'mentions',
    group: Number(n.is_read) === 0 || n.is_read === false ? 'Unread dispatches' : 'Earlier activity',
    title: n.title,
    description: n.message,
    timestamp: `${n.channel} · ${formatRelativeTime(n.created_at)}`,
    unread: !n.is_read,
    status: isRevision ? 'error' : isFlight ? 'success' : 'information',
    icon: isFlight ? RiCalendarCheckLine : isRevision ? RiErrorWarningFill : RiMailCheckLine,
    actions: [
      ...(n.campaign_id
        ? [{ id: 'inspect', label: 'Inspect brief', variant: 'primary' as const }]
        : []),
      ...(!n.is_read ? [{ id: 'read', label: 'Mark read', variant: 'secondary' as const }] : []),
    ],
  };
}

export function NotificationsView({
  notifications,
  unreadCount,
  onMarkRead,
  onMarkAllRead,
  onInspectCampaign,
  onRefresh,
}: {
  notifications: WorkspaceNotification[];
  unreadCount: number;
  onMarkRead: (notificationId: string) => void;
  onMarkAllRead: () => void;
  onInspectCampaign: (campaignId: string) => void;
  onRefresh: () => void;
}) {
  const items = useMemo(
    () => notifications.map(toBoardUINotification),
    [notifications],
  );

  const handleAction = (notificationId: string, actionId: string) => {
    const matched = notifications.find((n) => n.notification_id === notificationId);
    if (!matched) return;
    if (!matched.is_read) onMarkRead(notificationId);
    if (actionId === 'inspect' && matched.campaign_id) {
      onInspectCampaign(matched.campaign_id);
    }
  };

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-border-button-default bg-background-secondary-default p-3">
        <div className="flex flex-col gap-0.5 px-1">
          <span className="text-body-medium text-text-primary">
            {unreadCount > 0
              ? `${unreadCount} unread workspace dispatches`
              : 'All workspace dispatches acknowledged'}
          </span>
          <span className="text-caption-1-regular text-text-secondary">
            Synced from durable outbox delivery across in-app, push, and email lanes.
          </span>
        </div>

        <Button variant="secondary" size="small" leadingIcon={RiRefreshLine} onClick={onRefresh}>
          Refresh feed
        </Button>
      </div>

      <NotificationCenter
        title="Workspace notifications"
        notifications={items}
        onAction={handleAction}
        onMarkAllRead={onMarkAllRead}
        className="w-full max-w-none"
      />
    </div>
  );
}
