import React, { useState, useEffect, useRef } from 'react';

// ============================================================================
// 1. UNIFIED DESIGN SYSTEM: "THE PERFORATED LEDGER & FACET INSTRUMENT"
// ============================================================================
const TOKENS = {
  bgPlaster: '#F2F0EB',
  surfaceCard: '#FBFAF7',
  surfaceRecessed: '#E9E6DF',
  hairline: '#D8D3C7',
  textPrimary: '#122230',
  textSecondary: '#46535F',
  inkPrussian: '#16324A',
  labelOnInk: '#FFFFFF',
  cadmiumYellow: '#F0B323',
  changedRowTint: '#F8F2E4',
  status: {
    approved:  { solid: '#1F7A5C', chipBg: '#E4F0EC', label: 'Approved' },
    scheduled: { solid: '#1F7A5C', chipBg: '#E4F0EC', label: 'Scheduled' },
    changes:   { solid: '#8A5200', chipBg: '#F6ECD9', label: 'Changes' },
    blocked:   { solid: '#B3281A', chipBg: '#F7E5E2', label: 'Blocked' },
    review:    { solid: '#21496A', chipBg: '#E3ECF3', label: 'In review' },
    brand:     { solid: '#16324A', chipBg: '#E3ECF3', label: 'Campaign Grid' }
  },
  fontSans: '-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "Inter", system-ui, sans-serif',
  fontMono: '"SF Mono", "JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, monospace'
};

// Strict 4-Tier Typography Scale (11px minimum floor across the entire app)
const TYPE = {
  t1: { fontSize: '30px', fontWeight: 700, letterSpacing: '-0.03em', lineHeight: 1.08 },
  t2: { fontSize: '16px', fontWeight: 600, letterSpacing: '-0.015em', lineHeight: 1.25 },
  t3: { fontSize: '13px', fontWeight: 500, letterSpacing: '-0.005em', lineHeight: 1.38 },
  t4: {
    fontFamily: TOKENS.fontMono,
    fontVariantNumeric: 'tabular-nums',
    fontSize: '11px',
    fontWeight: 600,
    letterSpacing: '0.02em',
    lineHeight: 1.15
  }
};

const MonoIcons = {
  Check: ({ color = TOKENS.status.approved.solid, size = 13 }) => (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none" style={{ display: 'block', flexShrink: 0 }}>
      <path d="M13.2 4.5L6.5 11.2L2.8 7.5" stroke={color} strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  ),
  Loop: ({ color = TOKENS.status.changes.solid, size = 13 }) => (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none" style={{ display: 'block', flexShrink: 0 }}>
      <path d="M2.5 8A5.5 5.5 0 0 1 12.2 4.5M13.5 8A5.5 5.5 0 0 1 3.8 11.5" stroke={color} strokeWidth="1.75" strokeLinecap="round" />
      <path d="M10.2 4.5H12.6V2.1M5.8 11.5H3.4V13.9" stroke={color} strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  ),
  Clock: ({ color = TOKENS.status.review.solid, size = 13 }) => (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none" style={{ display: 'block', flexShrink: 0 }}>
      <circle cx="8" cy="8" r="5.75" stroke={color} strokeWidth="1.75" />
      <path d="M8 5V8.2L10.2 9.6" stroke={color} strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  ),
  Alert: ({ color = TOKENS.status.blocked.solid, size = 13 }) => (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none" style={{ display: 'block', flexShrink: 0 }}>
      <circle cx="8" cy="8" r="5.75" stroke={color} strokeWidth="1.75" />
      <path d="M8 5.2V8.5M8 10.9H8.01" stroke={color} strokeWidth="1.75" strokeLinecap="round" />
    </svg>
  ),
  Lock: ({ color = TOKENS.textSecondary, size = 13 }) => (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none" style={{ display: 'block', flexShrink: 0 }}>
      <rect x="3.25" y="7.25" width="9.5" height="6.5" rx="1.75" stroke={color} strokeWidth="1.75" />
      <path d="M5.25 7.25V5.25a2.75 2.75 0 0 1 5.5 0v2" stroke={color} strokeWidth="1.75" strokeLinecap="round" />
    </svg>
  ),
  ChevronLeft: ({ color = TOKENS.textPrimary, size = 15 }) => (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none" style={{ display: 'block', flexShrink: 0 }}>
      <path d="M10 3.5L5.5 8L10 12.5" stroke={color} strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  ),
  ArrowRight: ({ color = TOKENS.textSecondary, size = 13 }) => (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none" style={{ display: 'block', flexShrink: 0 }}>
      <path d="M3 8H13M9.5 4.5L13 8L9.5 11.5" stroke={color} strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  ),
  HandHold: ({ color = '#FFFFFF', size = 15 }) => (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none" style={{ display: 'block', flexShrink: 0 }}>
      <path d="M6.5 8.5V3.75a1.25 1.25 0 0 1 2.5 0V7.5m0 0V4.75a1.25 1.25 0 0 1 2.5 0V7.5m0 0V6a1.25 1.25 0 0 1 2.5 0v4.25a4.25 4.25 0 0 1-4.25 4.25H7.25a4 4 0 0 1-3.4-1.9L2.4 10.3a1.2 1.2 0 0 1 1.7-1.6L6.5 10" stroke={color} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  ),
  PipelineTab: ({ color = '#FFFFFF', size = 15 }) => (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none" style={{ display: 'block', flexShrink: 0 }}>
      <rect x="2.25" y="2.75" width="11.5" height="4" rx="1.25" stroke={color} strokeWidth="1.75" />
      <rect x="2.25" y="9.25" width="11.5" height="4" rx="1.25" stroke={color} strokeWidth="1.75" />
    </svg>
  ),
  CalendarTab: ({ color = TOKENS.textSecondary, size = 15 }) => (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none" style={{ display: 'block', flexShrink: 0 }}>
      <rect x="2.25" y="3.25" width="11.5" height="10.5" rx="1.75" stroke={color} strokeWidth="1.75" />
      <path d="M5.25 2V4.25M10.75 2V4.25M2.25 6.75H13.75" stroke={color} strokeWidth="1.75" strokeLinecap="round" />
    </svg>
  ),
  InsightsTab: ({ color = TOKENS.textSecondary, size = 15 }) => (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none" style={{ display: 'block', flexShrink: 0 }}>
      <path d="M2.25 12.25L6 8.5L9 10.75L13.75 4.75" stroke={color} strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  ),
  ActivityTab: ({ color = TOKENS.textSecondary, size = 15 }) => (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none" style={{ display: 'block', flexShrink: 0 }}>
      <circle cx="4" cy="4.5" r="1.5" stroke={color} strokeWidth="1.75" />
      <circle cx="4" cy="11.5" r="1.5" stroke={color} strokeWidth="1.75" />
      <path d="M4 6V10M7.5 4.5H13.5M7.5 11.5H13.5" stroke={color} strokeWidth="1.75" strokeLinecap="round" />
    </svg>
  ),
  WifiOff: ({ color = TOKENS.textSecondary, size = 14 }) => (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none" style={{ display: 'block', flexShrink: 0 }}>
      <path d="M2 2L14 14M10.8 10.8A4 4 0 0 0 5.2 10.8M13.2 8.2A7.5 7.5 0 0 0 8 6C6.8 6 5.7 6.3 4.7 6.8M8 13H8.01" stroke={color} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  ),
  Pause: ({ color = TOKENS.status.blocked.solid, size = 14 }) => (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none" style={{ display: 'block', flexShrink: 0 }}>
      <rect x="4" y="3" width="2.75" height="10" rx="1" stroke={color} strokeWidth="1.6" />
      <rect x="9.25" y="3" width="2.75" height="10" rx="1" stroke={color} strokeWidth="1.6" />
    </svg>
  ),
  Edit: ({ color = TOKENS.textPrimary, size = 13 }) => (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none" style={{ display: 'block', flexShrink: 0 }}>
      <path d="M11.2 2.5L13.5 4.8L5.3 13H3V10.7L11.2 2.5Z" stroke={color} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
};

function FacetCell({ status = 'review', size = 13, selected = false }) {
  const cfg = TOKENS.status[status] || TOKENS.status.review;
  const solidColor = cfg.solid;
  const upperColor = status === 'brand' ? '#D8D3C7' : cfg.chipBg;

  return (
    <div
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: selected ? '2px' : 0,
        borderRadius: selected ? '5px' : '3px',
        border: selected ? `1.5px solid ${TOKENS.inkPrussian}` : 'none',
        position: 'relative',
        flexShrink: 0
      }}
    >
      <svg
        width={size}
        height={size}
        viewBox="0 0 16 16"
        style={{
          display: 'block',
          borderRadius: '2.5px',
          overflow: 'hidden',
          border: `0.5px solid ${solidColor}`
        }}
      >
        <polygon points="0,0 16,0 0,16" fill={upperColor} />
        <polygon points="16,0 16,16 0,16" fill={solidColor} />
      </svg>
      {selected && (
        <span
          style={{
            position: 'absolute',
            top: '-3px',
            right: '-3px',
            width: '5px',
            height: '5px',
            borderRadius: '999px',
            backgroundColor: TOKENS.cadmiumYellow,
            border: `1px solid ${TOKENS.inkPrussian}`
          }}
        />
      )}
    </div>
  );
}

function StatusBadge({ status = 'review', customLabel }) {
  const cfg = TOKENS.status[status] || TOKENS.status.review;
  const renderIcon = () => {
    if (status === 'approved' || status === 'scheduled') return <MonoIcons.Check color={cfg.solid} size={10} />;
    if (status === 'changes') return <MonoIcons.Loop color={cfg.solid} size={10} />;
    if (status === 'blocked') return <MonoIcons.Alert color={cfg.solid} size={10} />;
    return <MonoIcons.Clock color={cfg.solid} size={10} />;
  };

  return (
    <div
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: '4px',
        backgroundColor: cfg.chipBg,
        border: `1px solid ${TOKENS.hairline}`,
        borderRadius: '999px',
        padding: '2px 7px 2px 5px',
        flexShrink: 0
      }}
    >
      <FacetCell status={status} size={9} />
      {renderIcon()}
      <span style={{ ...TYPE.t4, color: cfg.solid, whiteSpace: 'nowrap' }}>
        {customLabel || cfg.label}
      </span>
    </div>
  );
}

function TicketPerforation({ notchBg = TOKENS.bgPlaster }) {
  return (
    <div
      style={{
        position: 'relative',
        height: '16px',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        width: '100%'
      }}
    >
      <div
        style={{
          position: 'absolute',
          left: '-8px',
          width: '15px',
          height: '15px',
          borderRadius: '999px',
          backgroundColor: notchBg,
          border: `1px solid ${TOKENS.hairline}`,
          boxSizing: 'border-box'
        }}
      />
      <div
        style={{
          width: 'calc(100% - 24px)',
          borderTop: `1px dashed ${TOKENS.hairline}`
        }}
      />
      <div
        style={{
          position: 'absolute',
          right: '-8px',
          width: '15px',
          height: '15px',
          borderRadius: '999px',
          backgroundColor: notchBg,
          border: `1px solid ${TOKENS.hairline}`,
          boxSizing: 'border-box'
        }}
      />
    </div>
  );
}

function CellMeter({
  amount = 25000,
  prevAmount = null,
  maxAmount = 40000,
  ceilingRatio = 0.75,
  totalCells = 24,
  cellHeight = 10
}) {
  const filledCount = Math.min(totalCells, Math.max(1, Math.round((amount / maxAmount) * totalCells)));
  const prevFilledCount = prevAmount
    ? Math.min(totalCells, Math.max(1, Math.round((prevAmount / maxAmount) * totalCells)))
    : filledCount - 3;
  const ceilingIndex = Math.round(ceilingRatio * totalCells);

  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: '3px',
        width: '100%',
        padding: '2px 0'
      }}
    >
      {Array.from({ length: totalCells }).map((_, idx) => {
        const isFilled = idx < filledCount;
        const isAddedDelta = isFilled && idx >= Math.max(0, prevFilledCount);
        const bg = !isFilled
          ? TOKENS.surfaceRecessed
          : isAddedDelta
            ? TOKENS.cadmiumYellow
            : TOKENS.inkPrussian;

        return (
          <React.Fragment key={idx}>
            {idx === ceilingIndex && (
              <div
                title="Approved ceiling tick ($30,000)"
                style={{
                  width: '2.5px',
                  height: `${cellHeight + 6}px`,
                  backgroundColor: TOKENS.status.blocked.solid,
                  borderRadius: '1px',
                  margin: '0 2px',
                  flexShrink: 0
                }}
              />
            )}
            <div
              style={{
                flex: 1,
                height: `${cellHeight}px`,
                borderRadius: '2px',
                backgroundColor: bg,
                border: isAddedDelta ? `0.5px solid ${TOKENS.inkPrussian}` : 'none'
              }}
            />
          </React.Fragment>
        );
      })}
    </div>
  );
}

// ============================================================================
// FIX 3 & FIX 7: AudienceSegmentBar routes cleanly to Diff Inspector
// ============================================================================
function AudienceSegmentBar({ mode = 'Lookalike', onInspectDiff, highlighted = false }) {
  const isLookalike = mode === 'Lookalike' || mode === 'Cart Abandoners' || mode === 'Loyalty Tier 1';
  const segments = Array.from({ length: 12 }).map((_, i) => {
    if (isLookalike) {
      if (i < 3) return 'core';
      if (i < 5) return 'lookalike';
      return 'suppressed';
    } else {
      if (i >= 9) return 'waste';
      return 'broad';
    }
  });

  return (
    <div
      onClick={onInspectDiff}
      style={{
        backgroundColor: highlighted ? TOKENS.changedRowTint : TOKENS.bgPlaster,
        border: highlighted ? `1.5px solid ${TOKENS.inkPrussian}` : `1px solid ${TOKENS.hairline}`,
        borderRadius: '12px',
        padding: '12px 14px',
        display: 'flex',
        flexDirection: 'column',
        gap: '8px',
        cursor: onInspectDiff ? 'pointer' : 'default'
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <span style={{ ...TYPE.t3, fontWeight: 600, color: TOKENS.textPrimary }}>
          Audience · {mode}
        </span>
        <span
          style={{
            ...TYPE.t4,
            color: isLookalike ? TOKENS.status.approved.solid : TOKENS.status.changes.solid,
            backgroundColor: isLookalike ? TOKENS.status.approved.chipBg : TOKENS.status.changes.chipBg,
            padding: '2px 8px',
            borderRadius: '999px'
          }}
        >
          {isLookalike ? '5 of 12 segments active' : '12 of 12 broad reach'}
        </span>
      </div>

      <div style={{ display: 'flex', alignItems: 'center', gap: '4px', width: '100%' }}>
        {segments.map((type, idx) => {
          const bg =
            type === 'core'
              ? TOKENS.inkPrussian
              : type === 'lookalike'
                ? TOKENS.cadmiumYellow
                : type === 'waste'
                  ? TOKENS.status.blocked.solid
                  : type === 'broad'
                    ? TOKENS.status.review.solid
                    : TOKENS.surfaceRecessed;
          return (
            <div
              key={idx}
              style={{
                flex: 1,
                height: '8px',
                borderRadius: '2px',
                backgroundColor: bg,
                border: type === 'lookalike' ? `0.5px solid ${TOKENS.inkPrussian}` : 'none'
              }}
            />
          );
        })}
      </div>

      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <span style={{ ...TYPE.t3, color: TOKENS.textSecondary }}>
          {isLookalike ? '7 low-intent segments suppressed' : 'Includes 3 high-CPA waste segments'}
        </span>
        <span style={{ ...TYPE.t4, color: TOKENS.inkPrussian }}>
          Inspect diff →
        </span>
      </div>
    </div>
  );
}

// ============================================================================
// FIX 7: VerticalVersionThread embeds contextual "Compare diff →" CTA
// ============================================================================
function VerticalVersionThread({
  stamps = [],
  selectedStampIdx = 2,
  onSelectStamp,
  activeClauseFilter,
  onHighlightClause,
  onOpenDiff
}) {
  return (
    <div
      style={{
        backgroundColor: TOKENS.surfaceCard,
        border: `1px solid ${TOKENS.hairline}`,
        borderRadius: '16px',
        padding: '14px 16px',
        display: 'flex',
        flexDirection: 'column',
        gap: '12px'
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <span style={{ ...TYPE.t2, color: TOKENS.textPrimary }}>Version thread</span>
        {onOpenDiff && (
          <button
            onClick={onOpenDiff}
            style={{
              padding: '4px 10px',
              borderRadius: '999px',
              backgroundColor: TOKENS.surfaceRecessed,
              border: `1px solid ${TOKENS.hairline}`,
              ...TYPE.t4,
              color: TOKENS.inkPrussian,
              cursor: 'pointer'
            }}
          >
            Compare diff →
          </button>
        )}
      </div>

      <div style={{ display: 'flex', flexDirection: 'column' }}>
        {stamps.map((st, idx) => {
          const isSelected = selectedStampIdx === idx;
          const isLast = idx === stamps.length - 1;
          const cfg = TOKENS.status[st.status] || TOKENS.status.review;

          return (
            <div key={st.version} style={{ display: 'flex', alignItems: 'stretch', gap: '12px' }}>
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', width: '20px', flexShrink: 0 }}>
                <div style={{ paddingTop: '2px' }}>
                  <FacetCell status={st.status} size={isSelected ? 15 : 12} selected={isSelected} />
                </div>
                {!isLast && (
                  <div
                    style={{
                      width: '1.5px',
                      flex: 1,
                      minHeight: '18px',
                      backgroundColor: TOKENS.hairline,
                      margin: '4px 0'
                    }}
                  />
                )}
              </div>

              <div
                onClick={() => onSelectStamp(idx)}
                style={{
                  flex: 1,
                  marginBottom: isLast ? 0 : '10px',
                  padding: isSelected ? '12px' : '6px 10px',
                  borderRadius: '12px',
                  backgroundColor: isSelected ? TOKENS.bgPlaster : 'transparent',
                  border: isSelected ? `1.5px solid ${TOKENS.inkPrussian}` : `1px solid transparent`,
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '8px',
                  cursor: 'pointer'
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '8px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <span style={{ ...TYPE.t2, fontFamily: TOKENS.fontMono, color: TOKENS.textPrimary }}>
                      {st.version}
                    </span>
                    <span style={{ ...TYPE.t3, color: cfg.solid, fontWeight: 600 }}>
                      {st.stampWord}
                    </span>
                  </div>
                  <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>
                    {st.time}
                  </span>
                </div>

                {isSelected && (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                    <span style={{ ...TYPE.t3, color: TOKENS.textSecondary }}>
                      Reviewer: <strong style={{ color: TOKENS.textPrimary }}>{st.actor}</strong>
                    </span>

                    {st.clauses.map((clause, cIdx) => {
                      const isClauseActive = activeClauseFilter === clause.field;
                      const clauseCfg = TOKENS.status[clause.clauseStatus] || TOKENS.status.review;
                      return (
                        <div
                          key={cIdx}
                          onClick={(e) => {
                            e.stopPropagation();
                            onHighlightClause && onHighlightClause(isClauseActive ? null : clause.field);
                          }}
                          style={{
                            padding: '8px 10px',
                            borderRadius: '10px',
                            backgroundColor: isClauseActive ? TOKENS.changedRowTint : TOKENS.surfaceCard,
                            border: isClauseActive ? `1.5px solid ${TOKENS.inkPrussian}` : `1px solid ${TOKENS.hairline}`,
                            display: 'flex',
                            flexDirection: 'column',
                            gap: '3px'
                          }}
                        >
                          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                            <span style={{ ...TYPE.t4, color: TOKENS.textPrimary }}>
                              {clause.field} · {clause.metricDelta}
                            </span>
                            <span style={{ ...TYPE.t4, color: clauseCfg.solid }}>
                              {clause.resolutionTag}
                            </span>
                          </div>
                          <span style={{ ...TYPE.t3, color: TOKENS.textSecondary }}>
                            {clause.note}
                          </span>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function FlightTicketCard({ campaign, leaseSeconds, onSelect }) {
  const formatLease = (secs) => {
    const m = String(Math.floor(secs / 60)).padStart(2, '0');
    const s = String(secs % 60).padStart(2, '0');
    return `${m}:${s}`;
  };

  return (
    <div
      onClick={() => onSelect(campaign)}
      style={{
        backgroundColor: TOKENS.surfaceCard,
        border: `1px solid ${TOKENS.hairline}`,
        borderRadius: '16px',
        position: 'relative',
        cursor: 'pointer',
        overflow: 'hidden',
        width: '100%',
        flexShrink: 0
      }}
    >
      <div style={{ padding: '14px 16px 10px', display: 'flex', flexDirection: 'column', gap: '8px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <span
            style={{
              ...TYPE.t4,
              color: TOKENS.textPrimary,
              backgroundColor: TOKENS.surfaceRecessed,
              padding: '3px 8px',
              borderRadius: '6px',
              border: `0.5px solid ${TOKENS.hairline}`
            }}
          >
            {campaign.version}
          </span>
          <StatusBadge status={campaign.status} />
        </div>

        <div style={{ ...TYPE.t2, color: TOKENS.textPrimary }}>
          {campaign.title}
        </div>

        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '8px' }}>
          <span style={{ ...TYPE.t3, color: TOKENS.textSecondary }}>
            {campaign.owner}
          </span>

          {campaign.hasActiveLease ? (
            <div
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: '5px',
                backgroundColor: TOKENS.surfaceRecessed,
                padding: '3px 8px',
                borderRadius: '999px',
                border: `0.5px solid ${TOKENS.hairline}`
              }}
            >
              <MonoIcons.Lock color={TOKENS.textSecondary} size={11} />
              <span style={{ ...TYPE.t4, color: TOKENS.textPrimary }}>
                Vikram is editing, {formatLease(leaseSeconds)}
              </span>
            </div>
          ) : (
            <span
              style={{
                ...TYPE.t4,
                color: campaign.deltaType === 'changes' ? TOKENS.status.changes.solid : TOKENS.status.approved.solid
              }}
            >
              {campaign.deltaText}
            </span>
          )}
        </div>
      </div>

      <TicketPerforation notchBg={TOKENS.bgPlaster} />

      <div style={{ padding: '8px 16px 14px', display: 'flex', flexDirection: 'column', gap: '8px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <span style={{ ...TYPE.t3, color: TOKENS.textSecondary }}>
            {campaign.channel} · {campaign.dates}
          </span>
          <span style={{ ...TYPE.t2, fontFamily: TOKENS.fontMono, color: TOKENS.textPrimary }}>
            ${campaign.budget.toLocaleString()}
          </span>
        </div>

        <CellMeter
          amount={campaign.budget}
          prevAmount={campaign.prevBudget}
          maxAmount={40000}
          ceilingRatio={0.75}
          totalCells={24}
          cellHeight={8}
        />
      </div>
    </div>
  );
}

function SolidBottomBar({ activeTab = 'pipeline', onSelectTab }) {
  const tabs = [
    { id: 'pipeline', label: 'Pipeline', Icon: MonoIcons.PipelineTab },
    { id: 'calendar', label: 'Calendar', Icon: MonoIcons.CalendarTab },
    { id: 'insights', label: 'Insights', Icon: MonoIcons.InsightsTab },
    { id: 'activity', label: 'Activity', Icon: MonoIcons.ActivityTab }
  ];

  return (
    <div
      style={{
        marginTop: 'auto',
        width: '100%',
        backgroundColor: TOKENS.surfaceCard,
        borderTop: `1px solid ${TOKENS.hairline}`,
        padding: '8px 16px 12px',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        gap: '6px',
        boxSizing: 'border-box',
        flexShrink: 0
      }}
    >
      {tabs.map((tab) => {
        const isActive = activeTab === tab.id;
        return (
          <button
            key={tab.id}
            onClick={() => onSelectTab && onSelectTab(tab.id)}
            style={{
              minHeight: '44px',
              padding: isActive ? '0 16px' : '0 12px',
              borderRadius: '999px',
              backgroundColor: isActive ? TOKENS.inkPrussian : 'transparent',
              border: 'none',
              display: 'inline-flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '6px',
              cursor: 'pointer'
            }}
          >
            <tab.Icon color={isActive ? TOKENS.labelOnInk : TOKENS.textSecondary} size={15} />
            {isActive && (
              <span style={{ ...TYPE.t3, fontWeight: 600, color: TOKENS.labelOnInk }}>
                {tab.label}
              </span>
            )}
          </button>
        );
      })}
    </div>
  );
}

// ============================================================================
// FIX 7: Authentic iOS Bottom-Sheet Container over Dimmed Parent Context
// ============================================================================
function BottomSheetScaffold({
  parentTitle = 'Diwali Festive Sale',
  parentSub = 'Owner: Riya Sen · V3.0',
  parentStatus = 'review',
  onClose,
  rightAction,
  children
}) {
  return (
    <div style={{ ...phoneFrameStyle, backgroundColor: '#122230' }}>
      <div style={{ ...iosStatusBarStyle, color: 'rgba(255,255,255,0.85)' }}>
        <span style={TYPE.t4}>09:41</span>
        <span style={{ ...TYPE.t4, color: 'rgba(255,255,255,0.65)' }}>5G · 100%</span>
      </div>

      {/* Dimmed Parent Context Peek (Top 14% of Viewport) */}
      <div
        onClick={onClose}
        style={{
          margin: '2px 12px 0',
          padding: '10px 14px 18px',
          borderRadius: '18px 18px 0 0',
          backgroundColor: TOKENS.bgPlaster,
          opacity: 0.42,
          transform: 'scale(0.96)',
          transformOrigin: 'top center',
          cursor: 'pointer',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          userSelect: 'none'
        }}
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
          <span style={{ ...TYPE.t2, color: TOKENS.textPrimary }}>{parentTitle}</span>
          <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>{parentSub}</span>
        </div>
        <StatusBadge status={parentStatus} />
      </div>

      {/* Active Sheet Container with 20px Top Radius & Centered 36×4pt Grabber */}
      <div
        style={{
          marginTop: '-8px',
          flex: 1,
          backgroundColor: TOKENS.bgPlaster,
          borderRadius: '20px 20px 0 0',
          borderTop: `1px solid ${TOKENS.hairline}`,
          display: 'flex',
          flexDirection: 'column',
          overflow: 'hidden',
          zIndex: 2
        }}
      >
        <div
          style={{
            padding: '10px 16px 8px',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            gap: '8px',
            borderBottom: `1px solid ${TOKENS.hairline}`,
            backgroundColor: TOKENS.surfaceCard
          }}
        >
          <div
            onClick={onClose}
            style={{
              width: '36px',
              height: '4px',
              borderRadius: '999px',
              backgroundColor: TOKENS.hairline,
              cursor: 'pointer'
            }}
          />
          <div
            style={{
              width: '100%',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between'
            }}
          >
            <button
              onClick={onClose}
              style={{
                minHeight: '32px',
                padding: '0 8px 0 0',
                backgroundColor: 'transparent',
                border: 'none',
                display: 'inline-flex',
                alignItems: 'center',
                gap: '4px',
                ...TYPE.t3,
                fontWeight: 600,
                color: TOKENS.textPrimary,
                cursor: 'pointer'
              }}
            >
              <MonoIcons.ChevronLeft color={TOKENS.textPrimary} size={15} />
              <span>Dismiss sheet</span>
            </button>
            {rightAction}
          </div>
        </div>

        {children}
      </div>
    </div>
  );
}

const INITIAL_CAMPAIGNS = [
  {
    id: 'camp-diwali',
    title: 'Diwali Festive Sale',
    version: 'V3.0',
    status: 'review',
    owner: 'Riya Sen',
    deltaText: 'Budget +25% vs V2.0',
    deltaType: 'changes',
    hasActiveLease: false,
    channel: 'Social',
    dates: 'Nov 01–14',
    budget: 25000,
    prevBudget: 20000,
    audience: 'Lookalike',
    targetCpa: '$15.00',
    dna: ['changes', 'changes', 'approved', 'approved'],
    versions: {
      'V1.0': {
        tag: 'V1.0',
        status: 'approved',
        statusText: 'Approved',
        budget: 20000,
        prevBudget: 20000,
        audience: 'Broad',
        prevAudience: 'Broad',
        channel: 'Social',
        schedule: 'Nov 01 to Nov 14',
        targetCpa: '$15.00',
        dna: ['approved', 'approved', 'approved', 'approved']
      },
      'V2.0': {
        tag: 'V2.0',
        status: 'changes',
        statusText: 'Changes',
        budget: 20000,
        prevBudget: 20000,
        audience: 'Broad',
        prevAudience: 'Broad',
        channel: 'Social',
        schedule: 'Nov 01 to Nov 14',
        targetCpa: '$15.00',
        dna: ['approved', 'blocked', 'approved', 'changes']
      },
      'V3.0': {
        tag: 'V3.0',
        status: 'review',
        statusText: 'In review',
        budget: 25000,
        prevBudget: 20000,
        audience: 'Lookalike',
        prevAudience: 'Broad',
        channel: 'Social',
        schedule: 'Nov 01 to Nov 14',
        targetCpa: '$15.00',
        dna: ['changes', 'changes', 'approved', 'approved']
      }
    },
    stampLedger: [
      {
        version: 'V1.0',
        status: 'approved',
        stampWord: 'Approved',
        actor: 'Arjun Mehta',
        time: 'Oct 28 · 10:15',
        clauses: [
          {
            field: 'Budget',
            metricDelta: '$20,000 baseline',
            note: 'Initial pilot cap within Q4 threshold',
            clauseStatus: 'approved',
            resolutionTag: 'Locked V1.0'
          },
          {
            field: 'Channel',
            metricDelta: 'Social · Nov 01–14',
            note: '14-day festive slot verified free',
            clauseStatus: 'approved',
            resolutionTag: 'Slot Verified'
          }
        ]
      },
      {
        version: 'V2.0',
        status: 'changes',
        stampWord: 'Changes',
        actor: 'Arjun Mehta',
        time: 'Oct 30 · 14:20',
        clauses: [
          {
            field: 'Audience',
            metricDelta: 'Broad (12/12 cells)',
            note: 'Broad reach causes 3 high-CPA waste segments',
            clauseStatus: 'changes',
            resolutionTag: 'Fixed in V3.0 →'
          },
          {
            field: 'Budget',
            metricDelta: 'Hold at $20,000',
            note: 'Do not scale budget until audience is narrowed',
            clauseStatus: 'changes',
            resolutionTag: 'Unlocked V3.0 →'
          }
        ]
      },
      {
        version: 'V3.0',
        status: 'review',
        stampWord: 'In review',
        actor: 'Riya Sen → Arjun',
        time: 'Today · 09:12',
        clauses: [
          {
            field: 'Audience',
            metricDelta: 'Broad → Lookalike',
            note: 'Suppressed 7 waste cells; isolated top 5 cells',
            clauseStatus: 'approved',
            resolutionTag: 'V2 Clause Met'
          },
          {
            field: 'Budget',
            metricDelta: '$20,000 → $25,000',
            note: '+3 cells added safely below $30k ceiling tick',
            clauseStatus: 'changes',
            resolutionTag: 'Needs Stamp'
          }
        ]
      }
    ]
  },
  {
    id: 'camp-brand',
    title: 'Brand Refresh',
    version: 'V2.0',
    status: 'review',
    owner: 'Riya Sen',
    deltaText: 'Vikram is editing',
    deltaType: 'changes',
    hasActiveLease: true,
    channel: 'Display',
    dates: 'Nov 05–18',
    budget: 18000,
    prevBudget: 15000,
    audience: 'Lookalike',
    targetCpa: '$14.20',
    dna: ['changes', 'approved', 'approved', 'approved'],
    versions: {
      'V1.0': {
        tag: 'V1.0',
        status: 'approved',
        statusText: 'Approved',
        budget: 15000,
        prevBudget: 15000,
        audience: 'Broad',
        prevAudience: 'Broad',
        channel: 'Display',
        schedule: 'Nov 05 to Nov 18',
        targetCpa: '$14.20',
        dna: ['approved', 'approved', 'approved', 'approved']
      },
      'V2.0': {
        tag: 'V2.0',
        status: 'review',
        statusText: 'In review',
        budget: 18000,
        prevBudget: 15000,
        audience: 'Lookalike',
        prevAudience: 'Broad',
        channel: 'Display',
        schedule: 'Nov 05 to Nov 18',
        targetCpa: '$14.20',
        dna: ['changes', 'approved', 'approved', 'approved']
      }
    },
    stampLedger: [
      {
        version: 'V1.0',
        status: 'approved',
        stampWord: 'Approved',
        actor: 'Arjun Mehta',
        time: 'Oct 26 · 11:10',
        clauses: [
          {
            field: 'Budget',
            metricDelta: '$15,000 cap',
            note: 'Display frequency cap verified',
            clauseStatus: 'approved',
            resolutionTag: 'Locked V1.0'
          }
        ]
      },
      {
        version: 'V2.0',
        status: 'review',
        stampWord: 'In review',
        actor: 'Vikram Sharma',
        time: 'Active lease',
        clauses: [
          {
            field: 'Budget',
            metricDelta: '$15,000 → $18,000',
            note: 'Adding +3 cells for Display retargeting',
            clauseStatus: 'review',
            resolutionTag: 'Editing Now'
          }
        ]
      }
    ]
  },
  {
    id: 'camp-retarget',
    title: 'Q4 Retargeting',
    version: 'V3.0',
    status: 'review',
    owner: 'Vikram Sharma',
    deltaText: 'Budget +20% vs V2.0',
    deltaType: 'changes',
    hasActiveLease: false,
    channel: 'Search',
    dates: 'Nov 10–24',
    budget: 30000,
    prevBudget: 25000,
    audience: 'Cart Abandoners',
    targetCpa: '$12.50',
    dna: ['changes', 'changes', 'approved', 'approved'],
    versions: {
      'V3.0': {
        tag: 'V3.0',
        status: 'review',
        statusText: 'In review',
        budget: 30000,
        prevBudget: 25000,
        audience: 'Lookalike',
        prevAudience: 'Broad',
        channel: 'Search',
        schedule: 'Nov 10 to Nov 24',
        targetCpa: '$12.50',
        dna: ['changes', 'changes', 'approved', 'approved']
      }
    },
    stampLedger: []
  }
];

const INITIAL_AUDIT_EVENTS = [
  {
    id: 'ev-1',
    time: '09:48',
    actor: 'Arjun Mehta',
    fromState: 'review',
    toState: 'approved',
    transition: 'Submitted → Approved',
    status: 'approved',
    category: 'Decisions',
    campaign: 'Diwali Festive Sale · V1.0',
    dna: ['approved', 'approved', 'approved', 'approved']
  },
  {
    id: 'ev-2',
    time: '09:12',
    actor: 'Riya Sen',
    fromState: 'changes',
    toState: 'review',
    transition: 'Submitted V3.0',
    status: 'review',
    category: 'Decisions',
    campaign: 'Diwali Festive Sale · $25,000, Lookalike',
    dna: ['changes', 'changes', 'approved', 'approved']
  }
];

const OUTBOX_RELAYS = [
  {
    id: 'out-1',
    label: 'Approval email · Riya Sen',
    sub: 'Committed in DB · Dispatched',
    chipText: 'Processed',
    status: 'approved',
    attemptCells: ['approved', 'empty', 'empty', 'empty', 'empty']
  },
  {
    id: 'out-2',
    label: 'Review digest · Vikram Sharma',
    sub: 'Decision safe · SMTP backoff 4s',
    chipText: 'Retrying 2 of 5',
    status: 'changes',
    attemptCells: ['blocked', 'changes', 'empty', 'empty', 'empty']
  }
];

export default function App() {
  const [viewMode, setViewMode] = useState('interactive');
  const [activeScreen, setActiveScreen] = useState('pipeline');
  const [viewer, setViewer] = useState('Arjun Mehta');

  const [campaigns, setCampaigns] = useState(INITIAL_CAMPAIGNS);
  const [auditEvents, setAuditEvents] = useState(INITIAL_AUDIT_EVENTS);

  const [pipelineFilter, setPipelineFilter] = useState('review');
  const [selectedCampaignId, setSelectedCampaignId] = useState('camp-diwali');
  const [selectedVersionTag, setSelectedVersionTag] = useState('V3.0');
  const [selectedStampIdx, setSelectedStampIdx] = useState(2);
  const [activeClauseFilter, setActiveClauseFilter] = useState(null);

  const [diffTab, setDiffTab] = useState('V3.0');

  const [decisionOutcome, setDecisionOutcome] = useState('Approve');
  const [decisionReason, setDecisionReason] = useState(
    'Lookalike aperture eliminates broad waste and $25,000 cap sits below ceiling.'
  );
  const [pinnedClauses, setPinnedClauses] = useState(['Budget $25,000', 'Audience Lookalike']);
  const [reasonError, setReasonError] = useState('');
  const [shakeTrigger, setShakeTrigger] = useState(false);

  const [holdProgress, setHoldProgress] = useState(28);
  const [isHolding, setIsHolding] = useState(false);
  const holdTimerRef = useRef(null);

  const [activityFilter, setActivityFilter] = useState('All');
  const [leaseSeconds, setLeaseSeconds] = useState(202);
  const [commitBanner, setCommitBanner] = useState(null);

  // Milestone 3: Authoring & Concurrency States (P0 Fix 1)
  const [studioBudget, setStudioBudget] = useState(25000);
  const [studioAudience, setStudioAudience] = useState('Lookalike');
  const [studioChannel, setStudioChannel] = useState('Social');
  const [studioObjective, setStudioObjective] = useState('Festive Conversion');
  const [conflictChoices, setConflictChoices] = useState({
    budget: 'mine',
    audience: 'theirs',
    channel: 'mine'
  });

  // Milestone 4: Calendar & Pre-Flight States (P0 Fix 2 & P2 Fix 6)
  const [selectedDay, setSelectedDay] = useState('10');
  const [calendarWindowStart, setCalendarWindowStart] = useState(0); // 5-day rolling window (0..2)
  const [selectedFlightChannel, setSelectedFlightChannel] = useState('Social');
  const [calendarFlights, setCalendarFlights] = useState([
    {
      id: 'fl-search',
      campaignId: 'camp-retarget',
      channel: 'Search',
      title: 'Diwali Launch',
      version: 'V1.0',
      owner: 'Riya Sen',
      status: 'scheduled',
      word: 'Scheduled',
      startIdx: 0,
      endIdx: 5,
      budget: 20000,
      dailyBurn: 3300
    },
    {
      id: 'fl-social',
      campaignId: 'camp-diwali',
      channel: 'Social',
      title: 'Diwali Festive Sale',
      version: 'V3.0',
      owner: 'Riya Sen',
      status: 'review',
      word: 'In review',
      startIdx: 1,
      endIdx: 5,
      budget: 25000,
      dailyBurn: 5000
    },
    {
      id: 'fl-display',
      campaignId: 'camp-brand',
      channel: 'Display',
      title: 'Q4 Retargeting',
      version: 'V2.0',
      owner: 'Vikram Sharma',
      status: 'blocked',
      word: 'Conflict',
      startIdx: 2,
      endIdx: 6,
      budget: 30000,
      dailyBurn: 6000,
      conflictHolder: 'Winter Promo V1.0',
      conflictStartIdx: 1,
      conflictEndIdx: 3
    },
    {
      id: 'fl-email',
      campaignId: null,
      channel: 'Email',
      title: 'VIP Access',
      version: 'V1.0',
      owner: 'Arjun Mehta',
      status: 'scheduled',
      word: 'Scheduled',
      startIdx: 1,
      endIdx: 3,
      budget: 8000,
      dailyBurn: 2600
    },
    {
      id: 'fl-video',
      campaignId: null,
      channel: 'Video',
      title: 'Festive Reels',
      version: 'V2.0',
      owner: 'Riya Sen',
      status: 'review',
      word: 'In review',
      startIdx: 3,
      endIdx: 6,
      budget: 18000,
      dailyBurn: 4500
    }
  ]);

  // Milestone 5: Spend Override Governance State (P1 Fix 5)
  const [spendAmount] = useState(28500);
  const [isResumeReasonOpen, setIsResumeReasonOpen] = useState(false);
  const [resumeReason, setResumeReason] = useState(
    'Paused retargeting ad set ($38.50 CPA); reallocated cap to Lookalike ($10.80 CPA).'
  );
  const [resumeError, setResumeError] = useState('');
  const [insightsRange, setInsightsRange] = useState('30 days');
  const [scrubIndex, setScrubIndex] = useState(4);

  useEffect(() => {
    const timer = setInterval(() => {
      setLeaseSeconds((prev) => (prev > 1 ? prev - 1 : 202));
    }, 1000);
    return () => clearInterval(timer);
  }, []);

  const activeCampaign = campaigns.find((c) => c.id === selectedCampaignId) || campaigns[0];
  const activeVersion =
    activeCampaign.versions[selectedVersionTag] ||
    activeCampaign.versions[activeCampaign.version] ||
    Object.values(activeCampaign.versions)[0];

  // ==========================================================================
  // FIX 3: Synchronized Version & Stamp Selection Handler (Zero Split-Brain)
  // ==========================================================================
  const selectCampaignVersion = (verTag, explicitStampIdx = null) => {
    setSelectedVersionTag(verTag);
    const stamps = activeCampaign.stampLedger || [];
    if (explicitStampIdx !== null) {
      setSelectedStampIdx(explicitStampIdx);
    } else {
      const foundIdx = stamps.findIndex((s) => s.version === verTag);
      if (foundIdx !== -1) setSelectedStampIdx(foundIdx);
    }
  };

  const counts = {
    all: campaigns.length,
    review: campaigns.filter((c) => c.status === 'review').length,
    changes: campaigns.filter((c) => c.status === 'changes').length,
    approved: campaigns.filter((c) => c.status === 'approved').length,
    scheduled: campaigns.filter((c) => c.status === 'scheduled').length
  };

  const triggerErrorShake = (msg) => {
    setReasonError(msg);
    setShakeTrigger(true);
    setTimeout(() => setShakeTrigger(false), 380);
  };

  const togglePinnedClause = (clauseName) => {
    setPinnedClauses((prev) =>
      prev.includes(clauseName) ? prev.filter((c) => c !== clauseName) : [...prev, clauseName]
    );
  };

  // ==========================================================================
  // FIX 2: Unified State Sync Across Campaigns, Calendar & Pre-Flight
  // ==========================================================================
  const commitDecisionNow = (outcomeType) => {
    const trimmed = decisionReason.trim();
    if (!trimmed) {
      triggerErrorShake('Reason is required before recording a decision.');
      return;
    }

    const mappedStatus =
      outcomeType === 'Approve'
        ? 'approved'
        : outcomeType === 'Request changes'
          ? 'changes'
          : 'blocked';

    const mappedWord =
      outcomeType === 'Approve'
        ? 'Approved'
        : outcomeType === 'Request changes'
          ? 'Changes'
          : 'Blocked';

    setCampaigns((prev) =>
      prev.map((c) => {
        if (c.id !== activeCampaign.id) return c;
        const targetVer = selectedVersionTag || c.version;
        const updatedVersions = {
          ...c.versions,
          [targetVer]: {
            ...c.versions[targetVer],
            status: mappedStatus,
            statusText: mappedWord,
            dna: mappedStatus === 'approved' ? ['approved', 'approved', 'approved', 'approved'] : ['changes', 'changes', 'approved', 'approved']
          }
        };
        const updatedStamps = c.stampLedger.map((st) =>
          st.version === targetVer
            ? {
                ...st,
                status: mappedStatus,
                stampWord: mappedWord,
                actor: 'Arjun Mehta',
                time: '09:49',
                clauses: [
                  {
                    field: 'Budget',
                    metricDelta: `$${c.budget.toLocaleString()} verified`,
                    note: trimmed,
                    clauseStatus: mappedStatus,
                    resolutionTag: `${mappedWord} ${targetVer}`
                  },
                  {
                    field: 'Audience',
                    metricDelta: 'Lookalike (5/12 cells)',
                    note: 'Waste segments suppressed',
                    clauseStatus: mappedStatus,
                    resolutionTag: 'Locked'
                  }
                ]
              }
            : st
        );
        return {
          ...c,
          status: mappedStatus,
          deltaText: `${mappedWord} by Arjun`,
          deltaType: mappedStatus === 'approved' ? 'approved' : 'changes',
          dna: mappedStatus === 'approved' ? ['approved', 'approved', 'approved', 'approved'] : c.dna,
          versions: updatedVersions,
          stampLedger: updatedStamps
        };
      })
    );

    // Sync decision status into Calendar swimlanes
    setCalendarFlights((prev) =>
      prev.map((fl) =>
        fl.campaignId === activeCampaign.id
          ? {
              ...fl,
              status: mappedStatus === 'approved' ? 'approved' : mappedStatus,
              word: mappedWord
            }
          : fl
      )
    );

    setAuditEvents((prev) => [
      {
        id: `ev-${Date.now()}`,
        time: '09:49',
        actor: 'Arjun Mehta',
        fromState: 'review',
        toState: mappedStatus,
        transition: `Submitted → ${mappedWord}`,
        status: mappedStatus,
        category: 'Decisions',
        campaign: `${activeCampaign.title} · ${selectedVersionTag}`,
        dna: ['approved', 'approved', 'approved', 'approved']
      },
      ...prev
    ]);

    setHoldProgress(28);
    setIsHolding(false);
    setCommitBanner(`${mappedWord} stamp locked on ${selectedVersionTag}. Ready to schedule.`);
    setActiveScreen('detail');
    setTimeout(() => setCommitBanner(null), 4000);
  };

  // Schedule Commit Sync (Updates both Campaign and Calendar flight to Scheduled)
  const commitScheduleNow = (verTag) => {
    setCampaigns((prev) =>
      prev.map((c) => {
        if (c.id !== activeCampaign.id) return c;
        return {
          ...c,
          status: 'scheduled',
          deltaText: `Scheduled (${verTag})`,
          deltaType: 'approved',
          versions: {
            ...c.versions,
            [verTag]: {
              ...c.versions[verTag],
              status: 'scheduled',
              statusText: 'Scheduled'
            }
          }
        };
      })
    );

    setCalendarFlights((prev) =>
      prev.map((fl) =>
        fl.campaignId === activeCampaign.id || fl.channel === activeCampaign.channel
          ? {
              ...fl,
              title: activeCampaign.title,
              version: verTag,
              status: 'scheduled',
              word: 'Scheduled'
            }
          : fl
      )
    );

    setAuditEvents((prev) => [
      {
        id: `ev-sched-${Date.now()}`,
        time: '09:51',
        actor: viewer,
        fromState: 'approved',
        toState: 'scheduled',
        transition: `Approved → Scheduled ${verTag}`,
        status: 'scheduled',
        category: 'Schedule',
        campaign: `${activeCampaign.title} · ${activeCampaign.channel} (${activeCampaign.dates})`,
        dna: ['approved', 'approved', 'approved', 'approved']
      },
      ...prev
    ]);

    setSelectedFlightChannel(activeCampaign.channel);
    setCommitBanner(`Scheduled ${verTag} on ${activeCampaign.channel} (${activeCampaign.dates}).`);
    setActiveScreen('calendar');
    setTimeout(() => setCommitBanner(null), 4000);
  };

  const startHold = () => {
    if (decisionOutcome !== 'Approve') {
      commitDecisionNow(decisionOutcome);
      return;
    }
    if (!decisionReason.trim()) {
      triggerErrorShake('Reason is required before recording a decision.');
      return;
    }
    setReasonError('');
    setIsHolding(true);
    let current = 28;
    clearInterval(holdTimerRef.current);
    holdTimerRef.current = setInterval(() => {
      current += 6;
      if (current >= 100) {
        clearInterval(holdTimerRef.current);
        setHoldProgress(100);
        commitDecisionNow('Approve');
      } else {
        setHoldProgress(current);
      }
    }, 30);
  };

  const cancelHold = () => {
    clearInterval(holdTimerRef.current);
    setIsHolding(false);
    setHoldProgress(28);
  };

  // ==========================================================================
  // SCREEN 01: PIPELINE
  // ==========================================================================
  const renderPipelineScreen = () => {
    const filteredList =
      pipelineFilter === 'all'
        ? campaigns
        : campaigns.filter((c) => c.status === pipelineFilter);

    const filterChips = [
      { id: 'all', label: `All ${counts.all}` },
      { id: 'review', label: `In review ${counts.review}` },
      { id: 'changes', label: `Changes ${counts.changes}` },
      { id: 'approved', label: `Approved ${counts.approved}` },
      { id: 'scheduled', label: `Scheduled ${counts.scheduled}` }
    ];

    return (
      <div style={phoneFrameStyle}>
        <div style={iosStatusBarStyle}>
          <span style={TYPE.t4}>09:41</span>
          <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>5G · 100%</span>
        </div>

        <div style={{ padding: '6px 16px 4px', display: 'flex', flexDirection: 'column', gap: '4px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <FacetCell status="brand" size={13} />
            <span style={{ ...TYPE.t3, color: TOKENS.textSecondary }}>
              Campaign Grid · {viewer}
            </span>
          </div>
          <h1 style={{ ...TYPE.t1, color: TOKENS.textPrimary, margin: 0 }}>Pipeline</h1>
        </div>

        <div
          style={{
            margin: '8px 16px 4px',
            backgroundColor: TOKENS.surfaceCard,
            border: `1px solid ${TOKENS.hairline}`,
            borderRadius: '16px',
            padding: '16px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: '12px'
          }}
        >
          <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
            <span style={{ ...TYPE.t1, fontFamily: TOKENS.fontMono, color: TOKENS.textPrimary }}>
              {counts.review}
            </span>
            <span style={{ ...TYPE.t3, color: TOKENS.textSecondary }}>
              waiting for your review
            </span>
          </div>

          <button
            onClick={() => {
              setSelectedCampaignId('camp-diwali');
              selectCampaignVersion('V3.0', 2);
              setActiveScreen('detail');
            }}
            style={{
              minHeight: '44px',
              padding: '0 18px',
              borderRadius: '999px',
              backgroundColor: TOKENS.inkPrussian,
              color: TOKENS.labelOnInk,
              border: 'none',
              ...TYPE.t2,
              cursor: 'pointer',
              display: 'inline-flex',
              alignItems: 'center',
              gap: '6px',
              flexShrink: 0
            }}
          >
            <span>Review now</span>
          </button>
        </div>

        <div
          style={{
            padding: '10px 16px 8px',
            display: 'flex',
            alignItems: 'center',
            gap: '6px',
            overflowX: 'auto',
            width: '100%',
            boxSizing: 'border-box',
            flexShrink: 0
          }}
        >
          {filterChips.map((chip) => {
            const isSelected = pipelineFilter === chip.id;
            return (
              <button
                key={chip.id}
                onClick={() => setPipelineFilter(chip.id)}
                style={{
                  position: 'relative',
                  padding: '7px 12px 9px',
                  borderRadius: '999px',
                  backgroundColor: isSelected ? TOKENS.surfaceCard : TOKENS.surfaceRecessed,
                  border: isSelected ? `1.5px solid ${TOKENS.inkPrussian}` : `1px solid ${TOKENS.hairline}`,
                  ...TYPE.t4,
                  color: isSelected ? TOKENS.textPrimary : TOKENS.textSecondary,
                  cursor: 'pointer',
                  whiteSpace: 'nowrap',
                  flexShrink: 0,
                  overflow: 'hidden'
                }}
              >
                <span>{chip.label}</span>
                {isSelected && (
                  <span
                    style={{
                      position: 'absolute',
                      bottom: 0,
                      left: '10px',
                      right: '10px',
                      height: '2.5px',
                      backgroundColor: TOKENS.cadmiumYellow
                    }}
                  />
                )}
              </button>
            );
          })}
        </div>

        <div
          style={{
            padding: '4px 16px 16px',
            display: 'flex',
            flexDirection: 'column',
            gap: '12px',
            overflowY: 'auto',
            flex: 1,
            width: '100%',
            boxSizing: 'border-box'
          }}
        >
          {filteredList.map((camp) => (
            <FlightTicketCard
              key={camp.id}
              campaign={camp}
              leaseSeconds={leaseSeconds}
              onSelect={(c) => {
                setSelectedCampaignId(c.id);
                selectCampaignVersion(c.version, Math.max(0, (c.stampLedger?.length || 1) - 1));
                setActiveScreen('detail');
              }}
            />
          ))}
        </div>

        <SolidBottomBar
          activeTab="pipeline"
          onSelectTab={(tabId) => {
            if (tabId === 'activity') setActiveScreen('activity');
            else if (tabId === 'calendar') setActiveScreen('calendar');
            else if (tabId === 'insights') setActiveScreen('insights');
            else setActiveScreen('pipeline');
          }}
        />
      </div>
    );
  };

  // ==========================================================================
  // SCREEN 02: CAMPAIGN DETAIL (Fixes 3, 4, and 7 applied)
  // ==========================================================================
  const renderCampaignDetailScreen = () => {
    const stamps =
      activeCampaign.stampLedger && activeCampaign.stampLedger.length > 0
        ? activeCampaign.stampLedger
        : INITIAL_CAMPAIGNS[0].stampLedger;

    const isVersionApproved = activeVersion.status === 'approved';
    const isVersionScheduled = activeVersion.status === 'scheduled' || activeCampaign.status === 'scheduled';
    const isCurrentHead = selectedVersionTag === activeCampaign.version;
    const isOwner = viewer === 'Riya Sen';

    return (
      <div style={phoneFrameStyle}>
        <div style={iosStatusBarStyle}>
          <span style={TYPE.t4}>09:41</span>
          <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>5G · 100%</span>
        </div>

        {/* FIX 7: Clean Top Navigation Chrome (Single contextual Edit trigger) */}
        <div
          style={{
            padding: '6px 16px 10px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            borderBottom: `1px solid ${TOKENS.hairline}`
          }}
        >
          <button
            onClick={() => setActiveScreen('pipeline')}
            style={{
              minHeight: '36px',
              padding: '0 8px 0 0',
              backgroundColor: 'transparent',
              border: 'none',
              display: 'inline-flex',
              alignItems: 'center',
              gap: '4px',
              ...TYPE.t3,
              fontWeight: 600,
              color: TOKENS.textPrimary,
              cursor: 'pointer'
            }}
          >
            <MonoIcons.ChevronLeft color={TOKENS.textPrimary} size={15} />
            <span>Pipeline</span>
          </button>

          <button
            onClick={() => {
              setStudioBudget(activeVersion.budget);
              setStudioAudience(activeVersion.audience);
              setStudioChannel(activeVersion.channel);
              setActiveScreen('studio');
            }}
            style={{
              minHeight: '34px',
              padding: '0 12px',
              borderRadius: '999px',
              backgroundColor: TOKENS.surfaceCard,
              border: `1px solid ${TOKENS.hairline}`,
              display: 'inline-flex',
              alignItems: 'center',
              gap: '6px',
              ...TYPE.t4,
              color: TOKENS.textPrimary,
              cursor: 'pointer'
            }}
          >
            <MonoIcons.Edit color={TOKENS.textPrimary} size={12} />
            <span>Edit {activeCampaign.version}</span>
          </button>
        </div>

        <div
          style={{
            padding: '14px 16px 18px',
            display: 'flex',
            flexDirection: 'column',
            gap: '14px',
            overflowY: 'auto',
            flex: 1,
            width: '100%',
            boxSizing: 'border-box'
          }}
        >
          {commitBanner && (
            <div
              style={{
                padding: '10px 12px',
                borderRadius: '12px',
                backgroundColor: TOKENS.status.approved.chipBg,
                border: `1px solid ${TOKENS.hairline}`,
                display: 'flex',
                alignItems: 'center',
                gap: '8px'
              }}
            >
              <FacetCell status="approved" size={12} />
              <span style={{ ...TYPE.t3, fontWeight: 600, color: TOKENS.status.approved.solid }}>
                {commitBanner}
              </span>
            </div>
          )}

          <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: '8px' }}>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
              <h1 style={{ ...TYPE.t1, color: TOKENS.textPrimary, margin: 0 }}>
                {activeCampaign.title}
              </h1>
              <span style={{ ...TYPE.t3, color: TOKENS.textSecondary }}>
                Owner: {activeCampaign.owner} · Reviewing {selectedVersionTag}
              </span>
            </div>
            <StatusBadge status={activeVersion.status} />
          </div>

          {/* FIX 3 & FIX 7: Synchronized Version Thread with embedded Compare Diff CTA */}
          <VerticalVersionThread
            stamps={stamps}
            selectedStampIdx={selectedStampIdx}
            onSelectStamp={(idx) => {
              const ver = stamps[idx]?.version;
              if (ver && activeCampaign.versions[ver]) {
                selectCampaignVersion(ver, idx);
              } else {
                setSelectedStampIdx(idx);
              }
            }}
            activeClauseFilter={activeClauseFilter}
            onHighlightClause={(field) => setActiveClauseFilter(field)}
            onOpenDiff={() => {
              setDiffTab(selectedVersionTag);
              setActiveScreen('diff');
            }}
          />

          <div
            style={{
              backgroundColor: TOKENS.surfaceCard,
              border: `1px solid ${TOKENS.hairline}`,
              borderRadius: '16px',
              overflow: 'hidden',
              display: 'flex',
              flexDirection: 'column'
            }}
          >
            {/* FIX 7: Budget Card with contextual "Live spend meter →" link */}
            <div
              style={{
                padding: '14px 16px 10px',
                backgroundColor: activeClauseFilter === 'Budget' ? TOKENS.changedRowTint : 'transparent',
                display: 'flex',
                flexDirection: 'column',
                gap: '8px'
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <span style={{ ...TYPE.t3, color: TOKENS.textSecondary }}>
                  Budget ({selectedVersionTag})
                </span>
                <span style={{ ...TYPE.t2, fontFamily: TOKENS.fontMono, color: TOKENS.textPrimary }}>
                  ${activeVersion.budget.toLocaleString()}
                </span>
              </div>

              <CellMeter
                amount={activeVersion.budget}
                prevAmount={activeVersion.prevBudget}
                maxAmount={40000}
                ceilingRatio={0.75}
                totalCells={24}
                cellHeight={9}
              />

              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', paddingTop: '2px' }}>
                <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>
                  Ceiling tick: $30,000
                </span>
                <button
                  onClick={() => setActiveScreen('spend_live')}
                  style={{
                    background: 'none',
                    border: 'none',
                    padding: 0,
                    ...TYPE.t4,
                    color: TOKENS.inkPrussian,
                    cursor: 'pointer'
                  }}
                >
                  Live spend meter →
                </button>
              </div>
            </div>

            <TicketPerforation notchBg={TOKENS.bgPlaster} />

            <div style={{ padding: '10px 16px 14px', display: 'flex', flexDirection: 'column', gap: '10px' }}>
              <AudienceSegmentBar
                mode={activeVersion.audience}
                highlighted={activeClauseFilter === 'Audience'}
                onInspectDiff={() => {
                  setDiffTab(selectedVersionTag);
                  setActiveScreen('diff');
                }}
              />

              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  paddingTop: '4px',
                  borderTop: `1px solid ${TOKENS.hairline}`
                }}
              >
                <span style={{ ...TYPE.t3, color: TOKENS.textSecondary }}>Channel</span>
                <span style={{ ...TYPE.t4, color: TOKENS.textPrimary }}>{activeVersion.channel}</span>
              </div>

              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  paddingTop: '6px',
                  borderTop: `1px solid ${TOKENS.hairline}`
                }}
              >
                <span style={{ ...TYPE.t3, color: TOKENS.textSecondary }}>Target CPA</span>
                <span style={{ ...TYPE.t4, color: TOKENS.textPrimary }}>{activeVersion.targetCpa}</span>
              </div>
            </div>
          </div>

          <p style={{ ...TYPE.t3, color: TOKENS.textSecondary, margin: '0 2px', maxWidth: '44ch', textAlign: 'left' }}>
            {!isCurrentHead
              ? `Historical snapshot (${selectedVersionTag}). Prior approvals never authorize ${activeCampaign.version}.`
              : 'Only the approved, current version can be scheduled.'}
          </p>
        </div>

        {/* ====================================================================
            FIX 4: Role- & Status-Gated Sticky Bottom Bar (One Primary Action)
           ==================================================================== */}
        <div
          style={{
            padding: '10px 16px 14px',
            backgroundColor: TOKENS.surfaceCard,
            borderTop: `1px solid ${TOKENS.hairline}`,
            width: '100%',
            boxSizing: 'border-box',
            display: 'flex',
            gap: '8px'
          }}
        >
          {isVersionScheduled ? (
            <button
              onClick={() => setActiveScreen('calendar')}
              style={{
                flex: 1,
                minHeight: '46px',
                borderRadius: '999px',
                backgroundColor: TOKENS.status.approved.solid,
                color: TOKENS.labelOnInk,
                border: 'none',
                ...TYPE.t2,
                cursor: 'pointer'
              }}
            >
              Scheduled on {activeCampaign.channel} · View Calendar
            </button>
          ) : isVersionApproved && isCurrentHead ? (
            <button
              onClick={() => setActiveScreen('preflight_pass')}
              style={{
                flex: 1,
                minHeight: '46px',
                borderRadius: '999px',
                backgroundColor: TOKENS.inkPrussian,
                color: TOKENS.labelOnInk,
                border: 'none',
                ...TYPE.t2,
                cursor: 'pointer'
              }}
            >
              Schedule {selectedVersionTag}
            </button>
          ) : !isCurrentHead ? (
            <>
              <button
                onClick={() => selectCampaignVersion(activeCampaign.version, stamps.length - 1)}
                style={{
                  flex: 1,
                  minHeight: '46px',
                  borderRadius: '999px',
                  backgroundColor: TOKENS.inkPrussian,
                  color: TOKENS.labelOnInk,
                  border: 'none',
                  ...TYPE.t3,
                  fontWeight: 600,
                  cursor: 'pointer'
                }}
              >
                Return to {activeCampaign.version} (Current)
              </button>
              <button
                onClick={() => setActiveScreen('preflight_blocked')}
                style={{
                  padding: '0 14px',
                  minHeight: '46px',
                  borderRadius: '999px',
                  backgroundColor: TOKENS.surfaceRecessed,
                  color: TOKENS.status.blocked.solid,
                  border: `1px solid ${TOKENS.hairline}`,
                  ...TYPE.t4,
                  cursor: 'pointer'
                }}
              >
                Test {selectedVersionTag} gate
              </button>
            </>
          ) : activeVersion.status === 'changes' ? (
            <button
              onClick={() => setActiveScreen('studio')}
              style={{
                flex: 1,
                minHeight: '46px',
                borderRadius: '999px',
                backgroundColor: TOKENS.inkPrussian,
                color: TOKENS.labelOnInk,
                border: 'none',
                ...TYPE.t2,
                cursor: 'pointer'
              }}
            >
              Edit in Proposal Studio
            </button>
          ) : (
            <button
              onClick={() => {
                if (isOwner) setActiveScreen('blocked');
                else setActiveScreen('decision');
              }}
              style={{
                flex: 1,
                minHeight: '46px',
                borderRadius: '999px',
                backgroundColor: TOKENS.inkPrussian,
                color: TOKENS.labelOnInk,
                border: 'none',
                ...TYPE.t2,
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: '8px'
              }}
            >
              {isOwner && <MonoIcons.Lock color={TOKENS.cadmiumYellow} size={14} />}
              <span>{isOwner ? `Inspect ${selectedVersionTag} (Owner Lock)` : `Review ${selectedVersionTag}`}</span>
            </button>
          )}
        </div>
      </div>
    );
  };

  // ==========================================================================
  // SCREEN 03: DIFF INSPECTOR
  // ==========================================================================
  const renderDiffScreen = () => {
    const isV3 = diffTab === 'V3.0';

    return (
      <div style={phoneFrameStyle}>
        <div style={iosStatusBarStyle}>
          <span style={TYPE.t4}>09:41</span>
          <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>5G · 100%</span>
        </div>

        <div
          style={{
            padding: '6px 16px 10px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            borderBottom: `1px solid ${TOKENS.hairline}`
          }}
        >
          <button
            onClick={() => setActiveScreen('detail')}
            style={{
              minHeight: '34px',
              padding: '0 8px 0 0',
              backgroundColor: 'transparent',
              border: 'none',
              display: 'inline-flex',
              alignItems: 'center',
              gap: '4px',
              ...TYPE.t3,
              fontWeight: 600,
              color: TOKENS.textPrimary,
              cursor: 'pointer'
            }}
          >
            <MonoIcons.ChevronLeft color={TOKENS.textPrimary} size={15} />
            <span>{activeCampaign.title}</span>
          </button>
          <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>
            V2.0 to {diffTab}
          </span>
        </div>

        <div
          style={{
            padding: '14px 16px 18px',
            display: 'flex',
            flexDirection: 'column',
            gap: '14px',
            flex: 1,
            width: '100%',
            boxSizing: 'border-box',
            overflowY: 'auto'
          }}
        >
          <h1 style={{ ...TYPE.t1, color: TOKENS.textPrimary, margin: 0 }}>
            Changes in {diffTab}
          </h1>

          <div
            style={{
              backgroundColor: TOKENS.surfaceRecessed,
              borderRadius: '12px',
              padding: '3px',
              display: 'flex',
              gap: '4px',
              border: `1px solid ${TOKENS.hairline}`
            }}
          >
            {['V1.0', 'V2.0', 'V3.0'].map((ver) => {
              const selected = diffTab === ver;
              return (
                <button
                  key={ver}
                  onClick={() => setDiffTab(ver)}
                  style={{
                    flex: 1,
                    minHeight: '36px',
                    borderRadius: '9px',
                    backgroundColor: selected ? TOKENS.surfaceCard : 'transparent',
                    border: selected ? `1.5px solid ${TOKENS.inkPrussian}` : 'none',
                    ...TYPE.t4,
                    color: selected ? TOKENS.textPrimary : TOKENS.textSecondary,
                    cursor: 'pointer'
                  }}
                >
                  {ver}
                </button>
              );
            })}
          </div>

          <div
            style={{
              backgroundColor: TOKENS.changedRowTint,
              border: `1px solid ${TOKENS.hairline}`,
              borderRadius: '16px',
              overflow: 'hidden'
            }}
          >
            <div style={{ padding: '14px 16px 10px', display: 'flex', flexDirection: 'column', gap: '10px' }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <span style={{ ...TYPE.t2, color: TOKENS.textPrimary }}>Budget</span>
                <StatusBadge status="changes" customLabel="Changed" />
              </div>

              <div style={{ display: 'flex', alignItems: 'baseline', gap: '10px' }}>
                <span
                  style={{
                    ...TYPE.t2,
                    fontFamily: TOKENS.fontMono,
                    color: TOKENS.textSecondary,
                    textDecoration: 'line-through'
                  }}
                >
                  $20,000
                </span>
                <MonoIcons.ArrowRight color={TOKENS.textSecondary} size={13} />
                <span style={{ ...TYPE.t1, fontFamily: TOKENS.fontMono, color: TOKENS.textPrimary }}>
                  {isV3 ? `$${activeCampaign.budget.toLocaleString()}` : '$20,000'}
                </span>
              </div>

              <CellMeter
                amount={isV3 ? activeCampaign.budget : 20000}
                prevAmount={20000}
                maxAmount={40000}
                ceilingRatio={0.75}
                totalCells={24}
                cellHeight={10}
              />
            </div>

            <TicketPerforation notchBg={TOKENS.bgPlaster} />

            <div style={{ padding: '8px 16px 12px', display: 'flex', justifyContent: 'space-between' }}>
              <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>
                Previous: $20,000
              </span>
              <span style={{ ...TYPE.t4, color: TOKENS.status.changes.solid }}>
                +${(activeCampaign.budget - 20000).toLocaleString()} (+25%)
              </span>
            </div>
          </div>

          <div
            style={{
              backgroundColor: TOKENS.surfaceCard,
              border: `1px solid ${TOKENS.hairline}`,
              borderRadius: '16px',
              overflow: 'hidden'
            }}
          >
            <div
              style={{
                padding: '14px 16px',
                backgroundColor: TOKENS.changedRowTint,
                borderBottom: `1px solid ${TOKENS.hairline}`,
                display: 'flex',
                flexDirection: 'column',
                gap: '8px'
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <span style={{ ...TYPE.t2, color: TOKENS.textPrimary }}>Audience</span>
                <StatusBadge status="changes" customLabel="Changed" />
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <span style={{ ...TYPE.t3, color: TOKENS.textSecondary, textDecoration: 'line-through' }}>
                  Broad (12/12)
                </span>
                <MonoIcons.ArrowRight color={TOKENS.textSecondary} size={12} />
                <span style={{ ...TYPE.t3, fontWeight: 600, color: TOKENS.textPrimary }}>
                  Lookalike (5/12 high-intent)
                </span>
              </div>
            </div>

            <div
              style={{
                padding: '12px 16px',
                borderBottom: `1px solid ${TOKENS.hairline}`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between'
              }}
            >
              <span style={{ ...TYPE.t3, color: TOKENS.textSecondary }}>Channel</span>
              <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>Social, unchanged</span>
            </div>

            <div
              style={{
                padding: '12px 16px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between'
              }}
            >
              <span style={{ ...TYPE.t3, color: TOKENS.textSecondary }}>Schedule</span>
              <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>Nov 01 to Nov 14, unchanged</span>
            </div>
          </div>

          <p style={{ ...TYPE.t3, color: TOKENS.textSecondary, margin: '0 2px', maxWidth: '44ch', textAlign: 'left' }}>
            The V1.0 approval does not apply to {diffTab}.
          </p>
        </div>

        <SolidBottomBar
          activeTab="pipeline"
          onSelectTab={(tabId) => {
            if (tabId === 'activity') setActiveScreen('activity');
            else if (tabId === 'calendar') setActiveScreen('calendar');
            else if (tabId === 'insights') setActiveScreen('insights');
            else setActiveScreen('pipeline');
          }}
        />
      </div>
    );
  };

  // ==========================================================================
  // SCREEN 04: DECISION SHEET (Wrapped in BottomSheetScaffold — Fix 7)
  // ==========================================================================
  const renderDecisionSheetScreen = () => {
    return (
      <BottomSheetScaffold
        parentTitle={activeCampaign.title}
        parentSub={`Owner: ${activeCampaign.owner} · ${selectedVersionTag}`}
        parentStatus={activeVersion.status}
        onClose={() => setActiveScreen('detail')}
        rightAction={<span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>Review {selectedVersionTag}</span>}
      >
        <div
          style={{
            padding: '16px',
            display: 'flex',
            flexDirection: 'column',
            gap: '14px',
            flex: 1,
            width: '100%',
            boxSizing: 'border-box',
            overflowY: 'auto'
          }}
        >
          <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
            <h1 style={{ ...TYPE.t1, color: TOKENS.textPrimary, margin: 0 }}>
              Review {selectedVersionTag}
            </h1>
            <span style={{ ...TYPE.t3, color: TOKENS.textSecondary }}>
              {activeCampaign.title} · Budget ${activeVersion.budget.toLocaleString()}
            </span>
          </div>

          <div
            style={{
              backgroundColor: TOKENS.surfaceRecessed,
              borderRadius: '12px',
              padding: '3px',
              display: 'flex',
              gap: '4px',
              border: `1px solid ${TOKENS.hairline}`
            }}
          >
            {['Approve', 'Request changes', 'Reject'].map((outcome) => {
              const selected = decisionOutcome === outcome;
              return (
                <button
                  key={outcome}
                  onClick={() => setDecisionOutcome(outcome)}
                  style={{
                    flex: 1,
                    minHeight: '38px',
                    borderRadius: '9px',
                    backgroundColor: selected ? TOKENS.surfaceCard : 'transparent',
                    border: selected ? `1.5px solid ${TOKENS.inkPrussian}` : 'none',
                    ...TYPE.t3,
                    fontWeight: 600,
                    color: selected ? TOKENS.textPrimary : TOKENS.textSecondary,
                    cursor: 'pointer'
                  }}
                >
                  {outcome}
                </button>
              );
            })}
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>Reason (mandatory)</span>
              <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>{decisionReason.trim().length} chars</span>
            </div>
            <textarea
              value={decisionReason}
              onChange={(e) => setDecisionReason(e.target.value)}
              placeholder="Explain why the budget, audience and KPIs are acceptable"
              rows={3}
              style={{
                width: '100%',
                backgroundColor: TOKENS.surfaceCard,
                border: reasonError ? `1.5px solid ${TOKENS.status.blocked.solid}` : `1px solid ${TOKENS.hairline}`,
                borderRadius: '12px',
                padding: '12px',
                ...TYPE.t3,
                color: TOKENS.textPrimary,
                boxSizing: 'border-box',
                resize: 'none',
                outline: 'none',
                transform: shakeTrigger ? 'translateX(6px)' : 'none',
                transition: 'transform 80ms ease'
              }}
            />
            {reasonError && (
              <span style={{ ...TYPE.t4, color: TOKENS.status.blocked.solid }}>{reasonError}</span>
            )}
          </div>

          <div
            style={{
              backgroundColor: TOKENS.surfaceCard,
              border: `1px solid ${TOKENS.hairline}`,
              borderRadius: '16px',
              padding: '12px 14px',
              display: 'flex',
              flexDirection: 'column',
              gap: '8px'
            }}
          >
            <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>Pinned parameter clauses</span>
            {['Budget $25,000', 'Audience Lookalike'].map((clause) => {
              const isPinned = pinnedClauses.includes(clause);
              return (
                <div
                  key={clause}
                  onClick={() => togglePinnedClause(clause)}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    padding: '8px 10px',
                    borderRadius: '8px',
                    backgroundColor: isPinned ? TOKENS.changedRowTint : TOKENS.surfaceRecessed,
                    border: isPinned ? `1px solid ${TOKENS.inkPrussian}` : `1px solid ${TOKENS.hairline}`,
                    cursor: 'pointer'
                  }}
                >
                  <span style={{ ...TYPE.t3, color: TOKENS.textPrimary }}>{clause}</span>
                  <span style={{ ...TYPE.t4, color: isPinned ? TOKENS.status.approved.solid : TOKENS.textSecondary }}>
                    {isPinned ? 'Pinned ✓' : 'Tap to pin'}
                  </span>
                </div>
              );
            })}
          </div>

          <div style={{ marginTop: 'auto', display: 'flex', flexDirection: 'column', gap: '8px' }}>
            {decisionOutcome === 'Approve' ? (
              <div
                onMouseDown={startHold}
                onMouseUp={cancelHold}
                onMouseLeave={cancelHold}
                onTouchStart={startHold}
                onTouchEnd={cancelHold}
                style={{
                  position: 'relative',
                  width: '100%',
                  height: '50px',
                  borderRadius: '999px',
                  backgroundColor: TOKENS.inkPrussian,
                  overflow: 'hidden',
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center'
                }}
              >
                <div
                  style={{
                    position: 'absolute',
                    top: 0,
                    left: 0,
                    bottom: 0,
                    width: `${holdProgress}%`,
                    backgroundColor: TOKENS.cadmiumYellow,
                    opacity: 0.35,
                    transition: 'width 30ms linear'
                  }}
                />
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', zIndex: 2 }}>
                  <MonoIcons.HandHold color={TOKENS.labelOnInk} size={16} />
                  <span style={{ ...TYPE.t2, color: TOKENS.labelOnInk }}>
                    {isHolding ? 'Holding to commit...' : `Hold to approve ${selectedVersionTag}`}
                  </span>
                </div>
              </div>
            ) : (
              <button
                onClick={() => commitDecisionNow(decisionOutcome)}
                style={{
                  width: '100%',
                  minHeight: '48px',
                  borderRadius: '999px',
                  backgroundColor: decisionOutcome === 'Reject' ? TOKENS.status.blocked.solid : TOKENS.status.changes.solid,
                  color: '#FFFFFF',
                  border: 'none',
                  ...TYPE.t2,
                  cursor: 'pointer'
                }}
              >
                {decisionOutcome === 'Reject' ? 'Reject Version' : 'Request Changes'}
              </button>
            )}

            <p style={{ ...TYPE.t3, color: TOKENS.textSecondary, textAlign: 'left', margin: 0 }}>
              Hold for a moment to confirm. This decision cannot be edited, only amended.
            </p>
          </div>
        </div>
      </BottomSheetScaffold>
    );
  };

  // ==========================================================================
  // SCREEN 05: DECISION BLOCKED (Wrapped in BottomSheetScaffold — Fix 7)
  // ==========================================================================
  const renderDecisionBlockedScreen = () => {
    return (
      <BottomSheetScaffold
        parentTitle={activeCampaign.title}
        parentSub={`Owner: Riya Sen · ${selectedVersionTag}`}
        parentStatus={activeVersion.status}
        onClose={() => setActiveScreen('detail')}
        rightAction={<span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>Owner lock</span>}
      >
        <div
          style={{
            padding: '16px',
            display: 'flex',
            flexDirection: 'column',
            gap: '14px',
            flex: 1,
            width: '100%',
            boxSizing: 'border-box',
            overflowY: 'auto'
          }}
        >
          <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
            <h1 style={{ ...TYPE.t1, color: TOKENS.textPrimary, margin: 0 }}>
              Review {selectedVersionTag}
            </h1>
            <span style={{ ...TYPE.t3, color: TOKENS.textSecondary }}>
              {activeCampaign.title} · Viewer: Riya Sen (Owner)
            </span>
          </div>

          <div
            style={{
              backgroundColor: TOKENS.surfaceRecessed,
              border: `1px solid ${TOKENS.hairline}`,
              borderRadius: '16px',
              padding: '16px',
              display: 'flex',
              alignItems: 'center',
              gap: '12px'
            }}
          >
            <MonoIcons.Lock color={TOKENS.textSecondary} size={20} />
            <span style={{ ...TYPE.t2, color: TOKENS.textPrimary }}>
              You own this campaign, so you cannot decide on it.
            </span>
          </div>

          <div style={{ opacity: 0.5, pointerEvents: 'none', display: 'flex', flexDirection: 'column', gap: '14px' }}>
            <textarea
              disabled
              placeholder="Reason field disabled for campaign owners..."
              rows={4}
              style={{
                width: '100%',
                backgroundColor: TOKENS.surfaceRecessed,
                border: `1.5px solid ${TOKENS.hairline}`,
                borderRadius: '12px',
                padding: '12px',
                ...TYPE.t3,
                color: TOKENS.textSecondary,
                boxSizing: 'border-box',
                resize: 'none'
              }}
            />
          </div>

          <div style={{ marginTop: 'auto' }}>
            <div
              style={{
                width: '100%',
                minHeight: '48px',
                borderRadius: '999px',
                backgroundColor: TOKENS.surfaceRecessed,
                color: TOKENS.textSecondary,
                border: `1px solid ${TOKENS.hairline}`,
                ...TYPE.t2,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center'
              }}
            >
              <span>Owner view</span>
            </div>
          </div>
        </div>
      </BottomSheetScaffold>
    );
  };

  // ==========================================================================
  // FIX 1 (P0): SCREENS 06 & 07 — PROPOSAL STUDIO & SUBMIT IN PROGRESS
  // ==========================================================================
  const renderProposalStudioScreen = (isSubmitting = false) => {
    const formatLease = (secs) => {
      const m = String(Math.floor(secs / 60)).padStart(2, '0');
      const s = String(secs % 60).padStart(2, '0');
      return `${m}:${s}`;
    };

    const projectedCpa = studioAudience === 'Lookalike'
      ? (11.4 * (studioBudget / 25000)).toFixed(2)
      : (15.8 * (studioBudget / 25000)).toFixed(2);
    const projectedCtr = studioAudience === 'Lookalike' ? '2.8%' : '1.9%';
    const projectedConv = studioAudience === 'Lookalike' ? '3.1%' : '2.1%';

    const handleStudioSubmit = () => {
      if (isSubmitting) return;
      setCampaigns((prev) =>
        prev.map((c) => {
          if (c.id !== activeCampaign.id) return c;
          const updatedVersions = {
            ...c.versions,
            [c.version]: {
              ...c.versions[c.version],
              status: 'review',
              statusText: 'In review',
              budget: studioBudget,
              audience: studioAudience,
              channel: studioChannel
            }
          };
          return {
            ...c,
            status: 'review',
            budget: studioBudget,
            audience: studioAudience,
            channel: studioChannel,
            deltaText: `Budget $${studioBudget.toLocaleString()} (${studioAudience})`,
            deltaType: 'changes',
            versions: updatedVersions
          };
        })
      );

      setCommitBanner(`Submitted ${activeCampaign.version} ($${studioBudget.toLocaleString()} · ${studioAudience}).`);
      setActiveScreen('detail');
      setTimeout(() => setCommitBanner(null), 4000);
    };

    return (
      <BottomSheetScaffold
        parentTitle={activeCampaign.title}
        parentSub={`Editing ${activeCampaign.version} · Lease active`}
        parentStatus="review"
        onClose={() => setActiveScreen('detail')}
        rightAction={
          <div
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: '5px',
              backgroundColor: TOKENS.status.approved.chipBg,
              padding: '3px 8px',
              borderRadius: '999px',
              border: `1px solid ${TOKENS.hairline}`
            }}
          >
            <FacetCell status="approved" size={9} />
            <span style={{ ...TYPE.t4, color: TOKENS.status.approved.solid }}>
              Editing, lease {formatLease(leaseSeconds)}
            </span>
          </div>
        }
      >
        <div
          style={{
            padding: '14px 16px 16px',
            display: 'flex',
            flexDirection: 'column',
            gap: '12px',
            flex: 1,
            overflowY: 'auto',
            boxSizing: 'border-box'
          }}
        >
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
            <h1 style={{ ...TYPE.t1, color: TOKENS.textPrimary, margin: 0 }}>
              Edit {activeCampaign.version}
            </h1>
            <button
              onClick={() => setActiveScreen(isSubmitting ? 'studio' : 'submit_progress')}
              style={{
                padding: '4px 9px',
                borderRadius: '999px',
                backgroundColor: TOKENS.surfaceRecessed,
                border: `1px solid ${TOKENS.hairline}`,
                ...TYPE.t4,
                color: TOKENS.textPrimary,
                cursor: 'pointer'
              }}
            >
              {isSubmitting ? 'Back to edit' : 'Test offline queue'}
            </button>
          </div>

          {/* Offline Idempotency Banner (Screen 07) */}
          {isSubmitting && (
            <div
              style={{
                backgroundColor: TOKENS.changedRowTint,
                border: `1.5px solid ${TOKENS.inkPrussian}`,
                borderRadius: '12px',
                padding: '12px 14px',
                display: 'flex',
                alignItems: 'flex-start',
                gap: '10px'
              }}
            >
              <MonoIcons.WifiOff color={TOKENS.inkPrussian} size={16} />
              <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
                <span style={{ ...TYPE.t3, fontWeight: 600, color: TOKENS.textPrimary }}>
                  No connection. We will retry this exact submission when you are back online.
                </span>
                <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>
                  Idempotency key #K-9042 locked
                </span>
              </div>
            </div>
          )}

          {/* Hero Budget Entry & Tactile Ruler Scrubber */}
          <div
            style={{
              backgroundColor: TOKENS.surfaceCard,
              border: `1px solid ${TOKENS.hairline}`,
              borderRadius: '16px',
              padding: '14px 16px',
              display: 'flex',
              flexDirection: 'column',
              gap: '10px',
              opacity: isSubmitting ? 0.65 : 1,
              pointerEvents: isSubmitting ? 'none' : 'auto'
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <span style={{ ...TYPE.t3, color: TOKENS.textSecondary }}>Budget cap</span>
              <span style={{ ...TYPE.t4, color: TOKENS.status.blocked.solid }}>Ceiling $30,000</span>
            </div>

            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '8px' }}>
              <button
                onClick={() => setStudioBudget((b) => Math.max(10000, b - 1000))}
                style={{
                  minWidth: '44px',
                  minHeight: '44px',
                  borderRadius: '12px',
                  backgroundColor: TOKENS.surfaceRecessed,
                  border: `1px solid ${TOKENS.hairline}`,
                  ...TYPE.t2,
                  fontFamily: TOKENS.fontMono,
                  color: TOKENS.textPrimary,
                  cursor: 'pointer'
                }}
              >
                −1k
              </button>

              <span style={{ ...TYPE.t1, fontFamily: TOKENS.fontMono, color: TOKENS.textPrimary }}>
                ${studioBudget.toLocaleString()}
              </span>

              <button
                onClick={() => setStudioBudget((b) => Math.min(35000, b + 1000))}
                style={{
                  minWidth: '44px',
                  minHeight: '44px',
                  borderRadius: '12px',
                  backgroundColor: TOKENS.surfaceRecessed,
                  border: `1px solid ${TOKENS.hairline}`,
                  ...TYPE.t2,
                  fontFamily: TOKENS.fontMono,
                  color: TOKENS.textPrimary,
                  cursor: 'pointer'
                }}
              >
                +1k
              </button>
            </div>

            {/* Tactile Ruler Tick Strip */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', paddingTop: '2px' }}>
              <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', height: '22px', padding: '0 2px' }}>
                {Array.from({ length: 21 }).map((_, idx) => {
                  const tickVal = 15000 + idx * 1000;
                  const isMajor = tickVal % 5000 === 0;
                  const isCurrent = Math.abs(studioBudget - tickVal) < 500;
                  const isCeiling = tickVal === 30000;
                  return (
                    <div
                      key={idx}
                      onClick={() => setStudioBudget(tickVal)}
                      style={{
                        width: isCurrent ? '4px' : isMajor ? '2px' : '1.5px',
                        height: isCurrent ? '22px' : isMajor ? '14px' : '8px',
                        borderRadius: '1px',
                        backgroundColor: isCurrent
                          ? TOKENS.cadmiumYellow
                          : isCeiling
                            ? TOKENS.status.blocked.solid
                            : isMajor
                              ? TOKENS.inkPrussian
                              : TOKENS.hairline,
                        border: isCurrent ? `0.5px solid ${TOKENS.inkPrussian}` : 'none',
                        cursor: 'pointer'
                      }}
                    />
                  );
                })}
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>$15k</span>
                <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>$25k</span>
                <span style={{ ...TYPE.t4, color: TOKENS.status.blocked.solid }}>$30k cap</span>
                <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>$35k</span>
              </div>
            </div>
          </div>

          {/* Grouped Inset Form: Objective, Audience, Channel */}
          <div
            style={{
              backgroundColor: TOKENS.surfaceCard,
              border: `1px solid ${TOKENS.hairline}`,
              borderRadius: '16px',
              overflow: 'hidden',
              opacity: isSubmitting ? 0.65 : 1,
              pointerEvents: isSubmitting ? 'none' : 'auto'
            }}
          >
            <div
              style={{
                padding: '12px 16px',
                borderBottom: `1px solid ${TOKENS.hairline}`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between'
              }}
            >
              <span style={{ ...TYPE.t3, color: TOKENS.textSecondary }}>Objective</span>
              <button
                onClick={() =>
                  setStudioObjective((o) =>
                    o === 'Festive Conversion' ? 'Brand Reach' : 'Festive Conversion'
                  )
                }
                style={{
                  padding: '4px 10px',
                  borderRadius: '8px',
                  backgroundColor: TOKENS.surfaceRecessed,
                  border: `1px solid ${TOKENS.hairline}`,
                  ...TYPE.t4,
                  color: TOKENS.textPrimary,
                  cursor: 'pointer'
                }}
              >
                {studioObjective}
              </button>
            </div>

            <div
              style={{
                padding: '12px 16px',
                borderBottom: `1px solid ${TOKENS.hairline}`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between'
              }}
            >
              <span style={{ ...TYPE.t3, color: TOKENS.textSecondary }}>Audience</span>
              <div style={{ display: 'flex', gap: '4px' }}>
                {['Lookalike', 'Broad'].map((aud) => {
                  const active = studioAudience === aud;
                  return (
                    <button
                      key={aud}
                      onClick={() => setStudioAudience(aud)}
                      style={{
                        padding: '4px 10px',
                        borderRadius: '8px',
                        backgroundColor: active ? TOKENS.inkPrussian : TOKENS.surfaceRecessed,
                        color: active ? TOKENS.labelOnInk : TOKENS.textSecondary,
                        border: 'none',
                        ...TYPE.t4,
                        cursor: 'pointer'
                      }}
                    >
                      {aud}
                    </button>
                  );
                })}
              </div>
            </div>

            <div
              style={{
                padding: '12px 16px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between'
              }}
            >
              <span style={{ ...TYPE.t3, color: TOKENS.textSecondary }}>Channel</span>
              <div style={{ display: 'flex', gap: '4px' }}>
                {['Social', 'Search', 'Display'].map((ch) => {
                  const active = studioChannel === ch;
                  return (
                    <button
                      key={ch}
                      onClick={() => setStudioChannel(ch)}
                      style={{
                        padding: '4px 10px',
                        borderRadius: '8px',
                        backgroundColor: active ? TOKENS.inkPrussian : TOKENS.surfaceRecessed,
                        color: active ? TOKENS.labelOnInk : TOKENS.textSecondary,
                        border: 'none',
                        ...TYPE.t4,
                        cursor: 'pointer'
                      }}
                    >
                      {ch}
                    </button>
                  );
                })}
              </div>
            </div>
          </div>

          {/* 3-Column Live Projections in SF Mono */}
          <div
            style={{
              backgroundColor: TOKENS.surfaceCard,
              border: `1px solid ${TOKENS.hairline}`,
              borderRadius: '14px',
              padding: '10px 14px',
              display: 'grid',
              gridTemplateColumns: 'repeat(3, 1fr)',
              gap: '8px'
            }}
          >
            <div>
              <div style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>CPA</div>
              <div style={{ ...TYPE.t2, fontFamily: TOKENS.fontMono, color: TOKENS.textPrimary }}>
                ${projectedCpa}
              </div>
            </div>
            <div>
              <div style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>CTR</div>
              <div style={{ ...TYPE.t2, fontFamily: TOKENS.fontMono, color: TOKENS.textPrimary }}>
                {projectedCtr}
              </div>
            </div>
            <div>
              <div style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>Conversion</div>
              <div style={{ ...TYPE.t2, fontFamily: TOKENS.fontMono, color: TOKENS.textPrimary }}>
                {projectedConv}
              </div>
            </div>
          </div>

          <div style={{ marginTop: 'auto', display: 'flex', flexDirection: 'column', gap: '8px' }}>
            <button
              disabled={isSubmitting}
              onClick={handleStudioSubmit}
              style={{
                width: '100%',
                minHeight: '48px',
                borderRadius: '999px',
                backgroundColor: isSubmitting ? TOKENS.surfaceRecessed : TOKENS.inkPrussian,
                color: isSubmitting ? TOKENS.textPrimary : TOKENS.labelOnInk,
                border: `1px solid ${TOKENS.hairline}`,
                ...TYPE.t2,
                cursor: isSubmitting ? 'default' : 'pointer',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: '8px'
              }}
            >
              {isSubmitting && <MonoIcons.Clock color={TOKENS.inkPrussian} size={15} />}
              <span>{isSubmitting ? `Securing ${activeCampaign.version}...` : `Submit ${activeCampaign.version}`}</span>
            </button>

            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '0 4px' }}>
              <span style={{ ...TYPE.t3, color: TOKENS.textSecondary }}>
                {isSubmitting ? 'Safe to retry. This submit is sent once.' : 'Draft saved locally'}
              </span>
              <button
                onClick={() => setActiveScreen('conflict')}
                style={{
                  background: 'none',
                  border: 'none',
                  padding: 0,
                  ...TYPE.t4,
                  color: TOKENS.inkPrussian,
                  cursor: 'pointer'
                }}
              >
                Simulate V4.0 conflict →
              </button>
            </div>
          </div>
        </div>
      </BottomSheetScaffold>
    );
  };

  // ==========================================================================
  // FIX 1 (P0): SCREEN 08 — STALE-SAVE CONFLICT RESOLVER (T-11)
  // ==========================================================================
  const renderConflictScreen = () => {
    const resolvedBudget = conflictChoices.budget === 'mine' ? studioBudget : 28000;
    const resolvedAudience = conflictChoices.audience === 'mine' ? studioAudience : 'Retargeting Tier-1';
    const resolvedChannel = conflictChoices.channel === 'mine' ? studioChannel : 'Social';

    const handleMergeConflict = () => {
      setCampaigns((prev) =>
        prev.map((c) => {
          if (c.id !== activeCampaign.id) return c;
          const v4Snapshot = {
            tag: 'V4.0',
            status: 'review',
            statusText: 'In review',
            budget: resolvedBudget,
            prevBudget: c.budget,
            audience: resolvedAudience,
            prevAudience: c.audience,
            channel: resolvedChannel,
            schedule: 'Nov 01 to Nov 14',
            targetCpa: '$14.40',
            dna: ['changes', 'changes', 'approved', 'approved']
          };
          const v4Stamp = {
            version: 'V4.0',
            status: 'review',
            stampWord: 'In review',
            actor: 'Riya + Vikram (Merged)',
            time: 'Just now',
            clauses: [
              {
                field: 'Budget',
                metricDelta: `$${resolvedBudget.toLocaleString()} merged`,
                note: `Resolved stale save (${conflictChoices.budget === 'mine' ? 'kept local' : 'took Vikram V4.0'})`,
                clauseStatus: 'changes',
                resolutionTag: 'Merged V4.0'
              },
              {
                field: 'Audience',
                metricDelta: resolvedAudience,
                note: 'Merged audience selection',
                clauseStatus: 'approved',
                resolutionTag: 'Verified'
              }
            ]
          };
          const nextStamps = [...c.stampLedger.filter((s) => s.version !== 'V4.0'), v4Stamp];
          return {
            ...c,
            version: 'V4.0',
            status: 'review',
            budget: resolvedBudget,
            audience: resolvedAudience,
            channel: resolvedChannel,
            deltaText: 'Merged V4.0 awaiting review',
            versions: {
              ...c.versions,
              'V4.0': v4Snapshot
            },
            stampLedger: nextStamps
          };
        })
      );

      setSelectedVersionTag('V4.0');
      setSelectedStampIdx(3);
      setCommitBanner('Merged into V4.0 without overwriting Vikram’s concurrent save.');
      setActiveScreen('detail');
      setTimeout(() => setCommitBanner(null), 4000);
    };

    const conflictRows = [
      {
        key: 'budget',
        label: 'Budget',
        mineLabel: `Mine: $${studioBudget.toLocaleString()}`,
        theirsLabel: 'V4.0: $28,000'
      },
      {
        key: 'audience',
        label: 'Audience',
        mineLabel: `Mine: ${studioAudience}`,
        theirsLabel: 'V4.0: Retargeting'
      },
      {
        key: 'channel',
        label: 'Channel',
        mineLabel: `Mine: ${studioChannel}`,
        theirsLabel: 'V4.0: Social'
      }
    ];

    return (
      <BottomSheetScaffold
        parentTitle={activeCampaign.title}
        parentSub="409 VERSION_CONFLICT · Stale save"
        parentStatus="changes"
        onClose={() => setActiveScreen('studio')}
        rightAction={<span style={{ ...TYPE.t4, color: TOKENS.status.changes.solid }}>T-11 Merge</span>}
      >
        <div
          style={{
            padding: '14px 16px 16px',
            display: 'flex',
            flexDirection: 'column',
            gap: '12px',
            flex: 1,
            overflowY: 'auto',
            boxSizing: 'border-box'
          }}
        >
          <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
            <h1 style={{ ...TYPE.t1, color: TOKENS.textPrimary, margin: 0 }}>
              A newer version exists
            </h1>
            <span style={{ ...TYPE.t3, color: TOKENS.textSecondary }}>
              Vikram Sharma saved V4.0 while you were editing. Choose per field to merge.
            </span>
          </div>

          {/* Two Side-by-Side Provenance Cards */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px' }}>
            <div
              style={{
                backgroundColor: TOKENS.surfaceCard,
                border: `1.5px solid ${TOKENS.inkPrussian}`,
                borderRadius: '12px',
                padding: '10px 12px',
                display: 'flex',
                flexDirection: 'column',
                gap: '3px'
              }}
            >
              <span style={{ ...TYPE.t4, color: TOKENS.inkPrussian }}>Your edits</span>
              <span style={{ ...TYPE.t3, fontWeight: 600, color: TOKENS.textPrimary }}>
                Kept on this device
              </span>
              <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>
                ${studioBudget.toLocaleString()} · {studioAudience}
              </span>
            </div>

            <div
              style={{
                backgroundColor: TOKENS.surfaceCard,
                border: `1px solid ${TOKENS.hairline}`,
                borderRadius: '12px',
                padding: '10px 12px',
                display: 'flex',
                flexDirection: 'column',
                gap: '3px'
              }}
            >
              <span style={{ ...TYPE.t4, color: TOKENS.status.changes.solid }}>Server HEAD</span>
              <span style={{ ...TYPE.t3, fontWeight: 600, color: TOKENS.textPrimary }}>
                V4.0 by Vikram Sharma
              </span>
              <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>
                $28,000 · Retargeting
              </span>
            </div>
          </div>

          {/* Per-Field 2-Option Segmented Controls */}
          <div
            style={{
              backgroundColor: TOKENS.surfaceCard,
              border: `1px solid ${TOKENS.hairline}`,
              borderRadius: '16px',
              padding: '12px 14px',
              display: 'flex',
              flexDirection: 'column',
              gap: '12px'
            }}
          >
            {conflictRows.map((row) => {
              const choice = conflictChoices[row.key];
              return (
                <div key={row.key} style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span style={{ ...TYPE.t3, fontWeight: 600, color: TOKENS.textPrimary }}>
                      {row.label}
                    </span>
                    <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>
                      {choice === 'mine' ? 'Keeping yours' : 'Taking V4.0'}
                    </span>
                  </div>

                  <div
                    style={{
                      backgroundColor: TOKENS.surfaceRecessed,
                      borderRadius: '10px',
                      padding: '3px',
                      display: 'grid',
                      gridTemplateColumns: '1fr 1fr',
                      gap: '4px',
                      border: `1px solid ${TOKENS.hairline}`
                    }}
                  >
                    <button
                      onClick={() =>
                        setConflictChoices((prev) => ({ ...prev, [row.key]: 'mine' }))
                      }
                      style={{
                        minHeight: '36px',
                        borderRadius: '8px',
                        backgroundColor: choice === 'mine' ? TOKENS.surfaceCard : 'transparent',
                        border: choice === 'mine' ? `1.5px solid ${TOKENS.inkPrussian}` : 'none',
                        ...TYPE.t4,
                        color: choice === 'mine' ? TOKENS.textPrimary : TOKENS.textSecondary,
                        cursor: 'pointer'
                      }}
                    >
                      {row.mineLabel}
                    </button>

                    <button
                      onClick={() =>
                        setConflictChoices((prev) => ({ ...prev, [row.key]: 'theirs' }))
                      }
                      style={{
                        minHeight: '36px',
                        borderRadius: '8px',
                        backgroundColor: choice === 'theirs' ? TOKENS.surfaceCard : 'transparent',
                        border: choice === 'theirs' ? `1.5px solid ${TOKENS.inkPrussian}` : 'none',
                        ...TYPE.t4,
                        color: choice === 'theirs' ? TOKENS.textPrimary : TOKENS.textSecondary,
                        cursor: 'pointer'
                      }}
                    >
                      {row.theirsLabel}
                    </button>
                  </div>
                </div>
              );
            })}
          </div>

          <div style={{ marginTop: 'auto', display: 'flex', flexDirection: 'column', gap: '8px' }}>
            <button
              onClick={handleMergeConflict}
              style={{
                width: '100%',
                minHeight: '48px',
                borderRadius: '999px',
                backgroundColor: TOKENS.inkPrussian,
                color: TOKENS.labelOnInk,
                border: 'none',
                ...TYPE.t2,
                cursor: 'pointer'
              }}
            >
              Merge and continue
            </button>

            <button
              onClick={() => setActiveScreen('detail')}
              style={{
                width: '100%',
                minHeight: '40px',
                borderRadius: '999px',
                backgroundColor: 'transparent',
                color: TOKENS.textSecondary,
                border: 'none',
                ...TYPE.t3,
                fontWeight: 600,
                cursor: 'pointer'
              }}
            >
              Discard my edits
            </button>
          </div>
        </div>
      </BottomSheetScaffold>
    );
  };

  // ==========================================================================
  // FIX 6 (P2): SCREEN 09 — CALENDAR (5-DAY ROLLING GANTT, 54PX ROWS, 11PX FLOOR)
  // ==========================================================================
  const renderCalendarScreen = () => {
    const allDays = [
      { idx: 0, d: 'MON', n: '09' },
      { idx: 1, d: 'TUE', n: '10' },
      { idx: 2, d: 'WED', n: '11' },
      { idx: 3, d: 'THU', n: '12' },
      { idx: 4, d: 'FRI', n: '13' },
      { idx: 5, d: 'SAT', n: '14' },
      { idx: 6, d: 'SUN', n: '15' }
    ];

    const visibleDays = allDays.slice(calendarWindowStart, calendarWindowStart + 5);
    const selectedDayObj = allDays.find((d) => d.n === selectedDay) || allDays[1];
    const selectedFlight =
      calendarFlights.find((f) => f.channel === selectedFlightChannel) || calendarFlights[1];

    const shiftSelectedFlight = (delta) => {
      setCalendarFlights((prev) =>
        prev.map((fl) => {
          if (fl.channel !== selectedFlightChannel) return fl;
          const span = fl.endIdx - fl.startIdx;
          const nextStart = Math.max(0, Math.min(6 - span, fl.startIdx + delta));
          const nextEnd = nextStart + span;

          if (fl.conflictHolder) {
            const overlaps = nextStart <= fl.conflictEndIdx && nextEnd >= fl.conflictStartIdx;
            return {
              ...fl,
              startIdx: nextStart,
              endIdx: nextEnd,
              status: overlaps ? 'blocked' : 'approved',
              word: overlaps ? 'Conflict' : 'Clear'
            };
          }

          return {
            ...fl,
            startIdx: nextStart,
            endIdx: nextEnd
          };
        })
      );
    };

    const activeFlightsOnDay = calendarFlights.filter(
      (f) => selectedDayObj.idx >= f.startIdx && selectedDayObj.idx <= f.endIdx
    );
    const dailySpendTotal = activeFlightsOnDay.reduce((acc, f) => acc + f.dailyBurn, 0);
    const hasConflictToday = calendarFlights.some(
      (f) =>
        f.status === 'blocked' &&
        selectedDayObj.idx >= f.startIdx &&
        selectedDayObj.idx <= f.endIdx
    );

    return (
      <div style={phoneFrameStyle}>
        <div style={iosStatusBarStyle}>
          <span style={TYPE.t4}>09:41</span>
          <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>5G · 100%</span>
        </div>

        <div
          style={{
            padding: '6px 16px 4px',
            display: 'flex',
            alignItems: 'baseline',
            justifyContent: 'space-between'
          }}
        >
          <h1 style={{ ...TYPE.t1, color: TOKENS.textPrimary, margin: 0 }}>Calendar</h1>
          <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
            <button
              onClick={() => setCalendarWindowStart((w) => Math.max(0, w - 1))}
              disabled={calendarWindowStart === 0}
              style={{
                minHeight: '30px',
                padding: '0 8px',
                borderRadius: '8px',
                backgroundColor: TOKENS.surfaceCard,
                border: `1px solid ${TOKENS.hairline}`,
                ...TYPE.t4,
                color: calendarWindowStart === 0 ? TOKENS.hairline : TOKENS.textPrimary,
                cursor: calendarWindowStart === 0 ? 'default' : 'pointer'
              }}
            >
              ‹
            </button>
            <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>
              Nov {visibleDays[0].n}–{visibleDays[visibleDays.length - 1].n}
            </span>
            <button
              onClick={() => setCalendarWindowStart((w) => Math.min(2, w + 1))}
              disabled={calendarWindowStart === 2}
              style={{
                minHeight: '30px',
                padding: '0 8px',
                borderRadius: '8px',
                backgroundColor: TOKENS.surfaceCard,
                border: `1px solid ${TOKENS.hairline}`,
                ...TYPE.t4,
                color: calendarWindowStart === 2 ? TOKENS.hairline : TOKENS.textPrimary,
                cursor: calendarWindowStart === 2 ? 'default' : 'pointer'
              }}
            >
              ›
            </button>
          </div>
        </div>

        {/* 5-Day Rolling Day Selector (56px wide touch-friendly pills, 11px floor) */}
        <div
          style={{
            padding: '4px 16px 8px',
            display: 'grid',
            gridTemplateColumns: 'repeat(5, 1fr)',
            gap: '6px',
            flexShrink: 0
          }}
        >
          {visibleDays.map((day) => {
            const active = selectedDay === day.n;
            const dayHasConflict = calendarFlights.some(
              (f) => f.status === 'blocked' && day.idx >= f.startIdx && day.idx <= f.endIdx
            );

            return (
              <button
                key={day.n}
                onClick={() => setSelectedDay(day.n)}
                style={{
                  minHeight: '48px',
                  padding: '6px 4px',
                  borderRadius: '12px',
                  backgroundColor: active ? TOKENS.inkPrussian : TOKENS.surfaceCard,
                  border: active
                    ? `1.5px solid ${TOKENS.inkPrussian}`
                    : dayHasConflict
                      ? `1px solid ${TOKENS.status.blocked.solid}`
                      : `1px solid ${TOKENS.hairline}`,
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: '2px',
                  cursor: 'pointer'
                }}
              >
                <span
                  style={{
                    ...TYPE.t4,
                    color: active ? TOKENS.cadmiumYellow : TOKENS.textSecondary
                  }}
                >
                  {day.d}
                </span>
                <span
                  style={{
                    ...TYPE.t2,
                    fontFamily: TOKENS.fontMono,
                    color: active ? TOKENS.labelOnInk : TOKENS.textPrimary
                  }}
                >
                  {day.n}
                </span>
              </button>
            );
          })}
        </div>

        <div
          style={{
            padding: '0 16px 12px',
            display: 'flex',
            flexDirection: 'column',
            gap: '10px',
            flex: 1,
            overflowY: 'auto',
            width: '100%',
            boxSizing: 'border-box'
          }}
        >
          {/* 5-Channel × 5-Day Spacious Swimlane Matrix (54px tall rows) */}
          <div
            style={{
              backgroundColor: TOKENS.surfaceCard,
              border: `1px solid ${TOKENS.hairline}`,
              borderRadius: '16px',
              overflow: 'hidden',
              display: 'flex',
              flexDirection: 'column'
            }}
          >
            {calendarFlights.map((lane, rIdx) => {
              const isSelected = selectedFlightChannel === lane.channel;
              const isScheduled = lane.status === 'scheduled' || lane.status === 'approved';
              const isConflict = lane.status === 'blocked';

              const winStart = calendarWindowStart;
              const winEnd = calendarWindowStart + 4;
              const clampedStart = Math.max(winStart, lane.startIdx);
              const clampedEnd = Math.min(winEnd, lane.endIdx);
              const isVisible = clampedEnd >= clampedStart;

              const leftPct = ((clampedStart - winStart) / 5) * 100;
              const widthPct = ((clampedEnd - clampedStart + 1) / 5) * 100;

              const barPalette = isScheduled
                ? {
                    bg: TOKENS.status.approved.solid,
                    text: '#FFFFFF',
                    border: `1.5px solid ${TOKENS.status.approved.solid}`
                  }
                : isConflict
                  ? {
                      bgImage: `repeating-linear-gradient(45deg, ${TOKENS.status.blocked.chipBg}, ${TOKENS.status.blocked.chipBg} 6px, #F2D2CD 6px, #F2D2CD 12px)`,
                      bg: TOKENS.status.blocked.chipBg,
                      text: TOKENS.status.blocked.solid,
                      border: `1.5px solid ${TOKENS.status.blocked.solid}`
                    }
                  : {
                      bg: TOKENS.status.review.chipBg,
                      text: TOKENS.status.review.solid,
                      border: `1.5px dashed ${TOKENS.status.review.solid}`
                    };

              return (
                <div
                  key={lane.id}
                  onClick={() => setSelectedFlightChannel(lane.channel)}
                  style={{
                    display: 'grid',
                    gridTemplateColumns: '76px 1fr',
                    alignItems: 'center',
                    minHeight: '52px',
                    padding: '6px 10px',
                    backgroundColor: isSelected ? TOKENS.changedRowTint : 'transparent',
                    borderBottom:
                      rIdx < calendarFlights.length - 1 ? `1px solid ${TOKENS.hairline}` : 'none',
                    cursor: 'pointer'
                  }}
                >
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '2px', paddingRight: '6px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
                      <FacetCell status={lane.status} size={10} />
                      <span
                        style={{
                          ...TYPE.t3,
                          fontWeight: isSelected ? 700 : 600,
                          color: TOKENS.textPrimary
                        }}
                      >
                        {lane.channel}
                      </span>
                    </div>
                    <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>
                      {lane.version}
                    </span>
                  </div>

                  <div style={{ position: 'relative', height: '38px', width: '100%' }}>
                    <div
                      style={{
                        position: 'absolute',
                        inset: 0,
                        display: 'grid',
                        gridTemplateColumns: 'repeat(5, 1fr)',
                        pointerEvents: 'none'
                      }}
                    >
                      {visibleDays.map((d) => (
                        <div
                          key={d.n}
                          style={{
                            borderLeft: `0.5px dashed ${TOKENS.hairline}`,
                            backgroundColor:
                              d.n === selectedDay ? 'rgba(240, 179, 35, 0.14)' : 'transparent'
                          }}
                        />
                      ))}
                    </div>

                    {isVisible && (
                      <div
                        style={{
                          position: 'absolute',
                          top: '3px',
                          height: '32px',
                          left: `${leftPct}%`,
                          width: `${widthPct}%`,
                          backgroundColor: barPalette.bg,
                          backgroundImage: barPalette.bgImage || 'none',
                          border: isSelected ? `1.5px solid ${TOKENS.inkPrussian}` : barPalette.border,
                          borderRadius: '8px',
                          padding: '0 10px',
                          boxSizing: 'border-box',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'space-between',
                          gap: '6px',
                          overflow: 'hidden',
                          zIndex: 2,
                          transition: 'left 180ms ease, width 180ms ease'
                        }}
                      >
                        <div style={{ display: 'flex', alignItems: 'center', gap: '5px', minWidth: 0 }}>
                          {isScheduled && <MonoIcons.Check color="#FFFFFF" size={12} />}
                          {isConflict && <MonoIcons.Alert color={TOKENS.status.blocked.solid} size={12} />}
                          {!isScheduled && !isConflict && (
                            <MonoIcons.Clock color={TOKENS.status.review.solid} size={12} />
                          )}
                          <span
                            style={{
                              ...TYPE.t3,
                              fontWeight: 600,
                              color: barPalette.text,
                              whiteSpace: 'nowrap',
                              overflow: 'hidden',
                              textOverflow: 'ellipsis'
                            }}
                          >
                            {lane.title}
                          </span>
                        </div>

                        <span
                          style={{
                            ...TYPE.t4,
                            color: barPalette.text,
                            flexShrink: 0
                          }}
                        >
                          {lane.word}
                        </span>
                      </div>
                    )}
                  </div>
                </div>
              );
            })}

            {/* Touch-Friendly 44pt Slot Shift Controls */}
            <div
              style={{
                padding: '8px 12px',
                backgroundColor: TOKENS.bgPlaster,
                borderTop: `1px solid ${TOKENS.hairline}`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                gap: '8px'
              }}
            >
              <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>
                {selectedFlight.channel}: Nov {allDays[selectedFlight.startIdx].n}–Nov {allDays[selectedFlight.endIdx].n}
              </span>

              <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                <button
                  onClick={() => shiftSelectedFlight(-1)}
                  disabled={selectedFlight.startIdx === 0}
                  style={{
                    minHeight: '36px',
                    padding: '0 12px',
                    borderRadius: '8px',
                    backgroundColor: TOKENS.surfaceCard,
                    border: `1px solid ${TOKENS.hairline}`,
                    ...TYPE.t4,
                    color: selectedFlight.startIdx === 0 ? TOKENS.hairline : TOKENS.textPrimary,
                    cursor: selectedFlight.startIdx === 0 ? 'default' : 'pointer'
                  }}
                >
                  ◀ −1d
                </button>
                <button
                  onClick={() => shiftSelectedFlight(1)}
                  disabled={selectedFlight.endIdx === 6}
                  style={{
                    minHeight: '36px',
                    padding: '0 12px',
                    borderRadius: '8px',
                    backgroundColor: TOKENS.surfaceCard,
                    border: `1px solid ${TOKENS.hairline}`,
                    ...TYPE.t4,
                    color: selectedFlight.endIdx === 6 ? TOKENS.hairline : TOKENS.textPrimary,
                    cursor: selectedFlight.endIdx === 6 ? 'default' : 'pointer'
                  }}
                >
                  +1d ▶
                </button>
              </div>
            </div>
          </div>

          {/* Dark Anchor Flight Summary Card with Full-Row Tappable Conflict Banner */}
          <div
            style={{
              marginTop: 'auto',
              backgroundColor: TOKENS.inkPrussian,
              borderRadius: '16px',
              overflow: 'hidden',
              color: TOKENS.labelOnInk,
              border: `1px solid ${TOKENS.inkPrussian}`,
              padding: '12px 16px',
              display: 'flex',
              flexDirection: 'column',
              gap: '10px'
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '8px' }}>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <FacetCell status={selectedFlight.status} size={11} />
                  <span style={{ ...TYPE.t2, color: TOKENS.labelOnInk }}>
                    {selectedFlight.title} · {selectedFlight.version}
                  </span>
                </div>
                <span style={{ ...TYPE.t4, color: TOKENS.cadmiumYellow }}>
                  {selectedFlight.channel} · Nov {allDays[selectedFlight.startIdx].n}–{allDays[selectedFlight.endIdx].n} · ${dailySpendTotal.toLocaleString()}/d
                </span>
              </div>

              <button
                onClick={() => {
                  if (selectedFlight.campaignId) {
                    setSelectedCampaignId(selectedFlight.campaignId);
                  }
                  if (selectedFlight.status === 'blocked' || selectedFlight.version === 'V2.0') {
                    setActiveScreen('preflight_blocked');
                  } else {
                    setActiveScreen('preflight_pass');
                  }
                }}
                style={{
                  minHeight: '44px',
                  padding: '0 16px',
                  borderRadius: '999px',
                  backgroundColor: TOKENS.cadmiumYellow,
                  color: TOKENS.textPrimary,
                  border: 'none',
                  ...TYPE.t3,
                  fontWeight: 700,
                  cursor: 'pointer',
                  flexShrink: 0
                }}
              >
                Schedule
              </button>
            </div>

            {selectedFlight.status === 'blocked' && (
              <button
                onClick={() => {
                  shiftSelectedFlight(2);
                  setCalendarWindowStart(2);
                }}
                style={{
                  minHeight: '44px',
                  padding: '8px 12px',
                  borderRadius: '10px',
                  backgroundColor: 'rgba(179, 40, 26, 0.35)',
                  border: `1px solid ${TOKENS.status.blocked.solid}`,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  gap: '8px',
                  cursor: 'pointer',
                  width: '100%'
                }}
              >
                <span style={{ ...TYPE.t4, color: '#FFD2CC', textAlign: 'left' }}>
                  Held by {selectedFlight.conflictHolder} (Nov 10–12)
                </span>
                <span
                  style={{
                    ...TYPE.t4,
                    color: TOKENS.textPrimary,
                    backgroundColor: TOKENS.cadmiumYellow,
                    padding: '4px 10px',
                    borderRadius: '999px',
                    flexShrink: 0
                  }}
                >
                  Shift to Nov 13 →
                </span>
              </button>
            )}
          </div>
        </div>

        <SolidBottomBar
          activeTab="calendar"
          onSelectTab={(tabId) => {
            if (tabId === 'pipeline') setActiveScreen('pipeline');
            else if (tabId === 'insights') setActiveScreen('insights');
            else if (tabId === 'activity') setActiveScreen('activity');
            else setActiveScreen('calendar');
          }}
        />
      </div>
    );
  };

  // ==========================================================================
  // FIX 2 & FIX 7: SCREENS 10 & 11 — PRE-FLIGHT PASS & BLOCKED (BOTTOM SHEETS)
  // ==========================================================================
  const renderPreFlightScreen = (forceBlocked = false) => {
    const targetVer = forceBlocked ? 'V2.0' : selectedVersionTag;
    const verObj = activeCampaign.versions[targetVer] || activeCampaign.versions['V3.0'];
    const isApproved = !forceBlocked && (verObj?.status === 'approved' || verObj?.status === 'scheduled');
    const isCurrent = !forceBlocked && targetVer === activeCampaign.version;
    const isBlocked = forceBlocked || !isApproved || !isCurrent;

    const gates = isBlocked
      ? [
          {
            title: 'Version belongs to this campaign',
            sub: `${activeCampaign.title} · ${targetVer}`,
            state: 'pass'
          },
          {
            title: `${targetVer} has not been approved. The V1.0 approval does not carry over.`,
            sub: 'SCHEDULE_BLOCKED',
            state: 'fail'
          },
          {
            title: 'This is the current version',
            sub: 'Not checked',
            state: 'muted'
          },
          {
            title: `No slot collisions on ${activeCampaign.channel}`,
            sub: 'Not checked',
            state: 'muted'
          }
        ]
      : [
          {
            title: 'Version belongs to this campaign',
            sub: `${activeCampaign.title} · ${targetVer}`,
            state: 'pass'
          },
          {
            title: 'This exact version is approved',
            sub: 'Approved by Arjun Mehta · 09:49',
            state: 'pass'
          },
          {
            title: 'This is the current version',
            sub: `HEAD == ${targetVer} verified`,
            state: 'pass'
          },
          {
            title: `No slot collisions on ${activeCampaign.channel}`,
            sub: `${activeCampaign.dates} window clear`,
            state: 'pass'
          }
        ];

    return (
      <BottomSheetScaffold
        parentTitle={activeCampaign.title}
        parentSub={`${activeCampaign.channel} · ${activeCampaign.dates}`}
        parentStatus={isBlocked ? 'blocked' : 'approved'}
        onClose={() => setActiveScreen('calendar')}
        rightAction={
          <button
            onClick={() => setActiveScreen(forceBlocked ? 'preflight_pass' : 'preflight_blocked')}
            style={{
              padding: '4px 9px',
              borderRadius: '999px',
              backgroundColor: TOKENS.surfaceRecessed,
              border: `1px solid ${TOKENS.hairline}`,
              ...TYPE.t4,
              color: TOKENS.textPrimary,
              cursor: 'pointer'
            }}
          >
            {forceBlocked ? 'View V3.0 pass' : 'Test V2.0 block'}
          </button>
        }
      >
        <div
          style={{
            padding: '16px',
            display: 'flex',
            flexDirection: 'column',
            gap: '14px',
            flex: 1,
            width: '100%',
            boxSizing: 'border-box',
            overflowY: 'auto'
          }}
        >
          <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
            <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>
              Pre-flight check for {targetVer}
            </span>
            <h1
              style={{
                ...TYPE.t1,
                color: isBlocked ? TOKENS.status.blocked.solid : TOKENS.status.approved.solid,
                margin: 0
              }}
            >
              {isBlocked ? 'Gate 2 blocked' : 'All 4 checks passed'}
            </h1>
          </div>

          <div
            style={{
              backgroundColor: TOKENS.surfaceCard,
              border: `1px solid ${TOKENS.hairline}`,
              borderRadius: '16px',
              overflow: 'hidden'
            }}
          >
            {gates.map((g, idx) => {
              const isFail = g.state === 'fail';
              const isPass = g.state === 'pass';
              return (
                <div
                  key={idx}
                  style={{
                    padding: '14px 16px',
                    backgroundColor: isFail ? TOKENS.status.blocked.chipBg : 'transparent',
                    borderBottom: idx < gates.length - 1 ? `1px solid ${TOKENS.hairline}` : 'none',
                    opacity: g.state === 'muted' ? 0.45 : 1,
                    display: 'flex',
                    alignItems: 'flex-start',
                    gap: '12px'
                  }}
                >
                  <div style={{ paddingTop: '2px' }}>
                    {isPass && <MonoIcons.Check color={TOKENS.status.approved.solid} size={15} />}
                    {isFail && <MonoIcons.Alert color={TOKENS.status.blocked.solid} size={15} />}
                    {g.state === 'muted' && <FacetCell status="brand" size={12} />}
                  </div>

                  <div style={{ display: 'flex', flexDirection: 'column', gap: '3px', flex: 1 }}>
                    <span
                      style={{
                        ...TYPE.t3,
                        fontWeight: 600,
                        color: isFail ? TOKENS.status.blocked.solid : TOKENS.textPrimary
                      }}
                    >
                      {g.title}
                    </span>
                    <span
                      style={{
                        ...TYPE.t4,
                        color: isFail ? TOKENS.status.blocked.solid : TOKENS.textSecondary
                      }}
                    >
                      {g.sub}
                    </span>
                  </div>
                </div>
              );
            })}
          </div>

          <div style={{ marginTop: 'auto', display: 'flex', flexDirection: 'column', gap: '8px' }}>
            <button
              disabled={isBlocked}
              onClick={() => commitScheduleNow(targetVer)}
              style={{
                width: '100%',
                minHeight: '48px',
                borderRadius: '999px',
                backgroundColor: isBlocked ? TOKENS.surfaceRecessed : TOKENS.inkPrussian,
                color: isBlocked ? TOKENS.textSecondary : TOKENS.labelOnInk,
                border: `1px solid ${TOKENS.hairline}`,
                ...TYPE.t2,
                cursor: isBlocked ? 'not-allowed' : 'pointer'
              }}
            >
              {isBlocked ? 'Schedule blocked' : `Schedule ${targetVer}`}
            </button>

            {isBlocked && (
              <button
                onClick={() => setActiveScreen('decision')}
                style={{
                  width: '100%',
                  minHeight: '44px',
                  borderRadius: '999px',
                  backgroundColor: TOKENS.surfaceCard,
                  color: TOKENS.inkPrussian,
                  border: `1.5px solid ${TOKENS.inkPrussian}`,
                  ...TYPE.t3,
                  fontWeight: 600,
                  cursor: 'pointer'
                }}
              >
                Review {targetVer} to unlock gate
              </button>
            )}
          </div>
        </div>
      </BottomSheetScaffold>
    );
  };

  // ==========================================================================
  // FIX 5 (P1): SCREENS 12 & 13 — SPEND LIVE & SPEND PAUSED (REASON REQUIRED)
  // ==========================================================================
  const renderSpendScreen = (isPaused = false) => {
    const totalSquares = 40;
    const ceilingIndex = 30;
    const filledSquares = isPaused ? 30 : Math.round((spendAmount / 50000) * totalSquares);

    const channelSpendRows = [
      { name: 'Social · Lookalike', cpa: isPaused ? '$24.10' : '$10.80', ratio: isPaused ? 9 : 6 },
      { name: 'Search · Brand Intent', cpa: '$11.40', ratio: 5 },
      { name: 'Display · Retargeting', cpa: isPaused ? '$38.50' : '$12.20', ratio: isPaused ? 10 : 4 }
    ];

    const handleConfirmResume = () => {
      const trimmed = resumeReason.trim();
      if (!trimmed) {
        setResumeError('Written override reason is mandatory (T-02).');
        return;
      }
      setResumeError('');
      setIsResumeReasonOpen(false);
      setAuditEvents((prev) => [
        {
          id: `ev-res-${Date.now()}`,
          time: '09:53',
          actor: viewer,
          fromState: 'blocked',
          toState: 'approved',
          transition: 'Paused → Delivery resumed',
          status: 'approved',
          category: 'Decisions',
          campaign: `${activeCampaign.title} · "${trimmed}"`,
          dna: ['approved', 'approved', 'approved', 'approved']
        },
        ...prev
      ]);
      setCommitBanner('Delivery resumed with audit reason logged.');
      setActiveScreen('spend_live');
      setTimeout(() => setCommitBanner(null), 4000);
    };

    return (
      <div style={phoneFrameStyle}>
        <div style={iosStatusBarStyle}>
          <span style={TYPE.t4}>09:41</span>
          <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>5G · 100%</span>
        </div>

        <div
          style={{
            padding: '6px 16px 10px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            borderBottom: `1px solid ${TOKENS.hairline}`
          }}
        >
          <button
            onClick={() => setActiveScreen('detail')}
            style={{
              minHeight: '34px',
              padding: '0 8px 0 0',
              backgroundColor: 'transparent',
              border: 'none',
              display: 'inline-flex',
              alignItems: 'center',
              gap: '4px',
              ...TYPE.t3,
              fontWeight: 600,
              color: TOKENS.textPrimary,
              cursor: 'pointer'
            }}
          >
            <MonoIcons.ChevronLeft color={TOKENS.textPrimary} size={15} />
            <span>{activeCampaign.title}</span>
          </button>

          <StatusBadge
            status={isPaused ? 'blocked' : 'approved'}
            customLabel={isPaused ? 'Paused at ceiling' : 'Running'}
          />
        </div>

        <div
          style={{
            padding: '14px 16px 18px',
            display: 'flex',
            flexDirection: 'column',
            gap: '14px',
            flex: 1,
            width: '100%',
            boxSizing: 'border-box',
            overflowY: 'auto'
          }}
        >
          {commitBanner && (
            <div
              style={{
                padding: '10px 12px',
                borderRadius: '12px',
                backgroundColor: TOKENS.status.approved.chipBg,
                border: `1px solid ${TOKENS.hairline}`,
                display: 'flex',
                alignItems: 'center',
                gap: '8px'
              }}
            >
              <FacetCell status="approved" size={12} />
              <span style={{ ...TYPE.t3, fontWeight: 600, color: TOKENS.status.approved.solid }}>
                {commitBanner}
              </span>
            </div>
          )}

          {isPaused && (
            <div
              style={{
                backgroundColor: TOKENS.status.blocked.chipBg,
                border: `1.5px solid ${TOKENS.status.blocked.solid}`,
                borderRadius: '12px',
                padding: '12px 14px',
                display: 'flex',
                alignItems: 'center',
                gap: '10px'
              }}
            >
              <MonoIcons.Pause color={TOKENS.status.blocked.solid} size={16} />
              <span style={{ ...TYPE.t3, fontWeight: 600, color: TOKENS.status.blocked.solid }}>
                Delivery paused automatically at the $15.00 ceiling
              </span>
            </div>
          )}

          <div
            style={{
              backgroundColor: TOKENS.surfaceCard,
              border: `1px solid ${TOKENS.hairline}`,
              borderRadius: '16px',
              padding: '16px',
              display: 'flex',
              flexDirection: 'column',
              gap: '12px'
            }}
          >
            <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
              <span
                style={{
                  ...TYPE.t1,
                  fontFamily: TOKENS.fontMono,
                  color: isPaused ? TOKENS.status.blocked.solid : TOKENS.textPrimary
                }}
              >
                CPA {isPaused ? '$15.20' : '$11.40'}
              </span>
              <span style={{ ...TYPE.t4, color: TOKENS.status.blocked.solid }}>
                Ceiling $15.00
              </span>
            </div>

            <span style={{ ...TYPE.t3, color: TOKENS.textSecondary }}>
              Spent ${isPaused ? '37,500' : spendAmount.toLocaleString()} of $50,000
            </span>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
              {[0, 20].map((rowStart) => (
                <div key={rowStart} style={{ display: 'flex', alignItems: 'center', gap: '3px' }}>
                  {Array.from({ length: 20 }).map((_, colIdx) => {
                    const cellIdx = rowStart + colIdx;
                    const isFilled = cellIdx < filledSquares;
                    const isLeading = isFilled && cellIdx >= filledSquares - 3;
                    const isCeilingTick = cellIdx === ceilingIndex;

                    return (
                      <React.Fragment key={cellIdx}>
                        {isCeilingTick && (
                          <div
                            style={{
                              width: '3px',
                              height: '18px',
                              backgroundColor: TOKENS.status.blocked.solid,
                              borderRadius: '1px',
                              margin: '0 2px',
                              flexShrink: 0
                            }}
                          />
                        )}
                        <div
                          style={{
                            flex: 1,
                            height: '12px',
                            borderRadius: '2px',
                            backgroundColor: !isFilled
                              ? TOKENS.surfaceRecessed
                              : isPaused && isLeading
                                ? TOKENS.status.blocked.solid
                                : isLeading
                                  ? TOKENS.cadmiumYellow
                                  : TOKENS.inkPrussian
                          }}
                        />
                      </React.Fragment>
                    );
                  })}
                </div>
              ))}
            </div>
          </div>

          <div
            style={{
              backgroundColor: TOKENS.surfaceCard,
              border: `1px solid ${TOKENS.hairline}`,
              borderRadius: '16px',
              overflow: 'hidden'
            }}
          >
            {channelSpendRows.map((ch, idx) => (
              <div
                key={ch.name}
                style={{
                  padding: '12px 16px',
                  borderBottom: idx < channelSpendRows.length - 1 ? `1px solid ${TOKENS.hairline}` : 'none',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '6px'
                }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span style={{ ...TYPE.t3, fontWeight: 600, color: TOKENS.textPrimary }}>{ch.name}</span>
                  <span
                    style={{
                      ...TYPE.t4,
                      color: isPaused && idx !== 1 ? TOKENS.status.blocked.solid : TOKENS.textPrimary
                    }}
                  >
                    CPA {ch.cpa}
                  </span>
                </div>
                <div style={{ display: 'flex', gap: '3px' }}>
                  {Array.from({ length: 12 }).map((_, i) => (
                    <div
                      key={i}
                      style={{
                        flex: 1,
                        height: '6px',
                        borderRadius: '1.5px',
                        backgroundColor:
                          i < ch.ratio
                            ? isPaused && idx !== 1
                              ? TOKENS.status.blocked.solid
                              : TOKENS.inkPrussian
                            : TOKENS.surfaceRecessed
                      }}
                    />
                  ))}
                </div>
              </div>
            ))}
          </div>

          {/* FIX 5: Mandatory Reason Capture Drawer before Resuming Delivery */}
          {isPaused && isResumeReasonOpen && (
            <div
              style={{
                backgroundColor: TOKENS.changedRowTint,
                border: `1.5px solid ${TOKENS.inkPrussian}`,
                borderRadius: '14px',
                padding: '12px 14px',
                display: 'flex',
                flexDirection: 'column',
                gap: '8px'
              }}
            >
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span style={{ ...TYPE.t4, color: TOKENS.inkPrussian }}>
                  Override reason (logged to Activity) *
                </span>
                <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>
                  {resumeReason.trim().length} chars
                </span>
              </div>
              <textarea
                value={resumeReason}
                onChange={(e) => setResumeReason(e.target.value)}
                rows={2}
                placeholder="Explain what corrective action was taken before resuming..."
                style={{
                  width: '100%',
                  backgroundColor: TOKENS.surfaceCard,
                  border: resumeError ? `1.5px solid ${TOKENS.status.blocked.solid}` : `1px solid ${TOKENS.hairline}`,
                  borderRadius: '8px',
                  padding: '8px 10px',
                  ...TYPE.t3,
                  color: TOKENS.textPrimary,
                  boxSizing: 'border-box',
                  resize: 'none'
                }}
              />
              {resumeError && (
                <span style={{ ...TYPE.t4, color: TOKENS.status.blocked.solid }}>{resumeError}</span>
              )}
            </div>
          )}

          <div style={{ marginTop: 'auto', display: 'flex', flexDirection: 'column', gap: '8px' }}>
            {isPaused ? (
              <>
                <button
                  onClick={() => {
                    if (!isResumeReasonOpen) setIsResumeReasonOpen(true);
                    else handleConfirmResume();
                  }}
                  style={{
                    width: '100%',
                    minHeight: '48px',
                    borderRadius: '999px',
                    backgroundColor: TOKENS.inkPrussian,
                    color: TOKENS.labelOnInk,
                    border: 'none',
                    ...TYPE.t2,
                    cursor: 'pointer'
                  }}
                >
                  {isResumeReasonOpen ? 'Confirm & resume delivery' : 'Resume delivery (reason required)'}
                </button>
                <button
                  onClick={() => setActiveScreen('studio')}
                  style={{
                    width: '100%',
                    minHeight: '42px',
                    borderRadius: '999px',
                    backgroundColor: TOKENS.surfaceCard,
                    color: TOKENS.textPrimary,
                    border: `1.5px solid ${TOKENS.inkPrussian}`,
                    ...TYPE.t3,
                    fontWeight: 600,
                    cursor: 'pointer'
                  }}
                >
                  Raise ceiling, needs review
                </button>
              </>
            ) : (
              <button
                onClick={() => setActiveScreen('spend_paused')}
                style={{
                  width: '100%',
                  minHeight: '48px',
                  borderRadius: '999px',
                  backgroundColor: TOKENS.inkPrussian,
                  color: TOKENS.labelOnInk,
                  border: 'none',
                  ...TYPE.t2,
                  cursor: 'pointer'
                }}
              >
                Pause delivery
              </button>
            )}
          </div>
        </div>
      </div>
    );
  };

  // ==========================================================================
  // SCREEN 14: INSIGHTS
  // ==========================================================================
  const renderInsightsScreen = () => {
    const points = [
      { date: 'Nov 02', spend: '$6,200', conv: '2.6%', x: 24, yProj: 82, yAct: 76 },
      { date: 'Nov 04', spend: '$10,400', conv: '2.8%', x: 84, yProj: 70, yAct: 62 },
      { date: 'Nov 06', spend: '$14,800', conv: '2.9%', x: 144, yProj: 58, yAct: 48 },
      { date: 'Nov 08', spend: '$18,100', conv: '3.0%', x: 204, yProj: 49, yAct: 36 },
      { date: 'Nov 10', spend: '$21,000', conv: '3.1%', x: 264, yProj: 40, yAct: 24 },
      { date: 'Nov 12', spend: '$25,000', conv: '3.3%', x: 318, yProj: 32, yAct: 16 }
    ];

    const activePt = points[scrubIndex] || points[4];

    const kpis = [
      { name: 'Conversion rate', val: '3.1%', delta: '+0.4%', status: 'approved' },
      { name: 'CTR', val: '2.8%', delta: '+0.2%', status: 'approved' },
      { name: 'ROI', val: '3.8x', delta: '+0.3x', status: 'approved' },
      { name: 'CPA', val: '$11.40', delta: 'Ceiling $15.00', isDarkAnchor: true },
      { name: 'AOV', val: '$62.40', delta: '+$4.10', status: 'approved' }
    ];

    return (
      <div style={phoneFrameStyle}>
        <div style={iosStatusBarStyle}>
          <span style={TYPE.t4}>09:41</span>
          <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>5G · 100%</span>
        </div>

        <div style={{ padding: '6px 16px 6px' }}>
          <h1 style={{ ...TYPE.t1, color: TOKENS.textPrimary, margin: 0 }}>Insights</h1>
        </div>

        <div
          style={{
            padding: '6px 16px 14px',
            display: 'flex',
            flexDirection: 'column',
            gap: '12px',
            flex: 1,
            overflowY: 'auto'
          }}
        >
          <div
            style={{
              backgroundColor: TOKENS.surfaceRecessed,
              borderRadius: '12px',
              padding: '3px',
              display: 'flex',
              gap: '4px',
              border: `1px solid ${TOKENS.hairline}`
            }}
          >
            {['7 days', '30 days', 'Quarter'].map((rng) => {
              const selected = insightsRange === rng;
              return (
                <button
                  key={rng}
                  onClick={() => setInsightsRange(rng)}
                  style={{
                    flex: 1,
                    minHeight: '34px',
                    borderRadius: '9px',
                    backgroundColor: selected ? TOKENS.surfaceCard : 'transparent',
                    border: selected ? `1.5px solid ${TOKENS.inkPrussian}` : 'none',
                    ...TYPE.t4,
                    color: selected ? TOKENS.textPrimary : TOKENS.textSecondary,
                    cursor: 'pointer'
                  }}
                >
                  {rng}
                </button>
              );
            })}
          </div>

          <div
            style={{
              backgroundColor: TOKENS.surfaceCard,
              border: `1px solid ${TOKENS.hairline}`,
              borderRadius: '16px',
              padding: '14px',
              display: 'flex',
              flexDirection: 'column',
              gap: '8px'
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <span style={{ ...TYPE.t4, color: TOKENS.inkPrussian }}>
                {activePt.date} · Spend {activePt.spend} · Conv {activePt.conv}
              </span>
              <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>Tap points</span>
            </div>

            <svg width="100%" height="105" viewBox="0 0 340 105" style={{ display: 'block', overflow: 'visible' }}>
              <polyline
                fill="none"
                stroke={TOKENS.textSecondary}
                strokeWidth="1.75"
                strokeDasharray="4 4"
                points={points.map((p) => `${p.x},${p.yProj}`).join(' ')}
              />
              <polyline
                fill="none"
                stroke={TOKENS.cadmiumYellow}
                strokeWidth="3"
                points={points.map((p) => `${p.x},${p.yAct}`).join(' ')}
              />
              <line
                x1={activePt.x}
                y1="6"
                x2={activePt.x}
                y2="96"
                stroke={TOKENS.inkPrussian}
                strokeWidth="1.25"
              />
              {points.map((pt, idx) => (
                <circle
                  key={pt.date}
                  cx={pt.x}
                  cy={pt.yAct}
                  r={scrubIndex === idx ? 5.5 : 3.5}
                  fill={scrubIndex === idx ? TOKENS.cadmiumYellow : TOKENS.inkPrussian}
                  stroke={TOKENS.inkPrussian}
                  strokeWidth="1.5"
                  style={{ cursor: 'pointer' }}
                  onClick={() => setScrubIndex(idx)}
                />
              ))}
            </svg>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
            {kpis.map((kpi) => {
              if (kpi.isDarkAnchor) {
                return (
                  <div
                    key={kpi.name}
                    onClick={() => setActiveScreen('spend_live')}
                    style={{
                      backgroundColor: TOKENS.inkPrussian,
                      borderRadius: '14px',
                      padding: '12px 16px',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      cursor: 'pointer'
                    }}
                  >
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
                      <span style={{ ...TYPE.t3, color: TOKENS.bgPlaster }}>CPA (Dark Anchor)</span>
                      <span style={{ ...TYPE.t4, color: TOKENS.cadmiumYellow }}>{kpi.delta}</span>
                    </div>
                    <span style={{ ...TYPE.t1, fontFamily: TOKENS.fontMono, color: TOKENS.labelOnInk }}>
                      {kpi.val}
                    </span>
                  </div>
                );
              }

              return (
                <div
                  key={kpi.name}
                  style={{
                    backgroundColor: TOKENS.surfaceCard,
                    border: `1px solid ${TOKENS.hairline}`,
                    borderRadius: '12px',
                    padding: '10px 14px',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between'
                  }}
                >
                  <span style={{ ...TYPE.t3, fontWeight: 600, color: TOKENS.textPrimary }}>{kpi.name}</span>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <span
                      style={{
                        ...TYPE.t4,
                        color: TOKENS.status.approved.solid,
                        backgroundColor: TOKENS.status.approved.chipBg,
                        padding: '2px 7px',
                        borderRadius: '999px'
                      }}
                    >
                      {kpi.delta}
                    </span>
                    <span style={{ ...TYPE.t2, fontFamily: TOKENS.fontMono, color: TOKENS.textPrimary }}>
                      {kpi.val}
                    </span>
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        <SolidBottomBar
          activeTab="insights"
          onSelectTab={(tabId) => {
            if (tabId === 'pipeline') setActiveScreen('pipeline');
            else if (tabId === 'calendar') setActiveScreen('calendar');
            else if (tabId === 'activity') setActiveScreen('activity');
            else setActiveScreen('insights');
          }}
        />
      </div>
    );
  };

  // ==========================================================================
  // SCREEN 15: ACTIVITY
  // ==========================================================================
  const renderActivityScreen = () => {
    const filteredEvents =
      activityFilter === 'All'
        ? auditEvents
        : auditEvents.filter((e) => e.category === activityFilter);

    return (
      <div style={phoneFrameStyle}>
        <div style={iosStatusBarStyle}>
          <span style={TYPE.t4}>09:41</span>
          <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>5G · 100%</span>
        </div>

        <div style={{ padding: '6px 16px 4px' }}>
          <h1 style={{ ...TYPE.t1, color: TOKENS.textPrimary, margin: 0 }}>Activity</h1>
        </div>

        <div style={{ padding: '8px 16px 8px', display: 'flex', alignItems: 'center', gap: '6px' }}>
          {['All', 'Decisions', 'Schedule', 'System'].map((tab) => {
            const isSelected = activityFilter === tab;
            return (
              <button
                key={tab}
                onClick={() => setActivityFilter(tab)}
                style={{
                  position: 'relative',
                  padding: '7px 12px 9px',
                  borderRadius: '999px',
                  backgroundColor: isSelected ? TOKENS.surfaceCard : TOKENS.surfaceRecessed,
                  border: isSelected ? `1.5px solid ${TOKENS.inkPrussian}` : `1px solid ${TOKENS.hairline}`,
                  ...TYPE.t4,
                  color: isSelected ? TOKENS.textPrimary : TOKENS.textSecondary,
                  cursor: 'pointer'
                }}
              >
                <span>{tab}</span>
                {isSelected && (
                  <span
                    style={{
                      position: 'absolute',
                      bottom: 0,
                      left: '10px',
                      right: '10px',
                      height: '2.5px',
                      backgroundColor: TOKENS.cadmiumYellow
                    }}
                  />
                )}
              </button>
            );
          })}
        </div>

        <div
          style={{
            padding: '4px 16px 16px',
            display: 'flex',
            flexDirection: 'column',
            gap: '14px',
            overflowY: 'auto',
            flex: 1,
            width: '100%',
            boxSizing: 'border-box'
          }}
        >
          <div
            style={{
              backgroundColor: TOKENS.surfaceCard,
              border: `1px solid ${TOKENS.hairline}`,
              borderRadius: '16px',
              padding: '14px 16px',
              display: 'flex',
              flexDirection: 'column',
              gap: '12px'
            }}
          >
            {filteredEvents.map((ev, idx) => {
              const isLast = idx === filteredEvents.length - 1;
              return (
                <div key={ev.id} style={{ display: 'flex', alignItems: 'stretch', gap: '12px' }}>
                  <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', paddingTop: '3px' }}>
                    <FacetCell status={ev.toState} size={12} />
                    {!isLast && (
                      <div style={{ width: '1.5px', flex: 1, minHeight: '20px', backgroundColor: TOKENS.hairline, marginTop: '4px' }} />
                    )}
                  </div>

                  <div style={{ display: 'flex', flexDirection: 'column', gap: '4px', flex: 1, paddingBottom: isLast ? 0 : '4px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                      <span style={{ ...TYPE.t3, fontWeight: 600, color: TOKENS.textPrimary }}>
                        {ev.actor}
                      </span>
                      <span style={{ ...TYPE.t4, color: TOKENS.textSecondary }}>
                        {ev.time}
                      </span>
                    </div>
                    <span style={{ ...TYPE.t3, color: TOKENS.textSecondary }}>
                      {ev.campaign}
                    </span>
                    <div style={{ paddingTop: '2px' }}>
                      <StatusBadge status={ev.status} customLabel={ev.transition} />
                    </div>
                  </div>
                </div>
              );
            })}
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
            <h2 style={{ ...TYPE.t2, color: TOKENS.textPrimary, margin: '0 2px' }}>
              Notifications
            </h2>
            <div
              style={{
                backgroundColor: TOKENS.surfaceCard,
                border: `1px solid ${TOKENS.hairline}`,
                borderRadius: '16px',
                overflow: 'hidden'
              }}
            >
              {OUTBOX_RELAYS.map((item, idx) => (
                <div
                  key={item.id}
                  style={{
                    padding: '12px 16px',
                    display: 'flex',
                    flexDirection: 'column',
                    gap: '6px',
                    borderBottom: idx < OUTBOX_RELAYS.length - 1 ? `1px solid ${TOKENS.hairline}` : 'none'
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                    <span style={{ ...TYPE.t3, fontWeight: 600, color: TOKENS.textPrimary }}>
                      {item.label}
                    </span>
                    <StatusBadge status={item.status} customLabel={item.chipText} />
                  </div>

                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                    <span style={{ ...TYPE.t3, color: TOKENS.textSecondary }}>
                      {item.sub}
                    </span>
                    <div style={{ display: 'inline-flex', alignItems: 'center', gap: '3px' }}>
                      {item.attemptCells.map((cState, cIdx) => (
                        <div
                          key={cIdx}
                          style={{
                            width: '8px',
                            height: '8px',
                            borderRadius: '2px',
                            backgroundColor:
                              cState === 'approved'
                                ? TOKENS.status.approved.solid
                                : cState === 'changes'
                                  ? TOKENS.cadmiumYellow
                                  : cState === 'blocked'
                                    ? TOKENS.status.blocked.solid
                                    : TOKENS.surfaceRecessed
                          }}
                        />
                      ))}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <p style={{ ...TYPE.t3, color: TOKENS.textSecondary, margin: '0 2px', maxWidth: '44ch', textAlign: 'left' }}>
            The audit trail is append-only.
          </p>
        </div>

        <SolidBottomBar
          activeTab="activity"
          onSelectTab={(tabId) => {
            if (tabId === 'pipeline') setActiveScreen('pipeline');
            else if (tabId === 'calendar') setActiveScreen('calendar');
            else if (tabId === 'insights') setActiveScreen('insights');
            else setActiveScreen('activity');
          }}
        />
      </div>
    );
  };

  return (
    <div
      style={{
        minHeight: '100vh',
        backgroundColor: '#E5E2DA',
        fontFamily: TOKENS.fontSans,
        color: TOKENS.textPrimary,
        padding: '20px 16px 44px',
        boxSizing: 'border-box',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: '18px'
      }}
    >
      <div
        style={{
          width: '100%',
          maxWidth: '1320px',
          backgroundColor: TOKENS.surfaceCard,
          border: `1px solid ${TOKENS.hairline}`,
          borderRadius: '16px',
          padding: '12px 16px',
          display: 'flex',
          flexWrap: 'wrap',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: '10px',
          boxSizing: 'border-box'
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <FacetCell status="brand" size={20} />
          <div>
            <div style={{ ...TYPE.t2, color: TOKENS.textPrimary }}>
              Campaign Grid — Complete End-to-End Application (All Audit Fixes Verified)
            </div>
            <div style={{ ...TYPE.t3, color: TOKENS.textSecondary }}>
              P0 Studio & Conflict Wired · P1 Unified State & Role Gates · P2 5-Day Calendar & Bottom-Sheet Scaffolds
            </div>
          </div>
        </div>

        <div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: '8px' }}>
          <div
            style={{
              backgroundColor: TOKENS.surfaceRecessed,
              borderRadius: '999px',
              padding: '3px',
              display: 'flex',
              border: `1px solid ${TOKENS.hairline}`
            }}
          >
            {[
              { id: 'Arjun Mehta', label: 'Arjun Mehta (Reviewer)' },
              { id: 'Riya Sen', label: 'Riya Sen (Owner)' }
            ].map((p) => {
              const active = viewer === p.id;
              return (
                <button
                  key={p.id}
                  onClick={() => {
                    setViewer(p.id);
                    if (activeScreen === 'decision' && p.id === 'Riya Sen') setActiveScreen('blocked');
                    if (activeScreen === 'blocked' && p.id === 'Arjun Mehta') setActiveScreen('decision');
                  }}
                  style={{
                    padding: '5px 11px',
                    borderRadius: '999px',
                    backgroundColor: active ? TOKENS.surfaceCard : 'transparent',
                    border: active ? `1.5px solid ${TOKENS.inkPrussian}` : 'none',
                    ...TYPE.t4,
                    color: active ? TOKENS.textPrimary : TOKENS.textSecondary,
                    cursor: 'pointer'
                  }}
                >
                  {p.label}
                </button>
              );
            })}
          </div>

          <div
            style={{
              backgroundColor: TOKENS.surfaceRecessed,
              borderRadius: '999px',
              padding: '3px',
              display: 'flex',
              border: `1px solid ${TOKENS.hairline}`
            }}
          >
            <button
              onClick={() => setViewMode('interactive')}
              style={{
                padding: '5px 12px',
                borderRadius: '999px',
                backgroundColor: viewMode === 'interactive' ? TOKENS.inkPrussian : 'transparent',
                color: viewMode === 'interactive' ? TOKENS.labelOnInk : TOKENS.textSecondary,
                border: 'none',
                ...TYPE.t4,
                cursor: 'pointer'
              }}
            >
              Interactive iPhone (390×844)
            </button>
            <button
              onClick={() => setViewMode('grid')}
              style={{
                padding: '5px 12px',
                borderRadius: '999px',
                backgroundColor: viewMode === 'grid' ? TOKENS.inkPrussian : 'transparent',
                color: viewMode === 'grid' ? TOKENS.labelOnInk : TOKENS.textSecondary,
                border: 'none',
                ...TYPE.t4,
                cursor: 'pointer'
              }}
            >
              All 15 Stitch Screens Grid
            </button>
          </div>
        </div>

        {viewMode === 'interactive' && (
          <div
            style={{
              width: '100%',
              paddingTop: '8px',
              borderTop: `1px solid ${TOKENS.hairline}`,
              display: 'flex',
              flexWrap: 'wrap',
              alignItems: 'center',
              gap: '6px'
            }}
          >
            {[
              { id: 'pipeline', label: '01 Pipeline' },
              { id: 'detail', label: '02 Detail' },
              { id: 'diff', label: '03 Diff' },
              { id: 'decision', label: '04 Decision' },
              { id: 'blocked', label: '05 Blocked' },
              { id: 'studio', label: '06 Proposal Studio' },
              { id: 'submit_progress', label: '07 Submit in progress' },
              { id: 'conflict', label: '08 Stale conflict' },
              { id: 'calendar', label: '09 Calendar' },
              { id: 'preflight_pass', label: '10 Pre-flight pass' },
              { id: 'preflight_blocked', label: '11 Pre-flight blocked' },
              { id: 'spend_live', label: '12 Spend live' },
              { id: 'spend_paused', label: '13 Spend paused' },
              { id: 'insights', label: '14 Insights' },
              { id: 'activity', label: '15 Activity' }
            ].map((scr) => {
              const active = activeScreen === scr.id;
              return (
                <button
                  key={scr.id}
                  onClick={() => setActiveScreen(scr.id)}
                  style={{
                    padding: '5px 10px',
                    borderRadius: '999px',
                    backgroundColor: active ? TOKENS.inkPrussian : TOKENS.surfaceRecessed,
                    color: active ? TOKENS.labelOnInk : TOKENS.textPrimary,
                    border: `1px solid ${TOKENS.hairline}`,
                    ...TYPE.t4,
                    cursor: 'pointer'
                  }}
                >
                  {scr.label}
                </button>
              );
            })}
          </div>
        )}
      </div>

      {viewMode === 'interactive' && (
        <div style={{ display: 'flex', justifyContent: 'center', width: '100%' }}>
          {activeScreen === 'pipeline' && renderPipelineScreen()}
          {activeScreen === 'detail' && renderCampaignDetailScreen()}
          {activeScreen === 'diff' && renderDiffScreen()}
          {activeScreen === 'decision' && renderDecisionSheetScreen()}
          {activeScreen === 'blocked' && renderDecisionBlockedScreen()}
          {activeScreen === 'studio' && renderProposalStudioScreen(false)}
          {activeScreen === 'submit_progress' && renderProposalStudioScreen(true)}
          {activeScreen === 'conflict' && renderConflictScreen()}
          {activeScreen === 'calendar' && renderCalendarScreen()}
          {activeScreen === 'preflight_pass' && renderPreFlightScreen(false)}
          {activeScreen === 'preflight_blocked' && renderPreFlightScreen(true)}
          {activeScreen === 'spend_live' && renderSpendScreen(false)}
          {activeScreen === 'spend_paused' && renderSpendScreen(true)}
          {activeScreen === 'insights' && renderInsightsScreen()}
          {activeScreen === 'activity' && renderActivityScreen()}
        </div>
      )}

      {viewMode === 'grid' && (
        <div
          style={{
            width: '100%',
            maxWidth: '1320px',
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fill, minmax(390px, 1fr))',
            gap: '24px',
            justifyItems: 'center'
          }}
        >
          <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
            <span style={{ ...TYPE.t2, color: TOKENS.textPrimary }}>01 · Pipeline</span>
            {renderPipelineScreen()}
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
            <span style={{ ...TYPE.t2, color: TOKENS.textPrimary }}>02 · Campaign Detail</span>
            {renderCampaignDetailScreen()}
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
            <span style={{ ...TYPE.t2, color: TOKENS.textPrimary }}>03 · Diff (V2.0 to V3.0)</span>
            {renderDiffScreen()}
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
            <span style={{ ...TYPE.t2, color: TOKENS.textPrimary }}>04 · Decision Sheet</span>
            {renderDecisionSheetScreen()}
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
            <span style={{ ...TYPE.t2, color: TOKENS.textPrimary }}>05 · Decision Blocked</span>
            {renderDecisionBlockedScreen()}
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
            <span style={{ ...TYPE.t2, color: TOKENS.textPrimary }}>06 · Proposal Studio</span>
            {renderProposalStudioScreen(false)}
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
            <span style={{ ...TYPE.t2, color: TOKENS.textPrimary }}>07 · Submit In Progress</span>
            {renderProposalStudioScreen(true)}
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
            <span style={{ ...TYPE.t2, color: TOKENS.textPrimary }}>08 · Stale-Save Conflict</span>
            {renderConflictScreen()}
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
            <span style={{ ...TYPE.t2, color: TOKENS.textPrimary }}>09 · Calendar</span>
            {renderCalendarScreen()}
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
            <span style={{ ...TYPE.t2, color: TOKENS.textPrimary }}>10 · Pre-Flight Pass</span>
            {renderPreFlightScreen(false)}
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
            <span style={{ ...TYPE.t2, color: TOKENS.textPrimary }}>11 · Pre-Flight Blocked</span>
            {renderPreFlightScreen(true)}
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
            <span style={{ ...TYPE.t2, color: TOKENS.textPrimary }}>12 · Spend Live</span>
            {renderSpendScreen(false)}
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
            <span style={{ ...TYPE.t2, color: TOKENS.textPrimary }}>13 · Spend Paused</span>
            {renderSpendScreen(true)}
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
            <span style={{ ...TYPE.t2, color: TOKENS.textPrimary }}>14 · Insights</span>
            {renderInsightsScreen()}
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
            <span style={{ ...TYPE.t2, color: TOKENS.textPrimary }}>15 · Activity</span>
            {renderActivityScreen()}
          </div>
        </div>
      )}
    </div>
  );
}

const phoneFrameStyle = {
  width: '390px',
  height: '844px',
  backgroundColor: TOKENS.bgPlaster,
  border: `1.5px solid ${TOKENS.hairline}`,
  borderRadius: '32px',
  overflow: 'hidden',
  display: 'flex',
  flexDirection: 'column',
  position: 'relative',
  boxSizing: 'border-box',
  boxShadow: 'none'
};

const iosStatusBarStyle = {
  padding: '10px 20px 4px',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'space-between',
  color: TOKENS.textPrimary,
  flexShrink: 0
};