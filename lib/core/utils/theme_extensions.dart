import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// Extension helper para facilitar el acceso a los colores funcionales
/// de la aplicación desde cualquier BuildContext
extension ThemeExtensions on BuildContext {
  /// Obtiene si el tema actual es oscuro
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  
  /// Color para ingresos (siempre verde)
  Color get incomeColor => AppColors.income;
  
  /// Color para egresos (siempre rojo)
  Color get expenseColor => AppColors.expense;
  
  /// Color para categorías (amarillo)
  Color get categoryColor => AppColors.category;
  
  /// Color del FAB principal (rosa)
  Color get fabColor => AppColors.fabPrimary;
  
  /// Obtiene el color de transacción según el tipo
  Color transactionColor(bool isIncome) {
    return AppColors.getTransactionColor(isIncome);
  }
  
  /// Obtiene variantes de color para transacciones según el tema
  Color transactionColorVariant(bool isIncome) {
    return AppColors.getTransactionColorVariant(isIncome, isDarkMode);
  }
  
  /// Obtiene el color de categoría según el tema actual
  Color get categoryColorVariant => AppColors.getCategoryColor(isDarkMode);
}

/// Widget helper para construir un contenedor con color de transacción
class TransactionColorBox extends StatelessWidget {
  final bool isIncome;
  final Widget child;
  final bool useVariant;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const TransactionColorBox({
    Key? key,
    required this.isIncome,
    required this.child,
    this.useVariant = false,
    this.width,
    this.height,
    this.padding,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = useVariant 
        ? context.transactionColorVariant(isIncome)
        : context.transactionColor(isIncome);
    
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

/// Widget para construir un chip con color de categoría
class CategoryChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isSelected;

  const CategoryChip({
    Key? key,
    required this.label,
    this.icon,
    this.onTap,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final categoryColor = context.categoryColorVariant;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? categoryColor.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
                ? categoryColor 
                : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? categoryColor : null,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? categoryColor : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget para construir un indicador de ingreso/egreso
class TransactionIndicator extends StatelessWidget {
  final bool isIncome;
  final double size;
  final bool showIcon;

  const TransactionIndicator({
    Key? key,
    required this.isIncome,
    this.size = 24,
    this.showIcon = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = context.transactionColor(isIncome);
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: showIcon
          ? Icon(
              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
              size: size * 0.6,
              color: color,
            )
          : null,
    );
  }
}
