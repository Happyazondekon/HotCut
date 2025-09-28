import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';

void main() {
  runApp(HotspotManagerApp());
}

class HotspotManagerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HotCut',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HotspotManager(),
    );
  }
}

class ConnectedDevice {
  final String mac;
  final String ip;
  final String hostname;
  final String? deviceName;

  ConnectedDevice({
    required this.mac,
    required this.ip,
    required this.hostname,
    this.deviceName,
  });

  factory ConnectedDevice.fromJson(Map<String, dynamic> json) {
    return ConnectedDevice(
      mac: json['mac'] ?? '',
      ip: json['ip'] ?? '',
      hostname: json['hostname'] ?? 'Inconnu',
      deviceName: json['deviceName'],
    );
  }
}

class HotspotManager extends StatefulWidget {
  @override
  _HotspotManagerState createState() => _HotspotManagerState();
}

class _HotspotManagerState extends State<HotspotManager> {
  List<ConnectedDevice> connectedDevices = [];
  bool isLoading = false;
  String? hotspotInterface = 'wlan0'; // Interface par défaut

  @override
  void initState() {
    super.initState();
    refreshDevices();
  }

  // Méthode pour scanner les appareils connectés
  Future<void> refreshDevices() async {
    setState(() {
      isLoading = true;
    });

    try {
      List<ConnectedDevice> devices = await getConnectedDevices();
      setState(() {
        connectedDevices = devices;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      showErrorDialog('Erreur lors du scan: $e');
    }
  }

  // Obtenir la liste des appareils connectés
  Future<List<ConnectedDevice>> getConnectedDevices() async {
    List<ConnectedDevice> devices = [];

    try {
      // Méthode 1: Utiliser arp-scan (nécessite installation)
      ProcessResult arpResult = await Process.run('arp-scan', ['-l']);
      if (arpResult.exitCode == 0) {
        devices.addAll(parseArpScan(arpResult.stdout));
      }

      // Méthode 2: Lire la table ARP du système
      if (devices.isEmpty) {
        devices.addAll(await parseArpTable());
      }

      // Méthode 3: Scanner le réseau avec nmap (si disponible)
      if (devices.isEmpty) {
        devices.addAll(await nmapScan());
      }

    } catch (e) {
      print('Erreur lors du scan: $e');
    }

    return devices;
  }

  // Parser le résultat d'arp-scan
  List<ConnectedDevice> parseArpScan(String output) {
    List<ConnectedDevice> devices = [];
    List<String> lines = output.split('\n');

    for (String line in lines) {
      if (line.contains('\t')) {
        List<String> parts = line.split('\t');
        if (parts.length >= 2) {
          devices.add(ConnectedDevice(
            ip: parts[0].trim(),
            mac: parts[1].trim(),
            hostname: parts.length > 2 ? parts[2].trim() : 'Inconnu',
          ));
        }
      }
    }

    return devices;
  }

  // Lire la table ARP du système
  Future<List<ConnectedDevice>> parseArpTable() async {
    List<ConnectedDevice> devices = [];

    try {
      String arpPath = Platform.isLinux ? '/proc/net/arp' : '';
      if (arpPath.isNotEmpty && await File(arpPath).exists()) {
        String content = await File(arpPath).readAsString();
        List<String> lines = content.split('\n');

        for (int i = 1; i < lines.length; i++) {
          List<String> parts = lines[i].split(RegExp(r'\s+'));
          if (parts.length >= 6 && parts[3] != '00:00:00:00:00:00') {
            devices.add(ConnectedDevice(
              ip: parts[0],
              mac: parts[3],
              hostname: 'Appareil-${parts[0].split('.').last}',
            ));
          }
        }
      }
    } catch (e) {
      print('Erreur lecture ARP: $e');
    }

    return devices;
  }

  // Scanner avec nmap
  Future<List<ConnectedDevice>> nmapScan() async {
    List<ConnectedDevice> devices = [];

    try {
      // Obtenir la plage réseau
      ProcessResult result = await Process.run('ip', ['route', 'show']);
      String networkRange = '192.168.1.0/24'; // Par défaut

      if (result.exitCode == 0) {
        // Parser pour trouver la vraie plage réseau
        List<String> lines = result.stdout.split('\n');
        for (String line in lines) {
          if (line.contains(hotspotInterface ?? 'wlan0')) {
            // Extraire la plage réseau de la ligne
            break;
          }
        }
      }

      ProcessResult nmapResult = await Process.run('nmap', ['-sn', networkRange]);
      if (nmapResult.exitCode == 0) {
        // Parser les résultats nmap
        String output = nmapResult.stdout;
        RegExp ipRegex = RegExp(r'Nmap scan report for (\S+) \((\d+\.\d+\.\d+\.\d+)\)');

        for (RegExpMatch match in ipRegex.allMatches(output)) {
          String hostname = match.group(1) ?? 'Inconnu';
          String ip = match.group(2) ?? '';

          // Obtenir l'adresse MAC via ARP
          ProcessResult arpResult = await Process.run('arp', ['-n', ip]);
          String mac = 'Inconnu';
          if (arpResult.exitCode == 0) {
            List<String> arpParts = arpResult.stdout.split(' ');
            if (arpParts.length > 3) {
              mac = arpParts[3];
            }
          }

          devices.add(ConnectedDevice(
            ip: ip,
            mac: mac,
            hostname: hostname,
          ));
        }
      }
    } catch (e) {
      print('Erreur nmap: $e');
    }

    return devices;
  }

  // Déconnecter un appareil
  Future<void> disconnectDevice(ConnectedDevice device) async {
    try {
      // Méthode 1: Bloquer via iptables
      ProcessResult result = await Process.run('sudo', [
        'iptables',
        '-A', 'INPUT',
        '-s', device.ip,
        '-j', 'DROP'
      ]);

      if (result.exitCode == 0) {
        // Aussi bloquer en sortie
        await Process.run('sudo', [
          'iptables',
          '-A', 'OUTPUT',
          '-d', device.ip,
          '-j', 'DROP'
        ]);

        showSuccessDialog('Appareil ${device.hostname} (${device.ip}) déconnecté');
        refreshDevices();
      } else {
        throw Exception('Échec de la déconnexion');
      }
    } catch (e) {
      showErrorDialog('Erreur lors de la déconnexion: $e');
    }
  }

  // Débloquer un appareil
  Future<void> unblockDevice(ConnectedDevice device) async {
    try {
      // Supprimer les règles iptables
      await Process.run('sudo', [
        'iptables',
        '-D', 'INPUT',
        '-s', device.ip,
        '-j', 'DROP'
      ]);

      await Process.run('sudo', [
        'iptables',
        '-D', 'OUTPUT',
        '-d', device.ip,
        '-j', 'DROP'
      ]);

      showSuccessDialog('Appareil ${device.hostname} débloqué');
      refreshDevices();
    } catch (e) {
      showErrorDialog('Erreur lors du déblocage: $e');
    }
  }

  // Couper tous les appareils
  Future<void> disconnectAll() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmation'),
        content: Text('Voulez-vous vraiment déconnecter tous les appareils ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (ConnectedDevice device in connectedDevices) {
        await disconnectDevice(device);
      }
    }
  }

  void showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Erreur'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Succès'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gestionnaire Hotspot'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: refreshDevices,
          ),
          IconButton(
            icon: Icon(Icons.block),
            onPressed: connectedDevices.isNotEmpty ? disconnectAll : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistiques
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '${connectedDevices.length}',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text('Appareils connectés'),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      hotspotInterface ?? 'N/A',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text('Interface'),
                  ],
                ),
              ],
            ),
          ),

          // Liste des appareils
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : connectedDevices.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Aucun appareil connecté'),
                  SizedBox(height: 8),
                  TextButton(
                    onPressed: refreshDevices,
                    child: Text('Actualiser'),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: connectedDevices.length,
              itemBuilder: (context, index) {
                ConnectedDevice device = connectedDevices[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.devices, color: Colors.white),
                    ),
                    title: Text(device.hostname),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('IP: ${device.ip}'),
                        Text('MAC: ${device.mac}'),
                      ],
                    ),
                    trailing: PopupMenuButton(
                      onSelected: (value) {
                        if (value == 'disconnect') {
                          disconnectDevice(device);
                        } else if (value == 'unblock') {
                          unblockDevice(device);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'disconnect',
                          child: Row(
                            children: [
                              Icon(Icons.block, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Déconnecter'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'unblock',
                          child: Row(
                            children: [
                              Icon(Icons.wifi, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Débloquer'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: refreshDevices,
        child: Icon(Icons.refresh),
        tooltip: 'Actualiser la liste',
      ),
    );
  }
}