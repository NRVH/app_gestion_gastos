import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/member.dart';
import '../../../../core/providers/household_provider.dart';
import '../../../../core/providers/member_provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/utils/formatters.dart';

class MembersPage extends ConsumerWidget {
  const MembersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final householdId = ref.watch(currentHouseholdIdProvider);
    final currentUser = ref.watch(currentUserProvider);

    if (householdId == null || currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Miembros')),
        body: const Center(child: Text('No hay información disponible')),
      );
    }

    final membersAsync = ref.watch(householdMembersProvider);
    final currentMemberAsync = ref.watch(currentMemberProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Miembros de la casa'),
        elevation: 0,
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(householdMembersProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (members) {
          if (members.isEmpty) {
            return const Center(
              child: Text('No hay miembros en esta casa'),
            );
          }

          final currentMember = currentMemberAsync.value;
          final isOwner = currentMember?.role == MemberRole.owner;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Información general
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.people, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            'Total de miembros: ${members.length}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Los porcentajes de aportación se calculan automáticamente según los salarios',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Lista de miembros
              ...members.map((member) => _MemberCard(
                    member: member,
                    householdId: householdId,
                    currentUserId: currentUser.uid,
                    isOwner: isOwner,
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _MemberCard extends ConsumerWidget {
  final Member member;
  final String householdId;
  final String currentUserId;
  final bool isOwner;

  const _MemberCard({
    required this.member,
    required this.householdId,
    required this.currentUserId,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCurrentUser = member.uid == currentUserId;
    final canRemove = isOwner && !isCurrentUser;
    final canLeave = isCurrentUser && member.role != MemberRole.owner;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: member.role == MemberRole.owner
                      ? Colors.amber.shade100
                      : Colors.blue.shade100,
                  child: Icon(
                    member.role == MemberRole.owner ? Icons.star : Icons.person,
                    color: member.role == MemberRole.owner
                        ? Colors.amber.shade700
                        : Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 12),

                // Información del miembro
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              member.displayName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrentUser) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Tú',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        member.role == MemberRole.owner
                            ? '👑 Creador de la casa'
                            : '👤 Miembro',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // Menú de opciones
                if (canRemove || canLeave)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'remove') {
                        _showRemoveMemberDialog(context, ref);
                      } else if (value == 'leave') {
                        _showLeaveHouseholdDialog(context, ref);
                      }
                    },
                    itemBuilder: (context) => [
                      if (canRemove)
                        const PopupMenuItem(
                          value: 'remove',
                          child: Row(
                            children: [
                              Icon(Icons.person_remove, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Expulsar'),
                            ],
                          ),
                        ),
                      if (canLeave)
                        const PopupMenuItem(
                          value: 'leave',
                          child: Row(
                            children: [
                              Icon(Icons.exit_to_app, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Salir de la casa'),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),

            const Divider(height: 24),

            // Estadísticas
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  icon: Icons.percent,
                  label: 'Aportación',
                  value: '${(member.share * 100).toStringAsFixed(1)}%',
                  color: Colors.blue,
                ),
                _StatItem(
                  icon: Icons.attach_money,
                  label: 'Salario',
                  value: member.monthlySalary > 0
                      ? CurrencyFormatter.formatCompact(member.monthlySalary)
                      : 'No definido',
                  color: Colors.green,
                ),
                _StatItem(
                  icon: Icons.calendar_today,
                  label: 'Se unió',
                  value: member.joinedAt != null
                      ? DateFormatter.formatRelative(member.joinedAt!)
                      : 'Desconocido',
                  color: Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRemoveMemberDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Expulsar miembro'),
        content: Text(
          '¿Estás seguro de que quieres expulsar a ${member.displayName} de la casa?\n\n'
          'Esta acción eliminará su acceso a todos los datos de la casa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Expulsar'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(firestoreServiceProvider).removeMemberFromHousehold(
              householdId,
              member.uid,
            );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${member.displayName} ha sido expulsado'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showLeaveHouseholdDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Salir de la casa'),
        content: const Text(
          '¿Estás seguro de que quieres salir de esta casa?\n\n'
          'Perderás acceso a todos los gastos, aportaciones e historial de la casa.\n\n'
          'Podrás volver a unirte usando el código de invitación si lo tienes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(firestoreServiceProvider).removeMemberFromHousehold(
              householdId,
              member.uid,
            );

        if (context.mounted) {
          // Navegar de vuelta al home
          Navigator.of(context).popUntil((route) => route.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Has salido de la casa exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
