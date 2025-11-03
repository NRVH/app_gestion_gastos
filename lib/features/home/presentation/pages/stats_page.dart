import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/stats_provider.dart';
import '../../../../core/models/month_history.dart';
import '../../../../core/utils/formatters.dart';
import 'package:fl_chart/fl_chart.dart';

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  int _selectedMonthCount = 6; // Mostrar últimos 6 meses por defecto

  @override
  Widget build(BuildContext context) {
    final allTimeStatsAsync = ref.watch(allTimeStatsProvider);
    final recentMonthsAsync = ref.watch(recentMonthsProvider(_selectedMonthCount));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(allTimeStatsProvider);
              ref.invalidate(recentMonthsProvider(_selectedMonthCount));
            },
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumen de todos los tiempos
            allTimeStatsAsync.when(
              data: (stats) => _buildAllTimeStats(stats),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text('Error: $error'),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Selector de período
            _buildPeriodSelector(),

            const SizedBox(height: 16),

            // Gráfica de gastos por mes
            recentMonthsAsync.when(
              data: (months) => _buildMonthlyChart(months),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text('Error: $error'),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Gastos por categoría (todos los tiempos)
            allTimeStatsAsync.when(
              data: (stats) => _buildCategoryBreakdown(stats),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAllTimeStats(Map<String, dynamic> stats) {
    final totalSpent = stats['totalSpent'] as double;
    final totalContributed = stats['totalContributed'] as double;
    final monthsTracked = stats['monthsTracked'] as int;
    final averageMonthly = stats['averageMonthlySpending'] as double;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade400, Colors.blue.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.analytics,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumen histórico',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Todos los tiempos',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$monthsTracked ${monthsTracked == 1 ? "mes" : "meses"}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total gastado',
                  CurrencyFormatter.format(totalSpent),
                  Icons.trending_down,
                  Colors.red.shade300,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Total aportado',
                  CurrencyFormatter.format(totalContributed),
                  Icons.trending_up,
                  Colors.green.shade300,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'Promedio mensual',
            CurrencyFormatter.format(averageMonthly),
            Icons.bar_chart,
            Colors.orange.shade300,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Período',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPeriodChip('3 meses', 3),
                const SizedBox(width: 8),
                _buildPeriodChip('6 meses', 6),
                const SizedBox(width: 8),
                _buildPeriodChip('12 meses', 12),
                const SizedBox(width: 8),
                _buildPeriodChip('Todo', 999),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label, int months) {
    final isSelected = _selectedMonthCount == months;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedMonthCount = months;
        });
      },
      backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
      selectedColor: isDark 
          ? Colors.blueAccent.withOpacity(0.3)
          : Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: isDark 
          ? Colors.blueAccent.shade200
          : Theme.of(context).primaryColor,
      labelStyle: TextStyle(
        color: isDark 
            ? (isSelected ? Colors.white : Colors.grey.shade300)
            : (isSelected ? Colors.black87 : Colors.black54),
      ),
    );
  }

  Widget _buildMonthlyChart(List<MonthHistory> months) {
    if (months.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.insert_chart, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  'No hay datos para mostrar',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cierra un mes para ver estadísticas',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Ordenar meses de más antiguo a más reciente
    final sortedMonths = List<MonthHistory>.from(months)
      ..sort((a, b) => a.closedAt.compareTo(b.closedAt));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gastos por mes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: sortedMonths.map((m) => m.totalSpent).reduce((a, b) => a > b ? a : b) * 1.2,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final month = sortedMonths[groupIndex];
                        return BarTooltipItem(
                          '${month.id}\n${CurrencyFormatter.format(month.totalSpent)}',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= sortedMonths.length) return const Text('');
                          final month = sortedMonths[value.toInt()];
                          // Mostrar solo mes (formato: "Nov")
                          final parts = month.id.split('-');
                          if (parts.length != 2) return Text(month.id);
                          final monthNum = int.tryParse(parts[1]) ?? 1;
                          final monthNames = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 
                                             'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              monthNames[monthNum - 1],
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          if (value >= 1000) {
                            return Text('\$${(value / 1000).toStringAsFixed(0)}k');
                          }
                          return Text('\$${value.toInt()}');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1000,
                  ),
                  barGroups: List.generate(
                    sortedMonths.length,
                    (index) => BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: sortedMonths[index].totalSpent,
                          color: Colors.blue,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown(Map<String, dynamic> stats) {
    final categoryTotals = stats['categoryTotals'] as Map<String, Map<String, dynamic>>;
    
    if (categoryTotals.isEmpty) {
      return const SizedBox.shrink();
    }

    // Ordenar por total gastado
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => (b.value['totalSpent'] as double).compareTo(a.value['totalSpent'] as double));

    final totalSpent = stats['totalSpent'] as double;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gastos por categoría',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'Total histórico',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          ...sortedCategories.map((entry) {
            final categoryData = entry.value;
            final spent = categoryData['totalSpent'] as double;
            final percentage = totalSpent > 0 ? (spent / totalSpent) * 100 : 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _parseColor(categoryData['color'] as String?).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      categoryData['icon'] as String? ?? '📁',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                title: Text(
                  categoryData['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      '${percentage.toStringAsFixed(1)}% del total',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey[200],
                      color: _parseColor(categoryData['color'] as String?),
                    ),
                  ],
                ),
                trailing: Text(
                  CurrencyFormatter.format(spent),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _parseColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) return Colors.grey;
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }
}
