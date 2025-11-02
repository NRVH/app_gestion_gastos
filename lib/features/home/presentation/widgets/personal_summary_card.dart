import 'package:flutter/material.dart';
import '../../../../core/models/member.dart';
import '../../../../core/utils/formatters.dart';

class PersonalSummaryCard extends StatelessWidget {
  final Member member;
  final double monthTarget;

  const PersonalSummaryCard({
    super.key,
    required this.member,
    required this.monthTarget,
  });

  @override
  Widget build(BuildContext context) {
    final expected = member.expectedContribution(monthTarget);
    final remaining = member.remainingContribution(monthTarget);
    final progress = member.contributionProgress(monthTarget);
    final hasMetGoal = member.hasMetGoal(monthTarget);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mi Resumen',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        member.displayName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    PercentageFormatter.formatCompact(member.share),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor:
                      Theme.of(context).colorScheme.secondaryContainer,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoRow(
              context,
              'Te tocaba',
              CurrencyFormatter.format(expected),
              Icons.assignment,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              context,
              'Has aportado',
              CurrencyFormatter.format(member.contributedThisMonth),
              Icons.check_circle,
              valueColor: hasMetGoal ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              context,
              'Te falta',
              CurrencyFormatter.format(remaining),
              Icons.pending,
              valueColor: remaining > 0 ? Colors.red : Colors.green,
            ),
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tu progreso',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: hasMetGoal ? Colors.green : Colors.orange,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      hasMetGoal ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
        ),
      ],
    );
  }
}
