import 'package:flutter/material.dart';
import 'package:flutter_sphinx/flutter_sphinx.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:simple_permissions/simple_permissions.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _sphinx = FlutterSphinx();
  final List<String> _vocabulary = const [
    "this",
    "reader",
    "is",
    "very",
    "neat",
    "where",
    "is",
    "mojo"
  ];

  StreamController<int> _phraseIndex = StreamController()..add(0);

  final StreamController<bool> micPermissionGranted = StreamController();

  Future<bool> initialize() async {
    bool assetCopy = await initAssetCopy();
    await hasMicrophonePermission();
    return assetCopy;
  }

  Future<bool> initAssetCopy() async {
    print("Starting file copy");
    await copyAssetsToDocumentsDir();
    print("Copied all files to the documents dir");
    return true;
  }

  Future<bool> hasMicrophonePermission() async {
    bool granted =
        await SimplePermissions.checkPermission(Permission.RecordAudio);
    micPermissionGranted.add(granted);
    return granted;
  }

  Future<bool> requestMicPermission() async {
    await SimplePermissions.requestPermission(Permission.RecordAudio);
    return await hasMicrophonePermission();
  }

  Future<void> initializeSphinx(SphinxStateUninitialized state) async {
    Directory directory = await getApplicationDocumentsDirectory();
    state.initRecognizer(directory.path);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(
            title: const Text('Plugin example app'),
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
            return new Center(
              child: RaisedButton(
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
        int phraseIndex = snapshot.data;
        return StreamBuilder<SphinxState>(
            stream: _sphinx.stateChanges,
            builder: (BuildContext context, AsyncSnapshot snapshot) {
              if (snapshot.hasData) {
                final state = snapshot.data;
                if (state is SphinxStateLoading) {
                  return Center(
                    child: CircularProgressIndicator(),
                  );
                } else if (state is SphinxStateUnloaded) {
                  return Center(
                    child: RaisedButton(
                      onPressed: () {
                        state.loadVocabulary(_vocabulary[phraseIndex]);
                      },
                      child: Text("Load Vocabulary"),
                    ),
                  );
                } else if (state is SphinxStateUninitialized) {
                  return Center(
                    child: RaisedButton(
                      onPressed: () {
                        initializeSphinx(state)
                            .then((aVoid) => print("Initialization started"));
                      },
                      child: Text("Init recognizer"),
                    ),
                  );
                } else if (state is SphinxStateLoaded) {
                  return Center(
                    child: RaisedButton(
                      onPressed: () {
                        state.startListening();
                      },
                      child: Text("Start Listening"),
                    ),
                  );
                } else if (state is SphinxStateListening) {
                  return Container(
                      width: double.infinity,
                      child: Column(children: [
                        Text(
                          _vocabulary[phraseIndex],
                          style: TextStyle(fontSize: 20.0),
                        ),
                        StreamBuilder<String>(
                          stream: state.partialResults(),
                          builder:
                              (BuildContext context, AsyncSnapshot snapshot) {
                            if (snapshot.hasData) {
                              if (snapshot.data == _vocabulary[phraseIndex]) {
                                int nextIndex = (phraseIndex + 1) % _vocabulary.length;
                                _phraseIndex.add(nextIndex);
                                state.nextPhrase(_vocabulary[nextIndex]);
                              }
                              return Container(
                                width: double.infinity,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Text(snapshot.data),
                                    RaisedButton(
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
                    child: RaisedButton(
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
                  child: Text(snapshot.error),
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
