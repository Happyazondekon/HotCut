
# HotCut - Gestionnaire de Hotspot



Une application Flutter élégante et performante pour gérer et monitorer votre hotspot mobile Android.

## 🚀 Fonctionnalités

### 🔍 **Détection Intelligente**
- Scan automatique des appareils connectés à votre hotspot
- Détection du type d'appareil (smartphone, ordinateur, tablette, etc.)
- Informations détaillées : adresse MAC, IP, nom d'hôte, durée de connexion

### 🎨 **Interface Moderne**
- Design Material 3 avec thème sombre/clair automatique
- Animations fluides et feedback visuel
- Interface intuitive et responsive

### ⚡ **Gestion en Temps Réel**
- Statut du hotspot en direct
- Nombre d'appareils connectés
- Interface réseau utilisée
- Actualisation manuelle et automatique

### 🛡️ **Contrôle de Sécurité**
- Blocage/déblocage d'appareils individuels
- Déconnexion selective ou globale
- Protection contre les connexions non autorisées


## 🛠️ Installation

### Prérequis
- Flutter SDK 3.7.2 ou supérieur
- Android SDK
- Un appareil Android avec fonctionnalité hotspot

### Étapes d'installation

1. **Cloner le repository**
   ```bash
   git clone https://github.com/votre-username/hotcut.git
   cd hotcut
   ```

2. **Installer les dépendances**
   ```bash
   flutter pub get
   ```

3. **Configurer les permissions**
   L'application nécessite les permissions suivantes :
    - `ACCESS_WIFI_STATE`
    - `ACCESS_NETWORK_STATE`
    - `INTERNET`
    - `ACCESS_FINE_LOCATION` (pour Android 10+)

4. **Lancer l'application**
   ```bash
   flutter run
   ```

## 📱 Utilisation

### Premier Lancement
1. Activez le hotspot sur votre appareil Android
2. Lancez l'application HotCut
3. Accordez les permissions nécessaires
4. L'application scanne automatiquement les appareils connectés

### Gestion des Appareils
- **Actualiser** : Appuyez sur l'icône 🔄 pour scanner à nouveau
- **Bloquer un appareil** : Menu ⋮ → "Bloquer"
- **Déconnecter** : Menu ⋮ → "Déconnecter"
- **Déconnecter tout** : Menu ⋮ → "Déconnecter tout"

### Types d'Appareils Détectés
- 📱 **Téléphone** - Smartphones et téléphones mobiles
- 💻 **Ordinateur portable** - Laptops et notebooks
- 📟 **Tablette** - Tablettes et iPads
- 🖥️ **Ordinateur fixe** - PCs de bureau
- 🌐 **Routeur** - Équipements réseau
- ❓ **Inconnu** - Appareils non identifiés

## 🔧 Configuration Technique

### Structure du Projet
```
hotcut/
├── android/          # Configuration Android
├── ios/              # Configuration iOS
├── lib/
│   ├── main.dart     # Point d'entrée de l'application
│   └── ...          # Autres fichiers Dart
├── pubspec.yaml      # Dépendances et métadonnées
└── README.md
```

### Dépendances Principales
- `flutter` - Framework UI
- `process_run` - Exécution de commandes système
- `google_fonts` - Polices personnalisées
- `permission_handler` - Gestion des permissions

### Permissions Android
```xml
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

## 🎯 Fonctionnalités Techniques

### Détection des Appareils
L'application utilise plusieurs méthodes pour détecter les appareils connectés :

1. **Table ARP** - Lecture de `/proc/net/arp`
2. **Résolution DNS** - Recherche des noms d'hôte
3. **Analyse OUI** - Identification par adresse MAC

### Algorithmes d'Identification
```dart
DeviceType _determineDeviceType(String mac) {
  final oui = mac.substring(0, 8).toUpperCase();
  // Logique de correspondance OUI -> type d'appareil
}
```

## 🐛 Dépannage

### Problèmes Courants

**❌ Aucun appareil détecté**
- Vérifiez que le hotspot est activé
- Assurez-vous que des appareils sont connectés
- Vérifiez les permissions de localisation

**❌ Erreur de permissions**
- Réinstallez l'application
- Accordez manuellement les permissions dans Paramètres → Applications

**❌ Scan échoue**
- Redémarrez l'application
- Vérifiez la connexion Internet

### Logs de Débogage
Activez les logs détaillés avec :
```bash
flutter run --verbose
```

## 📊 Métriques

- **Temps de scan** : 2-3 secondes
- **Consommation mémoire** : ~50-80 MB
- **Compatibilité** : Android 8.0+
- **Taille APK** : ~15-20 MB

## 🤝 Contribution

Les contributions sont les bienvenues !

1. Fork le projet
2. Créez votre branche (`git checkout -b feature/AmazingFeature`)
3. Commit vos changements (`git commit -m 'Add some AmazingFeature'`)
4. Push sur la branche (`git push origin feature/AmazingFeature`)
5. Ouvrez une Pull Request

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier `LICENSE` pour plus de détails.

## 👨‍💻 Développement

### Architecture
- **State Management** : setState pour une simplicité
- **Design Pattern** : MVVM implicite
- **Animation** : Controllers personnalisés

### Améliorations Futures
- [ ] Support iOS
- [ ] Historique des connexions
- [ ] Notifications de nouvelle connexion
- [ ] Mode paysage
- [ ] Export des logs
- [ ] Widget home screen


<div align="center">

**Développé avec ❤️ et Flutter**



