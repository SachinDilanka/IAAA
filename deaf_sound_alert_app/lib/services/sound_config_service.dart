import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/detected_sound.dart';
import '../models/sound_config.dart';

class SoundConfigService {
  static final SoundConfigService _instance = SoundConfigService._internal();
  factory SoundConfigService() => _instance;
  SoundConfigService._internal();

  List<SoundConfig> _configs = [];

  List<SoundConfig> get configs => _configs;

  final List<SoundConfig> _defaultConfigs = [
    SoundConfig(key: 'sinhala_udaw_', name: 'උදව් (Udaw - Help)', category: 'Sinhala Keyword', priority: PriorityLevel.high),
    SoundConfig(key: 'sinhala_anathurak_', name: 'අනතුරක් (Anathurak - Danger)', category: 'Sinhala Keyword', priority: PriorityLevel.high),
    SoundConfig(key: 'sinhala_beraganna_', name: 'බේරාගන්න (Beraganna - Save Me)', category: 'Sinhala Keyword', priority: PriorityLevel.high),
    SoundConfig(key: 'sinhala_ginnak_', name: 'ගින්නක් (Ginnak - Fire)', category: 'Sinhala Keyword', priority: PriorityLevel.high),
    SoundConfig(key: 'ambulance', name: 'Ambulance Siren (ගිලන් රථ ශබ්දය)', category: 'Environmental Sound', priority: PriorityLevel.high),
    SoundConfig(key: 'vehicle horns', name: 'Vehicle Horns (වාහන නාලාව)', category: 'Environmental Sound', priority: PriorityLevel.high),
    
    SoundConfig(key: 'sinhala_karadarayak_', name: 'කරදරයක් (Karadarayak - Trouble)', category: 'Sinhala Keyword', priority: PriorityLevel.medium),
    SoundConfig(key: 'sinhala_balagena_', name: 'බලාගෙන (Balaagena - Watch Out)', category: 'Sinhala Keyword', priority: PriorityLevel.medium),
    SoundConfig(key: 'sinhala_ehata_wenna_', name: 'එහාට වෙන්න (Ehata Wenna - Move Aside)', category: 'Sinhala Keyword', priority: PriorityLevel.medium),
    SoundConfig(key: 'baby crying', name: 'Baby Crying (ළදරු හැඬීම)', category: 'Environmental Sound', priority: PriorityLevel.medium),
    SoundConfig(key: 'dog_bark_dataset', name: 'Dog Barking (බල්ලන් බුරන ශබ්දය)', category: 'Environmental Sound', priority: PriorityLevel.medium),
    
    SoundConfig(key: 'sinhala_parissamin_', name: 'පරිස්සමින් (Parissamin - Be Careful)', category: 'Sinhala Keyword', priority: PriorityLevel.low),
    SoundConfig(key: 'road', name: 'Road Sounds (පාරේ ශබ්ද)', category: 'Environmental Sound', priority: PriorityLevel.low),
    SoundConfig(key: 'traffic', name: 'Traffic Noise (වාහන තදබදය)', category: 'Environmental Sound', priority: PriorityLevel.low),
  ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedJson = prefs.getString('sound_configs');

    if (savedJson != null) {
      try {
        final List list = jsonDecode(savedJson);
        _configs = list.map((e) => SoundConfig.fromJson(e)).toList();
      } catch (e) {
        _configs = List.from(_defaultConfigs);
      }
    } else {
      _configs = List.from(_defaultConfigs);
    }

    // Ensure all default configs exist in _configs (migrate older saved configs)
    for (var def in _defaultConfigs) {
      if (!_configs.any((c) => c.key == def.key)) {
        _configs.add(SoundConfig(
          key: def.key,
          name: def.name,
          category: def.category,
          priority: def.priority,
          isEnabled: def.isEnabled,
        ));
      }
    }
  }

  Future<void> updatePriority(String key, PriorityLevel newPriority) async {
    final idx = _configs.indexWhere((c) => c.key == key);
    if (idx != -1) {
      _configs[idx].priority = newPriority;
      await _save();
    }
  }

  Future<void> toggleEnabled(String key, bool enabled) async {
    final idx = _configs.indexWhere((c) => c.key == key);
    if (idx != -1) {
      _configs[idx].isEnabled = enabled;
      await _save();
    }
  }

  SoundConfig? getConfig(String key) {
    if (_configs.isEmpty) {
      _configs = List.from(_defaultConfigs);
    }
    
    // First try loaded configs
    for (var config in _configs) {
      if (config.key == key) return config;
    }

    // Fallback to default configs
    for (var config in _defaultConfigs) {
      if (config.key == key) return config;
    }

    // Dynamic fallback guaranteed non-null
    return SoundConfig(
      key: key,
      name: key,
      category: key.startsWith('sinhala_') ? 'Sinhala Keyword' : 'Environmental Sound',
      priority: PriorityLevel.high,
    );
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_configs.map((c) => c.toJson()).toList());
    await prefs.setString('sound_configs', jsonStr);
  }
}
