package com.blockdrop.game

import android.app.UiModeManager
import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.util.Log
import java.net.Inet4Address
import java.net.NetworkInterface
import java.util.Collections
import android.content.pm.PackageManager
import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var discoveryMulticastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.blockdrop.game/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isTelevision" -> {
                        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
                        result.success(
                            uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
                                packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
                        )
                    }
                    "lanAddress" -> result.success(detectLanAddress())
                    "setDiscoveryMulticastLock" -> {
                        setDiscoveryMulticastLock(call.arguments == true)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun detectLanAddress(): Map<String, Any>? {
        val connectivity = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        // Inspect physical transports, not the VPN-backed default network.
        // https://developer.android.com/develop/connectivity/network-ops/reading-network-state
        val activeLan = runCatching {
            connectivity.allNetworks.mapNotNull { network ->
                val capabilities = connectivity.getNetworkCapabilities(network) ?: return@mapNotNull null
                val priority = when {
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> 2
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> 1
                    else -> return@mapNotNull null
                }
                val address = connectivity.getLinkProperties(network)?.linkAddresses
                    ?.firstOrNull { it.address is Inet4Address && !it.address.isLoopbackAddress }
                    ?: return@mapNotNull null
                priority to mapOf(
                    "ip" to address.address.hostAddress,
                    "prefixLength" to address.prefixLength,
                )
            }.maxByOrNull { it.first }?.second
        }.onFailure { Log.w("BlockDropLAN", "Reading Android connectivity failed", it) }.getOrNull()
        if (activeLan != null) {
            Log.i("BlockDropLAN", "Physical LAN via ConnectivityManager: $activeLan")
            return activeLan
        }

        // A statically configured Ethernet adapter can be absent from Android's
        // connectivity service (notably inside Waydroid), yet still have an IP.
        val interfaceLan = runCatching {
            Collections.list(NetworkInterface.getNetworkInterfaces()).asSequence()
                .filter { it.isUp && !it.isLoopback && !it.isPointToPoint }
                .flatMap { networkInterface ->
                    networkInterface.interfaceAddresses.asSequence()
                        .filter { it.address is Inet4Address && !it.address.isLoopbackAddress }
                        .map { address ->
                            val name = networkInterface.name.lowercase()
                            val priority = when {
                                name.startsWith("wlan") || name.startsWith("wifi") -> 2
                                name.startsWith("eth") || name.startsWith("en") -> 1
                                else -> 0
                            }
                            priority to mapOf(
                                "ip" to address.address.hostAddress,
                                "prefixLength" to address.networkPrefixLength.toInt(),
                            )
                        }
                }.maxByOrNull { it.first }?.second
        }.onFailure { Log.w("BlockDropLAN", "Reading network interfaces failed", it) }.getOrNull()
        Log.i("BlockDropLAN", "Physical LAN via interface fallback: $interfaceLan")
        return interfaceLan
    }

    private fun setDiscoveryMulticastLock(enabled: Boolean) {
        if (!enabled) {
            discoveryMulticastLock?.takeIf { it.isHeld }?.release()
            return
        }
        // Wi-Fi can filter incoming multicast discovery without this lock.
        // https://developer.android.com/reference/android/net/wifi/WifiManager.MulticastLock
        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager ?: return
        val lock = discoveryMulticastLock ?: wifi.createMulticastLock("blockdrop-lan-discovery")
            .apply {
                setReferenceCounted(false)
                discoveryMulticastLock = this
            }
        if (!lock.isHeld) lock.acquire()
    }

    override fun onDestroy() {
        setDiscoveryMulticastLock(false)
        super.onDestroy()
    }
}
