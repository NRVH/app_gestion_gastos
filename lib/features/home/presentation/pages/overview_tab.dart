import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/household_provider.dart';
import '../../../../core/providers/member_provider.dart';
import '../../../../core/providers/category_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/models/household.dart';
import '../../../../core/models/member.dart';
import '../../../../core/utils/formatters.dart';
import 'stats_page.dart';
import 'month_selector_page.dart';

class OverviewTab extends ConsumerWidget {
  const OverviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final householdAsync = ref.watch(currentHouseholdProvider);
    final currentMemberAsync = ref.watch(currentMemberProvider);
    final membersAsync = ref.watch(householdMembersProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: householdAsync.when(
          data: (household) => Align(
            alignment: Alignment.centerLeft,
            child: Text(household?.name ?? 'Inicio'),
          ),
          loading: () => const Align(
            alignment: Alignment.centerLeft,
            child: Text('Cargando...'),
          ),
          error: (_, __) => const Align(
            alignment: Alignment.centerLeft,
            child: Text('Error'),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => _navigateToStats(context),
            tooltip: 'Estadísticas',
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _showCloseMonthDialog(context, ref),
            tooltip: 'Cerrar mes',
          ),
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () => _navigateToMembers(context),
            tooltip: 'Miembros',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareHousehold(context, ref),
            tooltip: 'Compartir casa',
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                // Resumen personal
                currentMemberAsync.when(
                  data: (member) => member != null
                      ? _buildPersonalSummary(household, member)
                      : const SizedBox.shrink(),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                // Balance general de la casa
                _buildHouseholdBalance(household, membersAsync),

                // Botón para ver meses anteriores
                _buildMonthHistoryButton(context),

                const SizedBox(height: 16),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
        ),
      ),
    );
  }

  Widget _buildMonthHistoryButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: InkWell(
          onTap: () => _navigateToMonthSelector(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.history,
                    color: Colors.purple,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ver meses anteriores',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Consulta el histórico de los últimos 3 meses',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalSummary(Household household, Member member) {
    final expectedContribution = member.expectedContribution(household.monthTarget);
    final contributed = member.contributedThisMonth;
    final remaining = expectedContribution - contributed;
    final progress = contributed / expectedContribution;
    final hasMetGoal = member.hasMetGoal(household.monthTarget);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: hasMetGoal
                ? [Colors.green.shade400, Colors.green.shade600]
                : [Colors.blue.shade400, Colors.blue.shade600],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mi resumen personal',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        member.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasMetGoal)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Aportación: ${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      hasMetGoal ? '¡Meta cumplida!' : '${(member.share * 100).toStringAsFixed(1)}% del total',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stats row
            Row(
              children: [
                Expanded(
                  child: _buildPersonalStat(
                    'Aportado',
                    CurrencyFormatter.format(contributed),
                    Icons.check_circle_outline,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withOpacity(0.3),
                ),
                Expanded(
                  child: _buildPersonalStat(
                    remaining > 0 ? 'Falta' : 'Extra',
                    CurrencyFormatter.format(remaining.abs()),
                    remaining > 0 ? Icons.schedule : Icons.star,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withOpacity(0.3),
                ),
                Expanded(
                  child: _buildPersonalStat(
                    'Meta',
                    CurrencyFormatter.format(expectedContribution),
                    Icons.flag,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildHouseholdBalance(
    Household household,
    AsyncValue<List<Member>> membersAsync,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Balance de la casa',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildBalanceCard(
                  'Disponible',
                  household.availableBalance,
                  Colors.green,
                  Icons.account_balance_wallet,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBalanceCard(
                  'Meta mensual',
                  household.monthTarget,
                  Colors.blue,
                  Icons.flag,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildBalanceCard(
                  'Aportado',
                  household.monthPool,
                  Colors.orange,
                  Icons.savings,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: membersAsync.when(
                  data: (members) => _buildBalanceCard(
                    'Miembros',
                    members.length.toDouble(),
                    Colors.purple,
                    Icons.people,
                    isCount: true,
                  ),
                  loading: () => _buildBalanceCard(
                    'Miembros',
                    0,
                    Colors.purple,
                    Icons.people,
                    isCount: true,
                  ),
                  error: (_, __) => _buildBalanceCard(
                    'Miembros',
                    0,
                    Colors.purple,
                    Icons.people,
                    isCount: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(
    String label,
    double value,
    Color color,
    IconData icon, {
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
              isCount
                  ? value.toInt().toString()
                  : CurrencyFormatter.format(value),
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCloseMonthDialog(BuildContext context, WidgetRef ref) async {
    final householdAsync = ref.read(currentHouseholdProvider);
    final household = householdAsync.value;
    
    if (household == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar mes'),
        content: const Text(
          '¿Estás seguro de cerrar el mes actual?\n\n'
          '• Se guardarán los sobrantes/déficits de cada categoría\n'
          '• Se reiniciarán los gastos y aportaciones del mes\n'
          '• Esta acción no se puede deshacer',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Cerrar mes'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Mostrar loading
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cerrando mes...'),
                ],
              ),
            ),
          ),
        ),
      );

      final membersAsync = await ref.read(householdMembersProvider.future);
      final categoriesAsync = await ref.read(categoriesProvider.future);

      await ref.read(firestoreServiceProvider).closeMonth(
            householdId: household.id,
            household: household,
            members: membersAsync,
            categories: categoriesAsync,
          );

      // Cerrar loading
      if (!context.mounted) return;
      Navigator.pop(context);

      // Refrescar datos
      ref.invalidate(currentHouseholdProvider);
      ref.invalidate(categoriesProvider);
      ref.invalidate(householdMembersProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Mes cerrado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Cerrar loading si está abierto
      if (context.mounted) Navigator.pop(context);
      
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cerrar mes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToStats(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const StatsPage(),
      ),
    );
  }

  void _navigateToMonthSelector(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const MonthSelectorPage(),
      ),
    );
  }

  void _navigateToMembers(BuildContext context) {
    Navigator.of(context).pushNamed('/members');
  }

  void _shareHousehold(BuildContext context, WidgetRef ref) async {
    final householdAsync = ref.read(currentHouseholdProvider);
    final household = householdAsync.value;
    
    if (household == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay información del hogar')),
      );
      return;
    }

    // Generar código de invitación temporal
    String? inviteCode;
    try {
      inviteCode = await ref.read(firestoreServiceProvider).generateInviteCode(household.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
      return;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => _ShareHouseholdDialog(
        inviteCode: inviteCode!,
        householdName: household.name,
      ),
    );
  }
}

class _ShareHouseholdDialog extends StatefulWidget {
  final String inviteCode;
  final String householdName;

  const _ShareHouseholdDialog({
    required this.inviteCode,
    required this.householdName,
  });

  @override
  State<_ShareHouseholdDialog> createState() => _ShareHouseholdDialogState();
}

class _ShareHouseholdDialogState extends State<_ShareHouseholdDialog> {
  bool _copied = false;

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.inviteCode));
    
    setState(() => _copied = true);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Código copiado al portapapeles'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    
    // Reset copied state after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Compartir Hogar'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.qr_code, size: 80, color: Colors.blue),
          const SizedBox(height: 16),
          Text(
            widget.householdName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Código de invitación:',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.inviteCode,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'El código expira en 24 horas',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Comparte este código con tu pareja para que pueda unirse al hogar.',
            style: TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        FilledButton.icon(
          onPressed: _copyToClipboard,
          icon: Icon(_copied ? Icons.check : Icons.copy),
          label: Text(_copied ? 'Copiado' : 'Copiar código'),
        ),
      ],
    );
  }
}
