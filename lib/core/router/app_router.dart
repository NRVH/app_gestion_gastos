import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/home/presentation/pages/main_page.dart';
import '../../features/household/presentation/pages/members_page.dart';
import '../../features/household/presentation/pages/create_household_page.dart';
import '../../features/household/presentation/pages/join_household_page.dart';
import '../../features/expenses/presentation/pages/add_expense_page.dart';
import '../../features/expenses/presentation/pages/expenses_list_page.dart';
import '../../features/contributions/presentation/pages/add_contribution_page.dart';
import '../../features/contributions/presentation/pages/contributions_list_page.dart';
import '../../features/categories/presentation/pages/manage_categories_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';

class AppRouter {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String createHousehold = '/create-household';
  static const String joinHousehold = '/join-household';
  static const String addExpense = '/add-expense';
  static const String expensesList = '/expenses-list';
  static const String addContribution = '/add-contribution';
  static const String contributionsList = '/contributions-list';
  static const String manageCategories = '/manage-categories';
  static const String settings = '/settings';
  static const String members = '/members';

  static Route<dynamic>? onGenerateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashPage());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterPage());
      case home:
        return MaterialPageRoute(builder: (_) => const MainPage());
      case createHousehold:
        return MaterialPageRoute(builder: (_) => const CreateHouseholdPage());
      case joinHousehold:
        return MaterialPageRoute(builder: (_) => const JoinHouseholdPage());
      case addExpense:
        // Usando Bottom Sheet en lugar de página completa
        return MaterialPageRoute(
          builder: (context) => Builder(
            builder: (BuildContext context) {
              // Necesitamos el ref del context, por lo que usamos Consumer
              return Consumer(
                builder: (context, ref, _) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    showAddExpenseSheet(context, ref);
                    Navigator.of(context).pop();
                  });
                  return const SizedBox.shrink();
                },
              );
            },
          ),
        );
      case expensesList:
        return MaterialPageRoute(builder: (_) => const ExpensesListPage());
      case addContribution:
        // Usando Bottom Sheet en lugar de página completa
        return MaterialPageRoute(
          builder: (context) => Builder(
            builder: (BuildContext context) {
              return Consumer(
                builder: (context, ref, _) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    showAddContributionSheet(context, ref);
                    Navigator.of(context).pop();
                  });
                  return const SizedBox.shrink();
                },
              );
            },
          ),
        );
      case contributionsList:
        return MaterialPageRoute(builder: (_) => const ContributionsListPage());
      case manageCategories:
        return MaterialPageRoute(builder: (_) => const ManageCategoriesPage());
      case settings:
        return MaterialPageRoute(builder: (_) => const SettingsPage());
      case members:
        return MaterialPageRoute(builder: (_) => const MembersPage());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${routeSettings.name}'),
            ),
          ),
        );
    }
  }
}
