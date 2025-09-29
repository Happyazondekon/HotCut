package com.heyhappy.hotcut

import android.content.Context
import android.net.ConnectivityManager
import android.net.wifi.WifiManager
import android.os.Build
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.InetAddress
import java.util.concurrent.Executors

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.hotcut/network"
    private val executor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getConnectedDevices" -> {
                    executor.execute {
                        try {
                            val devices = scanNetwork()
                            runOnUiThread {
                                result.success(devices)
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("UNAVAILABLE", "Erreur lors du scan: ${e.message}", null)
                            }
                        }
                    }
                }
                "isHotspotEnabled" -> {
                    try {
                        val isEnabled = isHotspotEnabled()
                        result.success(isEnabled)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Erreur vérification hotspot: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Scan réseau avec plusieurs méthodes de détection
     */
    private fun scanNetwork(): List<Map<String, String>> {
        val devices = mutableListOf<Map<String, String>>()

        // Méthode 1: Tentative de lecture ARP via 'ip neigh' (plus moderne que /proc/net/arp)
        try {
            val ipNeighDevices = readArpViaIpCommand()
            devices.addAll(ipNeighDevices)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // Méthode 2: Si rien trouvé, scan ping sur les sous-réseaux courants
        if (devices.isEmpty()) {
            devices.addAll(scanTypicalHotspotSubnet())
        }

        return devices
    }

    /**
     * Utilise la commande 'ip neigh' au lieu de lire /proc/net/arp
     * Cette méthode fonctionne mieux sur Android 10+
     */
    private fun readArpViaIpCommand(): List<Map<String, String>> {
        val devices = mutableListOf<Map<String, String>>()
        try {
            val process = Runtime.getRuntime().exec("ip neigh show")
            val reader = BufferedReader(InputStreamReader(process.inputStream))

            var line: String?
            while (reader.readLine().also { line = it } != null) {
                // Format: 192.168.43.109 dev wlan0 lladdr 40:37:3d:xx:xx:xx REACHABLE
                val parts = line!!.split(Regex("\\s+"))

                if (parts.size >= 5) {
                    val ip = parts[0]
                    var mac = ""

                    // Chercher l'adresse MAC après "lladdr"
                    for (i in parts.indices) {
                        if (parts[i] == "lladdr" && i + 1 < parts.size) {
                            mac = parts[i + 1]
                            break
                        }
                    }

                    if (mac.isNotEmpty() && mac != "00:00:00:00:00:00" && mac.contains(':')) {
                        val hostname = try {
                            InetAddress.getByName(ip).hostName
                        } catch (e: Exception) {
                            ip
                        }

                        devices.add(
                            mapOf(
                                "ip" to ip,
                                "hostname" to hostname,
                                "mac" to mac.uppercase(),
                                "type" to guessDeviceType(hostname)
                            )
                        )
                    }
                }
            }
            reader.close()
            process.waitFor()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return devices
    }

    /**
     * Scan les plages d'IPs typiques d'un hotspot avec ping plus rapide
     */
    private fun scanTypicalHotspotSubnet(): List<Map<String, String>> {
        val devices = mutableListOf<Map<String, String>>()

        // Sous-réseaux Android courants
        val commonSubnets = listOf(
            "192.168.43.",  // Le plus courant sur Android
            "192.168.49.",  // Alternatif
            "192.168.14.",  // Samsung
            "192.168.50."   // Autre courant
        )

        for (baseIp in commonSubnets) {
            try {
                // Scan parallèle plus rapide (plage réduite pour la performance)
                val threads = mutableListOf<Thread>()

                for (i in 0..220) { // Scan les 50 premières adresses
                    val thread = Thread {
                        try {
                            val currentIpString = baseIp + i
                            val addr = InetAddress.getByName(currentIpString)

                            // Ping rapide avec timeout court
                            if (addr.isReachable(100)) {
                                synchronized(devices) {
                                    // Vérifier les doublons
                                    if (devices.none { it["ip"] == addr.hostAddress }) {
                                        val hostname = try {
                                            addr.canonicalHostName
                                        } catch (e: Exception) {
                                            addr.hostAddress
                                        }

                                        devices.add(
                                            mapOf(
                                                "ip" to (addr.hostAddress ?: currentIpString),
                                                "hostname" to hostname,
                                                "mac" to "N/A",
                                                "type" to guessDeviceType(hostname)
                                            )
                                        )
                                    }
                                }
                            }
                        } catch (e: Exception) {
                            // Ignorer les erreurs de ping individuelles
                        }
                    }
                    threads.add(thread)
                    thread.start()
                }

                // Attendre tous les threads (max 5 secondes par sous-réseau)
                threads.forEach {
                    try {
                        it.join(5000)
                    } catch (e: InterruptedException) {
                        // Timeout
                    }
                }

                // Si on a trouvé des appareils, pas besoin de scanner d'autres sous-réseaux
                if (devices.isNotEmpty()) {
                    break
                }

            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        return devices
    }

    /**
     * Détection du type d'appareil basée sur le hostname
     */
    private fun guessDeviceType(hostname: String): String {
        val h = hostname.lowercase()
        return when {
            h.contains("iphone") || h.contains("ios") -> "phone"
            h.contains("android") || h.contains("galaxy") || h.contains("pixel") ||
                    h.contains("xiaomi") || h.contains("oppo") || h.contains("huawei") -> "phone"
            h.contains("macbook") || h.contains("laptop") || h.contains("notebook") -> "laptop"
            h.contains("ipad") || h.contains("tablet") -> "tablet"
            h.contains("pc") || h.contains("desktop") || h.contains("windows") -> "desktop"
            h.contains("imac") || h.contains("mac-") -> "desktop"
            else -> "unknown"
        }
    }

    /**
     * Vérification si le hotspot est activé
     */
    private fun isHotspotEnabled(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // Android 13+ : Utiliser l'API officielle si disponible
                checkHotspotStatusModern()
            } else {
                // Anciennes versions : Méthode par réflexion
                checkHotspotStatusLegacy()
            }
        } catch (e: Exception) {
            e.printStackTrace()
            // En cas d'erreur, vérifier si l'interface wlan0 est active
            checkWlanInterface()
        }
    }

    @RequiresApi(Build.VERSION_CODES.TIRAMISU)
    private fun checkHotspotStatusModern(): Boolean {
        // Pour Android 13+, on peut utiliser ConnectivityManager
        val cm = applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        return try {
            // Vérifier si une interface de type tethering est active
            cm.allNetworks.any { network ->
                val networkCapabilities = cm.getNetworkCapabilities(network)
                networkCapabilities?.hasTransport(android.net.NetworkCapabilities.TRANSPORT_WIFI) == true
            }
        } catch (e: Exception) {
            checkHotspotStatusLegacy()
        }
    }

    private fun checkHotspotStatusLegacy(): Boolean {
        return try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val method = wifiManager.javaClass.getDeclaredMethod("isWifiApEnabled")
            method.isAccessible = true
            method.invoke(wifiManager) as Boolean
        } catch (e: Exception) {
            false
        }
    }

    private fun checkWlanInterface(): Boolean {
        return try {
            val process = Runtime.getRuntime().exec("ip addr show wlan0")
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            val output = reader.readText()
            reader.close()

            // Si wlan0 contient "UP" et "BROADCAST", le hotspot est probablement actif
            output.contains("UP") && output.contains("BROADCAST")
        } catch (e: Exception) {
            false
        }
    }
}