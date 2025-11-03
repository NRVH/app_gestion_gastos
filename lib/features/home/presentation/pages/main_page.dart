import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/update_provider.dart';
import 'overview_tab.dart';
import 'expenses_tab.dart';
import 'categories_tab.dart';
import 'contributions_tab.dart';
import '../../../settings/presentation/pages/settings_page.dart';

class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  int _currentIndex = 0;
  late PageController _pageController;

  final List<Widget> _pages = const [
    OverviewTab(),
    ContributionsTab(),
    ExpensesTab(),
    CategoriesTab(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    // Verificar actualizaciones al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(updateNotifierProvider.notifier).checkForUpdates();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onDestinationSelected(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasUpdate = ref.watch(hasUpdateAvailableProvider);

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          const NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings),
            label: 'Ingresos',
          ),
          const NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Gastos',
          ),
          const NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: 'Categorías',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: hasUpdate,
              label: const Text(''),
              backgroundColor: Colors.orange,
              child: const Icon(Icons.settings_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: hasUpdate,
              label: const Text(''),
              backgroundColor: Colors.orange,
              child: const Icon(Icons.settings),
            ),
            label: 'Config',
          ),
        ],
      ),
    );
  }
}
