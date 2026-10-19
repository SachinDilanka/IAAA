class GestureAssetPaths {
  GestureAssetPaths._();

  static String? forLetter(String letter) {
    final normalizedLetter = letter.toLowerCase();
    if (normalizedLetter.length != 1 ||
        normalizedLetter.codeUnitAt(0) < 97 ||
        normalizedLetter.codeUnitAt(0) > 122 ||
        normalizedLetter == 'n') {
      return null;
    }

    final sampleName = switch (normalizedLetter) {
      'b' => 'b_first_way',
      'k' => 'k_first_way',
      _ => normalizedLetter,
    };
    return 'dataset/landmarks/letter/$sampleName/$sampleName.json';
  }

  static String forMonth(String englishMonth) {
    final normalizedMonth = englishMonth.toLowerCase();
    final sampleName = switch (normalizedMonth) {
      'march' => 'mrach',
      'september' => 'september_similar_to_s',
      _ => normalizedMonth,
    };
    return 'dataset/landmarks/month/$normalizedMonth/$sampleName.json';
  }

  static String forVerb(String sampleName) =>
      'dataset/landmarks/verb/$sampleName/$sampleName.json';

  static bool isMonthAsset(String assetPath) =>
      assetPath.replaceAll('\\', '/').contains('/month/');

  static bool isVerbAsset(String assetPath) =>
      assetPath.replaceAll('\\', '/').contains('/verb/');

  static bool isDynamicAsset(String assetPath) =>
      isMonthAsset(assetPath) || isVerbAsset(assetPath);

  static String? animationNameFor(
    String assetPath, {
    double playbackSpeed = 1.0,
  }) {
    final parts = assetPath.replaceAll('\\', '/').split('/');
    if (parts.length < 4 ||
        parts[0] != 'dataset' ||
        parts[1] != 'landmarks' ||
        !const {'letter', 'month', 'verb'}.contains(parts[2])) {
      return null;
    }

    final baseName = '${parts[2]}_${parts[3]}';
    if (parts[2] == 'letter') return baseName;
    final speedName = switch (playbackSpeed) {
      0.5 => '0_5x',
      0.75 => '0_75x',
      _ => '1x',
    };
    return '${baseName}_$speedName';
  }
}
