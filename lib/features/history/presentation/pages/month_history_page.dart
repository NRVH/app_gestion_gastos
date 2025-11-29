import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/month_history.dart';
import '../../../../core/models/expense.dart';
import '../../../../core/models/contribution.dart';
import '../../../../core/providers/household_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/config/theme_config.dart';

class MonthHistoryPage extends ConsumerStatefulWidget {
  const MonthHistoryPage({super.key});

  @override
  ConsumerState<MonthHistoryPage> createState() => _MonthHistoryPageState();
}

class _MonthHistoryPageState extends ConsumerState<MonthHistoryPage> {
  String? _selectedMonth;

  @override
  Widget build(BuildContext context) {
    final householdAsync = ref.watch(currentHouseholdProvider);
    final householdId = ref.watch(currentHouseholdIdProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    if (householdId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Histórico de Meses')),
        body: const Center(child: Text('No hay household seleccionado')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Meses'),
        backgroundColor: isDark ? null : theme.colorScheme.primary,
        foregroundColor: isDark ? null : Colors.white,
      ),
      body: StreamBuilder<List<MonthHistory>>(
        stream: ref.read(firestoreServiceProvider).watchMonthHistory(householdId),
        builder: (context, snapshot) {
          print('📊 [MonthHistoryPage] ConnectionState: ${snapshot.connectionState}');
          print('📊 [MonthHistoryPage] HasError: ${snapshot.hasError}');
          print('📊 [MonthHistoryPage] Error: ${snapshot.error}');
          print('📊 [MonthHistoryPage] HasData: ${snapshot.hasData}');
          print('📊 [MonthHistoryPage] Data length: ${snapshot.data?.length}');
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print('❌ [MonthHistoryPage] Error completo: ${snapshot.error}');
            print('❌ [MonthHistoryPage] StackTrace: ${snapshot.stackTrace}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error al cargar histórico: ${snapshot.error}'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Volver'),
                  ),
                ],
              ),
            );
          }

          final months = snapshot.data ?? [];
          print('📊 [MonthHistoryPage] Meses recibidos: ${months.length}');
          
          if (months.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay meses cerrados',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Los meses cerrados aparecerán aquí',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          // Ordenar meses de más reciente a más antiguo
          try {
            print('🔄 [MonthHistoryPage] Ordenando ${months.length} meses...');
            for (var i = 0; i < months.length; i++) {
              print('  📅 Mes $i: id=${months[i].id}, type=${months[i].runtimeType}');
            }
            months.sort((a, b) {
              print('    🔍 Comparando: a.id=${a.id} vs b.id=${b.id}');
              return b.id.compareTo(a.id);
            });
            print('✅ [MonthHistoryPage] Ordenamiento completado');
          } catch (e, stackTrace) {
            print('❌ [MonthHistoryPage] Error al ordenar: $e');
            print('📋 StackTrace: $stackTrace');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error al procesar meses: $e'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Volver'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Lista de meses
              Expanded(
                flex: _selectedMonth == null ? 1 : 0,
                child: ListView.builder(
                  shrinkWrap: _selectedMonth != null,
                  physics: _selectedMonth != null ? const NeverScrollableScrollPhysics() : null,
                  itemCount: months.length,
                  itemBuilder: (context, index) {
                    final month = months[index];
                    final isSelected = _selectedMonth == month.id;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      color: isSelected 
                          ? (isDark ? theme.colorScheme.primary.withOpacity(0.2) : theme.colorScheme.primary.withOpacity(0.1))
                          : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          child: Text(
                            month.id.split('-').last,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          _formatMonthName(month.id),
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Meta: ${CurrencyFormatter.format(month.monthTarget)}'),
                            Text('Total gastado: ${CurrencyFormatter.format(month.totalSpent)}'),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.format(month.carryOverToNext),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: month.carryOverToNext >= 0 
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            Text(
                              'Disponible',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            _selectedMonth = isSelected ? null : month.id;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),

              // Detalles del mes seleccionado
              if (_selectedMonth != null) ...[
                const Divider(height: 1),
                Expanded(
                  flex: 1,
                  child: _buildMonthDetails(householdId, _selectedMonth!, isDark),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildMonthDetails(String householdId, String monthId, bool isDark) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
            child: TabBar(
              labelColor: theme.colorScheme.secondary,
              unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              indicatorColor: theme.colorScheme.secondary,
              tabs: const [
                Tab(icon: Icon(Icons.add_circle_outline), text: 'Ingresos'),
                Tab(icon: Icon(Icons.remove_circle_outline), text: 'Gastos'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Ingresos
                _buildContributionsList(householdId, monthId),
                // Gastos
                _buildExpensesList(householdId, monthId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContributionsList(String householdId, String monthId) {
    return StreamBuilder<List<Contribution>>(
      stream: ref.read(firestoreServiceProvider).watchContributions(householdId, month: monthId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final contributions = snapshot.data ?? [];
        
        if (contributions.isEmpty) {
          return const Center(child: Text('No hay ingresos en este mes'));
        }

        // Ordenar por fecha descendente
        contributions.sort((a, b) => b.date.compareTo(a.date));

        return ListView.builder(
          itemCount: contributions.length,
          itemBuilder: (context, index) {
            final contribution = contributions[index];
            return ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.add, color: Colors.white),
              ),
              title: Text(
                contribution.note.isEmpty ? 'Ingreso' : contribution.note,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contribution.byDisplayName ?? 'Usuario'),
                  Text(
                    DateFormatter.formatDate(contribution.date),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              trailing: Text(
                CurrencyFormatter.format(contribution.amount),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.green,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildExpensesList(String householdId, String monthId) {
    return StreamBuilder<List<Expense>>(
      stream: ref.read(firestoreServiceProvider).watchExpenses(householdId, month: monthId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final expenses = snapshot.data ?? [];
        
        if (expenses.isEmpty) {
          return const Center(child: Text('No hay gastos en este mes'));
        }

        // Ordenar por fecha descendente
        expenses.sort((a, b) => b.date.compareTo(a.date));

        return ListView.builder(
          itemCount: expenses.length,
          itemBuilder: (context, index) {
            final expense = expenses[index];
            return ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.red,
                child: Icon(Icons.remove, color: Colors.white),
              ),
              title: Text(
                expense.note.isEmpty ? 'Gasto' : expense.note,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(expense.categoryName ?? 'Sin categoría'),
                  Text(
                    '${expense.byDisplayName ?? 'Usuario'} • ${DateFormatter.formatDate(expense.date)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              trailing: Text(
                CurrencyFormatter.format(expense.amount),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.red,
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatMonthName(String monthId) {
    // monthId formato: "YYYY-MM"
    final parts = monthId.split('-');
    if (parts.length != 2) return monthId;
    
    final year = parts[0];
    final month = int.parse(parts[1]);
    
    const monthNames = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    
    return '${monthNames[month - 1]} $year';
  }
}
