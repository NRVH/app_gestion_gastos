import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/expense_provider.dart';
import '../../../../core/providers/contribution_provider.dart';
import '../../../../core/providers/category_provider.dart';
import '../../../../core/providers/household_provider.dart';
import '../../../../core/providers/member_provider.dart';
import '../../../../core/models/expense.dart';
import '../../../../core/models/contribution.dart';
import '../../../../core/models/category.dart';
import '../../../../core/models/member.dart';
import '../../../../core/utils/formatters.dart';

class StatsTab extends ConsumerStatefulWidget {
  const StatsTab({super.key});

  @override
  ConsumerState<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends ConsumerState<StatsTab> {
  bool _showByCategory = true;

  Color _parseColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) return Colors.grey;
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final householdAsync = ref.watch(currentHouseholdProvider);
    final expensesAsync = ref.watch(expensesProvider);
    final contributionsAsync = ref.watch(contributionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final membersAsync = ref.watch(householdMembersProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Estadísticas'),
          ),

          // Toggle view
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Por categoría'),
                    icon: Icon(Icons.category),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Por miembro'),
                    icon: Icon(Icons.person),
                  ),
                ],
                selected: {_showByCategory},
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() {
                    _showByCategory = newSelection.first;
                  });
                },
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: householdAsync.when(
              data: (household) {
                if (household == null) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No hay household activo'),
                    ),
                  );
                }

                return Column(
                  children: [
                    // Overview stats
                    _buildOverviewStats(
                      household,
                      expensesAsync,
                      contributionsAsync,
                    ),

                    // Main chart
                    if (_showByCategory)
                      _buildCategoryStats(expensesAsync, categoriesAsync)
                    else
                      _buildMemberStats(contributionsAsync, membersAsync),

                    // Recent activity
                    _buildRecentActivity(expensesAsync, contributionsAsync),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStats(
    household,
    AsyncValue<List<Expense>> expensesAsync,
    AsyncValue<List<Contribution>> contributionsAsync,
  ) {
    final totalExpenses = expensesAsync.value?.fold<double>(
          0,
          (sum, expense) => sum + expense.amount,
        ) ??
        0;

    final totalContributions = contributionsAsync.value?.fold<double>(
          0,
          (sum, contribution) => sum + contribution.amount,
        ) ??
        0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen del mes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total gastado',
                  CurrencyFormatter.format(totalExpenses),
                  Icons.shopping_cart,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Total aportado',
                  CurrencyFormatter.format(totalContributions),
                  Icons.savings,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Balance',
                  CurrencyFormatter.format(totalContributions - totalExpenses),
                  Icons.account_balance,
                  totalContributions >= totalExpenses
                      ? Colors.green
                      : Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Gastos',
                  '${expensesAsync.value?.length ?? 0}',
                  Icons.receipt,
                  Colors.blue,
                  isCount: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool isCount = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryStats(
    AsyncValue<List<Expense>> expensesAsync,
    AsyncValue<List<Category>> categoriesAsync,
  ) {
    return expensesAsync.when(
      data: (expenses) {
        if (expenses.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No hay gastos para mostrar')),
          );
        }

        return categoriesAsync.when(
          data: (categories) {
            // Group expenses by category
            final categoryTotals = <String, double>{};
            final categoryColors = <String, Color>{};
            final categoryNames = <String, String>{};

            for (final expense in expenses) {
              categoryTotals[expense.categoryId] =
                  (categoryTotals[expense.categoryId] ?? 0) + expense.amount;

              final category = categories.firstWhere(
                (c) => c.id == expense.categoryId,
                orElse: () => Category(
                  id: expense.categoryId,
                  name: 'Otros',
                  monthlyLimit: 0,
                  icon: '❓',
                  color: '#808080',
                ),
              );
              categoryColors[expense.categoryId] = _parseColor(category.color);
              categoryNames[expense.categoryId] = category.name;
            }

            final total = categoryTotals.values.fold<double>(0, (a, b) => a + b);

            return Padding(
              padding: const EdgeInsets.all(16),
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
                  const SizedBox(height: 16),
                  _buildPieChart(categoryTotals, categoryColors, categoryNames),
                  const SizedBox(height: 16),
                  ...categoryTotals.entries.map((entry) {
                    final percentage = (entry.value / total * 100);
                    return _buildCategoryStatItem(
                      categoryNames[entry.key] ?? 'Desconocido',
                      entry.value,
                      percentage,
                      categoryColors[entry.key] ?? Colors.grey,
                    );
                  }).toList(),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Error al cargar categorías')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error al cargar gastos')),
    );
  }

  Widget _buildMemberStats(
    AsyncValue<List<Contribution>> contributionsAsync,
    AsyncValue<List<Member>> membersAsync,
  ) {
    return contributionsAsync.when(
      data: (contributions) {
        if (contributions.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No hay contribuciones para mostrar')),
          );
        }

        return membersAsync.when(
          data: (members) {
            // Group contributions by member
            final memberTotals = <String, double>{};
            final memberNames = <String, String>{};

            for (final contribution in contributions) {
              memberTotals[contribution.by] =
                  (memberTotals[contribution.by] ?? 0) +
                      contribution.amount;

              final member = members.firstWhere(
                (m) => m.uid == contribution.by,
                orElse: () => Member(
                  uid: contribution.by,
                  displayName: 'Desconocido',
                  role: MemberRole.partner,
                  share: 0,
                ),
              );
              memberNames[contribution.by] = member.displayName;
            }

            final total = memberTotals.values.fold<double>(0, (a, b) => a + b);

            // Generate colors for members
            final memberColors = <String, Color>{};
            final colors = [
              Colors.blue,
              Colors.purple,
              Colors.orange,
              Colors.green,
              Colors.red,
            ];
            int colorIndex = 0;
            for (final memberId in memberTotals.keys) {
              memberColors[memberId] = colors[colorIndex % colors.length];
              colorIndex++;
            }

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contribuciones por miembro',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPieChart(memberTotals, memberColors, memberNames),
                  const SizedBox(height: 16),
                  ...memberTotals.entries.map((entry) {
                    final percentage = (entry.value / total * 100);
                    return _buildCategoryStatItem(
                      memberNames[entry.key] ?? 'Desconocido',
                      entry.value,
                      percentage,
                      memberColors[entry.key] ?? Colors.grey,
                    );
                  }).toList(),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Error al cargar miembros')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error al cargar contribuciones')),
    );
  }

  Widget _buildPieChart(
    Map<String, double> data,
    Map<String, Color> colors,
    Map<String, String> names,
  ) {
    return AspectRatio(
      aspectRatio: 1.5,
      child: CustomPaint(
        painter: _PieChartPainter(data, colors),
      ),
    );
  }

  Widget _buildCategoryStatItem(
    String name,
    double amount,
    double percentage,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.format(amount),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(
    AsyncValue<List<Expense>> expensesAsync,
    AsyncValue<List<Contribution>> contributionsAsync,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Actividad reciente',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                expensesAsync.when(
                  data: (expenses) {
                    final recentExpenses = expenses.take(3).toList();
                    if (recentExpenses.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No hay gastos recientes'),
                      );
                    }
                    return Column(
                      children: recentExpenses
                          .map((expense) => ListTile(
                                leading: const Icon(Icons.remove_circle,
                                    color: Colors.red),
                                title: Text(expense.note.isEmpty ? 'Gasto sin descripción' : expense.note),
                                subtitle: Text(
                                    DateFormatter.formatDate(expense.date)),
                                trailing: Text(
                                  CurrencyFormatter.format(expense.amount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ))
                          .toList(),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Error al cargar gastos'),
                  ),
                ),
                const Divider(),
                contributionsAsync.when(
                  data: (contributions) {
                    final recentContributions = contributions.take(3).toList();
                    if (recentContributions.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No hay contribuciones recientes'),
                      );
                    }
                    return Column(
                      children: recentContributions
                          .map((contribution) => ListTile(
                                leading: const Icon(Icons.add_circle,
                                    color: Colors.green),
                                title: Text(contribution.note.isEmpty ? 'Contribución' : contribution.note),
                                subtitle: Text(DateFormatter.formatDate(
                                    contribution.date)),
                                trailing: Text(
                                  CurrencyFormatter.format(contribution.amount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ))
                          .toList(),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Error al cargar contribuciones'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final Map<String, double> data;
  final Map<String, Color> colors;

  _PieChartPainter(this.data, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2.5;
    final total = data.values.fold<double>(0, (a, b) => a + b);

    double startAngle = -math.pi / 2;

    for (final entry in data.entries) {
      final sweepAngle = (entry.value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = colors[entry.key] ?? Colors.grey
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
    }

    // Draw white circle in center (donut style)
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.6, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
