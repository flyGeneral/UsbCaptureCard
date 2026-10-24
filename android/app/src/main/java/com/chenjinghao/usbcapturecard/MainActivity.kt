package com.chenjinghao.usbcapturecard

import android.Manifest
import android.content.pm.PackageManager
import android.hardware.usb.UsbDevice
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.PopupMenu
import android.widget.Toast
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.chenjinghao.usbcapturecard.databinding.ActivityMainBinding
import com.jiangdg.ausbc.CameraClient
import com.jiangdg.ausbc.base.CameraActivity
import com.jiangdg.ausbc.camera.CameraUvcStrategy
import com.jiangdg.ausbc.camera.bean.CameraRequest
import com.jiangdg.ausbc.callback.ICaptureCallBack
import com.jiangdg.ausbc.callback.IDeviceConnectCallBack
import com.jiangdg.ausbc.callback.IPlayCallBack
import com.jiangdg.ausbc.widget.IAspectRatio
import com.serenegiant.usb.USBMonitor
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 采集卡预览主界面(AUSBC 3.2.7)。
 *
 * 继承 CameraActivity 后,库内部负责:USB 权限申请、UVC 设备枚举/热插拔、
 * MJPEG 解码(失败自动退 YUV)、OpenGL 渲染、音频监听与 MP4 编码。
 * 子类只需提供预览视图与注入 UVC 策略的 CameraClient。
 *
 * 注意:3.2.7 的 openCamera 有运行时 CAMERA 权限门槛(即使 UVC 无需系统相机),
 * 未授权时 openCamera 静默返回,需在授权回调里手动重试。
 */
class MainActivity : CameraActivity() {

    companion object {
        private const val REQ_CAMERA_PERMISSION = 100
    }

    private var binding: ActivityMainBinding? = null
    private var client: CameraClient? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private var cameraReady = false
    private var muted = false
    private var isRecording = false
    private var recordStartMs = 0L

    private val tickRunnable = object : Runnable {
        override fun run() {
            if (!isRecording) return
            val sec = ((System.currentTimeMillis() - recordStartMs) / 1000).toInt()
            binding?.recBadge?.text =
                String.format(Locale.US, "REC %02d:%02d", sec / 60, sec % 60)
            mainHandler.postDelayed(this, 1000)
        }
    }

    // ---------- AUSBC 需要实现的方法 ----------

    override fun getRootView(layoutInflater: LayoutInflater): View? {
        val b = ActivityMainBinding.inflate(layoutInflater)
        binding = b
        b.btnRecord.setOnClickListener { toggleRecord() }
        b.btnMute.setOnClickListener { toggleMute() }
        b.btnResolution.setOnClickListener { showResolutionMenu(it) }
        return b.root
    }

    override fun getCameraView(): IAspectRatio? = binding?.cameraView

    override fun getCameraViewContainer(): ViewGroup? = binding?.cameraContainer

    override fun getCameraClient(): CameraClient {
        val strategy = CameraUvcStrategy(this)
        strategy.setDeviceConnectStatusListener(object : IDeviceConnectCallBack {
            override fun onAttachDev(device: UsbDevice?) {
                runOnUiThread {
                    Toast.makeText(this@MainActivity, "检测到采集卡", Toast.LENGTH_SHORT).show()
                }
            }

            override fun onDetachDec(device: UsbDevice?) {
                runOnUiThread { onCameraLost("采集卡已拔出") }
            }

            override fun onConnectDev(
                device: UsbDevice?,
                ctrlBlock: USBMonitor.UsbControlBlock?
            ) {
                runOnUiThread { onCameraReady() }
            }

            override fun onDisConnectDec(
                device: UsbDevice?,
                ctrlBlock: USBMonitor.UsbControlBlock?
            ) {
                runOnUiThread { onCameraLost("采集卡连接断开") }
            }

            override fun onCancelDev(device: UsbDevice?) {
                runOnUiThread { onCameraLost("USB 权限被拒绝,请重新插拔采集卡") }
            }
        })
        val c = CameraClient.newBuilder(this)
            .setEnableGLES(true)
            .setCameraStrategy(strategy)
            .setCameraRequest(
                CameraRequest.Builder()
                    .setPreviewWidth(1920)
                    .setPreviewHeight(1080)
                    .create()
            )
            .openDebug(true)
            .build()
        client = c
        return c
    }

    // ---------- CAMERA 运行时权限(3.2.7 openCamera 门槛) ----------

    override fun onStart() {
        super.onStart()
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
            != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this, arrayOf(Manifest.permission.CAMERA), REQ_CAMERA_PERMISSION
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQ_CAMERA_PERMISSION) return
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            // openCamera 可能在授权前被 TextureView 回调触发过并静默返回,这里补一次
            mainHandler.postDelayed({
                client?.openCamera(binding?.cameraView)
            }, 300)
        } else {
            Toast.makeText(this, "需要相机权限才能开启预览", Toast.LENGTH_LONG).show()
        }
    }

    // ---------- 设备状态 ----------

    private fun onCameraReady() {
        cameraReady = true
        binding?.let { b ->
            b.emptyView.visibility = View.GONE
            b.controlBar.visibility = View.VISIBLE
        }
        refreshStatusChip()
        if (!muted) startMicPlayback()
    }

    private fun onCameraLost(reason: String) {
        cameraReady = false
        if (isRecording) stopRecordUi()
        stopMicPlayback()
        binding?.let { b ->
            b.emptyView.visibility = View.VISIBLE
            b.controlBar.visibility = View.GONE
            b.statusChip.visibility = View.GONE
        }
        Toast.makeText(this, reason, Toast.LENGTH_SHORT).show()
    }

    // ---------- 音频监听 ----------

    private fun startMicPlayback() {
        if (!cameraReady) return
        try {
            client?.startPlayMic(object : IPlayCallBack {
                override fun onBegin() {}

                override fun onError(error: String) {
                    runOnUiThread {
                        Toast.makeText(
                            this@MainActivity,
                            "音频监听出错: $error",
                            Toast.LENGTH_SHORT
                        ).show()
                    }
                }

                override fun onComplete() {}
            })
        } catch (e: Exception) {
            Toast.makeText(this, "音频监听启动失败", Toast.LENGTH_SHORT).show()
        }
    }

    private fun stopMicPlayback() {
        try {
            client?.stopPlayMic()
        } catch (_: Exception) {
        }
    }

    private fun toggleMute() {
        muted = !muted
        binding?.btnMute?.text =
            if (muted) getString(R.string.btn_mute_off) else getString(R.string.btn_mute_on)
        if (!cameraReady) return
        if (muted) stopMicPlayback() else startMicPlayback()
    }

    // ---------- 录制 ----------

    private fun toggleRecord() {
        if (!cameraReady) return
        if (isRecording) {
            client?.captureVideoStop()
            return
        }
        val dir = File(getExternalFilesDir(Environment.DIRECTORY_MOVIES), "UsbCaptureCard")
        if (!dir.exists()) dir.mkdirs()
        val name = "capture_" +
                SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date()) + ".mp4"
        val path = File(dir, name).absolutePath

        client?.captureVideoStart(object : ICaptureCallBack {
            override fun onBegin() {
                runOnUiThread {
                    isRecording = true
                    recordStartMs = System.currentTimeMillis()
                    binding?.let { b ->
                        b.recBadge.visibility = View.VISIBLE
                        b.recBadge.text = "REC 00:00"
                        b.btnRecord.text = getString(R.string.btn_record_stop)
                    }
                    mainHandler.post(tickRunnable)
                }
            }

            override fun onError(error: String?) {
                runOnUiThread {
                    stopRecordUi()
                    Toast.makeText(
                        this@MainActivity,
                        getString(R.string.record_failed) + ": $error",
                        Toast.LENGTH_LONG
                    ).show()
                }
            }

            override fun onComplete(path: String?) {
                runOnUiThread {
                    stopRecordUi()
                    Toast.makeText(this@MainActivity, "已保存: $path", Toast.LENGTH_LONG).show()
                }
            }
        }, path, 0L)
    }

    private fun stopRecordUi() {
        isRecording = false
        mainHandler.removeCallbacks(tickRunnable)
        binding?.let { b ->
            b.recBadge.visibility = View.GONE
            b.btnRecord.text = getString(R.string.btn_record_start)
        }
    }

    // ---------- 分辨率 ----------

    private fun showResolutionMenu(anchor: View) {
        val sizes = runCatching { client?.getAllPreviewSizes(null) }.getOrNull()
            ?.filter { it.width > 0 && it.height > 0 }
            ?.distinctBy { "${it.width}x${it.height}" }
            ?.sortedByDescending { it.width.toLong() * it.height }
            ?.take(12)
            ?: emptyList()
        val popup = PopupMenu(this, anchor)
        if (sizes.isEmpty()) {
            popup.menu.add("读取分辨率失败")
        } else {
            sizes.forEachIndexed { i, s -> popup.menu.add(0, i, i, "${s.width}×${s.height}") }
            popup.setOnMenuItemClickListener { item ->
                sizes.getOrNull(item.itemId)?.let { s ->
                    // USB2 平板带宽不够 1080p 时,切 720p/更低档
                    val ok = client?.updateResolution(s.width, s.height) ?: false
                    if (!ok) {
                        Toast.makeText(this, "录制中不能切换分辨率", Toast.LENGTH_SHORT).show()
                    } else {
                        mainHandler.postDelayed({ refreshStatusChip() }, 1500)
                    }
                }
                true
            }
        }
        popup.show()
    }

    private fun refreshStatusChip() {
        val request = client?.getCameraRequest() ?: return
        binding?.statusChip?.let {
            it.visibility = View.VISIBLE
            it.text = "${request.previewWidth}×${request.previewHeight}"
        }
    }

    // ---------- 生命周期 ----------

    override fun onDestroy() {
        mainHandler.removeCallbacksAndMessages(null)
        binding = null
        super.onDestroy()
    }
}
