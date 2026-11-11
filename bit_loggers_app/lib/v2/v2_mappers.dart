import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'v2_components.dart';
import 'v2_tokens.dart';

/// Shared view-model builders mapping backend domain models to v2 instrument widgets.
class V2Mappers {
  V2Mappers._();

  static List<CampaignVersion> sortedVersions(Campaign campaign) {
    if (campaign.versions.isEmpty) {
      return campaign.currentVersion != null ? [campaign.currentVersion!] : const [];
    }
    final list = List<CampaignVersion>.from(campaign.versions);
    list.sort((a, b) => a.versionNo.compareTo(b.versionNo));
    return list;
  }

  static double? previousBudgetFor(Campaign campaign, CampaignVersion version) {
    final versions = sortedVersions(campaign);
    final idx = versions.indexWhere((v) => v.versionId == version.versionId || v.versionNo == version.versionNo);
    if (idx > 0) {
      return versions[idx - 1].budget;
    }
    return null;
  }

  static CampaignVersion? previousVersionFor(Campaign campaign, CampaignVersion version) {
    final versions = sortedVersions(campaign);
    final idx = versions.indexWhere((v) => v.versionId == version.versionId || v.versionNo == version.versionNo);
    if (idx > 0) return versions[idx - 1];
    return null;
  }

  static String deltaSummary(Campaign campaign) {
    final versions = sortedVersions(campaign);
    final cur = campaign.currentVersion;
    if (cur == null) return 'Draft';
    if (versions.length > 1) {
      final prev = versions[versions.length - 2];
      final diff = cur.budget - prev.budget;
      if (diff.abs() >= 1 && prev.budget > 0) {
        final pct = ((diff / prev.budget) * 100).round();
        final sign = diff > 0 ? '+' : '';
        return 'Budget $sign$pct% vs V${prev.versionNo}.0';
      }
      if (prev.targetAudience != cur.targetAudience) {
        return 'Audience refined vs V${prev.versionNo}.0';
      }
    }
    final statusKey = V2Tokens.normalizeStatusKey(campaign.status);
    if (statusKey == 'approved') return 'Approved by reviewer';
    if (statusKey == 'scheduled') return 'Scheduled on ${cur.channel}';
    if (statusKey == 'changes') return 'Revisions requested';
    if (statusKey == 'blocked') return 'Rejected during review';
    return 'Awaiting compliance signoff';
  }

  static String formatShortTimestamp(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return 'Recent';
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today · ${DateFormat('HH:mm').format(dt)}';
    }
    return DateFormat('MMM dd · HH:mm').format(dt);
  }

  static String flightWindowLabel(Campaign campaign, List<ScheduleEvent> events) {
    final ev = events.where((e) => e.campaignId == campaign.campaignId).toList();
    if (ev.isNotEmpty) {
      final s = DateTime.tryParse(ev.first.startsAt)?.toLocal();
      final e = DateTime.tryParse(ev.first.endsAt)?.toLocal();
      if (s != null && e != null) {
        return '${DateFormat('MMM dd').format(s)}–${DateFormat('dd').format(e)}';
      }
    }
    final created = DateTime.tryParse(campaign.createdAt)?.toLocal() ?? DateTime.now();
    final end = created.add(const Duration(days: 13));
    return '${DateFormat('MMM dd').format(created)}–${DateFormat('dd').format(end)}';
  }

  /// Builds synchronized vertical version stamps combining immutable snapshots + review decisions.
  static List<V2StampEntry> buildStampLedger(Campaign campaign) {
    final versions = sortedVersions(campaign);
    final list = <V2StampEntry>[];

    for (int i = 0; i < versions.length; i++) {
      final v = versions[i];
      final prev = i > 0 ? versions[i - 1] : null;
      final isCurrent = v.versionId == campaign.currentVersionId || i == versions.length - 1;

      ApprovalDecision? dec;
      for (final d in campaign.decisions) {
        if (d.versionId == v.versionId) {
          dec = d;
          break;
        }
      }

      String statusKey;
      String stampWord;
      String actor;
      if (dec != null) {
        if (dec.decisionType == 'APPROVED') {
          statusKey = (isCurrent && V2Tokens.normalizeStatusKey(campaign.status) == 'scheduled')
              ? 'scheduled'
              : 'approved';
          stampWord = statusKey == 'scheduled' ? 'Scheduled' : 'Approved';
        } else if (dec.decisionType == 'CHANGES_REQUESTED') {
          statusKey = 'changes';
          stampWord = 'Changes';
        } else {
          statusKey = 'blocked';
          stampWord = 'Blocked';
        }
        actor = V2Tokens.cleanPersonName(dec.reviewerName);
      } else if (isCurrent) {
        statusKey = V2Tokens.normalizeStatusKey(campaign.status);
        stampWord = V2Tokens.statusStyle(statusKey).label;
        actor = V2Tokens.cleanPersonName(campaign.ownerName);
      } else {
        statusKey = 'brand';
        stampWord = 'Superseded';
        actor = V2Tokens.cleanPersonName(campaign.ownerName);
      }

      final clauses = <V2StampClause>[];
      if (prev != null) {
        clauses.add(
          V2StampClause(
            field: 'Audience',
            metricDelta: prev.targetAudience == v.targetAudience
                ? '${v.targetAudience} (retained)'
                : '${_shortLabel(prev.targetAudience)} → ${_shortLabel(v.targetAudience)}',
            note: dec?.reason ?? v.aiSummary ?? 'Audience targeting verified against CPA guardrails.',
            clauseStatus: statusKey == 'changes' ? 'changes' : 'approved',
            resolutionTag: dec?.decisionType == 'CHANGES_REQUESTED'
                ? 'Needs update'
                : 'V${v.versionNo}.0 target',
          ),
        );
        clauses.add(
          V2StampClause(
            field: 'Budget',
            metricDelta:
                '${V2Tokens.formatCurrency(prev.budget)} → ${V2Tokens.formatCurrency(v.budget)}',
            note: v.budget <= 30000
                ? 'Within \$30k guardrail ceiling'
                : 'Exceeds standard \$30k ceiling',
            clauseStatus: statusKey == 'approved' || statusKey == 'scheduled'
                ? 'approved'
                : 'changes',
            resolutionTag: statusKey == 'approved' || statusKey == 'scheduled'
                ? 'Locked V${v.versionNo}.0'
                : 'Needs Stamp',
          ),
        );
      } else {
        clauses.add(
          V2StampClause(
            field: 'Budget',
            metricDelta: '${V2Tokens.formatCurrency(v.budget)} baseline',
            note: dec?.reason ?? v.objective,
            clauseStatus: statusKey == 'blocked' ? 'blocked' : 'approved',
            resolutionTag: 'Baseline V${v.versionNo}.0',
          ),
        );
        clauses.add(
          V2StampClause(
            field: 'Channel',
            metricDelta: '${v.channel} · CPA \$${v.kpiProjected.cpa.toStringAsFixed(2)}',
            note: v.aiSummary ?? v.targetAudience,
            clauseStatus: 'approved',
            resolutionTag: 'Channel set',
          ),
        );
      }

      list.add(
        V2StampEntry(
          versionNo: v.versionNo,
          versionTag: V2Tokens.formatVersionTag(v.versionNo),
          status: statusKey,
          stampWord: stampWord,
          actor: actor,
          time: formatShortTimestamp(dec?.decidedAt ?? v.createdAt),
          clauses: clauses,
        ),
      );
    }

    return list;
  }

  static String _shortLabel(String s) {
    final trimmed = s.trim();
    if (trimmed.length <= 16) return trimmed;
    return '${trimmed.substring(0, 14)}…';
  }
}

/// Perforated dispatch card representing a Campaign row in v2 Pipeline.
class V2FlightTicketCard extends StatelessWidget {
  final Campaign campaign;
  final List<ScheduleEvent> calendarEvents;
  final int leaseSeconds;
  final VoidCallback onTap;

  const V2FlightTicketCard({
    super.key,
    required this.campaign,
    required this.calendarEvents,
    required this.leaseSeconds,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cur = campaign.currentVersion;
    final budget = cur?.budget ?? 15000.0;
    final prevBudget = cur != null ? V2Mappers.previousBudgetFor(campaign, cur) : null;
    final versionTag = V2Tokens.formatVersionTag(cur?.versionNo ?? 1);
    final statusKey = V2Tokens.normalizeStatusKey(campaign.status);
    final deltaText = V2Mappers.deltaSummary(campaign);
    final dates = V2Mappers.flightWindowLabel(campaign, calendarEvents);
    final lock = campaign.activeLock;
    final deltaIsPositive = statusKey == 'approved' || statusKey == 'scheduled';

    return Material(
      color: V2Tokens.surfaceCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: V2Tokens.hairline, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: V2Tokens.surfaceRecessed,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: V2Tokens.hairline, width: 0.6),
                          ),
                          child: Text(versionTag, style: V2Tokens.t4(color: V2Tokens.textPrimary)),
                        ),
                        V2StatusBadge(status: statusKey),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(campaign.title, style: V2Tokens.t2()),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            V2Tokens.cleanPersonName(campaign.ownerName),
                            overflow: TextOverflow.ellipsis,
                            style: V2Tokens.t3(color: V2Tokens.textSecondary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (lock != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: V2Tokens.surfaceRecessed,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: V2Tokens.hairline, width: 0.6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.lock_outline_rounded, size: 11, color: V2Tokens.textSecondary),
                                const SizedBox(width: 5),
                                Text(
                                  '${V2Tokens.cleanPersonName(lock.holderName).split(' ').first} is editing, ${V2Tokens.formatLease(leaseSeconds)}',
                                  style: V2Tokens.t4(color: V2Tokens.textPrimary),
                                ),
                              ],
                            ),
                          )
                        else
                          Flexible(
                            child: Text(
                              deltaText,
                              overflow: TextOverflow.ellipsis,
                              style: V2Tokens.t4(
                                color: deltaIsPositive
                                    ? V2Tokens.approvedSolid
                                    : V2Tokens.changesSolid,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const V2TicketPerforation(notchBg: V2Tokens.bgPlaster),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            '${cur?.channel ?? 'Social'} · $dates',
                            overflow: TextOverflow.ellipsis,
                            style: V2Tokens.t3(color: V2Tokens.textSecondary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          V2Tokens.formatCurrency(budget),
                          style: V2Tokens.t2(mono: true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    V2CellMeter(
                      amount: budget,
                      prevAmount: prevBudget,
                      maxAmount: 40000,
                      ceilingRatio: 0.75,
                      totalCells: 24,
                      cellHeight: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

