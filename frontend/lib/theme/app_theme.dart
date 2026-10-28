import 'package:flutter/material.dart';

/// ============================================================================
/// ASSISTCOMM FLUTTER APPLICATION THEME
/// ============================================================================
/// Derived directly from the original web application stylesheets:
/// - app/static/css/design_system.css
/// - app/static/css/mobile.css
/// - app/static/css/components.css
/// - app/templates/card_view.html
/// - app/templates/mobile.html
///
/// ----------------------------------------------------------------------------
/// FONT REPORT & AUDIT:
/// ----------------------------------------------------------------------------
/// Original Fonts:
/// 1. Body & UI Text: 'Inter' (sans-serif)
/// 2. Headings & Billboard English: 'Outfit' (sans-serif)
/// 3. Sinhala Text: Browser / OS system font chain
///    (e.g., 'Iskoola Pota', 'Noto Sans Sinhala', 'Malithi Web')
///
/// DO FONT FILES EXIST IN THE PROJECT?
/// - NO. Font asset files (.ttf / .otf / .woff / .woff2) DO NOT exist in the project repository.
/// - In the original web application, fonts were loaded dynamically via Google Fonts CDN:
///   <link href="https://fonts.googleapis.com/css2?family=Inter:wght@700;800;900&family=Outfit:wght@700;900&display=swap" rel="stylesheet">
/// - In Flutter, the font family names ('Inter' and 'Outfit') are declared below.
///   If custom offline TTF files are added to `assets/fonts/` and registered in
///   `pubspec.yaml`, Flutter will render them immediately; otherwise Flutter
///   seamlessly falls back to the host operating system's typography (Roboto /
///   San Francisco / system Sinhala glyphs).
/// ============================================================================

class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // 1. FONT FAMILY CONSTANTS
  // ---------------------------------------------------------------------------
  static const String fontMain = 'Inter';
  static const String fontHeading = 'Outfit';

  // Fallback font families list
  static const List<String> fontMainFallback = [
    'Inter',
    '-apple-system',
    'BlinkMacSystemFont',
    'Segoe UI',
    'Roboto',
    'Noto Sans Sinhala',
    'Iskoola Pota',
    'sans-serif',
  ];

  static const List<String> fontHeadingFallback = [
    'Outfit',
    'Inter',
    'Noto Sans Sinhala',
    'sans-serif',
  ];

  // ---------------------------------------------------------------------------
  // 2. COLOR PALETTE: CORE & BRAND TOKENS
  // ---------------------------------------------------------------------------
  // Primary brand blues
  static const Color primary = Color(0xFF2563EB); // Royal Blue #2563eb
  static const Color primaryHover = Color(0xFF1D4ED8); // #1d4ed8
  static const Color primaryDark = Color(0xFF1E40AF); // #1e40af
  static const Color primaryLight = Color(0xFFEFF6FF); // #eff6ff

  // Cyan Accent & GPS Radar Glow
  static const Color accentCyan = Color(0xFF38BDF8); // #38bdf8
  static const Color accentHover = Color(0xFF0284C7); // #0284c7
  static const Color cyanRadarTrack = Color(0x5938BDF8); // 35% opacity

  // Surface, Card & Background (Light Mode)
  static const Color backgroundLight = Color(0xFFF8FAFC); // --phone-bg: #f8fafc
  static const Color surfaceLight = Color(0xFFFFFFFF); // --card-bg: #ffffff
  static const Color borderLight = Color(0xFFE2E8F0); // #e2e8f0
  static const Color borderHover = Color(0xFFCBD5E1); // #cbd5e1

  // Surface, Card & Background (Dark Mode)
  static const Color backgroundDark = Color(0xFF0B0F17); // #0b0f17
  static const Color surfaceDark = Color(0xFF161E2E); // #161e2e
  static const Color cardDark = Color(0xFF1E293B); // #1e293b
  static const Color borderDark = Color(0xFF2D3748); // #2d3748
  static const Color headerDark = Color(0xFF0F172A); // #0f172a

  // High-Contrast Billboard Palette (card_view.html)
  static const Color billboardBlack = Color(0xFF000000);
  static const Color billboardCardBg = Color(0xFF121212);
  static const Color billboardYellow = Color(0xFFFFEE00); // #ffee00
  static const Color billboardYellowMuted = Color(0x73FFEE00); // 45% opacity
  static const Color billboardToolbarBg = Color(0x1AFFFFFF); // 10% opacity
  static const Color billboardToolbarBorder = Color(0x33FFFFFF); // 20% opacity

  // Compatibility aliases for legacy overlay consumers
  static const Color darkBackground = billboardBlack;
  static const Color cardBackground = billboardCardBg;
  static const Color accentYellow = billboardYellow;
  static const Color accentYellowMuted = billboardYellowMuted;
  static const Color toolbarBackground = billboardToolbarBg;
  static const Color toolbarBorder = billboardToolbarBorder;
  static const double cardBorderRadius = 24.0;
  static const double cardBorderWidth = 4.0;

  // Typography Colors
  static const Color textMain = Color(0xFF0F172A); // #0f172a
  static const Color textSub = Color(0xFF334155); // #334155
  static const Color textMuted = Color(0xFF64748B); // #64748b
  static const Color textDisabled = Color(0xFF94A3B8); // #94a3b8
  static const Color textWhite = Color(0xFFFFFFFF);

  // Status & Feedback Indicators
  static const Color liveGreen = Color(0xFF10B981); // #10b981
  static const Color liveDot = Color(0xFF0F172A); // #0f172a
  static const Color warningAmber = Color(0xFFF59E0B); // #f59e0b
  static const Color dangerRed = Color(0xFFEF4444); // #ef4444
  static const Color infoBlue = Color(0xFF2563EB); // #2563eb

  // ---------------------------------------------------------------------------
  // 3. COLOR PALETTE: PREDEFINED VENUE CATEGORIES
  // ---------------------------------------------------------------------------
  // Hospital (Red / Rose)
  static const Color hospitalColor = Color(0xFFEF4444);
  static const Color hospitalBackground = Color(0xFFFEE2E2);
  static const Color hospitalDark = Color(0xFFDC2626);
  static const Color hospitalBorder = Color(0xFFFCA5A5);

  // Bank (Royal Blue)
  static const Color bankColor = Color(0xFF2563EB);
  static const Color bankBackground = Color(0xFFDBEAFE);
  static const Color bankDark = Color(0xFF1D4ED8);
  static const Color bankBorder = Color(0xFF93C5FD);

  // Restaurant (Warm Amber / Orange)
  static const Color restaurantColor = Color(0xFFF59E0B);
  static const Color restaurantBackground = Color(0xFFFEF3C7);
  static const Color restaurantDark = Color(0xFFD97706);
  static const Color restaurantBorder = Color(0xFFFDE68A);

  // Supermarket (Fresh Emerald Green)
  static const Color supermarketColor = Color(0xFF10B981);
  static const Color supermarketBackground = Color(0xFFDCFCE7);
  static const Color supermarketDark = Color(0xFF059669);
  static const Color supermarketBorder = Color(0xFFA7F3D0);

  // Pharmacy (Purple)
  static const Color pharmacyColor = Color(0xFF8B5CF6);
  static const Color pharmacyBackground = Color(0xFFEDE9FE);

  // Outside Predefined Venues (Indigo)
  static const Color outsideColor = Color(0xFF6366F1);
  static const Color outsideBackground = Color(0xFFE0E7FF);

  // ---------------------------------------------------------------------------
  // 4. SPACING & PADDING TOKENS (CSS equivalents)
  // ---------------------------------------------------------------------------
  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 12.0;
  static const double spaceLg = 16.0;
  static const double spaceXl = 20.0;
  static const double space2xl = 24.0;
  static const double space3xl = 32.0;

  static const EdgeInsets paddingScreen = EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);
  static const EdgeInsets paddingCard = EdgeInsets.all(16.0);
  static const EdgeInsets paddingButton = EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);

  // ---------------------------------------------------------------------------
  // 5. BORDER RADII (CSS variables)
  // ---------------------------------------------------------------------------
  static const double radiusSm = 8.0; // --radius-sm: 8px
  static const double radiusBtn = 14.0; // --radius-btn: 14px
  static const double radiusCard = 18.0; // --radius-card: 16-18px
  static const double radiusLg = 22.0; // --radius-lg: 20-22px
  static const double radiusPill = 9999.0; // 9999px fully rounded

  static final BorderRadius borderRadiusSm = BorderRadius.circular(radiusSm);
  static final BorderRadius borderRadiusBtn = BorderRadius.circular(radiusBtn);
  static final BorderRadius borderRadiusCard = BorderRadius.circular(radiusCard);
  static final BorderRadius borderRadiusLg = BorderRadius.circular(radiusLg);
  static final BorderRadius borderRadiusPill = BorderRadius.circular(radiusPill);

  // ---------------------------------------------------------------------------
  // 6. SHADOWS & GLOW EFFECTS
  // ---------------------------------------------------------------------------
  // Standard card elevation
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A000000), // rgba(0,0,0,0.04)
      blurRadius: 8.0,
      offset: Offset(0, 3),
    ),
  ];

  // Elevated floating toast / bottom sheet
  static const List<BoxShadow> toastShadow = [
    BoxShadow(
      color: Color(0x40000000), // rgba(0,0,0,0.25)
      blurRadius: 16.0,
      offset: Offset(0, 5),
    ),
  ];

  // Floating controls shadow
  static const List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: Color(0x1F000000), // rgba(0,0,0,0.12)
      blurRadius: 5.0,
      offset: Offset(0, 2),
    ),
  ];

  // Billboard High-Contrast Yellow Glow (card_view.html: 0 0 40px rgba(255, 238, 0, 0.25))
  static const List<BoxShadow> billboardCardShadow = [
    BoxShadow(
      color: Color(0x40FFEE00),
      blurRadius: 40.0,
      spreadRadius: 2.0,
      offset: Offset(0, 0),
    ),
  ];

  // Sinhala Text Glow (card_view.html: 0 0 25px rgba(255, 238, 0, 0.35))
  static const List<Shadow> sinhalaTextShadow = [
    Shadow(
      color: Color(0x59FFEE00),
      blurRadius: 25.0,
      offset: Offset(0, 0),
    ),
  ];

  // ---------------------------------------------------------------------------
  // 7. TYPOGRAPHY & TEXT STYLES
  // ---------------------------------------------------------------------------
  // Eyebrow / Small Upper Tag (e.g., "CURRENT LOCATION")
  static const TextStyle textEyebrow = TextStyle(
    fontFamily: fontMain,
    fontSize: 10.0,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: textMuted,
  );

  // Main Card Title (e.g., "Detecting Location...")
  static const TextStyle textTitleMedium = TextStyle(
    fontFamily: fontHeading,
    fontSize: 17.5,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    color: textMain,
  );

  // Section Heading (e.g., "Select a Message")
  static const TextStyle textHeading = TextStyle(
    fontFamily: fontHeading,
    fontSize: 18.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    color: textMain,
  );

  // Sinhala Phrase Item (Bold, clear, accessible)
  static const TextStyle textSinhalaPhrase = TextStyle(
    fontFamily: fontMain,
    fontSize: 15.5,
    fontWeight: FontWeight.w700,
    color: textMain,
    height: 1.35,
  );

  // English Subtitle / Translation
  static const TextStyle textEnglishSubtitle = TextStyle(
    fontFamily: fontMain,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    color: textMuted,
  );

  // High-Contrast Billboard Sinhala Text
  static const TextStyle textBillboardSinhala = TextStyle(
    fontFamily: fontMain,
    fontSize: 32.0,
    fontWeight: FontWeight.w900,
    height: 1.3,
    color: billboardYellow,
    shadows: sinhalaTextShadow,
  );

  // High-Contrast Billboard English Text
  static const TextStyle textBillboardEnglish = TextStyle(
    fontFamily: fontHeading,
    fontSize: 24.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    color: textWhite,
    height: 1.25,
  );

  // ---------------------------------------------------------------------------
  // 8. BUTTON STYLES
  // ---------------------------------------------------------------------------
  // Primary Blue Action Button
  static final ButtonStyle buttonPrimary = ElevatedButton.styleFrom(
    backgroundColor: primary,
    foregroundColor: textWhite,
    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusBtn)),
    elevation: 2.0,
    textStyle: const TextStyle(
      fontFamily: fontMain,
      fontSize: 14.0,
      fontWeight: FontWeight.w700,
    ),
  );

  // Secondary Outlined Button
  static final ButtonStyle buttonOutlined = OutlinedButton.styleFrom(
    foregroundColor: textMain,
    side: const BorderSide(color: borderLight, width: 1.5),
    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusBtn)),
    textStyle: const TextStyle(
      fontFamily: fontMain,
      fontSize: 13.0,
      fontWeight: FontWeight.w600,
    ),
  );

  // Live Status Badge Pill (LIVE button on Hero Card)
  static final BoxDecoration liveBadgeDecoration = BoxDecoration(
    color: surfaceLight,
    borderRadius: BorderRadius.circular(radiusPill),
    border: Border.all(color: borderLight, width: 1.2),
    boxShadow: const [
      BoxShadow(
        color: Color(0x0D000000),
        blurRadius: 4.0,
        offset: Offset(0, 1),
      ),
    ],
  );

  // Category Criteria Button Box (Hospital, Bank, etc.)
  static BoxDecoration categoryBoxDecoration({
    required Color color,
    bool isSelected = false,
  }) {
    return BoxDecoration(
      color: isSelected ? color : color.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(radiusCard),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.28),
          blurRadius: 8.0,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 9. FLUTTER THEMEDATA BUILDERS
  // ---------------------------------------------------------------------------
  /// Light Theme (Default Mobile Experience)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: accentCyan,
        surface: surfaceLight,
        error: dangerRed,
        onPrimary: textWhite,
        onSecondary: textMain,
        onSurface: textMain,
        onError: textWhite,
      ),
      fontFamily: fontMain,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceLight,
        foregroundColor: textMain,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontHeading,
          fontSize: 17.5,
          fontWeight: FontWeight.w800,
          color: textMain,
          letterSpacing: -0.3,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceLight,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontFamily: fontMain,
          fontSize: 11.0,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: fontMain,
          fontSize: 11.0,
          fontWeight: FontWeight.w500,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: borderLight, width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: buttonPrimary),
      outlinedButtonTheme: OutlinedButtonThemeData(style: buttonOutlined),
      dividerTheme: const DividerThemeData(
        color: borderLight,
        thickness: 1.0,
        space: 1.0,
      ),
    );
  }

  /// Dark Mode Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: accentCyan,
      scaffoldBackgroundColor: backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: accentCyan,
        secondary: primary,
        surface: surfaceDark,
        error: dangerRed,
        onPrimary: textMain,
        onSecondary: textWhite,
        onSurface: textWhite,
        onError: textWhite,
      ),
      fontFamily: fontMain,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        foregroundColor: textWhite,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: borderDark, width: 1.0),
        ),
      ),
    );
  }

  /// High Contrast Accessibility Theme (card_view.html standard)
  static ThemeData get highContrastTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: billboardYellow,
      scaffoldBackgroundColor: billboardBlack,
      colorScheme: const ColorScheme.dark(
        primary: billboardYellow,
        secondary: textWhite,
        surface: billboardCardBg,
        error: dangerRed,
        onPrimary: billboardBlack,
        onSecondary: billboardBlack,
        onSurface: textWhite,
        onError: billboardBlack,
      ),
      fontFamily: fontMain,
      cardTheme: CardThemeData(
        color: billboardCardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: billboardYellow, width: 3.5),
        ),
      ),
    );
  }
}
