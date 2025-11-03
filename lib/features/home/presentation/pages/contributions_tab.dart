import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/contribution_provider.dart';
import '../../../../core/providers/member_provider.dart';
import '../../../../core/providers/household_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/models/contribution.dart';
import '../../../../core/models/member.dart';
import '../../../../core/utils/formatters.dart';
import '../../../contributions/presentation/pages/edit_contribution_page.dart';

class ContributionsTab extends ConsumerStatefulWidget {
  const ContributionsTab({super.key});

  @override
  ConsumerState<ContributionsTab> createState() => _ContributionsTabState();
}

class _ContributionsTabState extends ConsumerState<ContributionsTab> {
  String? _selectedMemberId;

  @override
  Widget build(BuildContext context) {
    final householdAsync = ref.watch(currentHouseholdProvider);
    final membersAsync = ref.watch(householdMembersProvider);
    final contributionsAsync = ref.watch(contributionsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            title: const Text('Ingresos'),
            backgroundColor: Theme.of(context).colorScheme.surface,
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => _showInfo(context),
                tooltip: 'Información',
              ),
            ],
          ),

          // Member Filter
          SliverToBoxAdapter(
            child: membersAsync.when(
              data: (members) {
                if (members.isEmpty) {
                  return const SizedBox.shrink();
                }
                return _buildMemberFilter(members);
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          // Contributions List
          contributionsAsync.when(
            data: (contributions) {
              final filteredContributions = _selectedMemberId == null
                  ? contributions
                  : contributions
                      .where((c) => c.by == _selectedMemberId)
                      .toList();

              // Ordenar por monto de mayor a menor
              filteredContributions.sort((a, b) => b.amount.compareTo(a.amount));

              // Group by date
              final groupedContributions = <String, List<Contribution>>{};
              for (final contribution in filteredContributions) {
                final dateKey = DateFormatter.formatDate(contribution.date);
                groupedContributions.putIfAbsent(dateKey, () => []);
                groupedContributions[dateKey]!.add(contribution);
              }

              if (filteredContributions.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.savings,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _selectedMemberId == null
                              ? 'No hay aportaciones'
                              : 'No hay aportaciones de este miembro',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Toca el botón + para agregar',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Build list with padding
              return SliverPadding(
                padding: const EdgeInsets.only(bottom: 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entries = groupedContributions.entries.toList()
                        ..sort((a, b) => b.key.compareTo(a.key));
                      final entry = entries[index];
                      final date = entry.key;
                      final dayContributions = entry.value;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date header
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              date,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                          // Contributions for this date
                          ...dayContributions.map((contribution) {
                            final member = membersAsync.value?.firstWhere(
                              (m) => m.uid == contribution.by,
                              orElse: () => Member(
                                uid: contribution.by,
                                displayName: 'Desconocido',
                                role: MemberRole.partner,
                                share: 0,
                              ),
                            );
                            return _buildContributionItem(contribution, member);
                          }).toList(),
                        ],
                      );
                    },
                    childCount: groupedContributions.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SliverFillRemaining(
              child: Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
      floatingActionButton: householdAsync.when(
        data: (household) => household != null
            ? FloatingActionButton(
                onPressed: () => _navigateToAddContribution(context),
                child: const Icon(Icons.add),
              )
            : null,
        loading: () => null,
        error: (_, __) => null,
      ),
    );
  }

  Widget _buildMemberFilter(List<Member> members) {
    print('🔵 [ContributionsTab] Building member filter with ${members.length} members');
    for (var member in members) {
      print('🔵 [ContributionsTab] Member: ${member.displayName}, Role: ${member.role}, UID: ${member.uid}');
    }
    
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // All button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('Todos'),
              selected: _selectedMemberId == null,
              onSelected: (selected) {
                setState(() {
                  _selectedMemberId = null;
                });
              },
              avatar: _selectedMemberId == null
                  ? null
                  : const Icon(Icons.all_inclusive, size: 18),
            ),
          ),
          // Member chips
          ...members.map((member) {
            // Manejo seguro del role - comparar por string para evitar errores de enum
            IconData iconData;
            try {
              // Convertir a string para comparación segura
              final roleString = member.role.toString().split('.').last;
              if (roleString == 'owner') {
                iconData = Icons.star;
              } else {
                iconData = Icons.person;
              }
            } catch (e) {
              print('⚠️ [ContributionsTab] Error comparing role: $e, using default icon');
              iconData = Icons.person;
            }
            
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(member.displayName),
                selected: _selectedMemberId == member.uid,
                onSelected: (selected) {
                  setState(() {
                    _selectedMemberId = selected ? member.uid : null;
                  });
                },
                avatar: Icon(iconData, size: 18),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildContributionItem(Contribution contribution, Member? member) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.savings,
            color: Colors.green,
          ),
        ),
        title: Text(
          contribution.note.isEmpty ? 'Aportación' : contribution.note,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(member?.displayName ?? 'Desconocido'),
        trailing: Text(
          CurrencyFormatter.format(contribution.amount),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        onTap: () => _showContributionDetails(context, contribution, member),
      ),
    );
  }

  void _showContributionDetails(
    BuildContext context,
    Contribution contribution,
    Member? member,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _ContributionDetailsSheet(
        contribution: contribution,
        member: member,
        onDelete: () {
          Navigator.pop(context);
          _deleteContribution(contribution);
        },
        onEdit: () {
          Navigator.pop(context);
          _editContribution(context, contribution);
        },
      ),
    );
  }

  void _deleteContribution(Contribution contribution) async {
    final householdAsync = ref.read(currentHouseholdProvider);
    final household = householdAsync.value;
    if (household == null) return;

    final description =
        contribution.note.isEmpty ? 'esta aportación' : contribution.note;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar aportación'),
        content: Text('¿Eliminar "$description"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(firestoreServiceProvider).deleteContribution(
              household.id,
              contribution.id,
              contribution.by,
              contribution.amount,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aportación eliminada')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  void _editContribution(BuildContext context, Contribution contribution) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditContributionPage(contribution: contribution),
      ),
    );

    // Refresh if edited successfully
    if (result == true && mounted) {
      ref.invalidate(contributionsProvider);
    }
  }

  void _navigateToAddContribution(BuildContext context) {
    Navigator.of(context).pushNamed('/add-contribution');
  }

  void _showInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ingresos'),
        content: const Text(
          'Aquí puedes ver, agregar y gestionar todas las aportaciones que tú y tu pareja hacen al hogar.\n\n'
          'Las aportaciones se utilizan para cubrir los gastos compartidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

class _ContributionDetailsSheet extends StatelessWidget {
  final Contribution contribution;
  final Member? member;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _ContributionDetailsSheet({
    required this.contribution,
    required this.member,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.savings,
                  color: Colors.green,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contribution.note.isEmpty
                          ? 'Aportación'
                          : contribution.note,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      member?.displayName ?? 'Desconocido',
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildDetailRow(
            'Monto',
            CurrencyFormatter.format(contribution.amount),
            Icons.attach_money,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            'Fecha',
            DateFormatter.formatDate(contribution.date),
            Icons.calendar_today,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete),
                  label: const Text('Eliminar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              label: const Text('Cerrar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
