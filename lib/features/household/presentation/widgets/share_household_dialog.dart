import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Diálogo reutilizable para compartir el código de invitación del hogar.
/// 
/// Muestra el código de invitación generado y permite copiarlo al portapapeles.
/// El código expira en 24 horas.
class ShareHouseholdDialog extends StatefulWidget {
  final String inviteCode;
  final String householdName;
  final VoidCallback? onClose;

  const ShareHouseholdDialog({
    super.key,
    required this.inviteCode,
    required this.householdName,
    this.onClose,
  });

  /// Método estático para mostrar el diálogo de forma sencilla.
  /// 
  /// Ejemplo de uso:
  /// ```dart
  /// await ShareHouseholdDialog.show(
  ///   context,
  ///   inviteCode: '123456',
  ///   householdName: 'Mi Casa',
  /// );
  /// ```
  static Future<void> show(
    BuildContext context, {
    required String inviteCode,
    required String householdName,
    VoidCallback? onClose,
  }) {
    return showDialog(
      context: context,
      builder: (context) => ShareHouseholdDialog(
        inviteCode: inviteCode,
        householdName: householdName,
        onClose: onClose,
      ),
    );
  }

  @override
  State<ShareHouseholdDialog> createState() => _ShareHouseholdDialogState();
}

class _ShareHouseholdDialogState extends State<ShareHouseholdDialog> {
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

  void _handleClose() {
    Navigator.pop(context);
    widget.onClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Text('🔗', style: TextStyle(fontSize: 24)),
          SizedBox(width: 8),
          Text('Compartir Hogar'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📱', style: TextStyle(fontSize: 80)),
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
            '⏱️ El código expira en 24 horas',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '👥 Comparte este código con tu pareja para que pueda unirse al hogar.',
            style: TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _handleClose,
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
