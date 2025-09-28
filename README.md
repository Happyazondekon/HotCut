# HotCut 🔥📱

Une application Flutter moderne et élégante pour gérer les appareils connectés à votre hotspot WiFi. Surveillez, contrôlez et gérez tous les appareils connectés à votre réseau avec une interface utilisateur intuitive et des fonctionnalités avancées.

## ✨ Fonctionnalités

### 🎯 Fonctionnalités principales
- **Détection automatique** des appareils connectés
- **Blocage/déblocage** d'appareils spécifiques
- **Déconnexion forcée** d'appareils
- **Surveillance en temps réel** avec actualisation automatique
- **Identification intelligente** des types d'appareils
- **Interface moderne** avec thème sombre/clair

### 📊 Statistiques et monitoring
- Nombre total d'appareils connectés
- Appareils actifs vs bloqués
- Durée de connexion de chaque appareil
- Informations détaillées (IP, MAC, fabricant)

### 🎨 Interface utilisateur
- Design moderne avec Material Design 3
- Animations fluides et micro-interactions
- Thème adaptatif (clair/sombre)
- Interface responsive et intuitive
- Cartes d'appareils avec informations détaillées

### 🔧 Fonctionnalités avancées
- Tri par nom, IP, type ou heure de connexion
- Filtrage des appareils (afficher/masquer bloqués)
- Actions groupées (bloquer tous)
- Détection automatique du type d'appareil
- Reconnaissance du fabricant via MAC

## 🏗️ Architecture

L'application suit une architecture propre et modulaire :

```
lib/
├── main.dart                 # Point d'entrée

```

## 🚀 Installation

### Prérequis
- Flutter SDK (>= 3.0.0)
- Android SDK (API niveau 21+)
- Dart SDK (>= 3.0.0)
- Un appareil Android avec accès root (pour certaines fonctionnalités)

### Outils système requis
Pour un fonctionnement optimal, installez ces outils sur votre système :

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install arp-scan nmap iproute2 iptables

# CentOS/RHEL/Fedora
sudo yum install arp-scan nmap iproute iptables

# Arch Linux
sudo pacman -S arp-scan nmap iproute2 iptables
```

### Installation de l'application

1. **Cloner le repository**
```bash
git clone https://github.com/votreusername/hotcut.git
cd hotcut
```

2. **Installer les dépendances**
```bash
flutter pub get
```

3. **Générer les fichiers nécessaires**
```bash
flutter pub run build_runner build
```

4. **Lancer l'application**
```bash
flutter run
```

## 📱 Utilisation

### Première utilisation

1. **Permissions** : L'application demande les permissions nécessaires au premier lancement
2. **Détection automatique** : Le scan des appareils se lance automatiquement
3. **Interface principale** : Vous accédez à la liste des appareils connectés

### Actions disponibles

#### 🔍 Scanner les appareils
- Actualisation automatique toutes les 30 secondes
- Bouton de rafraîchissement manuel
- Animation de chargement élégante

#### 🚫 Bloquer un appareil
1. Appuyez sur le menu (⋮) d'un appareil
2. Sélectionnez "Bloquer"
3. L'appareil est immédiatement bloqué via iptables

#### ✅ Débloquer un appareil
1. Appuyez sur le menu (⋮) d'un appareil bloqué
2. Sélectionnez "Débloquer"
3. L'accès réseau est restauré

#### 🔌 Déconnecter un appareil
1. Appuyez sur le menu (⋮) d'un appareil
2. Sélectionnez "Déconnecter"
3. L'appareil est forcé à se déconnecter

#### 📊 Voir les détails
1. Appuyez sur une carte d'appareil
2. Une feuille modale affiche tous les détails
3. Informations complètes : IP, MAC, fabricant, etc.

## 🔧 Configuration

### Interface réseau
Par défaut, l'application utilise `wlan0` comme interface de hotspot. Pour modifier :

```dart
// Dans lib/services/device_service.dart
String? _hotspotInterface = 'wlan1'; // Changez selon votre configuration
```

### Intervalle de rafraîchissement
Pour modifier la fréquence d'actualisation :

```dart
// Dans lib/screens/home_screen.dart
_refreshTimer = Timer.periodic(Duration(seconds: 15), (timer) {
  // Changez 15 pour l'intervalle désiré en secondes
```

### Personnalisation du thème
Modifiez les couleurs dans `lib/theme/app_theme.dart` :

```dart
static const Color primaryColor = Color(0xFF667EEA); // Votre couleur
static const Color secondaryColor = Color(0xFF764BA2); // Votre couleur
```

## 🛠️ Fonctionnement technique

### Détection des appareils
L'application utilise plusieurs méthodes pour détecter les appareils :

1. **Table ARP** (`/proc/net/arp`) - Méthode principale
2. **arp-scan** - Scan réseau actif
3. **nmap** - Découverte réseau avancée

### Identification des appareils
- **Type d'appareil** : Basé sur les préfixes MAC et noms d'hôte
- **Fabricant** : Database des préfixes MAC OUI
- **Nom d'affichage** : Nom personnalisé > hostname > IP

### Gestion du blocage
- **iptables** : Règles INPUT/OUTPUT pour bloquer le trafic
- **DHCP release** : Libération du bail DHCP si disponible
- **Persistance** : Les règles sont temporaires (redémarrage les supprime)

## 🔒 Permissions et sécurité

### Permissions Android requises
```xml
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

### Permissions système (root)
Pour certaines fonctionnalités avancées :
```bash
# Blocage d'appareils
sudo iptables -A INPUT -s [IP] -j DROP

# Déconnexion DHCP
sudo dhcp_release [interface] [IP] [MAC]
```

## 🎨 Personnalisation

### Ajouter de nouveaux types d'appareils
Dans `lib/models/device_model.dart` :

```dart
enum DeviceType {
  smartphone,
  laptop,
  // Ajoutez votre nouveau type ici
  smartSpeaker,
  // ...
}
```

### Personnaliser l'identification
Dans `lib/services/device_service.dart`, méthode `_guessDeviceType()` :

```dart
// Ajoutez vos règles d'identification
if (hostnameL.contains('alexa') || hostnameL.contains('echo')) {
  return DeviceType.smartSpeaker;
}
```

### Modifier l'apparence des cartes
Dans `lib/widgets/device_card.dart`, personnalisez le `build()` :

```dart
// Changez les couleurs, icônes, layout selon vos préférences
```

## 🐛 Dépannage

### L'application ne détecte aucun appareil
1. Vérifiez que vous êtes sur le bon réseau
2. Confirmez l'interface réseau (`wlan0`, `wlan1`, etc.)
3. Installez les outils système requis (`arp-scan`, `nmap`)
4. Vérifiez les permissions de l'application

### Le blocage ne fonctionne pas
1. L'appareil doit avoir des privilèges root
2. `iptables` doit être installé et accessible
3. Vérifiez les règles : `sudo iptables -L`

### Erreurs de permissions
1. Accordez toutes les permissions demandées
2. Pour Android 10+, activez la localisation pour le WiFi
3. Redémarrez l'application après avoir accordé les permissions

### Performance lente
1. Réduisez l'intervalle de rafraîchissement
2. Limitez le nombre d'appareils affichés
3. Utilisez le filtrage pour masquer les appareils bloqués

## 📚 API et documentation

### Service DeviceService
```dart
// Obtenir les appareils connectés
List<ConnectedDevice> devices = await DeviceService().getConnectedDevices();

// Bloquer un appareil
bool success = await DeviceService().blockDevice(device);

// Débloquer un appareil
bool success = await DeviceService().unblockDevice(device);
```

### Modèle ConnectedDevice
```dart
ConnectedDevice device = ConnectedDevice(
  mac: '00:11:22:33:44:55',
  ip: '192.168.1.100',
  hostname: 'Mon-Appareil',
  deviceType: DeviceType.smartphone,
  vendor: 'Apple',
);
```

## 🤝 Contribution

Les contributions sont les bienvenues ! Voici comment contribuer :

1. **Fork** le projet
2. **Créer** une branche feature (`git checkout -b feature/AmazingFeature`)
3. **Commit** vos changements (`git commit -m 'Add AmazingFeature'`)
4. **Push** vers la branche (`git push origin feature/AmazingFeature`)
5. **Ouvrir** une Pull Request

### Standards de code
- Suivre les conventions Dart/Flutter
- Documenter les nouvelles fonctionnalités
- Tester sur plusieurs appareils
- Respecter l'architecture existante


Fait avec ❤️ par l'équipe HotCut