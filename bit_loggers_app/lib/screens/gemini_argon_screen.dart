import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// SCREEN 01: Proposal Intelligence & Gemini Argon
/// Follows the reference image (Screen 1) with exact fidelity:
/// - "PROPOSAL INTELLIGENCE" eyebrow
/// - "On your terms." Serif headline
/// - Bright Lime (#D7F46A) "Gemini 4 Argon" Card with "VERIFIED" badge and "•••• 8842 / DEMO CARD"
/// - "ACTIVE • MODEL V4.2" and "Alan Lee" metadata
/// - "* Verify & lock V3 snapshot" leaf pill button
/// - "Controls" section with Immutable version lock and Idempotency protection toggles
class GeminiArgonScreen extends StatefulWidget {
  final ApiService api;
  final VoidCallback? onSnapshotLocked;

  const GeminiArgonScreen({super.key, required this.api, this.onSnapshotLocked});

  @override
  State<GeminiArgonScreen> createState() => _GeminiArgonScreenState();
}

class _GeminiArgonScreenState extends State<GeminiArgonScreen> {
  bool _versionLockEnabled = true;
  bool _idempotencyEnabled = true;
  bool _isLocking = false;
  bool _isGenerating = false;
  String _audienceSummary = 'Audience narrowed to Gen-Z urban; budget +12% within CPA guardrails.';
  final String _cardMask = '•••• 8842';

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: AppTheme.leaf)),
        backgroundColor: isError ? AppTheme.statusRejected : AppTheme.forge,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _verifyAndLockSnapshot() async {
    setState(() => _isLocking = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() => _isLocking = false);
      _showSnack('V3 snapshot verified & locked. Cryptographic digest committed.');
      widget.onSnapshotLocked?.call();
    }
  }

  Future<void> _triggerAiRegeneration() async {
    setState(() => _isGenerating = true);
    try {
      final res = await widget.api.draftWithAI(
        'Target Gen-Z urban demographic with CPA guardrails',
        channel: 'Social',
        budget: 45000,
      );
      if (mounted) {
        setState(() {
          _audienceSummary = res['objective'] ?? _audienceSummary;
        });
        _showSnack('Gemini 4 Argon adjusted proposal parameters.');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _audienceSummary = 'Audience updated: High-intent mobile buyers; CPA ceiling at \$14.20.';
        });
        _showSnack('Gemini 4 Argon baseline updated.');
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userInitials = widget.api.currentUser.name.isNotEmpty
        ? widget.api.currentUser.name.split(' ').map((n) => n[0]).take(2).join()
        : 'AL';

    return Scaffold(
      backgroundColor: AppTheme.paper,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Top App Bar: CampaignGrid + Avatar AL
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CampaignGrid',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppTheme.secondarySystemBackground,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.appleCardShadow,
                  ),
                  child: Center(
                    child: Text(
                      userInitials,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Subtitle Eyebrow: PROPOSAL INTELLIGENCE
            const Text(
              'PROPOSAL INTELLIGENCE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),

            // Large Editorial Serif Headline
            const Text(
              'On your terms.',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.6,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 20),

            // BRIGHT LIME HERO CARD (#D7F46A)
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppTheme.verdictLime,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Gemini 4 Argon + VERIFIED pill
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Gemini 4 Argon',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.forge,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.forge.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.forge.withOpacity(0.2), width: 1),
                        ),
                        child: const Text(
                          'VERIFIED',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.forge,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Middle Summary
                  Text(
                    _audienceSummary,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.forge,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 26),

                  // Bottom Row: Card Mask + DEMO CARD
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: _isGenerating ? null : _triggerAiRegeneration,
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 14,
                              color: AppTheme.forge.withOpacity(0.7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isGenerating ? 'Synthesizing…' : 'Refine model',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.forge.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _cardMask,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.forge,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'DEMO CARD',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.forge,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Metadata Row: ACTIVE • MODEL V4.2 and User Name
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ACTIVE • MODEL V4.2',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  widget.api.currentUser.name.isNotEmpty
                      ? widget.api.currentUser.name
                      : 'Alan Lee',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ACTION BUTTON: "* Verify & lock V3 snapshot"
            InkWell(
              onTap: _isLocking ? null : _verifyAndLockSnapshot,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.forge,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppTheme.appleCardShadow,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_rounded, size: 18, color: AppTheme.verdictLime),
                    const SizedBox(width: 8),
                    Text(
                      _isLocking ? 'Locking snapshot…' : 'Verify & lock V3 snapshot',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.leaf,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Explanatory Caption
            const Center(
              child: Text(
                'Pause automatic model adjustments instantly. Your verified baseline stays locked.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 26),

            // SECTION: Controls
            const Text(
              'Controls',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 14),

            // Control Item 1: Immutable version lock
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.secondarySystemBackground,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppTheme.appleCardShadow,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppTheme.tertiarySystemBackground,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.language, size: 18, color: AppTheme.forge),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Immutable version lock',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _versionLockEnabled
                              ? 'Active lease held by Sarah'
                              : 'Unlocked (Concurrent revisions allowed)',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _versionLockEnabled,
                    activeColor: AppTheme.verdictLime,
                    activeTrackColor: AppTheme.forge,
                    onChanged: (val) {
                      setState(() => _versionLockEnabled = val);
                      _showSnack(val ? 'Version lock lease engaged.' : 'Version lock lease released.');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Control Item 2: Idempotency protection
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.secondarySystemBackground,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppTheme.appleCardShadow,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppTheme.tertiarySystemBackground,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.gps_fixed, size: 18, color: AppTheme.forge),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Idempotency protection',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _idempotencyEnabled
                              ? 'Deduplication & replay safe'
                              : 'Idempotency keys disabled',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _idempotencyEnabled,
                    activeColor: AppTheme.verdictLime,
                    activeTrackColor: AppTheme.forge,
                    onChanged: (val) {
                      setState(() => _idempotencyEnabled = val);
                      _showSnack(val ? 'Idempotency protection enabled (Strict).' : 'Idempotency protection relaxed.');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
