import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';

void main() {
  runApp(HotCutApp());
}

class HotCutApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HotCut',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
        fontFamily: 'SF Pro Display',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        fontFamily: 'SF Pro Display',
      ),
      themeMode: ThemeMode.system,
      home: const HotspotManagerHome(),
    );
  }
}

class ConnectedDevice {
  final String mac;
  final String ip;
  final String hostname;
  final String? deviceName;
  final DateTime connectedAt;
  final bool isBlocked;
  final DeviceType type;

  ConnectedDevice({
    required this.mac,
    required this.ip,
    required this.hostname,
    this.deviceName,
    required this.connectedAt,
    this.isBlocked = false,
    this.type = DeviceType.unknown,
  });

  factory ConnectedDevice.fromJson(Map<String, dynamic> json) {
    return ConnectedDevice(
      mac: json['mac'] ?? '',
      ip: json['ip'] ?? '',
      hostname: json['hostname'] ?? 'Appareil inconnu',
      deviceName: json['deviceName'],
      connectedAt: DateTime.parse(json['connectedAt'] ?? DateTime.now().toIso8601String()),
      isBlocked: json['isBlocked'] ?? false,
      type: DeviceType.values.byName(json['type'] ?? 'unknown'),
    );
  }

  String get displayName => deviceName ?? hostname;

  String get connectionDuration {
    final duration = DateTime.now().difference(connectedAt);
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
    return '${duration.inMinutes}m';
  }
}

enum DeviceType { phone, laptop, tablet, desktop, router, unknown }

extension DeviceTypeExtension on DeviceType {
  IconData get icon {
    switch (this) {
      case DeviceType.phone:
        return Icons.smartphone_rounded;
      case DeviceType.laptop:
        return Icons.laptop_mac_rounded;
      case DeviceType.tablet:
        return Icons.tablet_mac_rounded;
      case DeviceType.desktop:
        return Icons.desktop_mac_rounded;
      case DeviceType.router:
        return Icons.router_rounded;
      case DeviceType.unknown:
        return Icons.device_unknown_rounded;
    }
  }

  String get label {
    switch (this) {
      case DeviceType.phone:
        return 'Téléphone';
      case DeviceType.laptop:
        return 'Ordinateur portable';
      case DeviceType.tablet:
        return 'Tablette';
      case DeviceType.desktop:
        return 'Ordinateur';
      case DeviceType.router:
        return 'Routeur';
      case DeviceType.unknown:
        return 'Appareil inconnu';
    }
  }

  Color getColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (this) {
      case DeviceType.phone:
        return colorScheme.primary;
      case DeviceType.laptop:
        return colorScheme.secondary;
      case DeviceType.tablet:
        return colorScheme.tertiary;
      case DeviceType.desktop:
        return Colors.deepPurple;
      case DeviceType.router:
        return Colors.cyan;
      case DeviceType.unknown:
        return colorScheme.onSurface.withOpacity(0.5);
    }
  }
}

class HotspotManagerHome extends StatefulWidget {
  const HotspotManagerHome({Key? key}) : super(key: key);

  @override
  State<HotspotManagerHome> createState() => _HotspotManagerHomeState();
}

class _HotspotManagerHomeState extends State<HotspotManagerHome>
    with TickerProviderStateMixin {
  List<ConnectedDevice> connectedDevices = [];
  bool isLoading = false;
  bool isHotspotActive = true;
  String? hotspotInterface = 'wlan0';
  late AnimationController _refreshController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    //_loadMockData(); // Pour la démo
    // refreshDevices(); // Uncomment pour utiliser les vraies données
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // Données de démonstration
  void _loadMockData() {
    setState(() {
      connectedDevices = [
        ConnectedDevice(
          mac: '00:1A:2B:3C:4D:5E',
          ip: '192.168.1.101',
          hostname: 'iPhone de Marie',
          deviceName: 'iPhone 14 Pro',
          connectedAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 30)),
          type: DeviceType.phone,
        ),
        ConnectedDevice(
          mac: '00:1F:2E:3D:4C:5B',
          ip: '192.168.1.102',
          hostname: 'MacBook-Pro-de-Paul',
          deviceName: 'MacBook Pro',
          connectedAt: DateTime.now().subtract(const Duration(minutes: 45)),
          type: DeviceType.laptop,
        ),
        ConnectedDevice(
          mac: '00:2A:3B:4C:5D:6E',
          ip: '192.168.1.103',
          hostname: 'Samsung-Galaxy-Tab',
          deviceName: 'Galaxy Tab S8',
          connectedAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 15)),
          type: DeviceType.tablet,
          isBlocked: true,
        ),
        ConnectedDevice(
          mac: '00:3F:4E:5D:6C:7B',
          ip: '192.168.1.104',
          hostname: 'PC-Gaming-Alex',
          deviceName: 'PC Gaming',
          connectedAt: DateTime.now().subtract(const Duration(minutes: 20)),
          type: DeviceType.desktop,
        ),
      ];
    });
  }

  Future<void> refreshDevices() async {
    _refreshController.forward();
    setState(() {
      isLoading = true;
    });

    try {
      // Simulation du chargement
      await Future.delayed(const Duration(seconds: 2));
      //_loadMockData();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showErrorSnackBar('Erreur lors du scan: $e');
    } finally {
      _refreshController.reset();
    }
  }

  Future<void> disconnectDevice(ConnectedDevice device) async {
    final confirmed = await _showConfirmDialog(
      'Déconnecter ${device.displayName}',
      'Êtes-vous sûr de vouloir déconnecter cet appareil ?',
    );

    if (confirmed) {
      try {
        // Simulation de la déconnexion
        await Future.delayed(const Duration(milliseconds: 500));

        setState(() {
          connectedDevices.removeWhere((d) => d.mac == device.mac);
        });

        _showSuccessSnackBar('${device.displayName} déconnecté');
      } catch (e) {
        _showErrorSnackBar('Erreur lors de la déconnexion: $e');
      }
    }
  }

  Future<void> blockDevice(ConnectedDevice device) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        final index = connectedDevices.indexWhere((d) => d.mac == device.mac);
        if (index != -1) {
          connectedDevices[index] = ConnectedDevice(
            mac: device.mac,
            ip: device.ip,
            hostname: device.hostname,
            deviceName: device.deviceName,
            connectedAt: device.connectedAt,
            type: device.type,
            isBlocked: !device.isBlocked,
          );
        }
      });

      final action = device.isBlocked ? 'débloqué' : 'bloqué';
      _showSuccessSnackBar('${device.displayName} $action');
    } catch (e) {
      _showErrorSnackBar('Erreur: $e');
    }
  }

  Future<void> disconnectAll() async {
    final confirmed = await _showConfirmDialog(
      'Déconnecter tous les appareils',
      'Cette action déconnectera tous les appareils connectés. Continuer ?',
    );

    if (confirmed) {
      setState(() {
        connectedDevices.clear();
      });
      _showSuccessSnackBar('Tous les appareils ont été déconnectés');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 180,
              floating: true,
              pinned: true,
              snap: true,
              backgroundColor: colorScheme.surface,
              surfaceTintColor: colorScheme.surfaceTint,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                title: AnimatedOpacity(
                  opacity: innerBoxIsScrolled ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Text(
                    'HotCut',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primaryContainer,
                        colorScheme.primaryContainer.withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.onPrimaryContainer.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.wifi_rounded,
                                color: colorScheme.onPrimaryContainer,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'HotCut',
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Gestionnaire de hotspot',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  onPressed: refreshDevices,
                  icon: AnimatedBuilder(
                    animation: _refreshController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _refreshController.value * 2 * 3.14159,
                        child: Icon(
                          Icons.refresh_rounded,
                          color: colorScheme.onSurface,
                        ),
                      );
                    },
                  ),
                ),
                PopupMenuButton(
                  icon: Icon(Icons.more_vert_rounded, color: colorScheme.onSurface),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'settings',
                      child: Row(
                        children: [
                          Icon(Icons.settings_rounded),
                          SizedBox(width: 12),
                          Text('Paramètres'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'disconnect_all',
                      enabled: connectedDevices.isNotEmpty,
                      child: const Row(
                        children: [
                          Icon(Icons.wifi_off_rounded, color: Colors.red),
                          SizedBox(width: 12),
                          Text('Déconnecter tout'),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'disconnect_all') {
                      disconnectAll();
                    }
                  },
                ),
              ],
            ),
          ];
        },
        body: Column(
          children: [
            // Statistiques
            Padding(
              padding: const EdgeInsets.all(20),
              child: _buildStatsCard(colorScheme),
            ),

            // En-tête de la liste
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Appareils connectés',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${connectedDevices.length}',
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Liste des appareils
            Expanded(
              child: isLoading
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Scan en cours...'),
                  ],
                ),
              )
                  : connectedDevices.isEmpty
                  ? _buildEmptyState(colorScheme)
                  : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: connectedDevices.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final device = connectedDevices[index];
                  return _buildDeviceCard(device, colorScheme);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surfaceVariant,
            colorScheme.surfaceVariant.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            _buildStatItem(
              icon: Icons.wifi_find_rounded,
              value: isHotspotActive ? 'Actif' : 'Inactif',
              label: 'Hotspot',
              color: isHotspotActive ? Colors.green : Colors.red,
              colorScheme: colorScheme,
            ),
            Container(
              width: 1,
              height: 50,
              color: colorScheme.outline.withOpacity(0.2),
            ),
            _buildStatItem(
              icon: Icons.devices_rounded,
              value: '${connectedDevices.length}',
              label: 'Appareils',
              color: colorScheme.primary,
              colorScheme: colorScheme,
            ),
            Container(
              width: 1,
              height: 50,
              color: colorScheme.outline.withOpacity(0.2),
            ),
            _buildStatItem(
              icon: Icons.network_check_rounded,
              value: hotspotInterface ?? 'N/A',
              label: 'Interface',
              color: colorScheme.secondary,
              colorScheme: colorScheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required ColorScheme colorScheme,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.surfaceVariant,
                  colorScheme.surfaceVariant.withOpacity(0.5),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.wifi_off_rounded,
              size: 64,
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucun appareil connecté',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Les appareils connectés à votre hotspot apparaîtront ici',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: refreshDevices,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Actualiser'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(ConnectedDevice device, ColorScheme colorScheme) {
    final deviceColor = device.type.getColor(context);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: device.isBlocked
              ? Colors.red.withOpacity(0.3)
              : colorScheme.outline.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Icône de l'appareil avec gradient
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: device.isBlocked
                      ? [Colors.red.withOpacity(0.1), Colors.red.withOpacity(0.05)]
                      : [deviceColor.withOpacity(0.2), deviceColor.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                device.type.icon,
                color: device.isBlocked ? Colors.red : deviceColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),

            // Informations de l'appareil
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          device.displayName,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (device.isBlocked)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Bloqué',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.lan_rounded, size: 14, color: colorScheme.onSurface.withOpacity(0.6)),
                      const SizedBox(width: 6),
                      Text(
                        device.ip,
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.fingerprint_rounded, size: 14, color: colorScheme.onSurface.withOpacity(0.6)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          device.mac,
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Connecté depuis ${device.connectionDuration}',
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 09,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        device.type.label,
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 08,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Menu d'actions
            PopupMenuButton<String>(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (value) {
                switch (value) {
                  case 'block':
                    blockDevice(device);
                    break;
                  case 'disconnect':
                    disconnectDevice(device);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(
                        device.isBlocked ? Icons.wifi_rounded : Icons.block_rounded,
                        color: device.isBlocked ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      Text(device.isBlocked ? 'Débloquer' : 'Bloquer'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'disconnect',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Déconnecter'),
                    ],
                  ),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.more_vert_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}