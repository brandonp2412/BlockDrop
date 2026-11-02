package com.blockdrop.game

import android.Manifest
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.wifi.WifiManager
import android.net.wifi.p2p.WifiP2pConfig
import android.net.wifi.p2p.WifiP2pManager
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address
import java.net.NetworkInterface

/** Optional Android Wi-Fi Direct group lifecycle; gameplay remains raw TCP. */
class WifiDirectBridge(private val activity: Activity, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val manager = activity.getSystemService(Context.WIFI_P2P_SERVICE) as? WifiP2pManager
    private val channel = manager?.initialize(activity, activity.mainLooper) { lostConnection() }
    private val wifi = activity.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
    private val methods = MethodChannel(messenger, "com.blockdrop.game/wifi_direct")
    private val events = EventChannel(messenger, "com.blockdrop.game/wifi_direct/events")
    private val permissionCode = 9712
    private var permissionResult: MethodChannel.Result? = null
    private var sink: EventChannel.EventSink? = null
    private var registered = false
    private var groupOwner = false
    private var connected = false
    private var ownerIp: String? = null
    private var groupInterface: String? = null
    private var peers: List<Map<String, Any>> = emptyList()
    private val supported get() = manager != null && channel != null &&
        activity.packageManager.hasSystemFeature(PackageManager.FEATURE_WIFI_DIRECT)
    private val permission get() = if (Build.VERSION.SDK_INT >= 33)
        Manifest.permission.NEARBY_WIFI_DEVICES else Manifest.permission.ACCESS_FINE_LOCATION
    private val hasPermission get() = activity.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION -> {
                    if (intent.getIntExtra(WifiP2pManager.EXTRA_WIFI_STATE, -1) !=
                        WifiP2pManager.WIFI_P2P_STATE_ENABLED) lostConnection()
                    emit()
                }
                WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION -> refreshPeers()
                WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION -> refreshConnection()
            }
        }
    }

    init {
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    fun resume() {
        if (!registered) {
            val filter = IntentFilter().apply {
                addAction(WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION)
                addAction(WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION)
                addAction(WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION)
            }
            activity.registerReceiver(receiver, filter)
            registered = true
        }
        refreshConnection()
        refreshPeers()
        emit()
    }

    fun pause() {
        if (registered) activity.unregisterReceiver(receiver)
        registered = false
    }

    fun dispose() {
        pause()
        permissionResult?.error("cancelled", "Activity closed during permission request", null)
        permissionResult = null
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        sink = null
    }

    fun permissionResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != permissionCode) return false
        permissionResult?.success(grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED })
        permissionResult = null
        emit()
        return true
    }

    override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
        sink = eventSink
        emit()
    }

    override fun onCancel(arguments: Any?) { sink = null }

    private fun snapshot(): Map<String, Any?> = mapOf(
        "supported" to supported,
        "wifiEnabled" to (wifi?.isWifiEnabled == true),
        "permissionGranted" to hasPermission,
        "connected" to connected,
        "groupOwner" to groupOwner,
        "groupOwnerIp" to ownerIp,
        "peers" to peers,
    )

    private fun emit() { sink?.success(snapshot()) }

    private fun lostConnection() {
        connected = false
        groupOwner = false
        ownerIp = null
        groupInterface = null
        emit()
    }

    private fun refreshPeers() {
        if (!supported || !hasPermission) return
        try {
            manager!!.requestPeers(channel!!) { list ->
                peers = list.deviceList.map {
                    mapOf("name" to it.deviceName, "address" to it.deviceAddress,
                        "status" to it.status)
                }
                emit()
            }
        } catch (_: SecurityException) { emit() }
    }

    private fun fillLocalOwnerAddress() {
        if (!connected || !groupOwner || ownerIp != null || groupInterface == null) return
        ownerIp = runCatching {
            NetworkInterface.getByName(groupInterface)?.inetAddresses
                ?.asSequence()?.filterIsInstance<Inet4Address>()
                ?.firstOrNull { !it.isLoopbackAddress }?.hostAddress
        }.getOrNull()
    }

    private fun refreshConnection() {
        if (!supported || !hasPermission) return
        try {
            manager!!.requestConnectionInfo(channel!!) { info ->
                connected = info.groupFormed
                groupOwner = info.groupFormed && info.isGroupOwner
                ownerIp = if (info.groupFormed) info.groupOwnerAddress?.hostAddress else null
                if (!info.groupFormed) groupInterface = null
                fillLocalOwnerAddress()
                emit()
            }
            manager.requestGroupInfo(channel) { group ->
                groupInterface = group?.`interface`
                fillLocalOwnerAddress()
                emit()
            }
        } catch (_: SecurityException) { emit() }
    }

    private fun ready(result: MethodChannel.Result): Boolean {
        if (!supported) { result.error("unsupported", "Wi-Fi Direct is unavailable on this device", null); return false }
        if (wifi?.isWifiEnabled != true) { result.error("wifi_off", "Turn on Wi-Fi before using Wi-Fi Direct", null); return false }
        if (!hasPermission) { result.error("permission_denied", "Nearby devices permission is required", null); return false }
        return true
    }

    private fun action(result: MethodChannel.Result, operation: (WifiP2pManager.ActionListener) -> Unit) {
        if (!ready(result)) return
        try {
            operation(object : WifiP2pManager.ActionListener {
                override fun onSuccess() { result.success(null); refreshConnection() }
                override fun onFailure(reason: Int) {
                    result.error("operation_failed", "Wi-Fi Direct rejected request ($reason)", null)
                }
            })
        } catch (_: SecurityException) {
            result.error("permission_denied", "Wi-Fi Direct permission was denied", null)
        } catch (_: UnsupportedOperationException) {
            result.error("unsupported", "Wi-Fi Direct operation is unsupported", null)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> { refreshConnection(); result.success(snapshot()) }
            "requestPermission" -> {
                if (!supported) { result.error("unsupported", "Wi-Fi Direct unsupported", null); return }
                if (hasPermission) { result.success(true); return }
                if (permissionResult != null) { result.error("busy", "Permission request already open", null); return }
                permissionResult = result
                activity.requestPermissions(arrayOf(permission), permissionCode)
            }
            "discover" -> action(result) { manager!!.discoverPeers(channel!!, it) }
            "peers" -> {
                if (!ready(result)) return
                manager!!.requestPeers(channel!!) { list ->
                    peers = list.deviceList.map {
                        mapOf("name" to it.deviceName, "address" to it.deviceAddress,
                            "status" to it.status)
                    }
                    emit()
                    result.success(peers)
                }
            }
            "createGroup" -> {
                if (connected) { result.error("busy", "Disconnect the current Wi-Fi Direct group first", null); return }
                action(result) { manager!!.createGroup(channel!!, it) }
            }
            "connect" -> {
                if (connected) { result.error("busy", "Disconnect the current Wi-Fi Direct group first", null); return }
                val address = call.argument<String>("address")
                if (address == null || !Regex("(?i)^([0-9a-f]{2}:){5}[0-9a-f]{2}$").matches(address) ||
                    peers.none { it["address"] == address }) {
                    result.error("invalid_peer", "Choose a discovered Wi-Fi Direct peer", null)
                    return
                }
                action(result) {
                    val config = WifiP2pConfig().apply { deviceAddress = address; groupOwnerIntent = 0 }
                    manager!!.connect(channel!!, config, it)
                }
            }
            "cancelConnect" -> action(result) { manager!!.cancelConnect(channel!!, it) }
            "disconnect" -> {
                if (!supported) { result.error("unsupported", "Wi-Fi Direct unsupported", null); return }
                action(result) { manager!!.removeGroup(channel!!, it) }
            }
            else -> result.notImplemented()
        }
    }
}
