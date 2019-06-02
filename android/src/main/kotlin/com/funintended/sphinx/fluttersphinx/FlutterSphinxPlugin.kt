package com.funintended.sphinx.fluttersphinx

import edu.cmu.pocketsphinx.*
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import java.io.File
import java.lang.Exception

class FlutterSphinxPlugin(private val listenChannel: EventChannel, private val stateChannel: EventChannel) : MethodCallHandler, RecognitionListener {

    private var speechRecognizer: SpeechRecognizer? = null
    private var eventSink: EventChannel.EventSink? = null
    private var listenEventSink: EventChannel.EventSink? = null

    companion object {
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

    override fun onMethodCall(call: MethodCall, result: Result) {
        // TODO: implement android plugin here just like iOS
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
            "init" -> {
                initSpeechRecognizer(File(call.arguments as? String))
                eventSink?.success(buildEvent("initialized"))
            }
            "load" -> {
                (call.arguments as? String)?.let {
                    loadVocabulary(listOf(it))
                } ?: run {
                    result.error("Error setting the vocabulary", null, null)
                }

            }
            "start" -> {
                start("keyphrase", result)
                eventSink?.success(buildEvent("listening"))
                result.success("Started listening")
            }
            "word" -> {
                speechRecognizer?.stop()
                start(call.arguments as String, result)
            }
            "stop" -> {
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
        speechRecognizer = SpeechRecognizerSetup
                .defaultSetup()
                .setAcousticModel(File(assetsDir, "en-us-ptm"))
                .setDictionary(File(assetsDir, "cmudict-en-us.dict"))
                .setRawLogDir(assetsDir)
                .recognizer
                .also {
                    it.addNgramSearch("weather", File(assetsDir, "weather.dmp"))
                    
                    it.addListener(this)
                }
    }

    private fun loadVocabulary(words: List<String>) {
//        speechRecognizer?.addKeyphraseSearch("keyphrase", words[0])
        eventSink?.success(buildEvent("loaded"))
    }

    private fun start(searchName: String, result: Result) {
        speechRecognizer?.let {

//            it.addKeyphraseSearch("weather", searchName)
            it.startListening("weather")
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

    override fun onResult(p0: Hypothesis?) {

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
