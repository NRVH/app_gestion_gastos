import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _mxnFormat = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
    decimalDigits: 2,
  );

  static String format(double amount) {
    return _mxnFormat.format(amount);
  }

  static String formatCompact(double amount) {
    if (amount >= 1000000) {
      return '\$${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '\$${(amount / 1000).toStringAsFixed(1)}K';
    }
    return format(amount);
  }
}

class DateFormatter {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy', 'es_MX');
  static final DateFormat _dateTimeFormat =
      DateFormat('dd/MM/yyyy HH:mm', 'es_MX');
  static final DateFormat _monthYearFormat = DateFormat('MMMM yyyy', 'es_MX');
  static final DateFormat _monthFormat = DateFormat('yyyy-MM');

  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }

  static String formatDateTime(DateTime dateTime) {
    return _dateTimeFormat.format(dateTime);
  }

  static String formatMonthYear(DateTime date) {
    return _monthYearFormat.format(date);
  }

  static String getCurrentMonth() {
    return _monthFormat.format(DateTime.now());
  }

  static String getMonthId(DateTime date) {
    return _monthFormat.format(date);
  }

  static DateTime parseMonthId(String monthId) {
    return DateTime.parse('$monthId-01');
  }

  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Hoy';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else if (difference.inDays < 30) {
      return 'Hace ${(difference.inDays / 7).floor()} semanas';
    } else {
      return formatDate(date);
    }
  }
}

class PercentageFormatter {
  static String format(double percentage) {
    return '${(percentage * 100).toStringAsFixed(2)}%';
  }

  static String formatCompact(double percentage) {
    return '${(percentage * 100).toStringAsFixed(0)}%';
  }
}
