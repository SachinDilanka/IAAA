import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../theme/app_theme.dart';
import '../controllers/venue_controller.dart';
import '../providers/venue_provider.dart';

/// Available font size scale presets for high-contrast accessibility.
enum MessageCardFontSize {
  small(label: 'S', name: 'Small', sinhalaSize: 22.0, englishSize: 16.0),
  medium(label: 'M', name: 'Medium', sinhalaSize: 28.0, englishSize: 20.0),
  large(label: 'L', name: 'Large', sinhalaSize: 38.0, englishSize: 26.0),
  extraLarge(label: 'XL', name: 'Extra Large', sinhalaSize: 48.0, englishSize: 32.0);

  final String label;
  final String name;
  final double sinhalaSize;
  final double englishSize;

  const MessageCardFontSize({
    required this.label,
    required this.name,
    required this.sinhalaSize,
    required this.englishSize,
  });
}

/// Single shared modal overlay function for displaying selected messages.
///
/// Features:
/// - Opens via root navigator so it appears above bottom navigation bar and any docked panels.
/// - Centered modal dialog, visible immediately without scrolling.
/// - High-contrast billboard card style matching card_view.html and 04_card_display.png.
/// - Sinhala text displayed first in bold yellow (#ffee00) with text-shadow,
///   followed by a yellow divider, and English text below in clean white.
/// - Scales to fit and scrolls if message is long.
/// - Text size controls (Small, Medium, Large, Extra Large).
/// - 180° Flip button for showing across counter/desk.
/// - Close (X) button, Copy button, dismiss on outside tap or back press.
/// - Keeps screen awake while card is open (wakelock_plus) and releases on close.
/// - Does not speak message automatically.
/// - Leaves background list scroll offset completely unchanged.
/// - Defers any automatic GPS venue switch until the card is closed.
Future<void> showMessageCard(
  BuildContext context, {
  required String sinhala,
  String? english,
  String? categoryName,
  int? id,
  VenueController? venueController,
}) async {
  final controller = venueController ?? VenueProvider.maybeOf(context);
  controller?.setCardOverlayOpen(true);
  try {
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierColor: AppTheme.darkBackground.withValues(alpha: 0.88),
      builder: (BuildContext ctx) => MessageCardOverlay(
        sinhala: sinhala,
        english: english,
        categoryName: categoryName,
        id: id,
      ),
    );
  } finally {
    controller?.setCardOverlayOpen(false);
  }
}

/// The stateful message card overlay widget.
class MessageCardOverlay extends StatefulWidget {
  final String sinhala;
  final String? english;
  final String? categoryName;
  final int? id;

  const MessageCardOverlay({
    super.key,
    required this.sinhala,
    this.english,
    this.categoryName,
    this.id,
  });

  @override
  State<MessageCardOverlay> createState() => _MessageCardOverlayState();
}

class _MessageCardOverlayState extends State<MessageCardOverlay> {
  MessageCardFontSize _fontSize = MessageCardFontSize.large;
  bool _isFlipped = false;
  bool _copied = false;
  Timer? _copyResetTimer;

  @override
  void initState() {
    super.initState();
    _enableWakelock();
  }

  @override
  void dispose() {
    _copyResetTimer?.cancel();
    _disableWakelock();
    super.dispose();
  }

  Future<void> _enableWakelock() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {
      // Gracefully ignore platform channel errors in test / unsupported environments
    }
  }

  Future<void> _disableWakelock() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {
      // Gracefully ignore platform channel errors in test / unsupported environments
    }
  }

  void _copyToClipboard() {
    final hasEnglish = widget.english != null && widget.english!.trim().isNotEmpty;
    final textToCopy = hasEnglish
        ? '${widget.sinhala.trim()} / ${widget.english!.trim()}'
        : widget.sinhala.trim();

    Clipboard.setData(ClipboardData(text: textToCopy));
    setState(() {
      _copied = true;
    });

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied to clipboard! / පණිවිඩය පිටපත් කරන ලදී!'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    _copyResetTimer?.cancel();
    _copyResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _copied = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final hasEnglish = widget.english != null && widget.english!.trim().isNotEmpty;
    final cleanEnglish = widget.english?.trim() ?? '';

    return PopScope(
      canPop: true,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 620,
            maxHeight: media.size.height * 0.92,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Controls Toolbar matching card_view.html .billboard-toolbar
                  _buildToolbar(),

                  const SizedBox(height: 10),

                  // Billboard Message Card
                  Flexible(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
                        border: Border.all(
                          color: AppTheme.accentYellow,
                          width: AppTheme.cardBorderWidth,
                        ),
                        boxShadow: AppTheme.billboardCardShadow,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      child: RotatedBox(
                        quarterTurns: _isFlipped ? 2 : 0,
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Optional Category/ID Badge
                              if (widget.categoryName != null || widget.id != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                  ),
                                  child: Text(
                                    widget.id != null
                                        ? '#${widget.id}  ${widget.categoryName ?? ''}'
                                        : '${widget.categoryName}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppTheme.accentYellow,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Billboard Icon matching card_view.html .billboard-icon
                              const Icon(
                                Icons.chat_bubble_rounded,
                                size: 48,
                                color: AppTheme.accentYellow,
                              ),

                              const SizedBox(height: 18),

                              // Sinhala Primary Message matching .billboard-text-si
                              SelectableText(
                                widget.sinhala,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: _fontSize.sinhalaSize,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.accentYellow,
                                  height: 1.35,
                                  shadows: AppTheme.sinhalaTextShadow,
                                ),
                              ),

                              // Yellow Divider matching .billboard-divider
                              if (hasEnglish) ...[
                                const SizedBox(height: 16),
                                Container(
                                  width: 72,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentYellowMuted,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // English Secondary Message matching .billboard-text
                                SelectableText(
                                  cleanEnglish,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: _fontSize.englishSize,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textWhite,
                                    height: 1.25,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],

                              const SizedBox(height: 20),

                              // Instruction note for user / staff
                              Text(
                                'Show this screen to the staff member / කාර්ය මණ්ඩලයට පෙන්වන්න',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Bottom Action Buttons: Copy and Close
                  _buildBottomActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Top controls bar containing Text Size selector chips, Flip 180° button, and Close (X).
  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.toolbarBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.toolbarBorder),
      ),
      child: Row(
        children: [
          // Text Size Selector Chips (S, M, L, XL)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: MessageCardFontSize.values.map((size) {
                  final isSelected = _fontSize == size;
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _fontSize = size;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.accentYellow : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppTheme.accentYellow : Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          size.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Right Toolbar Controls: Flip Button & Close Button
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 180° Flip Button matching card_view.html #flip-text-btn
              InkWell(
                onTap: () {
                  setState(() {
                    _isFlipped = !_isFlipped;
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: _isFlipped ? AppTheme.accentYellow : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isFlipped ? AppTheme.accentYellow : Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.rotate_90_degrees_cw,
                        size: 14,
                        color: _isFlipped ? Colors.black : Colors.white,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '180°',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _isFlipped ? Colors.black : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Close (X) Button
              IconButton(
                key: const Key('message_card_close_button'),
                icon: const Icon(Icons.close, color: Colors.white, size: 22),
                tooltip: 'Close / වසන්න',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Bottom action bar with prominent Copy and Close buttons.
  Widget _buildBottomActions() {
    return Row(
      children: [
        // Copy Button matching requirements
        Expanded(
          flex: 3,
          child: ElevatedButton.icon(
            key: const Key('message_card_copy_button'),
            onPressed: _copyToClipboard,
            icon: Icon(_copied ? Icons.check : Icons.copy, size: 16),
            label: Text(
              _copied ? 'Copied! / පිටපත් කළා' : 'Copy / පිටපත් කරන්න',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentYellow,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Dismiss / Close Button
        Expanded(
          flex: 2,
          child: OutlinedButton(
            key: const Key('message_card_dismiss_button'),
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
      ],
    );
  }
}
