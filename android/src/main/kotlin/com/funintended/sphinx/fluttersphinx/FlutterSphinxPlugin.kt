package com.funintended.sphinx.fluttersphinx

import edu.cmu.pocketsphinx.SpeechRecognizer
import edu.cmu.pocketsphinx.SpeechRecognizerSetup
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import java.io.File

class FlutterSphinxPlugin(private val listenChannel: MethodChannel, private val stateChannel: MethodChannel) : MethodCallHandler {

    var speechRecognizer: SpeechRecognizer? = null

    companion object {
        @JvmStatic
        fun registerWith(registrar: Registrar) {
            // TODO: transcode iSPhinx swift class to Kotlin
            //recognizer.decoder.log
            val channel = MethodChannel(registrar.messenger(), "flutter_sphinx")
            val listenChannel = MethodChannel(registrar.messenger(), "flutter_sphinx/listen")
            val stateChannel = MethodChannel(registrar.messenger(), "flutter_sphinx/state")
            val instance = FlutterSphinxPlugin(listenChannel, stateChannel)
            channel.setMethodCallHandler(instance)
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        // TODO: implement android plugin here just like iOS
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
            "init" -> {
                initSpeechRecognizer(File(call.arguments as? String))
                stateChannel.invokeMethod("initialized", null)
            }
            "load" -> result.success("Load the dictionary")
            "state" -> result.success("Getting the current state")
            else -> result.notImplemented()
        }
    }

    private fun initSpeechRecognizer(assetsDir: File) {
        speechRecognizer = SpeechRecognizerSetup
                .defaultSetup()
                .setAcousticModel(File(assetsDir, "en-us-ptm"))
                .setDictionary(File(assetsDir, "cmudict-en-us.dict"))
                .recognizer
    }

    private fun start(searchName: String, result: Result) {
        speechRecognizer?.let {
            it.startListening(searchName)
        } ?: run {
            result.error("Speech recognizer not initialized", null, null)
        }
    }
}
