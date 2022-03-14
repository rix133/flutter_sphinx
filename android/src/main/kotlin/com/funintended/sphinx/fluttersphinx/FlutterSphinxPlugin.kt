package com.sphinx.fluttersphinx

import androidx.annotation.NonNull

import edu.cmu.pocketsphinx.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.lang.Exception

class FlutterSphinxPlugin(private val listenChannel: EventChannel, private val stateChannel: EventChannel) : FlutterPlugin, MethodCallHandler, RecognitionListener {

    private var speechRecognizer: SpeechRecognizer? = null
    private var eventSink: EventChannel.EventSink? = null
    private var listenEventSink: EventChannel.EventSink? = null

    private var assetsDir: File? = null

    companion object {

        const val KW_SEARCH = "keyword"

        @JvmStatic
        fun registerWith(registrar: Registrar) {
            // TODO: transcode iSPhinx swift class to Kotlin
            val channel = MethodChannel(registrar.messenger(), "flutter_sphinx")
            val listenChannel = EventChannel(registrar.messenger(), "flutter_sphinx/listen")
            val stateChannel = EventChannel(registrar.messenger(), "flutter_sphinx/state")
            val instance = FlutterSphinxPlugin(listenChannel, stateChannel)
            channel.setMethodCallHandler(instance)
        }
    }

    init {
        stateChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { eventSink = events }
            override fun onCancel(arguments: Any?) {}
        })

        listenChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { listenEventSink = events }
            override fun onCancel(arguments: Any?) {}
        })
    }
    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_sphinx")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        // TODO: implement android plugin here just like iOS
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
            "init" -> {
                initSpeechRecognizer(File(call.arguments as? String))
                eventSink?.success(buildEvent("initialized"))
            }
            "load" -> {
                speechRecognizer?.addKeywordSearch(KW_SEARCH, File(assetsDir, "keyword_list.lst"))
                loadVocabulary()
            }
            "start" -> {
                speechRecognizer?.addKeywordSearch(KW_SEARCH, File(assetsDir, "keyword_list.lst"))
                start(result)
                eventSink?.success(buildEvent("listening"))
                result.success("Started listening")
            }
            "word" -> {
                speechRecognizer?.cancel()
                speechRecognizer?.stop()
                speechRecognizer?.addKeywordSearch(KW_SEARCH, File(assetsDir, "keyword_list.lst"))
                start(result)
            }
            "stop" -> {
                speechRecognizer?.cancel()
                speechRecognizer?.stop()
                eventSink?.success(buildEvent("loaded"))
                result.success("Stopped listening")
            }
            "state" -> result.success("Getting the current state")
            else -> result.notImplemented()
        }
    }

    private fun buildEvent(event: String): Map<String, String> {
        return mapOf("event" to event)
    }

    private fun initSpeechRecognizer(assetsDir: File) {
        this.assetsDir = assetsDir
        speechRecognizer = SpeechRecognizerSetup
                .defaultSetup()
                .setAcousticModel(File(assetsDir, "en-us-ptm"))
                .setDictionary(File(assetsDir, "cmudict-en-us.dict"))
                .recognizer
                .also {
                    it.addListener(this)
                }
    }

    private fun loadVocabulary() {
        eventSink?.success(buildEvent("loaded"))
    }

    private fun start(result: Result) {
        speechRecognizer?.let {
            it.startListening(KW_SEARCH)
        } ?: run {
            result.error("Speech recognizer not initialized", null, null)
        }
    }

//    private fun generateDictionary(words: List<String>) {
//        var text = ""
//        for (word in words) {
//
//            speechRecognizer?.decoder?.lookupWord(word.toLowerCase())?.let {
//                text += "${word.toLowerCase()} $it\n"
//            } ?: run {
//                // TODO unSupportedWords.append(word)
//            }
//            try ? text.write(to: dictPathTemp!, atomically: true, encoding: .utf8)
//                speechRecognizer?.decoder?.loadDict(dictPathTemp!. path, fFilter: nil, format: "dict")
////                delegete.iSphinxUnsupportedWords(words: unSupportedWords)
//            }
//        }
//
//    private fun generateNGramModel(words: List<String>) {
//        nGramModel = NGramModel(config: config, logMath: recognizer. getDecoder().getLogMath(), lmFile: arpaFile)
//        for word in words {
//            nGramModel?.addWord(word: word.lowercased(), weight: 1.7)
//        }
//        recognizer.getDecoder().setLanguageModel(name: SEARCH_ID, nGramModel: nGramModel!)
//    }

    override fun onResult(hypothesis: Hypothesis?) {
        listenEventSink?.success(hypothesis?.hypstr)
    }

    override fun onPartialResult(hypothesis: Hypothesis?) {
        listenEventSink?.success(hypothesis?.hypstr)
    }

    override fun onTimeout() {

    }

    override fun onBeginningOfSpeech() {

    }

    override fun onEndOfSpeech() {

    }

    override fun onError(p0: Exception?) {

    }
}
