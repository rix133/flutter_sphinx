import 'package:flutter/material.dart';
import 'package:flutter_sphinx/flutter_sphinx.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _sphinx = FlutterSphinx();
  AudioCache audioPlayer = AudioCache();
  FlutterTts flutterTts = FlutterTts();
  final List<String> _vocabulary = randomisedVocabList();
  static List<String> randomisedVocabList() {
    return [
      "a",
      "about",
      "after",
      "all",
      "am",
      "an",
      "and",
      "are",
      "as",
      "at",
      "away",
      "back",
      "be",
      "because",
      "big",
      "but",
      "by",
      "call",
      "came",
      "can",
      "come",
      "could",
      "did",
      "do",
      "down",
      "for",
      "from",
      "get",
      "go",
      "got",
      "had",
      "has",
      "have",
      "he",
      "her",
      "here",
      "him",
      "his",
      "in",
      "into",
      "is",
      "it",
      "last",
      "like",
      "little",
      "live",
      "look",
      "made",
      "make",
      "me",
      "my",
      "new",
      "next",
      "not",
      "now",
      "of",
      "off",
      "old",
      "on",
      "once",
      "one",
      "other",
      "our",
      "out",
      "over",
      "put",
      "saw",
      "said",
      "see",
      "she",
      "so",
      "some",
      "take",
      "that",
      "the",
      "their",
      "them",
      "then",
      "there",
      "they",
      "this",
      "three",
      "time",
      "to",
      "today",
      "too",
      "two",
      "up",
      "us",
      "very",
      "was",
      "we",
      "were",
      "went",
      "what",
      "when",
      "will",
      "with",
      "you",
    ]..shuffle();
  }

  final List<String> _sentences = const [
    "the cat",
    "the rat",
    "the bat",
    'the rat',
    'the dot',
    'the cot',
    'the dog',
    'the rag',
    'the spot',
    'the pig',
    'the dig',
    'the cat is mad',
    'the dog is bad',
    'the rat is sad',
    'the dot is flat',
    'the red pot',
    'the red dot',
    'the cat got mad',
    'the cat got mad and sat on a pad',
    'I am',
    'I am hot',
    'I am not',
    'I am not bad',
    'I am not sad',
    'I am not mad',
    'I wish I had a frog'
  ];

  StreamController<int> _phraseIndex = StreamController.broadcast()..add(0);
  StreamController<bool> _wordCorrect = StreamController.broadcast()..add(false);

  final StreamController<bool> micPermissionGranted = StreamController();

  Future<bool> initialize() async {
    bool assetCopy = await initAssetCopy();
    await hasMicrophonePermission();
    await flutterTts.awaitSpeakCompletion(true);
    return assetCopy;
  }

  Future<bool> initAssetCopy() async {
    print("Starting file copy");
    await copyAssetsToDocumentsDir();
    print("Copied all files to the documents dir");
    return true;
  }

  Future<bool> hasMicrophonePermission() async {
    bool granted = await Permission.microphone.isGranted;
    micPermissionGranted.add(granted);
    return granted;
  }

  Future<bool> requestMicPermission() async {
    await Permission.microphone.request();
    return await hasMicrophonePermission();
  }

  Future<void> initializeSphinx(SphinxStateUninitialized state) async {
    Directory directory = await getApplicationDocumentsDirectory();
    state.initRecognizer(directory.path);
  }

  Future<void> wordCorrect(int phraseIndex, SphinxStateListening state) async {
    _wordCorrect.add(true);

    audioPlayer.play("audio/positive.mp3");

    await Future.delayed(const Duration(seconds: 1), () {
      int nextIndex = (phraseIndex + 1) % _vocabulary.length;
      _wordCorrect.add(false);
      _phraseIndex.add(nextIndex);
      state.nextPhrase(_vocabulary[nextIndex]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(
            title: const Text('Sphinx Test App'),
          ),
          body: FutureBuilder(
              future: initialize(),
              builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
                if (snapshot.data == true) {
                  return checkMicPermission();
                } else {
                  return _loadingView();
                }
              })),
    );
  }

  Widget checkMicPermission() {
    return StreamBuilder(
        stream: micPermissionGranted.stream,
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
          if (!snapshot.hasData) {
            return _loadingView();
          } else if (snapshot.data == true) {
            return contentView();
          } else {
            return Center(
              child: ElevatedButton(
                child: Text("Request microphone permissions"),
                onPressed: () {
                  requestMicPermission().then((granted) {
                    // No-op. The request is updating the permission stream
                  });
                },
              ),
            );
          }
        });
  }

  Widget _loadingView() {
    return Center(child: CircularProgressIndicator());
  }

  Widget contentView() {
    return StreamBuilder<int>(
      stream: _phraseIndex.stream,
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        int phraseIndex = snapshot.data ?? 0;
        return StreamBuilder<SphinxState>(
            stream: _sphinx.stateChanges,
            builder: (BuildContext context, AsyncSnapshot snapshot) {
              if (snapshot.hasData) {
                final state = snapshot.data;
                if (state is SphinxStateLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                } else if (state is SphinxStateUnloaded) {
                  return Center(
                    child: ElevatedButton(
                      onPressed: () {
                        state.loadVocabulary(_vocabulary[phraseIndex]);
                      },
                      child: Text("Load Vocabulary"),
                    ),
                  );
                } else if (state is SphinxStateUninitialized) {
                  return Center(
                    child: ElevatedButton(
                      onPressed: () {
                        initializeSphinx(state)
                            .then((aVoid) => print("Initialization started"));
                      },
                      child: Text("Init recognizer"),
                    ),
                  );
                } else if (state is SphinxStateLoaded) {
                  return Center(
                    child: ElevatedButton(
                      onPressed: () {
                        state.startListening();
                      },
                      child: Text("Start Listening"),
                    ),
                  );
                } else if (state is SphinxStateListening) {
                  return Container(
                      width: double.infinity,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Speak the word below:"),
                            StreamBuilder(
                                stream: _wordCorrect.stream,
                                builder: (BuildContext context,
                                    AsyncSnapshot snapshot) {
                                  bool wordCorrect = snapshot.data;
                                  return Row(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                      mainAxisAlignment:
                                      MainAxisAlignment.center,
                                      children: [
                                        Text(_vocabulary[phraseIndex],
                                            style: TextStyle(
                                                fontSize: 40.0,
                                                color: wordCorrect == true
                                                    ? Colors.green
                                                    : Colors.black)),
                                        IconButton(
                                          icon: Icon(Icons.speaker),
                                          onPressed: () {
                                            flutterTts.setLanguage('en-US');
                                            flutterTts.speak(_vocabulary[phraseIndex]);
                                          },
                                        )
                                      ]);
                                }),
                            StreamBuilder<String>(
                              stream: state.partialResults(),
                              builder: (BuildContext context,
                                  AsyncSnapshot snapshot) {
                                if (snapshot.hasData) {
                                  if (snapshot.data ==
                                      _vocabulary[phraseIndex]) {
                                    wordCorrect(phraseIndex, state)
                                        .then((aVoid) {
                                      // No-op
                                    });
                                  }
                                  return Container(
                                    width: double.infinity,
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                      mainAxisAlignment:
                                      MainAxisAlignment.center,
                                      children: <Widget>[
                                        // Text(snapshot.data),
                                        ElevatedButton(
                                          onPressed: () {
                                            state.stopListening();
                                          },
                                          child: Text("Stop Listening"),
                                        ),
                                      ],
                                    ),
                                  );
                                } else if (snapshot.hasError) {
                                  return Center(
                                    child: Text("error while listening"),
                                  );
                                } else {
                                  return Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                              },
                            ),
                          ]));
                } else if (state is SphinxStateError) {
                  return Center(
                    child: ElevatedButton(
                      onPressed: () {
                        state.reloadVocabulary(_vocabulary[phraseIndex]);
                      },
                      child: Text("Reload Vocabulary"),
                    ),
                  );
                } else {
                  throw StateError("unknown sphinx state");
                }
              } else if (snapshot.hasError) {
                return Center(
                  child: Text(snapshot.error.toString()),
                );
              } else {
                return Center(
                  child: CircularProgressIndicator(),
                );
              }
            });
      },
    );
  }
}
