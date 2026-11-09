import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Curated high-resolution imagery and authentic ad preview components
/// specifically designed for enterprise marketing campaign intelligence.
class MarketingVisuals {
  // Curated authentic photography per marketing channel
  static const Map<String, String> defaultChannelImages = {
    'Social': 'https://images.unsplash.com/photo-1611162617213-7d7a39e9b1d7?w=600&auto=format&fit=crop&q=80',
    'Search': 'https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=600&auto=format&fit=crop&q=80',
    'Email': 'https://images.unsplash.com/photo-1557804506-669a67965ba0?w=600&auto=format&fit=crop&q=80',
    'Display': 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=600&auto=format&fit=crop&q=80',
    'Video': 'https://images.unsplash.com/photo-1492691527719-9d1e07e534b4?w=600&auto=format&fit=crop&q=80',
  };

  /// Returns a valid visual asset URL for any campaign flight
  static String getCampaignAssetUrl(String? channel, String? specificAssetUrl) {
    if (specificAssetUrl != null &&
        specificAssetUrl.startsWith('http') &&
        !specificAssetUrl.contains('placeholder.com')) {
      return specificAssetUrl;
    }
    final ch = channel ?? 'Social';
    return defaultChannelImages[ch] ?? defaultChannelImages['Social']!;
  }

  /// Human profiles for marketers and reviewers
  static const Map<String, Map<String, String>> teamProfiles = {
    'usr-marketer-1': {
      'name': 'Elena Rostova',
      'role': 'Growth Lead',
      'initials': 'ER',
      'avatarUrl': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80',
    },
    'usr-reviewer-1': {
      'name': 'Marcus Vance',
      'role': 'Brand Director',
      'initials': 'MV',
      'avatarUrl': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&auto=format&fit=crop&q=80',
    },
    'usr-marketer-2': {
      'name': 'Devon Cross',
      'role': 'Lifecycle Strategist',
      'initials': 'DC',
      'avatarUrl': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&auto=format&fit=crop&q=80',
    },
  };

  static Map<String, String> getProfile(String? userId) {
    return teamProfiles[userId ?? ''] ?? {
      'name': 'Marketing Lead',
      'role': 'Campaign Operations',
      'initials': 'ML',
      'avatarUrl': '',
    };
  }
}

/// A resilient, high-craft thumbnail for marketing creative assets.
/// Automatically handles network loading, graceful offline fallbacks,
/// and channel badge overlay.
class CreativeAssetThumbnail extends StatelessWidget {
  final String? assetUrl;
  final String channel;
  final double width;
  final double height;
  final double borderRadius;
  final bool showChannelBadge;

  const CreativeAssetThumbnail({
    super.key,
    this.assetUrl,
    required this.channel,
    this.width = 68,
    this.height = 68,
    this.borderRadius = 12,
    this.showChannelBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveUrl = MarketingVisuals.getCampaignAssetUrl(channel, assetUrl);
    final channelColor = AppTheme.getChannelColor(channel);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        color: channelColor.withOpacity(0.08),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              effectiveUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: AppTheme.paper,
                  child: Center(
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: channelColor.withOpacity(0.5),
                      ),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: channelColor.withOpacity(0.12),
                  child: Center(
                    child: Icon(
                      _getChannelIcon(channel),
                      size: width * 0.4,
                      color: channelColor,
                    ),
                  ),
                );
              },
            ),
            if (showChannelBadge)
              Positioned(
                bottom: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.forge.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    channel.toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.leaf,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getChannelIcon(String ch) {
    switch (ch.toLowerCase()) {
      case 'social':
        return Icons.photo_camera_outlined;
      case 'search':
        return Icons.search_outlined;
      case 'email':
        return Icons.mail_outline;
      case 'display':
        return Icons.view_quilt_outlined;
      case 'video':
        return Icons.play_circle_outline;
      default:
        return Icons.campaign_outlined;
    }
  }
}

/// Human Marketer / Reviewer Avatar with authentic photography and role label
class MarketerAvatar extends StatelessWidget {
  final String? userId;
  final double size;
  final bool showLabel;

  const MarketerAvatar({
    super.key,
    this.userId,
    this.size = 24,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final profile = MarketingVisuals.getProfile(userId);
    final avatarUrl = profile['avatarUrl'] ?? '';
    final initials = profile['initials'] ?? 'ML';
    final name = profile['name'] ?? 'Marketing Lead';

    final avatarWidget = ClipOval(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTheme.forge.withOpacity(0.08),
        ),
        child: avatarUrl.isNotEmpty
            ? Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildInitials(initials),
              )
            : _buildInitials(initials),
      ),
    );

    if (!showLabel) return avatarWidget;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        avatarWidget,
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInitials(String initials) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.bold,
          color: AppTheme.forge,
        ),
      ),
    );
  }
}

/// An authentic live marketing creative preview mockup (Social, Search, Email, Display)
class LiveCreativeMockupCanvas extends StatelessWidget {
  final String channel;
  final String title;
  final String? headline;
  final String? copy;
  final String? assetUrl;
  final double? targetCpa;

  const LiveCreativeMockupCanvas({
    super.key,
    required this.channel,
    required this.title,
    this.headline,
    this.copy,
    this.assetUrl,
    this.targetCpa,
  });

  @override
  Widget build(BuildContext context) {
    switch (channel.toLowerCase()) {
      case 'social':
        return _buildSocialMockup();
      case 'search':
        return _buildSearchMockup();
      case 'email':
        return _buildEmailMockup();
      case 'display':
      case 'video':
      default:
        return _buildDisplayMockup();
    }
  }

  // Instagram / TikTok style mobile sponsor card
  Widget _buildSocialMockup() {
    final effectiveImg = MarketingVisuals.getCampaignAssetUrl('Social', assetUrl);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.secondarySystemBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.appleCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Brand / Sponsor Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTheme.forge,
                  child: const Text('BL', style: TextStyle(color: AppTheme.leaf, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('BitLoggers Brand', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                          const SizedBox(width: 4),
                          Icon(Icons.verified, size: 12, color: AppTheme.getChannelColor('Social')),
                        ],
                      ),
                      const Text('Sponsored · Instagram Feed Comp', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.more_horiz, size: 16, color: AppTheme.textSecondary),
              ],
            ),
          ),

          // Creative Visual (16:10 aspect ratio)
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Image.network(
              effectiveImg,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppTheme.paper,
                child: const Center(child: Icon(Icons.photo_library_outlined, size: 36, color: AppTheme.textSecondary)),
              ),
            ),
          ),

          // Action Callout Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: const Color(0xFFF9FAFB),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    headline ?? title,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.forge,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Shop Now', style: TextStyle(color: AppTheme.leaf, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          // Copy / Caption
          Padding(
            padding: const EdgeInsets.all(14),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary, height: 1.4),
                children: [
                  const TextSpan(text: 'bitloggers ', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: copy ?? 'Limited seasonal release. Experience seamless performance optimization with verified audience reach.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Google Search SERP ad card
  Widget _buildSearchMockup() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.secondarySystemBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.appleCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Sponsored', style: TextStyle(color: Color(0xFF2E7D32), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              const Text('https://bitloggers.io/campaign', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            headline ?? title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A0DAB),
              decoration: TextDecoration.underline,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            copy ?? 'Discover high-performance campaign flight intelligence. Guaranteed low CPA and maximum ROAS with real-time portfolio telemetry.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF4D5156), height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildSearchSitelink('Pricing & Tiers'),
              _buildSearchSitelink('Live Demo'),
              _buildSearchSitelink('Security Audit'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSitelink(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF1A0DAB), fontWeight: FontWeight.w500)),
    );
  }

  // VIP Newsletter email dispatch preview
  Widget _buildEmailMockup() {
    final effectiveImg = MarketingVisuals.getCampaignAssetUrl('Email', assetUrl);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.secondarySystemBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.appleCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Email header banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: AppTheme.separator, width: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.mail_outline, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Subject: ${headline ?? title}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Email Hero
          AspectRatio(
            aspectRatio: 16 / 7,
            child: Image.network(
              effectiveImg,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline ?? title,
                  style: const TextStyle(fontFamily: 'serif', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  copy ?? 'Dear Member, unlock exclusive early access to our seasonal campaign tier. Designed specifically for enterprise intelligence.',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.forge,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Claim Early Invitation →', style: TextStyle(color: AppTheme.leaf, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Display Leaderboard / Banner comp
  Widget _buildDisplayMockup() {
    final effectiveImg = MarketingVisuals.getCampaignAssetUrl('Display', assetUrl);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.secondarySystemBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.appleCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              effectiveImg,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline ?? title,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        copy ?? 'High-impact display ad creative across target programmatic networks.',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.forge,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Explore', style: TextStyle(color: AppTheme.leaf, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

