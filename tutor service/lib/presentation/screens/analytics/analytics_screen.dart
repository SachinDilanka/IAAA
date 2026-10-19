import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/database/database_helper.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  _AnalyticsScreenState createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<Map<String, dynamic>> _practiceLogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    final logs = await DatabaseHelper.instance.getPracticeLogs();
    if (!mounted) return;
    setState(() {
      _practiceLogs = logs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final scores = _practiceLogs.map(
      (log) => (log['dtw_accuracy_score'] as num).toDouble(),
    );
    final averageAccuracy = scores.isEmpty
        ? 0.0
        : scores.reduce((a, b) => a + b) / scores.length;
    final weeklyScores = _scoresForWindow(0, 7);
    final previousWeekScores = _scoresForWindow(7, 14);
    final weeklyChange = weeklyScores.isEmpty || previousWeekScores.isEmpty
        ? null
        : _average(weeklyScores) - _average(previousWeekScores);
    final dayAverages = _dayAverages();
    final bestDay = dayAverages.isEmpty
        ? null
        : dayAverages.entries.reduce(
            (best, entry) => entry.value >= best.value ? entry : best,
          );
    final weeklySpots = _weeklySpots();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1320),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'My Progress Analytics',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAnalyticsData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF171F2D),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _summaryMetric(
                        'Average Accuracy',
                        _practiceLogs.isEmpty
                            ? '—'
                            : '${averageAccuracy.round()}%',
                        '${_practiceLogs.length} practice ${_practiceLogs.length == 1 ? 'session' : 'sessions'}',
                      ),
                    ),
                    Container(
                      height: 70,
                      width: 1,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: _summaryMetric(
                          'Best Practice Day',
                          bestDay == null ? '—' : _weekdayName(bestDay.key),
                          bestDay == null
                              ? 'No practice data yet'
                              : '${bestDay.value.round()}% average accuracy',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Weekly Accuracy Trend',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                weeklyChange == null
                    ? 'Practice this week and next week to compare your trend.'
                    : '${weeklyChange >= 0 ? '+' : ''}${weeklyChange.round()}% vs. the previous 7 days',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.white60),
              ),
              const SizedBox(height: 12),
              Container(
                height: 220,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF171F2D),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: weeklySpots.isEmpty
                    ? Center(
                        child: Text(
                          'Your weekly accuracy trend will appear here after you practice.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.white60,
                          ),
                        ),
                      )
                    : LineChart(
                        LineChartData(
                          minX: 0,
                          maxX: 6,
                          minY: 0,
                          maxY: 100,
                          gridData: const FlGridData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  if (value < 0 || value > 6) {
                                    return const SizedBox.shrink();
                                  }
                                  final day = DateTime.now().subtract(
                                    Duration(
                                      days:
                                          DateTime.now().weekday -
                                          1 -
                                          value.toInt(),
                                    ),
                                  );
                                  return Text(
                                    _weekdayName(day.weekday).substring(0, 1),
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.white54,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: weeklySpots,
                              isCurved: true,
                              color: Colors.blueAccent,
                              barWidth: 4,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.blueAccent.withValues(
                                  alpha: 0.15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 24),
              Text(
                'Recent Practice',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              if (_practiceLogs.isEmpty)
                _emptyState()
              else
                ..._practiceLogs.take(8).map(_buildRecentPracticeTile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryMetric(String label, String value, String detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF79A8FF),
          ),
        ),
        Text(
          detail,
          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }

  List<double> _scoresForWindow(int startDaysAgo, int endDaysAgo) {
    final now = DateTime.now();
    return _practiceLogs
        .where((log) {
          final date = DateTime.parse(log['timestamp'] as String).toLocal();
          final age = now.difference(date).inDays;
          return age >= startDaysAgo && age < endDaysAgo;
        })
        .map((log) => (log['dtw_accuracy_score'] as num).toDouble())
        .toList();
  }

  Map<int, double> _dayAverages() {
    final grouped = <int, List<double>>{};
    for (final log in _practiceLogs) {
      final day = DateTime.parse(log['timestamp'] as String).toLocal().weekday;
      grouped
          .putIfAbsent(day, () => [])
          .add((log['dtw_accuracy_score'] as num).toDouble());
    }
    return {
      for (final entry in grouped.entries) entry.key: _average(entry.value),
    };
  }

  List<FlSpot> _weeklySpots() {
    final today = DateTime.now();
    final monday = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - 1));
    final grouped = <int, List<double>>{};
    for (final log in _practiceLogs) {
      final date = DateTime.parse(log['timestamp'] as String).toLocal();
      final day = DateTime(date.year, date.month, date.day);
      final index = day.difference(monday).inDays;
      if (index >= 0 && index < 7) {
        grouped
            .putIfAbsent(index, () => [])
            .add((log['dtw_accuracy_score'] as num).toDouble());
      }
    }
    return grouped.entries
        .map((entry) => FlSpot(entry.key.toDouble(), _average(entry.value)))
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));
  }

  Widget _buildRecentPracticeTile(Map<String, dynamic> log) {
    final score = (log['dtw_accuracy_score'] as num).toDouble();
    final date = DateTime.parse(log['timestamp'] as String).toLocal();
    final title = log['lesson_title'] as String? ?? 'Gesture';
    final color = score >= 70 ? Colors.green : Colors.orange;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF171F2D),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListTile(
          title: Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          subtitle: Text(
            '${date.day}/${date.month}/${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.white60),
          ),
          trailing: Text(
            '${score.round()}%',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF171F2D),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'No practice sessions yet. Complete a gesture practice and your results will show here.',
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(color: Colors.white60, fontSize: 13),
      ),
    );
  }

  double _average(List<double> values) =>
      values.reduce((a, b) => a + b) / values.length;

  String _weekdayName(int weekday) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[weekday - 1];
  }
}
