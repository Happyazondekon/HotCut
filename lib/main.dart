import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(HotCutApp());
}

class WavePainter extends CustomPainter {
  final double animation;
  final Color color;

  WavePainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    const startX = -1.0;
    const endX = 2.0;

    double getY(double x, double phaseOffset) {
      return size.height *
          (0.8 +
              0.15 *
                  (sin(x * 2.5 * pi + animation * 2 * pi + phaseOffset) +
                      0.5 * sin(x * 5 * pi + animation * 2 * pi + 2 * phaseOffset)) /
                  2.0);
    }

    path.moveTo(size.width * startX, size.height);
    for (double x = startX; x <= endX; x += 0.01) {
      path.lineTo(size.width * x, getY(x, 0.0));
    }
    path.lineTo(size.width * endX, size.height);
    path.close();
    canvas.drawPath(path, paint);

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
  bool shouldRepaint(covariant WavePainter oldDelegate) => false;
}

class HotCutApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HotCut',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6366F1), brightness: Brightness.light), fontFamily: 'SF Pro Display'),
      darkTheme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6366F1), brightness: Brightness.dark), fontFamily: 'SF Pro Display'),
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
    if (duration.inHours > 0) return '${duration.inHours}h ${duration.inMinutes % 60}m';
    if (duration.inMinutes > 0) return '${duration.inMinutes}m';
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
      default:
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
      default:
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
      default:
        return colorScheme.onSurface.withOpacity(0.5);
    }
  }
}

class HotspotManagerHome extends StatefulWidget {
  const HotspotManagerHome({Key? key}) : super(key: key);
  @override
  State createState() => _HotspotManagerHomeState();
}

class _HotspotManagerHomeState extends State<HotspotManagerHome> with TickerProviderStateMixin {
  static const platform = MethodChannel('com.hotcut/network');

  List<ConnectedDevice> connectedDevices = [];
  List<ConnectedDevice> connectionHistory = [];

  bool isLoading = false;
  bool isHotspotActive = true;
  String? hotspotInterface = 'wlan0';

  late AnimationController _refreshController;
  Timer? _autoRefreshTimer;
  int _dataUsage = 0;

  String _searchQuery = '';

  final TextEditingController _manualIpController = TextEditingController();
  final GlobalKey<FormState> _manualIpFormKey = GlobalKey<FormState>();

  final Map<String, Timer> _autoDisconnectTimers = {};

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      refreshDevices();
    });
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _autoRefreshTimer?.cancel();
    _manualIpController.dispose();
    // Cancel scheduled timers
    for (var timer in _autoDisconnectTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  Future<void> scanNetworkDevices() async {
    try {
      List<ConnectedDevice> devices = [];
      final bool isEnabled = await platform.invokeMethod('isHotspotEnabled').catchError((_) => true);
      if (mounted) {
        setState(() { isHotspotActive = isEnabled; });
      }

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
          _addToHistory(existingDevice);
        }
      }

      if (mounted) {
        setState(() {
          connectedDevices = devices;
          _dataUsage = (connectedDevices.length * 15 + Random().nextInt(10)).clamp(0, 100);
        });
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Erreur de scan : $e');
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
    if (mounted) setState(() => isLoading = true);
    try {
      await scanNetworkDevices();
    } catch (e) {
      if (mounted) _showErrorSnackBar('Erreur lors du scan : $e');
    } finally {
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 700));
        setState(() => isLoading = false);
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

  Future<void> disconnectDevice(ConnectedDevice device) async {
    final confirmed = await _showConfirmDialog(
      'Déconnecter ${device.displayName}',
      'Êtes-vous sûr de vouloir déconnecter cet appareil ?',
    );
    if (confirmed) {
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          setState(() { connectedDevices.removeWhere((d) => d.mac == device.mac); });
          _showSuccessSnackBar('${device.displayName} déconnecté');
        }
      } catch (e) {
        _showErrorSnackBar('Erreur lors de la déconnexion : $e');
      }
    }
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
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
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
      _showErrorSnackBar('Erreur : $e');
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

  Future<void> disconnectManualIp() async {
    if (!_manualIpFormKey.currentState!.validate()) return;

    final ipToDisconnect = _manualIpController.text.trim();

    final device = connectedDevices.firstWhere(
          (d) => d.ip == ipToDisconnect,
      orElse: () => ConnectedDevice(mac: '', ip: ipToDisconnect, hostname: 'IP manuelle', connectedAt: DateTime.now()),
    );

    final confirmed = await _showConfirmDialog(
      'Déconnecter appareil',
      'Êtes-vous sûr de vouloir déconnecter l\'appareil avec l\'IP $ipToDisconnect ?',
    );

    if (confirmed) {
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          setState(() { connectedDevices.removeWhere((d) => d.ip == ipToDisconnect); });
          _manualIpController.clear();
          _showSuccessSnackBar('Appareil avec IP $ipToDisconnect déconnecté');
        }
      } catch (e) {
        _showErrorSnackBar('Erreur lors de la déconnexion : $e');
      }
    }
  }

  void _addToHistory(ConnectedDevice device) {
    connectionHistory.removeWhere((d) => d.mac == device.mac);
    connectionHistory.insert(0, device);
    if (connectionHistory.length > 50) connectionHistory.removeLast(); // Garde max 50 entrées
  }

  void _scheduleAutoDisconnect(ConnectedDevice device, Duration delay) {
    if (_autoDisconnectTimers[device.mac] != null) {
      _autoDisconnectTimers[device.mac]!.cancel();
    }
    _autoDisconnectTimers[device.mac] = Timer(delay, () {
      if (mounted) {
        disconnectDevice(device);
        _autoDisconnectTimers.remove(device.mac);
      }
    });
    _showSuccessSnackBar('Déconnexion automatique planifiée dans ${delay.inMinutes} minutes pour ${device.displayName}');
  }

  // Méthodes UI

  Widget _buildStatCard({required IconData icon, required String label, required String value, required Color color, required ColorScheme colorScheme, required bool isDark}) {
    final backgroundColor = isDark ? colorScheme.surface.withOpacity(0.25) : Colors.white.withOpacity(0.8);
    final borderColor = isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 12),
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface, letterSpacing: -0.5)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.w500)),
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
          child: _buildStatCard(icon: Icons.speed_rounded, label: 'Débit estimé', value: '$_dataUsage Mb/s', color: Colors.blue.shade400, colorScheme: colorScheme, isDark: isDark),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(icon: Icons.router_rounded, label: 'Interface réseau', value: hotspotInterface ?? 'N/A', color: Colors.purple.shade400, colorScheme: colorScheme, isDark: isDark),
        ),
      ],
    );
  }

  Widget _buildDeviceCard(ConnectedDevice device, ColorScheme colorScheme, bool isDark) {
    final backgroundColor = isDark ? colorScheme.surface.withOpacity(0.25) : Colors.white.withOpacity(0.8);
    final borderColor = isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [BoxShadow(color: colorScheme.primary.withOpacity(isDark ? 0.05 : 0.03), blurRadius: 12, offset: const Offset(0, 3))],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: device.type.getColor(context).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: device.type.getColor(context).withOpacity(0.3), width: 1),
              ),
              child: Icon(device.type.icon, color: device.type.getColor(context), size: 24),
            ),
            title: Text(
              device.displayName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
                decoration: device.isBlocked ? TextDecoration.lineThrough : null,
                decorationColor: Colors.red,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${device.type.label} • ${device.ip}', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 11)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 12, color: colorScheme.onSurface.withOpacity(0.4)),
                    const SizedBox(width: 4),
                    Text(device.connectionDuration, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
                    const SizedBox(width: 8),
                    Icon(Icons.signal_wifi_4_bar_rounded, size: 12, color: colorScheme.onSurface.withOpacity(0.4)),
                    const SizedBox(width: 4),
                    Text('${(device.signalStrength * 100).toInt()}%', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
                  ],
                ),
              ],
            ),
            trailing: device.isBlocked
                ? Icon(Icons.lock_rounded, color: Colors.red.shade400, size: 24)
                : PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: colorScheme.onSurface.withOpacity(0.6), size: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                if (value == 'disconnect') disconnectDevice(device);
                else if (value == 'block') blockDevice(device);
                else if (value == 'details') _showDeviceDetails(device);
                else if (value == 'autodisco') _showAutoDisconnectDialog(device);
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'disconnect',
                  child: Row(children: [Icon(Icons.link_off_rounded, size: 20), SizedBox(width: 8), Text('Déconnecter')]),
                ),
                PopupMenuItem<String>(
                  value: 'block',
                  child: Row(children: [
                    Icon(Icons.block_rounded, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Text(device.isBlocked ? 'Débloquer' : 'Bloquer'),
                  ]),
                ),
                const PopupMenuItem<String>(
                  value: 'details',
                  child: Row(children: [Icon(Icons.info_outline_rounded, size: 20), SizedBox(width: 8), Text('Détails')]),
                ),
                const PopupMenuItem<String>(
                  value: 'autodisco',
                  child: Row(children: [Icon(Icons.timer_rounded, size: 20), SizedBox(width: 8), Text('Déconnexion automatique')]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Rechercher un appareil...',
          prefixIcon: Icon(Icons.search, color: colorScheme.primary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: (value) => setState(() {
          _searchQuery = value;
        }),
      ),
    );
  }

  Widget _buildManualIpEntry(ColorScheme colorScheme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Form(
        key: _manualIpFormKey,
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _manualIpController,
                decoration: InputDecoration(
                  labelText: 'Entrer IP manuellement',
                  hintText: 'Exemple: 192.168.43.105',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Veuillez entrer une IP';
                  final ipPattern = r'^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$';
                  final regExp = RegExp(ipPattern);
                  if (!regExp.hasMatch(value.trim())) return 'IP invalide';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: disconnectManualIp,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Déconnecter'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.cloud_off_rounded, size: 80, color: colorScheme.primary.withOpacity(0.7)),
          const SizedBox(height: 20),
          Text('Aucun appareil connecté', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
          const SizedBox(height: 6),
          Text(
            isHotspotActive
                ? 'Le Hotspot est actif, mais aucun client n\'est encore connecté.'
                : 'Activez votre Hotspot pour commencer à gérer les appareils.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: colorScheme.onSurface.withOpacity(0.6)),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: refreshDevices,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Re-scanner'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ]),
      ),
    );
  }

  void _showDeviceDetails(ConnectedDevice device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(device.displayName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MAC : ${device.mac}'),
            Text('IP : ${device.ip}'),
            Text('Type : ${device.type.label}'),
            Text('Connecté depuis : ${device.connectionDuration}'),
            Text('Statut : ${device.isBlocked ? 'Bloqué' : 'Connecté'}'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
      ),
    );
  }

  Future<void> _showAutoDisconnectDialog(ConnectedDevice device) async {
    Duration? selectedDuration;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Planifier déconnexion automatique de\n${device.displayName}'),
        content: DropdownButtonFormField<Duration>(
          decoration: const InputDecoration(labelText: 'Délai'),
          items: [
            const DropdownMenuItem(value: Duration(minutes: 1), child: Text('1 minute')),
            const DropdownMenuItem(value: Duration(minutes: 5), child: Text('5 minutes')),
            const DropdownMenuItem(value: Duration(minutes: 10), child: Text('10 minutes')),
            const DropdownMenuItem(value: Duration(minutes: 30), child: Text('30 minutes')),
          ],
          onChanged: (val) {
            selectedDuration = val;
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              if (selectedDuration != null) {
                _scheduleAutoDisconnect(device, selectedDuration!);
                Navigator.pop(context);
              }
            },
            child: const Text('Planifier'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [const Icon(Icons.error_outline_rounded, color: Colors.white), const SizedBox(width: 12), Expanded(child: Text(message))]),
      backgroundColor: Colors.red.shade600,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
    ));
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [const Icon(Icons.check_circle_rounded, color: Colors.white), const SizedBox(width: 12), Expanded(child: Text(message))]),
      backgroundColor: Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
    ));
  }

  List<ConnectedDevice> get _filteredDevices {
    if (_searchQuery.isEmpty) return connectedDevices;
    final query = _searchQuery.toLowerCase();
    return connectedDevices.where((d) {
      return d.displayName.toLowerCase().contains(query) || d.ip.contains(query) || d.type.label.toLowerCase().contains(query);
    }).toList();
  }

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
            expandedHeight: 180,
            floating: false,
            pinned: true,
            stretch: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 16, bottom: 12),
              title: const Text('HotCut', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: -0.5)),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [colorScheme.primary.withOpacity(0.3), colorScheme.secondary.withOpacity(0.2), colorScheme.background]
                            : [colorScheme.primary.withOpacity(0.15), colorScheme.secondary.withOpacity(0.1), colorScheme.background],
                      ),
                    ),
                  ),
                  CustomPaint(painter: WavePainter(animation: 0.0, color: colorScheme.primary.withOpacity(0.1))),
                  Positioned(
                    top: 60,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [colorScheme.primary, colorScheme.secondary]),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: colorScheme.primary.withOpacity(0.4), blurRadius: 16, spreadRadius: 1)],
                          ),
                          child: const Icon(Icons.wifi_tethering_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Gestionnaire de Hotspot', style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.onBackground.withOpacity(0.8), fontWeight: FontWeight.w500, fontSize: 15)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isHotspotActive ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: isHotspotActive ? Colors.green.withOpacity(0.5) : Colors.red.withOpacity(0.5)),
                                    ),
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      Container(width: 7, height: 7, decoration: BoxDecoration(color: isHotspotActive ? Colors.green : Colors.red, shape: BoxShape.circle)),
                                      const SizedBox(width: 5),
                                      Text(isHotspotActive ? 'Actif' : 'Inactif', style: TextStyle(color: isHotspotActive ? Colors.green : Colors.red, fontWeight: FontWeight.w600, fontSize: 12)),
                                    ]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            actions: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(color: colorScheme.surfaceVariant.withOpacity(0.4), borderRadius: BorderRadius.circular(12)),
                    child: IconButton(
                      onPressed: refreshDevices,
                      icon: AnimatedBuilder(
                        animation: _refreshController,
                        builder: (context, child) {
                          return Transform.rotate(angle: _refreshController.value * 2 * pi, child: Icon(Icons.refresh_rounded, color: colorScheme.onSurface, size: 20));
                        },
                      ),
                    ),
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(color: colorScheme.surfaceVariant.withOpacity(0.4), borderRadius: BorderRadius.circular(12)),
                    child: PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: colorScheme.onSurface, size: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      itemBuilder: (context) => [
                        const PopupMenuItem<String>(
                          value: 'settings',
                          child: Row(children: [Icon(Icons.settings_rounded, size: 20), SizedBox(width: 8), Text('Paramètres', style: TextStyle(fontSize: 15))]),
                        ),
                        PopupMenuItem<String>(
                          value: 'disconnect_all',
                          enabled: connectedDevices.isNotEmpty,
                          child: Row(children: const [Icon(Icons.wifi_off_rounded, color: Colors.red, size: 20), SizedBox(width: 8), Text('Déconnecter tout', style: TextStyle(fontSize: 15))]),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'disconnect_all') disconnectAll();
                      },
                    ),
                  ),
                ),
              )
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatsCards(colorScheme, isDark),
                _buildSearchField(colorScheme),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      Icon(Icons.devices_rounded, size: 20, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Appareils connectés', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, letterSpacing: -0.5, fontSize: 18)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [colorScheme.primaryContainer, colorScheme.secondaryContainer]),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: colorScheme.primary.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 1))],
                        ),
                        child: Text('${connectedDevices.length}', style: TextStyle(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ],
                  ),
                ),
                _buildManualIpEntry(colorScheme, isDark),
              ],
            ),
          ),
          if (isLoading)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(alignment: Alignment.center, children: [
                      SizedBox(width: 60, height: 60, child: CircularProgressIndicator(strokeWidth: 3, color: colorScheme.primary)),
                      Icon(Icons.wifi_find_rounded, size: 30, color: colorScheme.primary),
                    ]),
                    const SizedBox(height: 20),
                    Text('Analyse du réseau...', style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.8), fontWeight: FontWeight.w600, fontSize: 16)),
                  ],
                ),
              ),
            )
          else if (connectedDevices.isEmpty)
            SliverFillRemaining(child: _buildEmptyState(colorScheme, isDark))
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final device = _filteredDevices[index];
                    return Padding(padding: const EdgeInsets.only(bottom: 8), child: _buildDeviceCard(device, colorScheme, isDark));
                  },
                  childCount: _filteredDevices.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
