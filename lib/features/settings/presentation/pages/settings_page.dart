import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/migration_service.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_palettes.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/providers/household_provider.dart';
import '../../../../core/providers/member_provider.dart';
import '../../../../core/providers/update_provider.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/models/member.dart';
import '../../../household/presentation/pages/members_page.dart';
import 'update_details_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final paletteId = ref.watch(appPaletteProvider);
    final palette = AppPalettes.getPalette(paletteId);
    final user = ref.watch(currentUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        title: const Text('Configuración'),
      ),
      body: ListView(
        children: [
          // User info
          if (user != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(
                          Icons.person,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.displayName ?? 'Usuario',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email ?? '',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Profile Settings
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '👤 PERFIL',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ListTile(
                  leading: const Text('✏️', style: TextStyle(fontSize: 24)),
                  title: const Text('Editar nombre'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showEditNameDialog(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Text('💰', style: TextStyle(fontSize: 24)),
                  title: const Text('Salario mensual'),
                  subtitle: const Text('Configure su salario para calcular aportes'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showEditSalaryDialog(context, ref),
                ),
                if (user != null && !_isGoogleLinked(user)) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Text('🔗', style: TextStyle(fontSize: 24)),
                    title: const Text('Vincular con Google'),
                    subtitle: const Text('Inicia sesión también con tu cuenta de Google'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _linkWithGoogle(context, ref),
                  ),
                ],
              ],
            ),
          ),

          // Household Settings
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '🏠 MI CASA',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ListTile(
                  leading: const Text('🏡', style: TextStyle(fontSize: 24)),
                  title: const Text('Nombre de la casa'),
                  subtitle: const Text('Cambiar nombre del household'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showEditHouseholdNameDialog(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Text('👥', style: TextStyle(fontSize: 24)),
                  title: const Text('Miembros'),
                  subtitle: const Text('Gestionar quién está en la casa'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _navigateToMembers(context),
                ),
                const Divider(height: 1),
                Consumer(
                  builder: (context, ref, child) {
                    final householdAsync = ref.watch(currentHouseholdProvider);
                    return householdAsync.when(
                      data: (household) => ListTile(
                        leading: const Text('🎯', style: TextStyle(fontSize: 24)),
                        title: const Text('Meta mensual'),
                        subtitle: Text(
                          'Se calcula automáticamente: ${CurrencyFormatter.format(household?.monthTarget ?? 0)}',
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                        trailing: const Tooltip(
                          message: 'Edita las categorías para cambiar la meta',
                          child: Icon(Icons.info_outline),
                        ),
                      ),
                      loading: () => ListTile(
                        leading: const Text('🎯', style: TextStyle(fontSize: 24)),
                        title: const Text('Meta mensual'),
                        subtitle: const Text('Cargando...'),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                    );
                  },
                ),
              ],
            ),
          ),

          // Appearance
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '🎨 APARIENCIA',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ListTile(
                  leading: const Text('🌓', style: TextStyle(fontSize: 24)),
                  title: const Text('Tema'),
                  subtitle: Text(_getThemeModeText(themeMode)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showThemeModeDialog(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Text('🎨', style: TextStyle(fontSize: 24)),
                  title: const Text('Paleta de colores'),
                  subtitle: Text(_getPaletteText(paletteId)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showPaletteDialog(context, ref),
                ),
              ],
            ),
          ),

          // App Info
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '📱 APLICACIÓN',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Consumer(
              builder: (context, ref, child) {
                final updateState = ref.watch(updateNotifierProvider);
                
                return Column(
                  children: [
                    ListTile(
                      leading: Text(
                        updateState.hasUpdateAvailable ? '🔄' : '✅',
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: const Text('Buscar actualizaciones'),
                      subtitle: updateState.hasUpdateAvailable
                          ? Text(
                              '¡Nueva versión ${updateState.availableUpdate!.version} disponible!',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : FutureBuilder<PackageInfo>(
                              future: PackageInfo.fromPlatform(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Text('Versión actual: ${snapshot.data!.version}');
                                }
                                return const Text('Versión actual: 1.0.0');
                              },
                            ),
                      trailing: updateState.isChecking
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              updateState.hasUpdateAvailable
                                  ? Icons.arrow_forward_ios
                                  : Icons.refresh,
                              size: updateState.hasUpdateAvailable ? 16 : 24,
                            ),
                      onTap: updateState.isChecking
                          ? null
                          : () {
                              if (updateState.hasUpdateAvailable) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const UpdateDetailsPage(),
                                  ),
                                );
                              } else {
                                ref.read(updateNotifierProvider.notifier)
                                    .checkForUpdates(forceCheck: true);
                              }
                            },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Text('ℹ️', style: TextStyle(fontSize: 24)),
                      title: FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
                        builder: (context, snapshot) {
                          final version = snapshot.hasData ? snapshot.data!.version : '...';
                          return Text('Versión $version');
                        },
                      ),
                      subtitle: const Text('App Gestión Gastos'),
                    ),
                  ],
                );
              },
            ),
          ),

          // Danger Zone
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              '⚠️ ZONA PELIGROSA',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0.5,
                color: Colors.red,
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.red.withOpacity(0.05),
            child: Column(
              children: [
                ListTile(
                  leading: const Text('🚪', style: TextStyle(fontSize: 24)),
                  title: const Text(
                    'Cerrar sesión',
                    style: TextStyle(color: Colors.red),
                  ),
                  subtitle: const Text('Salir de tu cuenta'),
                  onTap: () => _signOut(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Text('🗑️', style: TextStyle(fontSize: 24)),
                  title: const Text(
                    'Eliminar casa',
                    style: TextStyle(color: Colors.red),
                  ),
                  subtitle: const Text('Borrar todo y empezar de nuevo'),
                  onTap: () => _deleteHousehold(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Text('❌', style: TextStyle(fontSize: 24)),
                  title: const Text(
                    'Eliminar cuenta',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Eliminar permanentemente tu cuenta y todos tus datos'),
                  onTap: () => _deleteAccount(context, ref),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Claro';
      case ThemeMode.dark:
        return 'Oscuro';
      case ThemeMode.system:
        return 'Sistema';
    }
  }

  String _getPaletteText(AppPaletteId paletteId) {
    return AppPalettes.getDisplayName(paletteId);
  }

  void _navigateToMembers(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const MembersPage(),
      ),
    );
  }

  Future<void> _showThemeModeDialog(BuildContext context, WidgetRef ref) async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Selecciona el tema'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                title: const Text('Claro'),
                value: ThemeMode.light,
                groupValue: ref.read(themeModeProvider),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(themeModeProvider.notifier).setThemeMode(value);
                    Navigator.of(context).pop();
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Oscuro'),
                value: ThemeMode.dark,
                groupValue: ref.read(themeModeProvider),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(themeModeProvider.notifier).setThemeMode(value);
                    Navigator.of(context).pop();
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Sistema'),
                value: ThemeMode.system,
                groupValue: ref.read(themeModeProvider),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(themeModeProvider.notifier).setThemeMode(value);
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showPaletteDialog(BuildContext context, WidgetRef ref) async {
    final currentPaletteId = ref.read(appPaletteProvider);
    
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Selecciona una paleta'),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: AppPaletteId.values.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final paletteId = AppPaletteId.values[index];
                final palette = AppPalettes.getPalette(paletteId);
                final isSelected = currentPaletteId == paletteId;
                
                return InkWell(
                  onTap: () {
                    ref.read(appPaletteProvider.notifier).setPalette(paletteId);
                    Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected 
                            ? palette.primary.withOpacity(0.5)
                            : Colors.grey.withOpacity(0.3),
                        width: isSelected ? 2 : 1,
                      ),
                      color: isSelected 
                          ? palette.primary.withOpacity(0.05)
                          : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        // Mini swatches mostrando los colores principales
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: palette.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: palette.secondary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: palette.tertiary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Nombre de la paleta
                        Expanded(
                          child: Text(
                            palette.displayName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        // Check mark para la seleccionada
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: palette.primary,
                            size: 24,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditHouseholdNameDialog(BuildContext context, WidgetRef ref) async {
    final householdId = ref.read(currentHouseholdIdProvider);
    if (householdId == null) return;

    // Obtener household directamente del stream
    final householdStream = ref.read(firestoreServiceProvider).watchHousehold(householdId);
    final household = await householdStream.first;
    
    if (household == null) return;

    final nameController = TextEditingController(text: household.name);

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nombre de la casa'),
          content: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'Ej: Nuestra Casa',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isEmpty) return;

                try {
                  await ref.read(firestoreServiceProvider).updateHousehold(
                    householdId,
                    {'name': newName},
                  );

                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nombre actualizado')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }  Future<void> _showEditMonthTargetDialog(BuildContext context, WidgetRef ref) async {
    final householdId = ref.read(currentHouseholdIdProvider);
    if (householdId == null) return;

    // Obtener household directamente del stream
    final householdStream = ref.read(firestoreServiceProvider).watchHousehold(householdId);
    final household = await householdStream.first;
    
    if (household == null) return;

    final targetController = TextEditingController(
      text: household.monthTarget.toStringAsFixed(0),
    );
    final formKey = GlobalKey<FormState>();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Meta mensual'),
          content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meta actual: ${CurrencyFormatter.format(household.monthTarget)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: targetController,
                      decoration: const InputDecoration(
                        labelText: 'Nueva meta mensual',
                        hintText: 'Ej: 76025',
                        prefixText: '\$',
                      ),
                      keyboardType: TextInputType.number,
                      validator: Validators.amount,
                  autofocus: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final newTarget = double.parse(targetController.text);

                try {
                  await ref.read(firestoreServiceProvider).updateHousehold(
                    householdId,
                    {'monthTarget': newTarget},
                  );

                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Meta actualizada')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteHousehold(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('⚠️ Eliminar Casa'),
          content: const Text(
            'Esto eliminará TODA la información:\n\n'
            '• Todas las categorías\n'
            '• Todos los gastos\n'
            '• Todas las aportaciones\n'
            '• Todos los miembros\n\n'
            'Esta acción NO se puede deshacer.\n\n'
            '¿Estás seguro?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Sí, eliminar todo'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final householdId = ref.read(currentHouseholdIdProvider);
      if (householdId == null) return;

      try {
        await ref.read(firestoreServiceProvider).deleteHousehold(householdId);
        await ref.read(currentHouseholdIdProvider.notifier).clear();

        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRouter.createHousehold,
            (route) => false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Casa eliminada. Puedes crear una nueva.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _showEditNameDialog(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final nameController = TextEditingController(text: user.displayName);

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar nombre'),
          content: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'Tu nombre',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isEmpty) return;

                try {
                  await ref.read(authServiceProvider).updateDisplayName(newName);
                  
                  // También actualizar en el miembro del household
                  final householdId = ref.read(currentHouseholdIdProvider);
                  if (householdId != null) {
                    await ref.read(firestoreServiceProvider).updateMember(
                      householdId,
                      user.uid,
                      {'displayName': newName},
                    );
                  }

                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nombre actualizado')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditSalaryDialog(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    final householdId = ref.read(currentHouseholdIdProvider);
    
    if (user == null || householdId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cargar la información')),
      );
      return;
    }

    final salaryController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog(
      context: context,
      builder: (context) {
        return StreamBuilder<Member?>(
          stream: ref.read(firestoreServiceProvider).watchMember(householdId, user.uid),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AlertDialog(
                title: const Text('Error'),
                content: Text('No se pudo cargar tu información: ${snapshot.error}'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cerrar'),
                  ),
                ],
              );
            }

            if (!snapshot.hasData) {
              return const AlertDialog(
                title: Text('Salario mensual'),
                content: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final member = snapshot.data;
            if (member == null) {
              return AlertDialog(
                title: const Text('Error'),
                content: const Text('No se pudo cargar tu información'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cerrar'),
                  ),
                ],
              );
            }

            // Inicializar el controlador solo si está vacío
            if (salaryController.text.isEmpty && member.monthlySalary > 0) {
              salaryController.text = member.monthlySalary.toStringAsFixed(0);
            }

            return AlertDialog(
              title: const Text('Salario mensual'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ingrese su salario mensual para calcular automáticamente su porcentaje de aportación',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    if (member.monthlySalary > 0) ...[
                      Text(
                        'Salario actual: ${CurrencyFormatter.format(member.monthlySalary)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Tu aportación: ${(member.share * 100).toStringAsFixed(2)}%',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: salaryController,
                      decoration: const InputDecoration(
                        labelText: 'Salario mensual',
                        hintText: 'Ej: 76700',
                        prefixText: '\$',
                      ),
                      keyboardType: TextInputType.number,
                      validator: Validators.amount,
                      autofocus: true,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final newSalary = double.parse(salaryController.text);

                    try {
                      final firestoreService = ref.read(firestoreServiceProvider);
                      
                      // Actualizar el salario del miembro
                      await firestoreService.updateMember(
                        householdId,
                        user.uid,
                        {'monthlySalary': newSalary},
                      );

                      // Recalcular porcentajes de todos los miembros
                      await firestoreService.recalculateMemberShares(householdId);

                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Salario y porcentajes actualizados')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: ${e.toString()}')),
                        );
                      }
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cerrar sesión'),
          content: const Text('¿Estás seguro de cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cerrar sesión'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      await ref.read(authServiceProvider).signOut();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRouter.login,
          (route) => false,
        );
      }
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    // Primer diálogo de confirmación
    final firstConfirmation = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('⚠️ Eliminar Cuenta'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Esta acción es permanente e irreversible.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('Se eliminarán:'),
              SizedBox(height: 8),
              Text('• Tu cuenta de usuario'),
              Text('• Todos tus datos personales'),
              Text('• Tus aportaciones y gastos'),
              Text('• Los households donde eres el único miembro'),
              SizedBox(height: 16),
              Text(
                '¿Estás absolutamente seguro?',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continuar'),
            ),
          ],
        );
      },
    );

    if (firstConfirmation != true || !context.mounted) return;

    // Segundo diálogo de confirmación con campo de texto
    final secondConfirmation = await showDialog<bool>(
      context: context,
      builder: (context) {
        final confirmController = TextEditingController();
        return AlertDialog(
          title: const Text('Confirmación Final'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Para confirmar, escribe: ELIMINAR'),
              const SizedBox(height: 16),
              TextField(
                controller: confirmController,
                decoration: const InputDecoration(
                  labelText: 'Escribe ELIMINAR',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (confirmController.text.toUpperCase() == 'ELIMINAR') {
                  Navigator.of(context).pop(true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Debes escribir ELIMINAR para confirmar')),
                  );
                }
              },
              child: const Text('Eliminar Cuenta'),
            ),
          ],
        );
      },
    );

    if (secondConfirmation != true || !context.mounted) return;

    // Mostrar diálogo de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Eliminando cuenta...'),
          ],
        ),
      ),
    );

    try {
      final authService = ref.read(authServiceProvider);
      final firestoreService = ref.read(firestoreServiceProvider);

      // Primero intentar eliminar la cuenta directamente
      try {
        // Eliminar datos de Firestore primero
        await firestoreService.deleteUserData(user.uid);
        
        // Luego eliminar la cuenta de Auth
        await authService.deleteAccount();

        if (context.mounted) {
          Navigator.of(context).pop(); // Cerrar diálogo de carga
          
          // Mostrar mensaje de éxito
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Cuenta eliminada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );

          // Redirigir a login
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRouter.login,
            (route) => false,
          );
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          // Necesita reautenticación
          if (context.mounted) {
            Navigator.of(context).pop(); // Cerrar diálogo de carga
            await _reauthenticateAndDelete(context, ref, user);
          }
        } else {
          rethrow;
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Cerrar diálogo de carga
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _reauthenticateAndDelete(BuildContext context, WidgetRef ref, User user) async {
    final isGoogleUser = _isGoogleLinked(user);
    
    if (isGoogleUser) {
      // Reautenticar con Google
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Reautenticación Requerida'),
            content: const Text(
              'Por seguridad, necesitas volver a iniciar sesión con Google antes de eliminar tu cuenta.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Continuar'),
              ),
            ],
          );
        },
      );

      if (confirmed != true || !context.mounted) return;

      try {
        // Mostrar loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Reautenticando...'),
              ],
            ),
          ),
        );

        await ref.read(authServiceProvider).reauthenticateWithGoogle();
        
        if (context.mounted) {
          Navigator.of(context).pop(); // Cerrar loading
          
          // Ahora intentar eliminar de nuevo
          await _proceedWithDeletion(context, ref, user);
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error reautenticando: ${e.toString()}')),
          );
        }
      }
    } else {
      // Reautenticar con contraseña
      final passwordController = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Reautenticación Requerida'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Por seguridad, ingresa tu contraseña para continuar:',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Confirmar'),
              ),
            ],
          );
        },
      );

      if (confirmed != true || !context.mounted) return;

      try {
        // Mostrar loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Reautenticando...'),
              ],
            ),
          ),
        );

        await ref.read(authServiceProvider).reauthenticateWithPassword(
          passwordController.text,
        );
        
        if (context.mounted) {
          Navigator.of(context).pop(); // Cerrar loading
          
          // Ahora intentar eliminar de nuevo
          await _proceedWithDeletion(context, ref, user);
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Contraseña incorrecta')),
          );
        }
      }
    }
  }

  Future<void> _proceedWithDeletion(BuildContext context, WidgetRef ref, User user) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Eliminando cuenta...'),
          ],
        ),
      ),
    );

    try {
      final authService = ref.read(authServiceProvider);
      final firestoreService = ref.read(firestoreServiceProvider);

      // Eliminar datos de Firestore
      await firestoreService.deleteUserData(user.uid);
      
      // Eliminar cuenta de Auth
      await authService.deleteAccount();

      if (context.mounted) {
        Navigator.of(context).pop(); // Cerrar loading
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cuenta eliminada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRouter.login,
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _isGoogleLinked(User user) {
    // Check if user has Google as a sign-in method
    return user.providerData.any((info) => info.providerId == 'google.com');
  }

  Future<void> _linkWithGoogle(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authServiceProvider).linkWithGoogle();
      
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuenta de Google vinculada exitosamente')),
      );
    } catch (e) {
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }
}
