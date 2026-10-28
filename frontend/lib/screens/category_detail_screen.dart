import 'package:flutter/material.dart';
import '../models/communication_models.dart';
import '../widgets/sinhala_speech_box.dart';
import '../widgets/message_card_overlay.dart';

class CategoryDetailScreen extends StatelessWidget {
  final CommunicationCategory category;
  final VenueType venueType;

  const CategoryDetailScreen({
    super.key,
    required this.category,
    required this.venueType,
  });

  void _showFullscreenCard(BuildContext context, CommunicationMessage msg) {
    showMessageCard(
      context,
      sinhala: msg.templateSi,
      english: msg.templateEn,
      categoryName: category.nameEn,
      id: msg.id,
    );
  }

  void _showFullscreenCustomText(BuildContext context, String text) {
    final cleanText = text.trim();
    final bool hasSi = RegExp(r'[\u0D80-\u0DFF]').hasMatch(cleanText);

    String si = hasSi ? cleanText : '';
    String en = hasSi ? '' : cleanText;

    for (final m in category.messages) {
      if (si.isEmpty && en.isNotEmpty) {
        if (m.templateEn.trim().toLowerCase() == en.toLowerCase()) {
          si = m.templateSi;
          break;
        }
      }
      if (en.isEmpty && si.isNotEmpty) {
        if (m.templateSi.trim() == si || si.contains(m.templateSi.trim()) || m.templateSi.trim().contains(si)) {
          en = m.templateEn;
          break;
        }
      }
    }

    if (si.isEmpty) si = en.isNotEmpty ? 'පණිවිඩය: $en' : 'මම බිහිරි කෙනෙක්.';
    if (en.isEmpty) en = hasSi ? 'Live Sinhala Speech Detection' : (si.isNotEmpty ? si : 'I am deaf.');

    showMessageCard(
      context,
      sinhala: si,
      english: en,
      categoryName: category.nameEn,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              category.nameSi,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              category.nameEn,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: venueType.themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: Text(
              '${category.messages.length} msgs',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Live Sinhala Speech Box at the top of category screen
          SinhalaSpeechBox(
            themeColor: venueType.themeColor,
            onShowFullscreen: (txt) => _showFullscreenCustomText(context, txt),
          ),

          if (category.messages.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: Text('No messages available for this category.')),
            )
          else
            ...category.messages.map((msg) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: InkWell(
                  onTap: () => _showFullscreenCard(context, msg),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: venueType.backgroundColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${msg.id}',
                            style: TextStyle(
                              color: venueType.themeColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.templateSi,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                msg.templateEn,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.fullscreen, color: venueType.themeColor),
                          tooltip: 'Show Large Card',
                          onPressed: () => _showFullscreenCard(context, msg),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
