import React, { useState, useEffect, useRef } from 'react';
import {
  ArrowUpRight,
  Check,
  ShieldCheck,
  Lock,
  Sparkles,
  Layers,
  Clock,
  AlertTriangle,
  X,
  Eye,
  Grid,
  Terminal,
  Smartphone,
  Download,
  Share2
} from 'lucide-react';

// ---------------------------------------------------------------------------
// VERSION LINEAGE SPECIMEN DATA (CONCISE, GALLERY-GRADE)
// ---------------------------------------------------------------------------
const SPECIMEN_NODES = [
  {
    id: 'V1',
    version: 'Version 1.0',
    title: 'Initial Festive Baseline',
    badge: 'Superseded',
    tone: 'slate',
    budget: '$38,000',
    channel: 'Paid Search',
    reviewer: 'Ananya Rao',
    scheduleState: 'Archived — Replaced by V3.0',
    reason: 'Target audience and $11.50 CPA ceiling verified for Q4 metro launch.'
  },
  {
    id: 'V2',
    version: 'Version 2.0',
    title: 'Unfiltered Expansion',
    badge: 'Rejected',
    tone: 'terracotta',
    budget: '$82,000',
    channel: 'Paid Search',
    reviewer: 'Vikram Mehta',
    scheduleState: 'Blocked — Rejected Decision',
    reason: 'Doubling budget while removing metro audience filters violates margin policy.'
  },
  {
    id: 'V3',
    version: 'Version 3.0',
    title: 'Sovereign Gold Launch',
    badge: 'Live on Calendar',
    tone: 'green',
    budget: '$44,000',
    channel: 'Paid Search · Nov 1–14',
    reviewer: 'Ananya Rao',
    scheduleState: 'Locked on Calendar (active_version_id)',
    reason: 'Restored high-intent metro audience and brought spend under the $50k threshold.'
  },
  {
    id: 'V3_1',
    version: 'Version 3.1',
    title: 'Exploratory Copy Sandbox',
    badge: 'Staged Draft',
    tone: 'cobalt',
    budget: '$44,000',
    channel: 'Staged in Sandbox',
    reviewer: 'Uncommitted Draft',
    scheduleState: 'Isolated (draft_version_id) — V3.0 Undisturbed',
    reason: 'Testing headline copy in an isolated sandbox without unlocking Version 3.0.'
  }
];

// ---------------------------------------------------------------------------
// CONCISE 15-ADR SUMMARY FOR OPTIONAL MODAL DRAWER
// ---------------------------------------------------------------------------
const ADR_LEDGER = [
  { id: '001', title: 'Modular Monolith & Async Workers', area: 'ACID Transactions' },
  { id: '002', title: 'Orthogonal Operational vs. Version State', area: 'Approval Integrity' },
  { id: '003', title: 'PostgreSQL Deferred & Composite DDL', area: 'Relational Safety' },
  { id: '004', title: 'Transactional Outbox with SKIP LOCKED', area: 'Zero Duplicate Alerts' },
  { id: '005', title: 'Client-Supplied Idempotency Keys', area: 'Network Retry Safety' },
  { id: '006', title: 'Heartbeat Leases & 15s Draft Buffers', area: 'Zero Work Loss' },
  { id: '007', title: 'Multi-Tiered Budget Threshold RBAC', area: 'Separation of Duties' },
  { id: '008', title: 'Append-Only Audit & Anchored Threads', area: 'Non-Repudiation' },
  { id: '009', title: 'Snapshot-Bound AI & Rule Fallbacks', area: 'Resilience' },
  { id: '010', title: 'Unified Decision REST Resource', area: 'Ordered Validation' },
  { id: '011', title: 'Read-Replica & Materialized 5-KPIs', area: 'OLTP Isolation' },
  { id: '012', title: 'GiST TSTZRANGE Calendar Exclusions', area: 'Collision Prevention' },
  { id: '013', title: 'Staging Sandboxes & Semantic Diffing', area: 'Queue Continuity' },
  { id: '014', title: 'Real-Time CPA Spend Circuit Breakers', area: 'Automated Halts' },
  { id: '015', title: 'Anti-Starvation Priority Queue Aging', area: 'Fairness & Triage' }
];

// ---------------------------------------------------------------------------
// HERO PROCEDURAL HALFTONE DOT PRINT SCHEMATIC CANVAS (VERSION LINEAGE)
// ---------------------------------------------------------------------------
function HeroHalftoneCanvas({ selectedNodeId, onSelectNode }) {
  const canvasRef = useRef(null);
  const isVisibleRef = useRef(true);
  const mousePosRef = useRef({
    x: -999,
    y: -999,
    smoothX: -999,
    smoothY: -999,
    active: false
  });

  // Normalized node anchors (0..1)
  const LINEAGE_NODES = [
    { id: 'V1', label: 'V1.0', title: 'Baseline', nx: 0.18, ny: 0.50, color: '#545B6B', budget: '$38k' },
    { id: 'V2', label: 'V2.0', title: 'Rejected', nx: 0.42, ny: 0.78, color: '#D85A32', budget: '$82k' },
    { id: 'V3', label: 'V3.0', title: 'Live (Locked)', nx: 0.65, ny: 0.50, color: '#1E6B52', budget: '$44k' },
    { id: 'V3_1', label: 'V3.1', title: 'Sandbox Draft', nx: 0.86, ny: 0.24, color: '#0D47A1', budget: '$44k' }
  ];

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    let animId;
    let time = 0;

    const observer = new IntersectionObserver(([entry]) => {
      isVisibleRef.current = entry.isIntersecting;
      if (entry.isIntersecting && !animId) {
        animId = requestAnimationFrame(render);
      }
    }, { threshold: 0.05 });
    observer.observe(canvas);

    function distToSegment(px, py, x0, y0, x1, y1) {
      const dx = x1 - x0;
      const dy = y1 - y0;
      const lenSq = dx * dx + dy * dy;
      if (lenSq === 0) return { dist: Math.hypot(px - x0, py - y0), t: 0 };
      let t = ((px - x0) * dx + (py - y0) * dy) / lenSq;
      t = Math.max(0, Math.min(1, t));
      return { dist: Math.hypot(px - (x0 + t * dx), py - (y0 + t * dy)), t };
    }

    function distToQuad(px, py, x0, y0, cx, cy, x1, y1) {
      let minDist = Infinity;
      let bestT = 0;
      for (let i = 0; i <= 8; i++) {
        const t = i / 8;
        const it = 1 - t;
        const qx = it * it * x0 + 2 * it * t * cx + t * t * x1;
        const qy = it * it * y0 + 2 * it * t * cy + t * t * y1;
        const d = Math.hypot(px - qx, py - qy);
        if (d < minDist) {
          minDist = d;
          bestT = t;
        }
      }
      return { dist: minDist, t: bestT };
    }

    const render = () => {
      if (!isVisibleRef.current) {
        animId = null;
        return;
      }
      animId = requestAnimationFrame(render);

      time += 0.016; // Fluid temporal cadence for version conduits & node ripples
      const dpr = Math.min(window.devicePixelRatio || 1, 2.0);
      const width = canvas.clientWidth;
      const height = canvas.clientHeight;
      if (canvas.width !== Math.floor(width * dpr) || canvas.height !== Math.floor(height * dpr)) {
        canvas.width = Math.floor(width * dpr);
        canvas.height = Math.floor(height * dpr);
      }
      ctx.save();
      ctx.scale(dpr, dpr);

      // Warm limestone paper base
      ctx.fillStyle = '#EDE9DF';
      ctx.fillRect(0, 0, width, height);

      // Smooth mouse lerping for quiet, silky 60 FPS motion
      const mouse = mousePosRef.current;
      if (mouse.active) {
        if (mouse.smoothX < 0) {
          mouse.smoothX = mouse.x;
          mouse.smoothY = mouse.y;
        } else {
          mouse.smoothX += (mouse.x - mouse.smoothX) * 0.35;
          mouse.smoothY += (mouse.y - mouse.smoothY) * 0.35;
        }
      } else {
        mouse.smoothX = -999;
        mouse.smoothY = -999;
      }

      // Halftone dot grid spacing (10.5 for crisp architectural density)
      const step = 10.5;

      // Node coordinate positions in current canvas dimensions
      const p1 = { x: width * 0.18, y: height * 0.50 };
      const p2 = { x: width * 0.42, y: height * 0.78 };
      const p3 = { x: width * 0.65, y: height * 0.50 };
      const p3_1 = { x: width * 0.86, y: height * 0.24 };

      // Quadratic curve control points
      const c2 = { x: width * 0.28, y: height * 0.78 }; // V1 -> V2 detour curve
      const c3 = { x: width * 0.74, y: height * 0.24 }; // V3 -> V3.1 sandbox curve

      // Pre-allocated batched Path2D buckets for authentic spot pigment printing
      const pathSlate = new Path2D();
      const pathEmerald = new Path2D();
      const pathTerracotta = new Path2D();
      const pathCobalt = new Path2D();

      const hasMouse = mouse.active && mouse.smoothX > 0;
      const mX = mouse.smoothX;
      const mY = mouse.smoothY;

      for (let y = step / 2; y < height; y += step) {
        const ny = y / height;

        for (let x = step / 2; x < width; x += step) {
          const nx = x / width;

          // 1. Lineage Conduits Proximity
          const sMain = distToSegment(x, y, p1.x, p1.y, p3.x, p3.y);
          const qDetour = distToQuad(x, y, p1.x, p1.y, c2.x, c2.y, p2.x, p2.y);
          const qSandbox = distToQuad(x, y, p3.x, p3.y, c3.x, c3.y, p3_1.x, p3_1.y);

          // 2. Node Radial Proximity
          const dV1 = Math.hypot(x - p1.x, y - p1.y);
          const dV2 = Math.hypot(x - p2.x, y - p2.y);
          const dV3 = Math.hypot(x - p3.x, y - p3.y);
          const dV3_1 = Math.hypot(x - p3_1.x, y - p3_1.y);

          // 3. Base Halftone Architectural Grid Field (Delicate paper grain)
          const topoWave = Math.sin(nx * 4.5 + time * 0.3) * Math.cos(ny * 3.5 - time * 0.25) * 0.04;
          let intensity = Math.max(0.06, 0.08 + topoWave);
          let targetBucket = 'slate';

          // 4. Main Highway (V1.0 -> V3.0): Energetic traveling pulse along the pipeline
          if (sMain.dist < 32) {
            const factor = Math.cos((sMain.dist / 32) * (Math.PI / 2));
            const pulse = 0.5 + 0.5 * Math.sin(sMain.t * 14 - time * 4.0);
            const isMainActive = selectedNodeId === 'V3' || selectedNodeId === 'V1';
            const weight = (isMainActive ? 0.78 : 0.48) * factor * (0.8 + 0.4 * pulse);
            intensity = Math.max(intensity, weight);
            targetBucket = sMain.t > 0.45 ? 'emerald' : 'slate';
          }

          // 5. Rejected Detour (V1.0 -> V2.0): Traveling warning pulse along detour spur
          if (qDetour.dist < 26) {
            const factor = Math.cos((qDetour.dist / 26) * (Math.PI / 2));
            const pulse = 0.5 + 0.5 * Math.sin(qDetour.t * 12 - time * 3.2);
            const isDetourActive = selectedNodeId === 'V2';
            const weight = (isDetourActive ? 0.85 : 0.45) * factor * (0.7 + 0.5 * pulse);
            if (weight > intensity) {
              intensity = weight;
              targetBucket = 'terracotta';
            }
          }

          // 6. Staged Draft Sandbox Loop (V3.0 -> V3.1): Traveling sandbox staging pulse
          if (qSandbox.dist < 26) {
            const factor = Math.cos((qSandbox.dist / 26) * (Math.PI / 2));
            const pulse = 0.5 + 0.5 * Math.sin(qSandbox.t * 12 - time * 3.5);
            const isSandboxActive = selectedNodeId === 'V3_1';
            const weight = (isSandboxActive ? 0.85 : 0.45) * factor * (0.7 + 0.5 * pulse);
            if (weight > intensity) {
              intensity = weight;
              targetBucket = 'cobalt';
            }
          }

          // 7. Concentric Ripple Orbits around Lineage Nodes (Active beacons of data)
          if (dV1 < 46) {
            const factor = Math.max(0, 1 - dV1 / 46);
            const ring = 0.5 + 0.5 * Math.cos(dV1 * 0.22 - time * 3.0);
            const nodeWeight = factor * (selectedNodeId === 'V1' ? 0.9 : 0.46) * ring;
            if (nodeWeight > intensity) {
              intensity = nodeWeight;
              targetBucket = 'slate';
            }
          }

          if (dV2 < 46) {
            const factor = Math.max(0, 1 - dV2 / 46);
            const ring = 0.5 + 0.5 * Math.cos(dV2 * 0.22 - time * 3.0);
            const nodeWeight = factor * (selectedNodeId === 'V2' ? 0.95 : 0.48) * ring;
            if (nodeWeight > intensity) {
              intensity = nodeWeight;
              targetBucket = 'terracotta';
            }
          }

          if (dV3 < 50) {
            const factor = Math.max(0, 1 - dV3 / 50);
            const ring = 0.5 + 0.5 * Math.cos(dV3 * 0.22 - time * 3.0);
            const nodeWeight = factor * (selectedNodeId === 'V3' ? 0.96 : 0.52) * ring;
            if (nodeWeight > intensity) {
              intensity = nodeWeight;
              targetBucket = 'emerald';
            }
          }

          if (dV3_1 < 46) {
            const factor = Math.max(0, 1 - dV3_1 / 46);
            const ring = 0.5 + 0.5 * Math.cos(dV3_1 * 0.22 - time * 3.0);
            const nodeWeight = factor * (selectedNodeId === 'V3_1' ? 0.95 : 0.48) * ring;
            if (nodeWeight > intensity) {
              intensity = nodeWeight;
              targetBucket = 'cobalt';
            }
          }

          // 8. Subtle, elegant magnifying glass hover effect (tight 65px radius, gentle 2.2px micro-deflection)
          let px = x;
          let py = y;
          let loupeScale = 1.0;

          if (hasMouse) {
            const dx = x - mX;
            const dy = y - mY;
            const dist = Math.hypot(dx, dy);
            const zone = 65; // Compact, focused reading loupe
            if (dist < zone) {
              const factor = Math.cos((dist / zone) * (Math.PI / 2));
              // Gentle 2.2px micro-deflection for smooth tactile breathing
              const push = factor * 2.2;
              if (dist > 0.01) {
                px += (dx / dist) * push;
                py += (dy / dist) * push;
              }
              // Quiet magnification from 1.0x to 1.32x (no giant exploding blobs)
              loupeScale = 1.0 + factor * 0.32;
              intensity = Math.min(0.92, intensity + factor * 0.14);
            }
          }

          // Compute final Halftone Dot Radius (clean, consistent architectural sizing)
          const radius = Math.max(0.75, intensity * (step * 0.43) * loupeScale);

          // Add to respective Path2D bucket
          if (targetBucket === 'emerald') {
            pathEmerald.moveTo(px + radius, py);
            pathEmerald.arc(px, py, radius, 0, Math.PI * 2);
          } else if (targetBucket === 'terracotta') {
            pathTerracotta.moveTo(px + radius, py);
            pathTerracotta.arc(px, py, radius, 0, Math.PI * 2);
          } else if (targetBucket === 'cobalt') {
            pathCobalt.moveTo(px + radius, py);
            pathCobalt.arc(px, py, radius, 0, Math.PI * 2);
          } else {
            pathSlate.moveTo(px + radius, py);
            pathSlate.arc(px, py, radius, 0, Math.PI * 2);
          }
        }
      }

      // Execute 4 batched pigment plate draw calls
      ctx.globalAlpha = 0.88;

      ctx.fillStyle = '#545B6B';
      ctx.fill(pathSlate);

      ctx.fillStyle = '#1E6B52';
      ctx.fill(pathEmerald);

      ctx.fillStyle = '#D85A32';
      ctx.fill(pathTerracotta);

      ctx.fillStyle = '#0D47A1';
      ctx.fill(pathCobalt);

      // 9. Minimal, elegant reading lens outline (subtle hairline ring, uncluttered)
      if (hasMouse) {
        ctx.save();
        ctx.strokeStyle = 'rgba(17, 22, 34, 0.16)';
        ctx.lineWidth = 0.8;
        ctx.beginPath();
        ctx.arc(mX, mY, 32, 0, Math.PI * 2);
        ctx.stroke();
        ctx.restore();
      }

      // 10. Clean architectural typography & animated radar beacon for active node
      LINEAGE_NODES.forEach((node) => {
        const nx = node.nx * width;
        const ny = node.ny * height;
        const isSelected = node.id === selectedNodeId;

        // Animated Radar Beacon for the Active Selected Node
        if (isSelected) {
          const beaconCycle = (time * 1.5) % 1;
          const beaconR = 12 + beaconCycle * 22;
          const beaconAlpha = (1 - beaconCycle) * 0.85;
          ctx.save();
          ctx.strokeStyle = node.color;
          ctx.lineWidth = 1.8;
          ctx.globalAlpha = beaconAlpha;
          ctx.beginPath();
          ctx.arc(nx, ny, beaconR, 0, Math.PI * 2);
          ctx.stroke();
          ctx.restore();
        }

        // Clean Station Point Anchor
        ctx.save();
        ctx.fillStyle = '#EDE9DF';
        ctx.strokeStyle = node.color;
        ctx.lineWidth = isSelected ? 2.8 : 1.8;
        ctx.beginPath();
        ctx.arc(nx, ny, isSelected ? 8 : 6, 0, Math.PI * 2);
        ctx.fill();
        ctx.stroke();

        ctx.fillStyle = node.color;
        ctx.beginPath();
        ctx.arc(nx, ny, isSelected ? 4 : 3, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();

        // Minimal, quiet text label without heavy box outlines
        const textY = node.id === 'V3_1' ? ny - 24 : ny + 14;
        ctx.save();
        ctx.font = isSelected
          ? '600 11px "JetBrains Mono", monospace'
          : '500 11px "JetBrains Mono", monospace';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'top';
        ctx.fillStyle = isSelected ? '#111622' : '#545B6B';
        ctx.globalAlpha = isSelected ? 1.0 : 0.8;
        ctx.fillText(`${node.label} · ${node.title}`, nx, textY);
        ctx.restore();
      });

      ctx.restore();
    };

    animId = requestAnimationFrame(render);
    return () => {
      observer.disconnect();
      if (animId) cancelAnimationFrame(animId);
    };
  }, [selectedNodeId]);

  // Pointer event handlers directly on canvas
  const handlePointerMove = (e) => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    mousePosRef.current.x = x;
    mousePosRef.current.y = y;
    mousePosRef.current.active = true;

    // Check if hovering near a node for pointer cursor
    const width = canvas.clientWidth;
    const height = canvas.clientHeight;
    let nearNode = false;
    LINEAGE_NODES.forEach((n) => {
      const nx = n.nx * width;
      const ny = n.ny * height;
      if (Math.hypot(x - nx, y - ny) < 36) {
        nearNode = true;
      }
    });
    canvas.style.cursor = nearNode ? 'pointer' : 'default';
  };

  const handlePointerLeave = () => {
    mousePosRef.current.active = false;
  };

  const handlePointerDown = (e) => {
    const canvas = canvasRef.current;
    if (!canvas || !onSelectNode) return;
    const rect = canvas.getBoundingClientRect();
    const clickX = e.clientX - rect.left;
    const clickY = e.clientY - rect.top;
    const width = canvas.clientWidth;
    const height = canvas.clientHeight;

    // Check if clicked near any node to select it
    LINEAGE_NODES.forEach((node) => {
      const nx = node.nx * width;
      const ny = node.ny * height;
      const dist = Math.hypot(clickX - nx, clickY - ny);
      if (dist < 40) {
        onSelectNode(node.id);
      }
    });
  };

  return (
    <canvas
      ref={canvasRef}
      onPointerMove={handlePointerMove}
      onPointerDown={handlePointerDown}
      onPointerLeave={handlePointerLeave}
      className="w-full h-full block touch-none"
    />
  );
}

// ---------------------------------------------------------------------------
// MASTERWORK CELESTIAL & COASTAL HALFTONE PANORAMA (JAPANESE WOODBLOCK & UKIYO-E FUSION)
// ---------------------------------------------------------------------------
const CELESTIAL_STARS = [
  { nx: 0.06, ny: 0.10, r: 1.3, phase: 0.2 },
  { nx: 0.13, ny: 0.06, r: 1.9, phase: 1.5, spike: true },
  { nx: 0.21, ny: 0.15, r: 1.2, phase: 2.8 },
  { nx: 0.27, ny: 0.08, r: 1.5, phase: 0.9 },
  { nx: 0.34, ny: 0.14, r: 1.1, phase: 3.2 },
  { nx: 0.41, ny: 0.07, r: 2.0, phase: 2.1, spike: true },
  { nx: 0.48, ny: 0.17, r: 1.3, phase: 1.1 },
  { nx: 0.54, ny: 0.09, r: 1.4, phase: 0.4 },
  { nx: 0.61, ny: 0.05, r: 1.2, phase: 2.7 },
  { nx: 0.67, ny: 0.13, r: 1.6, phase: 1.8 },
  { nx: 0.86, ny: 0.07, r: 1.5, phase: 0.7 },
  { nx: 0.92, ny: 0.14, r: 1.9, phase: 3.4, spike: true },
  { nx: 0.97, ny: 0.09, r: 1.2, phase: 1.2 },
  { nx: 0.10, ny: 0.22, r: 1.1, phase: 2.5 },
  { nx: 0.25, ny: 0.21, r: 1.3, phase: 0.8 },
  { nx: 0.44, ny: 0.24, r: 1.0, phase: 3.0 },
  { nx: 0.63, ny: 0.21, r: 1.2, phase: 1.6 },
  { nx: 0.89, ny: 0.23, r: 1.4, phase: 2.2 },
];

function CoastalHalftonePanorama({ mouseRef }) {
  const canvasRef = useRef(null);
  const internalMouseRef = useRef({ x: -999, y: -999, active: false });

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    let animId = null;
    let time = 0;
    let isVisible = true;

    // IntersectionObserver to only animate when in viewport (saves GPU & battery)
    const observer = new IntersectionObserver(([entry]) => {
      isVisible = entry.isIntersecting;
      if (isVisible && !animId) {
        animId = requestAnimationFrame(render);
      }
    });
    observer.observe(canvas);

    const render = () => {
      if (!isVisible) {
        animId = null;
        return;
      }
      time += 0.016;

      const dpr = Math.min(window.devicePixelRatio || 1, 2.0);
      const w = canvas.clientWidth;
      const h = canvas.clientHeight;
      if (!w || !h) {
        animId = requestAnimationFrame(render);
        return;
      }

      if (canvas.width !== Math.floor(w * dpr) || canvas.height !== Math.floor(h * dpr)) {
        canvas.width = Math.floor(w * dpr);
        canvas.height = Math.floor(h * dpr);
      }

      ctx.save();
      ctx.scale(dpr, dpr);

      // Deep Nocturnal Midnight Ultramarine Base
      ctx.fillStyle = '#061325';
      ctx.fillRect(0, 0, w, h);

      // Printmaking Halftone Pitch
      const step = 5.2;

      // Pointer resolution
      const activeMouse = mouseRef?.current || internalMouseRef.current;
      const mouseX = activeMouse.x;
      const mouseY = activeMouse.y;
      const hasMouse = mouseX > -900;

      // 12 Classical Woodblock & Copperplate Pigment Buckets
      const pathMoonCore = new Path2D();       // #FFFBEA
      const pathGoldGlint = new Path2D();      // #F0B323
      const pathChampagne = new Path2D();      // #EAD8AE
      const pathSeafoam = new Path2D();        // #E6F2FC
      const pathTerracotta = new Path2D();     // #D96B3D
      const pathRidgeShadow = new Path2D();    // #702611
      const pathAzureWave = new Path2D();      // #5A8FC8
      const pathOceanDeep = new Path2D();      // #143562
      const pathBasaltRock = new Path2D();     // #22344A
      const pathPineDark = new Path2D();       // #0D1C15
      const pathDuneSand = new Path2D();       // #CEBA8C
      const pathDuneShadow = new Path2D();     // #826B42

      // Pre-compute 1D landscape column profiles
      const cols = [];
      for (let x = step / 2; x < w; x += step) {
        const nx = x / w;

        // Distant majestic alpine crests
        const alpineY = 0.38 - 0.20 * Math.exp(-Math.pow((nx - 0.52) * 5.0, 2))
                             - 0.15 * Math.exp(-Math.pow((nx - 0.74) * 6.2, 2))
                             + 0.02 * Math.sin(nx * 32);

        // Warm midground ridge (organic harmonic peaks)
        const mountainY = 0.44 - 0.22 * Math.exp(-Math.pow((nx - 0.41) * 4.0, 2))
                               - 0.16 * Math.exp(-Math.pow((nx - 0.65) * 5.4, 2))
                               + 0.015 * Math.sin(nx * 22);

        // Rugged coastal basalt bluff (sloping gently from nx=0 to nx=0.32)
        const cliffHeight = nx < 0.32
          ? Math.pow((0.32 - nx) / 0.32, 1.6) * 0.26 + 0.025 * Math.sin(nx * 34)
          : 0;
        const cliffY = nx < 0.32 ? (0.68 - cliffHeight) : 1.0;

        // Ocean shoreline and dunes
        const shoreY = 0.72 + 0.05 * Math.sin(nx * 7.2 - 0.3) + 0.02 * Math.cos(nx * 14);
        const duneY = 0.77 + 0.07 * Math.sin(nx * 5.8 + 1.1) - 0.03 * Math.cos(nx * 13);

        cols.push({ x, nx, alpineY, mountainY, cliffY, shoreY, duneY });
      }

      // Moon position & constants
      const mx = 0.76 * w;
      const my = 0.20 * h;

      // Lighthouse position & beam constants
      const lx = 0.17 * w;
      const lCliffIdx = Math.max(0, Math.min(cols.length - 1, Math.floor((0.17 * w) / step)));
      const lyBase = (cols[lCliffIdx]?.cliffY || 0.48) * h;
      const lyTop = lyBase - 50;
      const beamAngle = -0.22 + 0.65 * Math.sin(time * 0.55);

      // Ship position on water
      const shipX = 0.56 * w;
      const shipY = 0.53 * h;

      // Scan-line synthesis of halftone dots
      for (let y = step / 2; y < h; y += step) {
        const ny = y / h;

        for (let i = 0; i < cols.length; i++) {
          const col = cols[i];
          const x = col.x;
          const nx = col.nx;

          let targetBucket = null;
          let dotScale = 0;

          // -------------------------------------------------------------
          // 1. CELESTIAL SKY & MOON & STARS (Above Alpine Ridge & Cliff)
          // -------------------------------------------------------------
          if (ny <= col.alpineY && ny <= col.cliffY) {
            const dMoon = Math.hypot(x - mx, y - my);

            // Crescent Moon Disc
            if (dMoon < 22) {
              const inShadow = Math.hypot(x - (mx + 7), y - (my - 4)) < 19;
              if (!inShadow) {
                targetBucket = pathMoonCore;
                dotScale = 0.98;
              } else {
                targetBucket = pathChampagne;
                dotScale = 0.45;
              }
            } else if (dMoon < 160) {
              // Radiant Concentric Halftone Rings from Moon
              const ringCycle = 0.5 + 0.5 * Math.cos(dMoon * 0.12 - time * 1.2);
              const haloAlpha = Math.exp(-dMoon / 120) * ringCycle;
              if (haloAlpha > 0.12) {
                targetBucket = haloAlpha > 0.35 ? pathGoldGlint : pathChampagne;
                dotScale = 0.55 + haloAlpha * 0.38;
              }
            }

            // Twinkling Celestial Stars
            if (!targetBucket) {
              for (let s = 0; s < CELESTIAL_STARS.length; s++) {
                const star = CELESTIAL_STARS[s];
                const ds = Math.hypot(x - star.nx * w, y - star.ny * h);
                if (ds < 7.0) {
                  const twinkle = 0.5 + 0.5 * Math.sin(time * 2.2 + star.phase);
                  if (star.spike && (Math.abs(x - star.nx * w) < 1.2 || Math.abs(y - star.ny * h) < 1.2) && ds < 12) {
                    targetBucket = pathMoonCore;
                    dotScale = 0.92;
                  } else if (ds < star.r * 2.2) {
                    targetBucket = star.spike ? pathMoonCore : pathGoldGlint;
                    dotScale = 0.70 + twinkle * 0.28;
                  }
                  break;
                }
              }
            }

            // Drifting Luminous Nocturnal Cirrus Clouds
            if (!targetBucket) {
              const cloudNoise = Math.sin(nx * 8 + time * 0.35) * Math.cos(ny * 14) + 0.3 * Math.sin(nx * 18 - time * 0.5);
              if (cloudNoise > 0.42 && ny < 0.36) {
                targetBucket = pathAzureWave;
                dotScale = 0.42 + cloudNoise * 0.32;
              }
            }
          }

          // -------------------------------------------------------------
          // 2. LIGHTHOUSE ARCHITECTURE & SWEEPING BEAM
          // -------------------------------------------------------------
          if (nx < 0.25) {
            // Tapered stone tower body
            const inTowerY = y >= lyTop && y <= lyBase;
            const progress = (lyBase - y) / 50;
            const halfW = 7.5 - progress * 3.2;
            if (inTowerY && Math.abs(x - lx) <= halfW) {
              targetBucket = pathMoonCore;
              dotScale = 0.95;
            } else if (Math.abs(x - lx) <= 5.5 && y >= lyTop - 8 && y < lyTop) {
              // Lantern Room
              targetBucket = pathGoldGlint;
              dotScale = 0.98;
            } else if (Math.abs(x - lx) <= 8 && Math.abs(y - lyTop) <= 1.5) {
              // Gallery Catwalk
              targetBucket = pathBasaltRock;
              dotScale = 0.90;
            }
          }

          // Sweeping Conic Light Beam across sky/clouds/ocean
          if (!targetBucket && x > lx) {
            const ptAngle = Math.atan2(y - (lyTop - 4), x - lx);
            const angleDiff = Math.abs(ptAngle - beamAngle);
            const distFromLamp = Math.hypot(x - lx, y - (lyTop - 4));
            if (angleDiff < 0.16 && distFromLamp < w * 0.8) {
              const beamFactor = Math.cos((angleDiff / 0.16) * (Math.PI / 2)) * Math.max(0, 1 - distFromLamp / (w * 0.8));
              if (beamFactor > 0.15) {
                targetBucket = beamFactor > 0.45 ? pathGoldGlint : pathChampagne;
                dotScale = 0.50 + beamFactor * 0.42;
              }
            }
          }

          // -------------------------------------------------------------
          // 3. COASTAL BLUFF & PINE TREES (Left Promontory)
          // -------------------------------------------------------------
          if (!targetBucket && nx < 0.32 && ny > col.cliffY && ny <= col.shoreY) {
            const isTreeRidge = ny < col.cliffY + 0.035 && Math.sin(nx * 95) > 0.15;
            if (isTreeRidge) {
              targetBucket = pathPineDark;
              dotScale = 0.88;
            } else {
              const rockNoise = Math.sin(nx * 44) * Math.cos(ny * 32);
              targetBucket = rockNoise > 0.1 ? pathBasaltRock : pathPineDark;
              dotScale = 0.82;
            }
          }

          // -------------------------------------------------------------
          // 4. DISTANT ALPINE PEAKS (Deep Midnight Indigo)
          // -------------------------------------------------------------
          if (!targetBucket && ny > col.alpineY && ny <= col.mountainY) {
            const isRim = Math.abs(ny - col.alpineY) < 0.022;
            if (isRim) {
              targetBucket = pathAzureWave;
              dotScale = 0.78;
            } else {
              targetBucket = pathOceanDeep;
              dotScale = 0.85;
            }
          }

          // -------------------------------------------------------------
          // 5. WARM MIDGROUND MOUNTAIN RIDGELINE (Terracotta & Ochre)
          // -------------------------------------------------------------
          if (!targetBucket && ny > col.mountainY && ny <= 0.45) {
            const ridgeHatch = Math.sin((nx * 1.8 + ny * 0.9) * 48);
            if (ridgeHatch > 0.05) {
              targetBucket = pathTerracotta;
              dotScale = 0.84 + 0.12 * Math.sin(nx * 18);
            } else {
              targetBucket = pathRidgeShadow;
              dotScale = 0.88;
            }
          }

          // -------------------------------------------------------------
          // 6. CLASSICAL TWO-MASTED SLOOP (On the Water)
          // -------------------------------------------------------------
          if (!targetBucket && Math.abs(x - shipX) < 22 && Math.abs(y - shipY) < 28) {
            const dx = x - shipX;
            const dy = y - shipY;
            const inHull = dy >= 8 && dy <= 16 && Math.abs(dx) <= (18 - (dy - 8));
            const inMainSail = dx >= -2 && dx <= 14 && dy >= -22 && dy <= 6 && (dx <= 14 - (dy + 22) * 0.5);
            const inForeSail = dx >= -16 && dx <= -4 && dy >= -14 && dy <= 6 && (Math.abs(dx + 10) <= 6 - (dy + 14) * 0.25);

            if (inHull) {
              targetBucket = pathPineDark;
              dotScale = 0.95;
            } else if (inMainSail || inForeSail) {
              targetBucket = pathChampagne;
              dotScale = 0.90;
            }
          }

          // -------------------------------------------------------------
          // 7. OCEAN SURFACE (Waves, Foam & Moonlight Wake)
          // -------------------------------------------------------------
          if (!targetBucket && ny > 0.45 && ny <= col.shoreY) {
            const isMoonCol = Math.abs(nx - 0.76) < 0.12;
            const glintNoise = Math.sin(nx * 110 + ny * 75 + time * 4.2);

            if (isMoonCol && glintNoise > 0.38) {
              targetBucket = pathGoldGlint;
              dotScale = 0.88;
            } else {
              const waveCycle = Math.sin(nx * 42 - time * 2.2 + ny * 26) + 0.4 * Math.cos(nx * 20 - time * 1.3);
              if (waveCycle > 0.88) {
                targetBucket = pathSeafoam;
                dotScale = 0.82;
              } else if (waveCycle > 0.1) {
                targetBucket = pathAzureWave;
                dotScale = 0.74;
              } else {
                targetBucket = pathOceanDeep;
                dotScale = 0.80;
              }
            }
          }

          // -------------------------------------------------------------
          // 8. FOREGROUND DUNES, SURF & SEA OATS
          // -------------------------------------------------------------
          if (!targetBucket && ny > col.shoreY) {
            if (Math.abs(ny - col.shoreY) < 0.022) {
              targetBucket = pathSeafoam;
              dotScale = 0.86;
            } else {
              const duneWave = Math.sin(nx * 26 + ny * 16);
              if (duneWave > 0.15) {
                targetBucket = pathDuneSand;
                dotScale = 0.82;
              } else {
                targetBucket = pathDuneShadow;
                dotScale = 0.86;
              }
            }
          }

          // -------------------------------------------------------------
          // 9. DYNAMIC READING LOUPE & TACTILE WAVE INTERACTION
          // -------------------------------------------------------------
          if (targetBucket) {
            let scaleMultiplier = 1.0;
            let px = x;
            let py = y;

            if (hasMouse) {
              const dx = x - mouseX;
              const dy = y - mouseY;
              const dist = Math.hypot(dx, dy);
              const zone = 135;

              if (dist < zone) {
                const norm = 1 - dist / zone;
                const push = Math.sin(norm * Math.PI) * 3.2;
                if (dist > 0.01) {
                  px += (dx / dist) * push;
                  py += (dy / dist) * push;
                }
                scaleMultiplier = 1.0 + norm * 0.48;
              }
            }

            const r = Math.max(0.75, dotScale * scaleMultiplier * (step * 0.46));
            targetBucket.moveTo(px + r, py);
            targetBucket.arc(px, py, r, 0, Math.PI * 2);
          }
        }
      }

      // Execute 12 pigment plate batch draw calls
      ctx.globalAlpha = 0.98;

      ctx.fillStyle = '#143562'; ctx.fill(pathOceanDeep);
      ctx.fillStyle = '#22344A'; ctx.fill(pathBasaltRock);
      ctx.fillStyle = '#0D1C15'; ctx.fill(pathPineDark);
      ctx.fillStyle = '#702611'; ctx.fill(pathRidgeShadow);
      ctx.fillStyle = '#D96B3D'; ctx.fill(pathTerracotta);
      ctx.fillStyle = '#5A8FC8'; ctx.fill(pathAzureWave);
      ctx.fillStyle = '#826B42'; ctx.fill(pathDuneShadow);
      ctx.fillStyle = '#CEBA8C'; ctx.fill(pathDuneSand);
      ctx.fillStyle = '#E6F2FC'; ctx.fill(pathSeafoam);
      ctx.fillStyle = '#EAD8AE'; ctx.fill(pathChampagne);
      ctx.fillStyle = '#F0B323'; ctx.fill(pathGoldGlint);
      ctx.fillStyle = '#FFFBEA'; ctx.fill(pathMoonCore);

      // Subtle hairline inspection lens outline if pointer active
      if (hasMouse) {
        ctx.save();
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.20)';
        ctx.lineWidth = 0.8;
        ctx.beginPath();
        ctx.arc(mouseX, mouseY, 40, 0, Math.PI * 2);
        ctx.stroke();
        ctx.restore();
      }

      ctx.restore();
      animId = requestAnimationFrame(render);
    };

    animId = requestAnimationFrame(render);

    return () => {
      observer.disconnect();
      if (animId) cancelAnimationFrame(animId);
    };
  }, [mouseRef]);

  return (
    <canvas
      ref={canvasRef}
      onMouseMove={(e) => {
        const rect = e.currentTarget.getBoundingClientRect();
        internalMouseRef.current = { x: e.clientX - rect.left, y: e.clientY - rect.top, active: true };
      }}
      onMouseLeave={() => {
        internalMouseRef.current = { x: -999, y: -999, active: false };
      }}
      className="w-full h-full block"
    />
  );
}

export default function App() {
  // Hero Specimen state
  const [selectedNodeId, setSelectedNodeId] = useState('V3');
  const heroMouseRef = useRef({ x: -999, y: -999 });
  const footerMouseRef = useRef({ x: -999, y: -999 });

  // Specimen A (1-Click Semantic Diff Switch)
  const [diffCase, setDiffCase] = useState('TYPO'); // 'TYPO' | 'BUDGET'

  // Specimen B (1-Click Queue Aging Toggle)
  const [aged24h, setAged24h] = useState(false);

  // Specimen C (1-Click Channel Collision & Spend Spike Toggles)
  const [testOverlap, setTestOverlap] = useState(false);
  const [cpaSpikeTriggered, setCpaSpikeTriggered] = useState(false);

  // Optional Clean Modals
  const [adrModalOpen, setAdrModalOpen] = useState(false);
  const [downloadModalOpen, setDownloadModalOpen] = useState(false);

  const activeNode =
    SPECIMEN_NODES.find((n) => n.id === selectedNodeId) || SPECIMEN_NODES[2];

  // Specimen B Queue Items
  const queueCards = aged24h
    ? [
        {
          rank: '#1',
          name: 'Diwali Sovereign Gold',
          meta: 'Version 3 · +24h Aging Credit Applied',
          score: 88,
          tag: 'Promoted to Top',
          tone: 'green'
        },
        {
          rank: '#2',
          name: 'Autumn Home Collection',
          meta: 'Version 1 · First-Time Clean Proposal',
          score: 74,
          tag: 'Standard Queue',
          tone: 'cobalt'
        },
        {
          rank: 'ESC',
          name: 'Luxury Watch Preview',
          meta: 'Version 5 · 4x Prior Revisions',
          score: 32,
          tag: 'Escalated Track',
          tone: 'terracotta'
        }
      ]
    : [
        {
          rank: '#1',
          name: 'Autumn Home Collection',
          meta: 'Version 1 · Clean Submission',
          score: 74,
          tag: 'Standard Queue',
          tone: 'cobalt'
        },
        {
          rank: '#2',
          name: 'Diwali Sovereign Gold',
          meta: 'Version 3 · Waiting 4h in Queue',
          score: 64,
          tag: 'Standard Queue',
          tone: 'green'
        },
        {
          rank: 'ESC',
          name: 'Luxury Watch Preview',
          meta: 'Version 5 · 4x Prior Revisions',
          score: 32,
          tag: 'Escalated Track',
          tone: 'terracotta'
        }
      ];

  return (
    <div className="min-h-screen bg-[#F6F4EE] text-[#111622] font-sans antialiased selection:bg-[#0D47A1] selection:text-white">
      {/* -------------------------------------------------------------------
          GOOGLE FONTS & FLUTED GLASS / HALFTONE SPECIMEN STYLES
      ------------------------------------------------------------------- */}
      <style>{`
        .font-serif-editorial {
          font-family: 'Newsreader', Georgia, serif;
        }
        .font-sans {
          font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
        }
        .font-mono-spec {
          font-family: 'JetBrains Mono', monospace;
        }

        /* 4K Analog Film Grain & Fine Risograph Noise Overlay */
        .fine-grain {
          background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.85' numOctaves='3' stitchTiles='stitch'/%3E%3CfeColorMatrix type='matrix' values='1 0 0 0 0  0 1 0 0 0  0 0 1 0 0  0 0 0 0.16 0'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter)'/%3E%3C/svg%3E");
          background-repeat: repeat;
        }

        /* Subtle Halftone Dot Pattern for Specimen Backgrounds */
        .halftone-stipple {
          background-image: radial-gradient(#111622 1px, transparent 1px);
          background-size: 8px 8px;
        }
      `}</style>

      {/* ===================================================================
          SECTION 1: MINIMALIST TOP BAR
      =================================================================== */}
      <header className="sticky top-0 z-30 bg-[#F6F4EE]/90 backdrop-blur-md border-b border-[#DED9CD]">
        <div className="max-w-[1280px] mx-auto px-6 h-20 flex items-center justify-between">
          {/* Brand Emblem + Serif Title */}
          <a href="#top" className="flex items-center gap-3 group">
            <svg
              className="w-8 h-6 text-[#0D47A1]"
              viewBox="0 0 36 26"
              fill="none"
              aria-hidden="true"
            >
              <path d="M2 22L10 4H17L9 22H2Z" fill="#0D47A1" />
              <path d="M14 22L22 4H34L26 22H14Z" fill="#111622" />
              <circle cx="29" cy="9" r="2.5" fill="#D85A32" />
            </svg>
            <span className="font-serif-editorial text-[23px] font-medium tracking-[-0.02em] text-[#111622]">
              Campaign Grid
            </span>
          </a>

          {/* Links + Download App Action */}
          <div className="flex items-center gap-6">
            <nav className="hidden md:flex items-center gap-6 text-[15px] text-[#545B6B] font-medium">
              <a href="#hero-specimen" className="hover:text-[#111622] transition-colors">
                Specimens
              </a>
              <a href="#bento-specimens" className="hover:text-[#111622] transition-colors">
                Architecture
              </a>
              <button
                type="button"
                onClick={() => setAdrModalOpen(true)}
                className="hover:text-[#111622] transition-colors"
              >
                Ledger
              </button>
              <a
                href="/editorial.html"
                className="hover:text-[#111622] transition-colors"
              >
                Editorial
              </a>
            </nav>

            <button
              type="button"
              onClick={() => setDownloadModalOpen(true)}
              className="px-4 py-2 rounded-lg bg-[#111622] hover:bg-[#0D47A1] text-[#F6F4EE] text-sm font-medium transition-all shadow-sm hover:shadow flex items-center gap-2"
            >
              <Smartphone className="w-4 h-4 text-[#D7F46A]" />
              <span>Download Mobile App</span>
            </button>
          </div>
        </div>
      </header>

      {/* ===================================================================
          SECTION 2: HERO SECTION (GALLERY WHITESPACE + FLUTED HALFTONE SPECIMEN)
      =================================================================== */}
      <section id="top" className="pt-20 pb-24 px-6">
        <div className="max-w-[1280px] mx-auto">
          {/* Editorial Headline & Subheadline */}
          <div className="max-w-[880px] space-y-6">
            <h1
              className="font-serif-editorial text-[#111622] font-normal tracking-[-0.03em]"
              style={{
                fontSize: 'clamp(3rem, 5.2vw, 4.75rem)',
                lineHeight: 1.04
              }}
            >
              Every campaign approval, bound to the exact version reviewed.
            </h1>

            <p className="text-[18px] text-[#545B6B] leading-[1.6] max-w-[54ch]">
              Campaign Grid separates live execution from exploratory drafts—so marketers can test
              changes freely while approved schedules stay locked.
            </p>

            {/* Clean CTAs including Direct Mobile App Download */}
            <div className="pt-2 flex flex-wrap items-center gap-4">
              <button
                type="button"
                onClick={() => setDownloadModalOpen(true)}
                className="px-6 py-3 rounded-lg bg-[#0D47A1] hover:bg-[#09357A] text-white text-[15px] font-medium transition-all shadow-md hover:shadow-lg flex items-center gap-2"
              >
                <Download className="w-4 h-4" />
                <span>Get Mobile App (APK / iOS)</span>
              </button>

              <a
                href="#bento-specimens"
                className="px-6 py-3 rounded-lg bg-[#EDE9DF] hover:bg-[#E2DDD0] border border-[#D5CFC2] text-[#111622] text-[15px] font-medium transition-colors flex items-center gap-2"
              >
                <span>Inspect Architecture</span>
                <ArrowUpRight className="w-4 h-4" />
              </a>

              <button
                type="button"
                onClick={() => setAdrModalOpen(true)}
                className="px-5 py-3 rounded-lg border border-[#D5CFC2] hover:bg-[#EDE9DF] text-[#545B6B] hover:text-[#111622] text-[15px] font-medium transition-colors"
              >
                Read 15 ADRs
              </button>

              <a
                href="/editorial.html"
                className="px-5 py-3 rounded-lg border border-[#D5CFC2] hover:bg-[#EDE9DF] text-[#545B6B] hover:text-[#111622] text-[15px] font-medium transition-colors"
              >
                Generative Study ↗
              </a>
            </div>
          </div>

          {/* HERO CENTERPIECE VISUAL: THE HALFTONE SPECIMEN VITRINE */}
          <div
            id="hero-specimen"
            className="mt-16 rounded-2xl border border-[#D5CFC2] bg-[#EDE9DF] overflow-hidden shadow-[0_20px_50px_rgba(17,22,34,0.06)]"
          >
            {/* Specimen Top Bar */}
            <div className="px-6 py-4 bg-[#F6F4EE] border-b border-[#D5CFC2] flex flex-wrap items-center justify-between gap-4">
              <div className="flex items-center gap-3">
                <span className="w-2.5 h-2.5 rounded-full bg-[#1E6B52]" />
                <h2 className="font-serif-editorial text-xl text-[#111622]">
                  Diwali Sovereign Gold — Version Lineage
                </h2>
              </div>
              <div className="flex items-center gap-2 text-xs font-mono-spec text-[#545B6B]">
                <span className="w-2 h-2 rounded-full bg-[#1E6B52]" />
                <span className="text-[#111622] font-semibold">
                  {activeNode.scheduleState.split('—')[0]}
                </span>
              </div>
            </div>

            {/* Split Vitrine: Left 7 Cols (Clean Unobstructed Lineage Canvas) + Right 5 Cols (Audit Dossier) */}
            <div className="grid grid-cols-1 lg:grid-cols-12 min-h-[500px]">
              {/* Left 7 Cols: Living Architectural Lineage Halftone Canvas */}
              <div className="lg:col-span-7 relative min-h-[440px] lg:min-h-[520px] bg-[#EDE9DF] border-b lg:border-b-0 lg:border-r border-[#D5CFC2] overflow-hidden select-none">
                <HeroHalftoneCanvas
                  selectedNodeId={selectedNodeId}
                  onSelectNode={setSelectedNodeId}
                />
              </div>

              {/* Right 5 Cols: Integrated Vitrine Audit Dossier */}
              <div className="lg:col-span-5 bg-[#F6F4EE] flex flex-col justify-between p-6 sm:p-7 space-y-6">
                {/* Version Quick Step Tabs (No redundant eyebrow headers) */}
                <div className="grid grid-cols-4 gap-1.5">
                  {SPECIMEN_NODES.map((node) => {
                    const isSelected = node.id === selectedNodeId;
                    return (
                      <button
                        key={node.id}
                        type="button"
                        onClick={() => setSelectedNodeId(node.id)}
                        className={`py-2 px-1 text-center rounded-lg font-mono-spec text-xs transition-all border ${
                          isSelected
                            ? 'bg-[#111622] text-white border-[#111622] shadow-sm font-semibold'
                            : 'bg-[#EDE9DF] text-[#545B6B] hover:text-[#111622] hover:bg-[#E4DFD3] border-[#D5CFC2]'
                        }`}
                      >
                        {node.id.replace('_', '.')}
                      </button>
                    );
                  })}
                </div>

                {/* Active Version Detailed Overview */}
                <div className="space-y-4 flex-1">
                  <div className="border-b border-[#DED9CD] pb-3.5">
                    <div className="flex items-center justify-between">
                      <span className="font-mono-spec text-xs text-[#0D47A1] font-semibold">
                        {activeNode.version}
                      </span>
                      <span
                        className={`font-mono-spec text-[11px] font-semibold px-2 py-0.5 rounded border ${
                          activeNode.tone === 'green'
                            ? 'bg-[#1E6B52]/10 border-[#1E6B52]/30 text-[#1E6B52]'
                            : activeNode.tone === 'terracotta'
                            ? 'bg-[#D85A32]/10 border-[#D85A32]/30 text-[#D85A32]'
                            : activeNode.tone === 'cobalt'
                            ? 'bg-[#0D47A1]/10 border-[#0D47A1]/30 text-[#0D47A1]'
                            : 'bg-[#545B6B]/10 border-[#545B6B]/30 text-[#545B6B]'
                        }`}
                      >
                        [ {activeNode.badge.toUpperCase()} ]
                      </span>
                    </div>
                    <h3 className="font-serif-editorial text-2xl text-[#111622] mt-1 leading-snug">
                      {activeNode.title}
                    </h3>
                    <div className="flex items-baseline gap-2 mt-1.5 font-mono-spec">
                      <span className="text-2xl font-bold text-[#111622]">{activeNode.budget}</span>
                      <span className="text-xs text-[#545B6B]">· {activeNode.channel}</span>
                    </div>
                  </div>

                  {/* Audit Decision Quote with Reviewer attribution */}
                  <blockquote className="border-l-2 border-[#111622]/20 pl-4 py-1 italic font-serif-editorial text-[17px] text-[#111622] leading-relaxed">
                    &ldquo;{activeNode.reason}&rdquo;
                    <cite className="block not-italic font-mono-spec text-[11px] text-[#545B6B] mt-1.5">
                      — Reviewer: {activeNode.reviewer}
                    </cite>
                  </blockquote>

                  {/* Technical ACID Lease Readout */}
                  <div className="pt-3 border-t border-[#DED9CD] space-y-2 font-mono-spec text-xs">
                    <div className="flex justify-between">
                      <span className="text-[#545B6B]">Audited By:</span>
                      <span className="font-medium text-[#111622]">{activeNode.reviewer}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-[#545B6B]">Calendar Lock:</span>
                      <span className="font-medium text-[#111622]">{activeNode.scheduleState}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-[#545B6B]">ACID Invariant:</span>
                      <span className="font-medium text-[#111622]">
                        {activeNode.id === 'V3'
                          ? 'active_version_id (Exclusive)'
                          : activeNode.id === 'V3_1'
                          ? 'draft_version_id (Isolated)'
                          : activeNode.id === 'V2'
                          ? 'Violates Margin Ceiling'
                          : 'Archived Baseline'}
                      </span>
                    </div>
                  </div>
                </div>

                {/* Interactive Simulation Switcher Button */}
                <div className="pt-2 border-t border-[#DED9CD]">
                  {activeNode.id === 'V3' && (
                    <button
                      type="button"
                      onClick={() => setSelectedNodeId('V3_1')}
                      className="w-full py-2.5 px-4 rounded-lg bg-[#0D47A1] hover:bg-[#09357A] text-white text-xs font-mono-spec font-medium transition-colors flex items-center justify-center gap-2 shadow-sm"
                    >
                      <span>Branch into Copy Sandbox (V3.1)</span>
                      <ArrowUpRight className="w-4 h-4" />
                    </button>
                  )}
                  {activeNode.id === 'V3_1' && (
                    <button
                      type="button"
                      onClick={() => setSelectedNodeId('V3')}
                      className="w-full py-2.5 px-4 rounded-lg bg-[#1E6B52] hover:bg-[#15523E] text-white text-xs font-mono-spec font-medium transition-colors flex items-center justify-center gap-2 shadow-sm"
                    >
                      <span>Return to Live Calendar (V3.0)</span>
                      <Check className="w-4 h-4" />
                    </button>
                  )}
                  {activeNode.id === 'V2' && (
                    <button
                      type="button"
                      onClick={() => setSelectedNodeId('V3')}
                      className="w-full py-2.5 px-4 rounded-lg bg-[#111622] hover:bg-[#0D47A1] text-white text-xs font-mono-spec font-medium transition-colors flex items-center justify-center gap-2 shadow-sm"
                    >
                      <span>Inspect Sovereign Gold Fix (V3.0)</span>
                      <ArrowUpRight className="w-4 h-4" />
                    </button>
                  )}
                  {activeNode.id === 'V1' && (
                    <button
                      type="button"
                      onClick={() => setSelectedNodeId('V3')}
                      className="w-full py-2.5 px-4 rounded-lg bg-[#111622] hover:bg-[#0D47A1] text-white text-xs font-mono-spec font-medium transition-colors flex items-center justify-center gap-2 shadow-sm"
                    >
                      <span>Advance to Live Version (V3.0)</span>
                      <ArrowUpRight className="w-4 h-4" />
                    </button>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ===================================================================
          SECTION 3: THREE INTERACTIVE ARCHITECTURAL SPECIMENS (NO SLIDERS)
      =================================================================== */}
      <section id="bento-specimens" className="py-24 px-6 border-t border-[#DED9CD]">
        <div className="max-w-[1280px] mx-auto space-y-14">
          <div className="max-w-[640px] space-y-3">
            <h2 className="font-serif-editorial text-4xl sm:text-5xl text-[#111622] tracking-[-0.02em]">
              Built for the moments where campaign workflows break.
            </h2>
            <p className="text-[17px] text-[#545B6B] leading-relaxed">
              Click any specimen switch below to test how Campaign Grid isolates working drafts,
              prevents review queue starvation, and guards live budgets.
            </p>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
            {/* ---------------------------------------------------------------
                SPECIMEN A: EXPLORATORY SANDBOX VS. LIVE BASELINE
            --------------------------------------------------------------- */}
            <div className="rounded-2xl border border-[#D5CFC2] bg-[#EDE9DF] p-7 flex flex-col justify-between space-y-8">
              <div className="space-y-3">
                <div className="flex items-center justify-end">
                  <Layers className="w-4 h-4 text-[#545B6B]" />
                </div>
                <h3 className="font-serif-editorial text-2xl text-[#111622]">
                  Exploratory edits never unschedule your live campaign.
                </h3>
                <p className="text-sm text-[#545B6B] leading-relaxed">
                  Fix a copy typo in-place without re-review, or test a major budget shift in a
                  sandbox while Version 3.0 stays locked on the calendar.
                </p>
              </div>

              {/* Visual Fluted Glass Barrier Schematic */}
              <div className="rounded-xl bg-[#F6F4EE] border border-[#D5CFC2] p-4 space-y-3 relative overflow-hidden">
                <div className="flex items-center justify-between text-xs font-mono-spec pb-2 border-b border-[#DED9CD]">
                  <div className="flex items-center gap-2 text-[#1E6B52] font-semibold">
                    <span className="w-2 h-2 rounded-full bg-[#1E6B52]" />
                    <span>V3.0 Live on Calendar</span>
                  </div>
                  <span className="text-xs text-[#545B6B]">$44,000 · Immutable Lock</span>
                </div>

                {/* Fluted Glass Refraction Strip */}
                <div className="fluted-glass rounded-lg p-3 border border-[#D5CFC2] flex items-center justify-between gap-3">
                  <div>
                    <div className="font-serif-editorial text-lg text-[#111622] leading-tight">
                      {diffCase === 'TYPO'
                        ? 'Fixed headline punctuation'
                        : 'Raised budget +20% to $52,800'}
                    </div>
                    <div className="font-mono-spec text-[11px] text-[#545B6B] mt-1">
                      {diffCase === 'TYPO' ? 'In-place copy edit' : 'Material budget change'}
                    </div>
                  </div>
                  <div className="text-right shrink-0">
                    <span
                      className={`inline-flex items-center gap-1.5 font-mono-spec text-[11px] font-semibold px-2.5 py-1 rounded border ${
                        diffCase === 'TYPO'
                          ? 'bg-[#1E6B52]/10 border-[#1E6B52]/30 text-[#1E6B52]'
                          : 'bg-[#D85A32]/10 border-[#D85A32]/30 text-[#D85A32]'
                      }`}
                    >
                      {diffCase === 'TYPO' ? '✓ Atomic Patch · In-Place' : '⚠ Triggers Version 4.0'}
                    </span>
                  </div>
                </div>
              </div>

              {/* 1-Click Tactile Switch */}
              <div className="grid grid-cols-2 gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setDiffCase('TYPO')}
                  className={`py-2.5 px-3 rounded-lg text-xs font-medium border transition-colors ${
                    diffCase === 'TYPO'
                      ? 'bg-[#111622] text-white border-[#111622]'
                      : 'bg-[#F6F4EE] text-[#545B6B] border-[#D5CFC2] hover:text-[#111622]'
                  }`}
                >
                  Fix Copy Typo
                </button>
                <button
                  type="button"
                  onClick={() => setDiffCase('BUDGET')}
                  className={`py-2.5 px-3 rounded-lg text-xs font-medium border transition-colors ${
                    diffCase === 'BUDGET'
                      ? 'bg-[#D85A32] text-white border-[#D85A32]'
                      : 'bg-[#F6F4EE] text-[#545B6B] border-[#D5CFC2] hover:text-[#111622]'
                  }`}
                >
                  Shift Budget +20%
                </button>
              </div>
            </div>

            {/* ---------------------------------------------------------------
                SPECIMEN B: ANTI-STARVATION REVIEW QUEUE
            --------------------------------------------------------------- */}
            <div className="rounded-2xl border border-[#D5CFC2] bg-[#EDE9DF] p-7 flex flex-col justify-between space-y-8">
              <div className="space-y-3">
                <div className="flex items-center justify-end">
                  <Clock className="w-4 h-4 text-[#545B6B]" />
                </div>
                <h3 className="font-serif-editorial text-2xl text-[#111622]">
                  Self-balancing triage that prevents reviewer starvation.
                </h3>
                <p className="text-sm text-[#545B6B] leading-relaxed">
                  Waiting campaigns earn aging credits so they never stall, while chronic 4x
                  revisions move to an escalation track.
                </p>
              </div>

              {/* Visual Queue Stack */}
              <div className="space-y-2">
                {queueCards.map((item) => (
                  <div
                    key={item.name}
                    className="p-3 rounded-xl bg-[#F6F4EE] border border-[#D5CFC2] flex items-center justify-between gap-3 transition-all"
                  >
                    <div className="flex items-center gap-3">
                      <span className="font-mono-spec text-xs font-bold text-[#545B6B] w-6">
                        {item.rank}
                      </span>
                      <div>
                        <div className="text-sm font-medium text-[#111622]">{item.name}</div>
                        <div className="font-mono-spec text-[11px] text-[#545B6B]">{item.meta}</div>
                      </div>
                    </div>
                    <div className="text-right font-mono-spec">
                      <div className="flex items-baseline justify-end gap-1">
                        <span
                          className={`text-sm font-bold tabular-nums ${
                            item.tone === 'green'
                              ? 'text-[#1E6B52]'
                              : item.tone === 'terracotta'
                              ? 'text-[#D85A32]'
                              : 'text-[#0D47A1]'
                          }`}
                        >
                          {item.score}
                        </span>
                        <span className="text-[10px] text-[#545B6B]">pts</span>
                      </div>
                      <div className="text-[10px] text-[#545B6B]">{item.tag}</div>
                    </div>
                  </div>
                ))}
              </div>

              {/* Single Toggle Button */}
              <button
                type="button"
                onClick={() => setAged24h(!aged24h)}
                className={`w-full py-2.5 px-4 rounded-lg text-xs font-medium border transition-colors ${
                  aged24h
                    ? 'bg-[#1E6B52] text-white border-[#1E6B52]'
                    : 'bg-[#111622] text-white border-[#111622] hover:bg-[#0D47A1]'
                }`}
              >
                {aged24h
                  ? 'Aging Applied (+24h Credit) · Click to Reset'
                  : 'Simulate +24h Queue Aging'}
              </button>
            </div>

            {/* ---------------------------------------------------------------
                SPECIMEN C: CHANNEL COLLISION & SPEND CIRCUIT BREAKER
            --------------------------------------------------------------- */}
            <div className="rounded-2xl border border-[#D5CFC2] bg-[#EDE9DF] p-7 flex flex-col justify-between space-y-8">
              <div className="space-y-3">
                <div className="flex items-center justify-end">
                  <ShieldCheck className="w-4 h-4 text-[#545B6B]" />
                </div>
                <h3 className="font-serif-editorial text-2xl text-[#111622]">
                  Collision-free channels and automatic spend tripwires.
                </h3>
                <p className="text-sm text-[#545B6B] leading-relaxed">
                  PostgreSQL range exclusions block overlapping channel bookings, while live CPA
                  tripwires pause runaway spend automatically.
                </p>
              </div>

              {/* Visual Timeline & Telemetry Schematic */}
              <div className="rounded-xl bg-[#F6F4EE] border border-[#D5CFC2] p-4 space-y-3">
                <div className="flex items-center justify-between font-mono-spec text-xs">
                  <span className="text-[#111622] font-medium">Paid Search (Nov 1–14)</span>
                  <span
                    className={`font-mono-spec text-[11px] font-semibold px-2 py-0.5 rounded border ${
                      testOverlap
                        ? 'bg-[#D85A32]/10 border-[#D85A32]/30 text-[#D85A32]'
                        : 'bg-[#1E6B52]/10 border-[#1E6B52]/30 text-[#1E6B52]'
                    }`}
                  >
                    {testOverlap ? '409 Conflict · Blocked' : 'Exclusive · Slot Locked'}
                  </span>
                </div>

                <div className="h-5 rounded bg-[#EDE9DF] relative overflow-hidden border border-[#D5CFC2]">
                  <div className="absolute inset-y-0 left-2 width-2/3 w-3/5 bg-[#0D47A1] text-white font-mono-spec text-[10px] flex items-center px-2">
                    V3.0 Reserved
                  </div>
                  {testOverlap && (
                    <div className="absolute inset-y-0 right-2 w-1/2 bg-[#D85A32]/90 text-white font-mono-spec text-[10px] flex items-center justify-end px-2">
                      Rejected Overlap
                    </div>
                  )}
                </div>

                <div className="pt-2 border-t border-[#DED9CD] flex items-center justify-between font-mono-spec text-xs">
                  <span className="text-[#545B6B]">
                    Live CPA: {cpaSpikeTriggered ? '$38.40 (320%)' : '$11.80 (Nominal)'}
                  </span>
                  <span
                    className={`font-mono-spec text-[11px] font-semibold px-2 py-0.5 rounded border ${
                      cpaSpikeTriggered
                        ? 'bg-[#D85A32]/10 border-[#D85A32]/30 text-[#D85A32]'
                        : 'bg-[#1E6B52]/10 border-[#1E6B52]/30 text-[#1E6B52]'
                    }`}
                  >
                    {cpaSpikeTriggered ? 'Tripwire · Spend Halted' : 'Nominal · Guardrails OK'}
                  </span>
                </div>
              </div>

              {/* Two 1-Click Test Buttons */}
              <div className="grid grid-cols-2 gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setTestOverlap(!testOverlap)}
                  className={`py-2.5 px-3 rounded-lg text-xs font-medium border transition-colors ${
                    testOverlap
                      ? 'bg-[#D85A32] text-white border-[#D85A32]'
                      : 'bg-[#F6F4EE] text-[#545B6B] border-[#D5CFC2] hover:text-[#111622]'
                  }`}
                >
                  {testOverlap ? 'Clear Overlap' : 'Test Overlapping Slot'}
                </button>
                <button
                  type="button"
                  onClick={() => setCpaSpikeTriggered(!cpaSpikeTriggered)}
                  className={`py-2.5 px-3 rounded-lg text-xs font-medium border transition-colors ${
                    cpaSpikeTriggered
                      ? 'bg-[#D85A32] text-white border-[#D85A32]'
                      : 'bg-[#F6F4EE] text-[#545B6B] border-[#D5CFC2] hover:text-[#111622]'
                  }`}
                >
                  {cpaSpikeTriggered ? 'Resume Campaign' : 'Trigger 300% CPA Spike'}
                </button>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ===================================================================
          SECTION 4: LIVING CELESTIAL & COASTAL HALFTONE PANORAMA (100% UNOBSTRUCTED)
      =================================================================== */}
      <section
        onPointerMove={(e) => {
          const rect = e.currentTarget.getBoundingClientRect();
          footerMouseRef.current = { x: e.clientX - rect.left, y: e.clientY - rect.top };
        }}
        onPointerLeave={() => {
          footerMouseRef.current = { x: -999, y: -999 };
        }}
        className="relative bg-[#061325] overflow-hidden h-[420px] sm:h-[480px] lg:h-[540px] border-t border-[#DED9CD] select-none group"
      >
        {/* Full-Bleed 4K Halftone Panorama Canvas (Living Generative Artwork) */}
        <div className="absolute inset-0 z-0">
          <CoastalHalftonePanorama mouseRef={footerMouseRef} />
        </div>

        {/* 4K Analog Film Grain & Fine Risograph Noise Overlay */}
        <div className="absolute inset-0 z-10 pointer-events-none fine-grain mix-blend-overlay opacity-25" />

        {/* Subtle Vignette Gradient for Depth */}
        <div className="absolute inset-0 z-10 pointer-events-none bg-gradient-to-b from-black/20 via-transparent to-black/30" />

        {/* Minimal Fine-Art Print Registration Stamps */}
        <div className="absolute bottom-4 left-6 sm:left-10 z-20 pointer-events-none font-mono-spec text-[11px] text-white/40 tracking-wider flex items-center gap-2">
          <span className="w-1.5 h-1.5 rounded-full bg-[#F0B323]" />
          <span>SPECIMEN IV · CELESTIAL COASTAL WAVEFIELD (COPPERPLATE HALFTONE)</span>
        </div>
        <div className="absolute bottom-4 right-6 sm:right-10 z-20 pointer-events-none hidden sm:block font-mono-spec text-[11px] text-white/35 tracking-wider">
          <span>60 FPS REACTIVE · LOUPE HOVER</span>
        </div>
      </section>

      {/* ===================================================================
          SECTION 5: EDITORIAL FOOTER (CRISP, LEGIBLE FROSTED GLASS BAR & LEDGER)
      =================================================================== */}
      <footer className="relative bg-[#071424] text-white border-t border-[#16324A] py-14 sm:py-16 px-6">
        <div className="max-w-[1280px] mx-auto">
          {/* Frosted Glass Footer Panel with Beveled Glass Edge & Backdrop Blur */}
          <div className="rounded-3xl border border-white/15 bg-white/[0.04] backdrop-blur-xl shadow-[0_20px_50px_rgba(0,0,0,0.5)] p-8 sm:p-12 md:p-14 relative overflow-hidden transition-all">
            {/* Top Beveled Glass Reflection Line */}
            <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-white/30 to-transparent pointer-events-none" />

            {/* Top Editorial Grid */}
            <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 pb-12">
              {/* Left Column (5 Cols): Brand Mark + 3-Line Summary */}
              <div className="lg:col-span-5 space-y-6">
                <div className="flex items-center gap-3">
                  <svg
                    className="w-9 h-7 text-white"
                    viewBox="0 0 36 26"
                    fill="none"
                    aria-hidden="true"
                  >
                    <path d="M2 22L10 4H17L9 22H2Z" fill="#FFFFFF" />
                    <path d="M14 22L22 4H34L26 22H14Z" fill="#FFFFFF" fillOpacity="0.8" />
                  </svg>
                  <span className="font-serif-editorial text-[30px] font-normal tracking-[-0.02em] text-white">
                    Campaign Grid
                  </span>
                </div>

                <p className="text-[16px] text-white/85 leading-[1.6] max-w-[40ch]">
                  Campaign Grid keeps marketing and finance teams in sync when proposals change, with
                  version-bound approvals, collision-free scheduling, and immutable audit trails.
                </p>
              </div>

              {/* Right Columns (7 Cols -> 3 Crisp Columns) */}
              <div className="lg:col-span-7 grid grid-cols-2 sm:grid-cols-3 gap-8 text-[15px]">
                <div className="space-y-3.5">
                  <div className="font-serif-editorial text-lg text-white">Product</div>
                  <ul className="space-y-2.5 text-white/80">
                    <li>
                      <a href="#hero-specimen" className="hover:text-white transition-colors">
                        Version Lineage
                      </a>
                    </li>
                    <li>
                      <a href="#bento-specimens" className="hover:text-white transition-colors">
                        Sandbox Diffs
                      </a>
                    </li>
                    <li>
                      <a href="#bento-specimens" className="hover:text-white transition-colors">
                        Priority Queue
                      </a>
                    </li>
                    <li>
                      <a href="#bento-specimens" className="hover:text-white transition-colors">
                        Spend Guardrails
                      </a>
                    </li>
                    <li>
                      <button
                        type="button"
                        onClick={() => setDownloadModalOpen(true)}
                        className="hover:text-white transition-colors font-medium text-[#D7F46A]"
                      >
                        Download Mobile App ↓
                      </button>
                    </li>
                  </ul>
                </div>

                <div className="space-y-3.5">
                  <div className="font-serif-editorial text-lg text-white">Architecture</div>
                  <ul className="space-y-2.5 text-white/80">
                    <li>
                      <button
                        type="button"
                        onClick={() => setAdrModalOpen(true)}
                        className="hover:text-white transition-colors"
                      >
                        PostgreSQL DDL
                      </button>
                    </li>
                    <li>
                      <button
                        type="button"
                        onClick={() => setAdrModalOpen(true)}
                        className="hover:text-white transition-colors"
                      >
                        Transactional Outbox
                      </button>
                    </li>
                    <li>
                      <button
                        type="button"
                        onClick={() => setAdrModalOpen(true)}
                        className="hover:text-white transition-colors"
                      >
                        GiST Exclusions
                      </button>
                    </li>
                    <li>
                      <button
                        type="button"
                        onClick={() => setAdrModalOpen(true)}
                        className="hover:text-white transition-colors"
                      >
                        Gemini 4 Argon
                      </button>
                    </li>
                    <li>
                      <button
                        type="button"
                        onClick={() => setAdrModalOpen(true)}
                        className="hover:text-white transition-colors"
                      >
                        15 ADRs
                      </button>
                    </li>
                  </ul>
                </div>

                <div className="space-y-3.5">
                  <div className="font-serif-editorial text-lg text-white">Resources</div>
                  <ul className="space-y-2.5 text-white/80">
                    <li>
                      <a href="#top" className="hover:text-white transition-colors">
                        System Status
                      </a>
                    </li>
                    <li>
                      <button
                        type="button"
                        onClick={() => setAdrModalOpen(true)}
                        className="hover:text-white transition-colors"
                      >
                        Documentation
                      </button>
                    </li>
                    <li>
                      <a href="#hero-specimen" className="hover:text-white transition-colors">
                        Audit Ledger
                      </a>
                    </li>
                    <li>
                      <a href="#bento-specimens" className="hover:text-white transition-colors">
                        Security
                      </a>
                    </li>
                    <li>
                      <a href="/editorial.html" className="text-[#D7F46A] hover:underline font-medium">
                        Generative Editorial Page ↗
                      </a>
                    </li>
                  </ul>
                </div>
              </div>
            </div>

            {/* Hairline Divider inside Glass */}
            <div className="border-t border-white/15 pt-6 flex flex-col sm:flex-row items-center justify-between gap-4 text-xs font-mono-spec text-white/75">
              <div>Engineered with precision by Bit Loggers</div>
              <div>Campaign Grid ©2026. All Rights Reserved</div>
            </div>
          </div>
        </div>
      </footer>

      {/* ===================================================================
          MODAL 1: DOWNLOAD MOBILE APP (ANDROID APK & IOS)
      =================================================================== */}
      {downloadModalOpen && (
        <div className="fixed inset-0 z-50 bg-[#111622]/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-[#F6F4EE] border border-[#D5CFC2] rounded-2xl max-w-xl w-full p-6 sm:p-8 shadow-2xl space-y-6 max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between border-b border-[#DED9CD] pb-4">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-[#0D47A1] text-white flex items-center justify-center">
                  <Smartphone className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="font-serif-editorial text-2xl text-[#111622]">
                    Download CampaignGrid Mobile
                  </h3>
                  <p className="text-xs text-[#545B6B] font-mono-spec mt-0.5">
                    Official Flutter Client · Android & iOS
                  </p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setDownloadModalOpen(false)}
                className="p-2 rounded-lg hover:bg-[#EDE9DF] text-[#545B6B] hover:text-[#111622] transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="space-y-4">
              {/* Option 1: Android Release APK */}
              <div className="p-4 rounded-xl bg-[#EDE9DF] border border-[#D5CFC2] space-y-3">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <span className="w-2.5 h-2.5 rounded-full bg-[#1E6B52]" />
                    <span className="font-serif-editorial text-lg text-[#111622]">Android APK Package</span>
                  </div>
                  <span className="font-mono-spec text-xs text-[#1E6B52] font-semibold">
                    v1.0.0 Release
                  </span>
                </div>
                <p className="text-xs text-[#545B6B] leading-relaxed">
                  Install directly on your Android device or emulator. Connects seamlessly to the local/remote PostgreSQL & TimescaleDB campaign backend.
                </p>
                <div className="pt-1 flex items-center gap-3">
                  <a
                    href="/downloads/CampaignGrid.apk"
                    download="CampaignGrid.apk"
                    onClick={() => {
                      alert('APK download initiated! When prompted on Android, allow installation from unknown sources.');
                    }}
                    className="px-4 py-2 rounded-lg bg-[#0D47A1] hover:bg-[#09357A] text-white text-xs font-medium flex items-center gap-2 transition-colors shadow-sm"
                  >
                    <Download className="w-3.5 h-3.5" />
                    <span>Download APK (32 MB)</span>
                  </a>
                  <span className="font-mono-spec text-[11px] text-[#545B6B]">SHA-256 Verified</span>
                </div>
              </div>

              {/* Option 2: iOS TestFlight / Mobile Profile */}
              <div className="p-4 rounded-xl bg-[#EDE9DF] border border-[#D5CFC2] space-y-3">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <span className="w-2.5 h-2.5 rounded-full bg-[#0D47A1]" />
                    <span className="font-serif-editorial text-lg text-[#111622]">iOS TestFlight Build</span>
                  </div>
                  <span className="font-mono-spec text-xs text-[#0D47A1] font-semibold">
                    Invite Beta
                  </span>
                </div>
                <p className="text-xs text-[#545B6B] leading-relaxed">
                  Available through Apple TestFlight for marketing governance officers and campaign reviewers on iPhone and iPad.
                </p>
                <button
                  type="button"
                  onClick={() => {
                    alert('TestFlight invitation requested! Please ensure your Apple ID is added to the enterprise internal tester team.');
                  }}
                  className="px-4 py-2 rounded-lg bg-[#111622] hover:bg-[#0D47A1] text-white text-xs font-medium flex items-center gap-2 transition-colors shadow-sm"
                >
                  <ArrowUpRight className="w-3.5 h-3.5" />
                  <span>Request TestFlight Access</span>
                </button>
              </div>

              {/* Developer Fast-Path */}
              <div className="p-3.5 rounded-xl bg-[#F6F4EE] border border-[#DED9CD] space-y-1.5">
                <div className="flex items-center gap-1.5 text-xs font-mono-spec text-[#545B6B]">
                  <Terminal className="w-3.5 h-3.5 text-[#0D47A1]" />
                  <span>Developer Quickstart:</span>
                </div>
                <div className="p-2 rounded bg-[#111622] text-[#F6F4EE] font-mono-spec text-[11px] select-all overflow-x-auto">
                  cd bit_loggers_app && flutter run -d chrome --web-port 8080
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ===================================================================
          MODAL 2: 15 ARCHITECTURE DECISION RECORDS (ADRs)
      =================================================================== */}
      {adrModalOpen && (
        <div className="fixed inset-0 z-50 bg-[#111622]/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-[#F6F4EE] border border-[#D5CFC2] rounded-2xl max-w-2xl w-full p-6 sm:p-8 shadow-2xl space-y-6 max-h-[85vh] overflow-y-auto">
            <div className="flex items-center justify-between border-b border-[#DED9CD] pb-4">
              <div>
                <h3 className="font-serif-editorial text-2xl text-[#111622]">
                  Architecture Decision Ledger (v2.0)
                </h3>
                <p className="text-xs text-[#545B6B] font-mono-spec mt-0.5">
                  15 Verified Decisions Protecting Campaign Governance
                </p>
              </div>
              <button
                type="button"
                onClick={() => setAdrModalOpen(false)}
                className="p-2 rounded-lg hover:bg-[#EDE9DF] text-[#545B6B] hover:text-[#111622] transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
              {ADR_LEDGER.map((adr) => (
                <div
                  key={adr.id}
                  className="p-3 rounded-lg bg-[#EDE9DF] border border-[#D5CFC2] flex items-start justify-between gap-3"
                >
                  <div>
                    <span className="font-mono-spec text-xs font-semibold text-[#0D47A1]">
                      ADR-{adr.id}
                    </span>
                    <div className="text-sm font-medium text-[#111622] mt-0.5">{adr.title}</div>
                  </div>
                  <span className="font-mono-spec text-[10px] text-[#545B6B] shrink-0">
                    {adr.area}
                  </span>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
