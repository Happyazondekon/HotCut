import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:ui'; // Import nécessaire pour ImageFilter.blur (Glassmorphism)
import 'dart:math'; // Import nécessaire pour les fonctions sin/pi (WavePainter)

import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(HotCutApp());
}

// ====================================================================
// WAVE PAINTER CLASS (Forme de fond pour la SliverAppBar)
// ====================================================================
class WavePainter extends CustomPainter {
  final double animation;
  final Color color;

  // L'animation est toujours utilisée pour la construction de la courbe,
  // mais nous allons la fixer à 0.0 pour un affichage statique.
  WavePainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();

    // Configuration des vagues
    const startX = -1.0;
    const endX = 2.0;

    // Fonction de courbe basée sur la valeur d'animation (maintenant fixe)
    double getY(double x, double phaseOffset) {
      return size.height *
          (0.8 +
              0.15 * // Amplitude
                  (sin(x * 2.5 * pi + animation * 2 * pi + phaseOffset) +
                      0.5 * sin(x * 5 * pi + animation * 2 * pi + phaseOffset * 2)) /
                  2.0);
    }

    // Vague principale
    path.moveTo(size.width * startX, size.height);
    for (double x = startX; x <= endX; x += 0.01) {
      path.lineTo(size.width * x, getY(x, 0.0));
    }
    path.lineTo(size.width * endX, size.height);
    path.close();
    canvas.drawPath(path, paint);

    // Seconde vague (pour la profondeur)
    final paint2 = Paint()..color = color.withOpacity(0.5);
    final path2 = Path();
    path2.moveTo(size.width * startX, size.height);
    for (double x = startX; x <= endX; x += 0.01) {
      path2.lineTo(size.width * x, getY(x, 1.0));
    }
    path2.lineTo(size.width * endX, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  // Retourne false car la valeur d'animation sera fixe (0.0), donc pas besoin de repeindre.
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return false;
  }
}

// ====================================================================
// APPLICATION
// ====================================================================

class HotCutApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HotCut',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Indigo 500
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

// ====================================================================
// DATA MODELS
// ====================================================================

class ConnectedDevice {
  final String mac;
  final String ip;
  final String hostname;
  final String? deviceName;
  final DateTime connectedAt;
  final bool isBlocked;
  final DeviceType type;
  final double signalStrength;

  ConnectedDevice({
    required this.mac,
    required this.ip,
    required this.hostname,
    this.deviceName,
    required this.connectedAt,
    this.isBlocked = false,
    this.type = DeviceType.unknown,
    this.signalStrength = 0.8,
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
      signalStrength: 0.8,
    );
  }

  String get displayName => deviceName ?? hostname;

  String get connectionDuration {
    final duration = DateTime.now().difference(connectedAt);
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    }
    return '${duration.inSeconds}s';
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

// ====================================================================
// HOME PAGE STATEFUL WIDGET
// ====================================================================

class HotspotManagerHome extends StatefulWidget {
  const HotspotManagerHome({Key? key}) : super(key: key);

  @override
  State<HotspotManagerHome> createState() => _HotspotManagerHomeState();
}

class _HotspotManagerHomeState extends State<HotspotManagerHome>
    with TickerProviderStateMixin {
  static const platform = MethodChannel('com.hotcut/network');
  List<ConnectedDevice> connectedDevices = [];
  bool isLoading = false;
  bool isHotspotActive = true;
  String? hotspotInterface = 'wlan0';
  late AnimationController _refreshController;
  // Les contrôleurs _pulseController et _waveController ont été retirés.
  Timer? _autoRefreshTimer; // Conservé pour la fonction de rafraîchissement manuel
  int _dataUsage = 0;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      refreshDevices();
      // Le rafraîchissement automatique est désactivé
      // _startAutoRefresh();
    });
  }

  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && !isLoading) {
        refreshDevices();
      }
    });
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> scanNetworkDevices() async {
    // Le contenu de scanNetworkDevices reste inchangé, simulant la récupération de données
    try {
      List<ConnectedDevice> devices = [];

      try {
        final bool isEnabled = await platform.invokeMethod('isHotspotEnabled').catchError((_) => true);
        if (mounted) {
          setState(() {
            isHotspotActive = isEnabled;
          });
        }
      } catch (e) {
        print('Erreur vérification hotspot: $e');
      }

      try {
        final List<dynamic> result = await platform.invokeMethod('getConnectedDevices').catchError((_) => [
          {'mac': '00:1A:2B:3C:4D:5E', 'ip': '192.168.43.101', 'hostname': 'MacBook-Pro', 'type': 'laptop', 'connectedAt': DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String()},
          {'mac': 'F0:E9:D8:C7:B6:A5', 'ip': '192.168.43.102', 'hostname': 'Galaxy-S23', 'deviceName': 'Mon Téléphone', 'type': 'phone', 'connectedAt': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String()},
          {'mac': '12:34:56:78:90:AB', 'ip': '192.168.43.103', 'hostname': 'Unknown-Device', 'type': 'unknown', 'connectedAt': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(), 'isBlocked': true},
        ]);

        for (var deviceData in result) {
          final Map<String, dynamic> device = Map<String, dynamic>.from(deviceData);
          final String mac = device['mac'] ?? 'N/A';
          final String ip = device['ip'] ?? '';
          final String hostname = device['hostname'] ?? 'Appareil inconnu';
          final String typeString = device['type'] ?? 'unknown';

          if (ip.isNotEmpty) {
            final existingDevice = connectedDevices.firstWhere(
                  (d) => d.mac == mac,
              orElse: () => ConnectedDevice(
                mac: mac,
                ip: ip,
                hostname: hostname,
                deviceName: device['deviceName'],
                connectedAt: DateTime.parse(device['connectedAt'] ?? DateTime.now().toIso8601String()),
                type: DeviceType.values.byName(typeString),
                isBlocked: device['isBlocked'] ?? false,
              ),
            );
            devices.add(existingDevice);
          }
        }
      } catch (e) {
        print('Erreur récupération appareils: $e');
        if (mounted) {
          _showErrorSnackBar('Impossible de récupérer les appareils: $e');
        }
      }

      if (mounted) {
        setState(() {
          connectedDevices = devices;
          _dataUsage = (connectedDevices.length * 15 + Random().nextInt(10)).clamp(0, 100);
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Erreur de scan: $e');
      }
    }
  }

  Future<void> refreshDevices() async {
    if (isLoading) return;

    final hasPermission = await _checkPermissions();
    if (!hasPermission) {
      _showErrorSnackBar('Permissions nécessaires pour scanner le réseau');
      return;
    }

    _refreshController.forward().then((_) => _refreshController.reset());

    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      await scanNetworkDevices();
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Erreur lors du scan: $e');
      }
    } finally {
      if (mounted) {
        // Délai pour l'effet visuel de chargement
        await Future.delayed(const Duration(milliseconds: 700));
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<bool> _checkPermissions() async {
    try {
      var status = await Permission.location.status;
      if (!status.isGranted) {
        status = await Permission.location.request();
      }
      return status.isGranted;
    } catch (e) {
      return false;
    }
  }

  // Fonctions de déconnexion et blocage inchangées...
  Future<void> disconnectDevice(ConnectedDevice device) async {
    final confirmed = await _showConfirmDialog(
      'Déconnecter ${device.displayName}',
      'Êtes-vous sûr de vouloir déconnecter cet appareil ?',
    );

    if (confirmed) {
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          setState(() {
            connectedDevices.removeWhere((d) => d.mac == device.mac);
          });
          _showSuccessSnackBar('${device.displayName} déconnecté');
        }
      } catch (e) {
        _showErrorSnackBar('Erreur lors de la déconnexion: $e');
      }
    }
  }

  Future<void> blockDevice(ConnectedDevice device) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
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
              signalStrength: device.signalStrength,
            );
          }
        });
        final action = device.isBlocked ? 'débloqué' : 'bloqué';
        _showSuccessSnackBar('${device.displayName} $action');
      }
    } catch (e) {
      _showErrorSnackBar('Erreur: $e');
    }
  }

  Future<void> disconnectAll() async {
    final confirmed = await _showConfirmDialog(
      'Déconnecter tous les appareils',
      'Cette action déconnectera tous les appareils connectés. Continuer ?',
    );

    if (confirmed && mounted) {
      setState(() {
        connectedDevices.clear();
      });
      _showSuccessSnackBar('Tous les appareils ont été déconnectés');
    }
  }

  // --- Utility Widgets (SnackBar / Dialog) ---
  // ... (fonctions _showErrorSnackBar, _showSuccessSnackBar, _showConfirmDialog inchangées)

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    ) ??
        false;
  }

  // --- Glassmorphism / Component Builders ---

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    final backgroundColor = isDark
        ? colorScheme.surface.withOpacity(0.25)
        : Colors.white.withOpacity(0.8);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.05);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20), // Réduit de 24 à 20
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Glassmorphism
        child: Container(
          padding: const EdgeInsets.all(16), // Réduit de 20 à 16
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10), // Réduit de 12 à 10
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(12), // Réduit de 14 à 12
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 10, // Réduit de 12 à 10
                      offset: const Offset(0, 3), // Réduit de 4 à 3
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 20), // Réduit de 24 à 20
              ),
              const SizedBox(height: 12), // Réduit de 16 à 12
              Text(
                value,
                style: TextStyle(
                  fontSize: 18, // Réduit de 20 à 18
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2), // Réduit de 4 à 2
              Text(
                label,
                style: TextStyle(
                  fontSize: 12, // Réduit de 13 à 12
                  color: colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards(ColorScheme colorScheme, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.speed_rounded,
            label: 'Débit estimé',
            value: '${_dataUsage} Mb/s',
            color: Colors.blue.shade400,
            colorScheme: colorScheme,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10), // Réduit de 12 à 10
        Expanded(
          child: _buildStatCard(
            icon: Icons.router_rounded,
            label: 'Interface réseau',
            value: hotspotInterface ?? 'N/A',
            color: Colors.purple.shade400,
            colorScheme: colorScheme,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceCard(
      ConnectedDevice device,
      ColorScheme colorScheme,
      bool isDark,
      ) {
    final backgroundColor = isDark
        ? colorScheme.surface.withOpacity(0.25)
        : Colors.white.withOpacity(0.8);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.05);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20), // Réduit de 24 à 20
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Glassmorphism
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withOpacity(isDark ? 0.05 : 0.03),
                blurRadius: 12, // Réduit de 16 à 12
                offset: const Offset(0, 3), // Réduit de 4 à 3
              ),
            ],
          ),
          child: ListTile(
            contentPadding:
            const EdgeInsets.symmetric(vertical: 4, horizontal: 16), // Réduit le padding
            leading: Container(
              padding: const EdgeInsets.all(10), // Réduit de 12 à 10
              decoration: BoxDecoration(
                color: device.type.getColor(context).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10), // Réduit de 12 à 10
                border: Border.all(
                  color: device.type.getColor(context).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                device.type.icon,
                color: device.type.getColor(context),
                size: 24, // Réduit de 28 à 24
              ),
            ),
            title: Text(
              device.displayName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
                decoration:
                device.isBlocked ? TextDecoration.lineThrough : null,
                decorationColor: Colors.red,
                fontSize: 16, // Réduit légèrement
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${device.type.label} • ${device.ip}',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 11, // Réduit de 12 à 11
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 12, // Réduit de 14 à 12
                      color: colorScheme.onSurface.withOpacity(0.4),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      device.connectionDuration,
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 11, // Réduit de 12 à 11
                      ),
                    ),
                    const SizedBox(width: 8), // Réduit de 12 à 8
                    Icon(
                      Icons.signal_wifi_4_bar_rounded,
                      size: 12, // Réduit de 14 à 12
                      color: colorScheme.onSurface.withOpacity(0.4),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(device.signalStrength * 100).toInt()}%',
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 11, // Réduit de 12 à 11
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: device.isBlocked
                ? Icon(
              Icons.lock_rounded,
              color: Colors.red.shade400,
              size: 24, // Réduit de 28 à 24
            )
                : PopupMenuButton(
              icon: Icon(
                Icons.more_vert_rounded,
                color: colorScheme.onSurface.withOpacity(0.6),
                size: 20, // Ajouté pour réduire l'icône
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12), // Réduit de 16 à 12
              ),
              onSelected: (value) {
                if (value == 'disconnect') {
                  disconnectDevice(device);
                } else if (value == 'block') {
                  blockDevice(device);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'disconnect',
                  child: Row(
                    children: [
                      Icon(Icons.link_off_rounded, size: 20), // Réduit l'icône
                      SizedBox(width: 8), // Réduit l'espace
                      Text('Déconnecter'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(
                        Icons.block_rounded,
                        color: Colors.red,
                        size: 20, // Réduit l'icône
                      ),
                      const SizedBox(width: 8), // Réduit l'espace
                      Text(device.isBlocked ? 'Débloquer' : 'Bloquer'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0), // Réduit de 32 à 24
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 80, // Réduit de 90 à 80
              color: colorScheme.primary.withOpacity(0.7),
            ),
            const SizedBox(height: 20), // Réduit de 24 à 20
            Text(
              'Aucun appareil connecté',
              style: TextStyle(
                fontSize: 20, // Réduit de 22 à 20
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6), // Réduit de 8 à 6
            Text(
              isHotspotActive
                  ? 'Le Hotspot est actif, mais aucun client n\'est encore connecté.'
                  : 'Activez votre Hotspot pour commencer à gérer les appareils.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15, // Réduit de 16 à 15
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 20), // Réduit de 24 à 20
            FilledButton.icon(
              onPressed: refreshDevices,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Re-scanner'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), // Réduit le padding
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), // Réduit de 16 à 12
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Main Build Method ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            // * Réduction de la hauteur
            expandedHeight: 180, // Réduit de 200 à 180
            floating: false,
            pinned: true,
            stretch: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 16, bottom: 12), // Réduit le padding
              title: const Text(
                'HotCut',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20, // Réduit de 22 à 20
                  letterSpacing: -0.5,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Dégradé de base (inchangé)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                          colorScheme.primary.withOpacity(0.3),
                          colorScheme.secondary.withOpacity(0.2),
                          colorScheme.background,
                        ]
                            : [
                          colorScheme.primary.withOpacity(0.15),
                          colorScheme.secondary.withOpacity(0.1),
                          colorScheme.background,
                        ],
                      ),
                    ),
                  ),
                  // 2. Forme de Vague Statique (inchangé)
                  CustomPaint(
                    painter: WavePainter(
                      animation: 0.0,
                      color: colorScheme.primary.withOpacity(0.1),
                    ),
                  ),
                  // 3. Contenu principal du header
                  Positioned(
                    top: 60, // Ajusté la position
                    left: 16, // Réduit de 20 à 16
                    right: 16, // Réduit de 20 à 16
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Icone Hotspot (statique et plus petit)
                            Container(
                              padding: const EdgeInsets.all(12), // Réduit de 16 à 12
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    colorScheme.primary,
                                    colorScheme.secondary,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16), // Réduit de 20 à 16
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withOpacity(0.4),
                                    blurRadius: 16, // Réduit de 20 à 16
                                    spreadRadius: 1, // Réduit de 2 à 1
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.wifi_tethering_rounded,
                                color: Colors.white,
                                size: 28, // Réduit de 32 à 28
                              ),
                            ),
                            const SizedBox(width: 16), // Réduit de 20 à 16
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Gestionnaire de Hotspot',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: colorScheme.onBackground.withOpacity(0.8),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 15, // Réduit légèrement
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10, // Réduit de 12 à 10
                                          vertical: 5, // Réduit de 6 à 5
                                        ),
                                        decoration: BoxDecoration(
                                          color: isHotspotActive
                                              ? Colors.green.withOpacity(0.2)
                                              : Colors.red.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(10), // Réduit de 12 à 10
                                          border: Border.all(
                                            color: isHotspotActive
                                                ? Colors.green.withOpacity(0.5)
                                                : Colors.red.withOpacity(0.5),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 7, // Réduit de 8 à 7
                                              height: 7, // Réduit de 8 à 7
                                              decoration: BoxDecoration(
                                                color: isHotspotActive
                                                    ? Colors.green
                                                    : Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 5), // Réduit de 6 à 5
                                            Text(
                                              isHotspotActive ? 'Actif' : 'Inactif',
                                              style: TextStyle(
                                                color: isHotspotActive
                                                    ? Colors.green
                                                    : Colors.red,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12, // Réduit de 13 à 12
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
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              // Bouton Rafraîchir (inchangé)
              ClipRRect(
                borderRadius: BorderRadius.circular(12), // Réduit de 16 à 12
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6), // Réduit de 8 à 6
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: refreshDevices,
                      icon: AnimatedBuilder(
                        animation: _refreshController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _refreshController.value * 2 * pi,
                            child: Icon(
                              Icons.refresh_rounded,
                              color: colorScheme.onSurface,
                              size: 20, // Réduit la taille
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              // Bouton Menu (inchangé)
              ClipRRect(
                borderRadius: BorderRadius.circular(12), // Réduit de 16 à 12
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10), // Réduit de 12 à 10
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: PopupMenuButton(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: colorScheme.onSurface,
                        size: 20, // Réduit la taille
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12), // Réduit de 16 à 12
                      ),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'settings',
                          child: Row(
                            children: [
                              Icon(Icons.settings_rounded, size: 20),
                              SizedBox(width: 8),
                              Text('Paramètres', style: TextStyle(fontSize: 15)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'disconnect_all',
                          enabled: connectedDevices.isNotEmpty,
                          child: const Row(
                            children: [
                              Icon(Icons.wifi_off_rounded, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text('Déconnecter tout', style: TextStyle(fontSize: 15)),
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
                  ),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), // Réduit le padding bas
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsCards(colorScheme, isDark),
                  const SizedBox(height: 20), // Réduit de 24 à 20
                  Row(
                    children: [
                      Icon(
                        Icons.devices_rounded,
                        size: 20, // Réduit de 24 à 20
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8), // Réduit de 12 à 8
                      Text(
                        'Appareils connectés',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                          fontSize: 18, // Réduit de 22 à 18
                        ),
                      ),
                      const Spacer(),
                      // Compteur avec dégradé
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12, // Réduit de 14 à 12
                          vertical: 4, // Réduit de 6 à 4
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primaryContainer,
                              colorScheme.secondaryContainer,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14), // Réduit de 16 à 14
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.2),
                              blurRadius: 6, // Réduit de 8 à 6
                              offset: const Offset(0, 1), // Réduit de 2 à 1
                            ),
                          ],
                        ),
                        child: Text(
                          '${connectedDevices.length}',
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 14, // Réduit de 16 à 14
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12), // Réduit de 16 à 12
                ],
              ),
            ),
          ),
          // Les états de chargement et vide sont inchangés dans leur logique
          if (isLoading)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 60, // Réduit de 80 à 60
                          height: 60, // Réduit de 80 à 60
                          child: CircularProgressIndicator(
                            strokeWidth: 3, // Réduit de 4 à 3
                            color: colorScheme.primary,
                          ),
                        ),
                        Icon(
                          Icons.wifi_find_rounded,
                          size: 30, // Réduit de 40 à 30
                          color: colorScheme.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20), // Réduit de 24 à 20
                    Text(
                      'Analyse du réseau...',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.8),
                        fontWeight: FontWeight.w600,
                        fontSize: 16, // Réduit
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (connectedDevices.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(colorScheme, isDark),
            )
          else
          // Liste des appareils
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final device = connectedDevices[index];
                    // Plus d'animation d'entrée
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8), // Réduit de 12 à 8
                      child: _buildDeviceCard(device, colorScheme, isDark),
                    );
                  },
                  childCount: connectedDevices.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)), // Réduit de 32 à 24
        ],
      ),
    );
  }
}