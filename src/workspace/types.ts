export interface WorkspaceUser {
  id: string;
  name: string;
  email: string;
  role: 'marketer' | 'reviewer' | 'admin' | string;
}

export interface KpiMetrics {
  conversionRate: number;
  ctr: number;
  roi: number;
  cpa: number;
  aov: number;
}

export interface CampaignVersion {
  version_id: string;
  version_no: number;
  title?: string;
  objective: string;
  target_audience: string;
  channel: string;
  budget: number;
  kpi_projected: KpiMetrics;
  ai_summary?: string;
  creative_headline?: string;
  creative_cta?: string;
  created_by: string;
  created_at: string;
}

export interface ApprovalDecision {
  decision_id: string;
  version_id: string;
  reviewer_id: string;
  reviewer_name?: string;
  decision: 'APPROVED' | 'CHANGES_REQUESTED' | 'REJECTED' | string;
  reason: string;
  policy_reference?: string;
  decided_at: string;
}

export interface EditLock {
  campaign_id: string;
  holder_id: string;
  holder_name?: string;
  expires_at: string;
}

export interface Campaign {
  campaign_id: string;
  title: string;
  status: string;
  owner_id: string;
  owner_name?: string;
  channel: string;
  budget: number;
  objective?: string;
  target_audience?: string;
  current_version_id?: string;
  current_version?: CampaignVersion;
  versions?: CampaignVersion[];
  decisions?: ApprovalDecision[];
  active_lock?: EditLock | null;
  created_at: string;
  updated_at: string;
}

export interface ScheduleEvent {
  schedule_id: string;
  campaign_id: string;
  version_id: string;
  version_no: number;
  title: string;
  channel: string;
  status: string;
  starts_at: string;
  ends_at: string;
}

export interface WorkspaceNotification {
  notification_id: string;
  title: string;
  message: string;
  channel: string;
  priority: string;
  is_read: number | boolean;
  created_at: string;
  campaign_id?: string;
}

export interface AuditEventItem {
  event_id: string;
  campaign_id?: string;
  actor_id?: string;
  actor_name?: string;
  event_type: string;
  previous_state?: string;
  new_state?: string;
  summary: string;
  details?: string;
  occurred_at: string;
}

export interface OutboxEventItem {
  event_id: string;
  event_type: string;
  status: string;
  attempts: number;
  max_attempts?: number;
  error_log?: string | null;
  next_retry_at?: string;
  created_at: string;
  payload?: Record<string, unknown>;
}

export interface DiagnosticLogItem {
  log_id: string;
  event_type: string;
  outcome: 'SUCCESS' | 'FAILURE' | 'WARNING' | string;
  correlation_id?: string;
  campaign_id?: string;
  error_category?: string;
  message: string;
  occurred_at: string;
}

export interface DiscussionMessage {
  message_id: string;
  campaign_id: string;
  version_id?: string;
  author_id: string;
  author_name?: string;
  author_role?: string;
  content: string;
  created_at: string;
}

export interface ChannelBreakdownItem {
  channel: string;
  count: number;
  budget: number;
  roi: number;
  conv: number;
}

export interface AnalyticsPayload {
  summary: {
    kpis: Record<
      keyof KpiMetrics,
      {
        projected: number;
        actual: number;
      }
    >;
  };
  channelBreakdown: ChannelBreakdownItem[];
  trends: Array<{
    date: string;
    projectedRevenue: number;
    actualRevenue: number;
    projectedConversions: number;
    actualConversions: number;
  }>;
}

export interface TestCaseResult {
  id: string;
  category: string;
  name: string;
  passed: boolean;
  durationMs: number;
  note: string;
}

export interface TestReport {
  allPassed: boolean;
  passedCount: number;
  total: number;
  qaSummary: {
    qa01Consistency: string;
    qa02Reliability: string;
    qa03Security: string;
  };
  results: TestCaseResult[];
}

