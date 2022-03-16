
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';

class FlutterSphinx {
  static const MethodChannel _methodChannel =
  const MethodChannel('flutter_sphinx');
  static const EventChannel _listeningChannel =
  const EventChannel('flutter_sphinx/listen');
  static const EventChannel _stateChannel =
  const EventChannel('flutter_sphinx/state');
  late Stream<SphinxState> _stateChanges;

  Stream<SphinxState> get stateChanges {
    if (_stateChanges != null) {
      return _stateChanges;
    }
    _stateChanges = _stateChannel.receiveBroadcastStream()
      .map((message) {
          print("state message: $message");
          // this comes through as a map
          final eventMap = message as Map<dynamic, dynamic>;
          final event = eventMap["event"];
          if(event == "initialized") {
            return SphinxStateUnloaded(_methodChannel);
          } else if (event == "loading") {
            return SphinxStateLoading();
          } else if (event == "loaded") {
            return SphinxStateLoaded(_methodChannel);
          } else if (event == "listening") {
            return SphinxStateListening(_methodChannel, _listeningChannel);
          } else if (event == "error") {
            return SphinxStateError(_methodChannel, eventMap["errorMessage"]);
          } else {
            throw StateError("unknown event found from Sphinx plugin");
          }
        }).startWith(SphinxStateUninitialized(_methodChannel));
    return _stateChanges;
  }
}

abstract class SphinxState {}

class SphinxStateLoading extends SphinxState {}

class SphinxStateUninitialized extends SphinxState {
  final MethodChannel _methodChannel;

  SphinxStateUninitialized(this._methodChannel);

  Future initRecognizer(String assetsDir) async {
    await _methodChannel.invokeMethod("init", assetsDir);
  }
}

class SphinxStateUnloaded extends SphinxState {
  final MethodChannel _methodChannel;

  SphinxStateUnloaded(this._methodChannel);

  Future loadVocabulary(String phrase) async {
    writeKeywordSearchFile([phrase]);
    await _methodChannel.invokeMethod("load", phrase);
  }
}

class SphinxStateError extends SphinxState {
  final String errorMessage;
  final MethodChannel _methodChannel;

  SphinxStateError(this._methodChannel, this.errorMessage);

  Future reloadVocabulary(String phrase) async {
    await _methodChannel.invokeMethod("load", phrase);
  }
}

class SphinxStateLoaded extends SphinxState {
  final MethodChannel _methodChannel;

  SphinxStateLoaded(this._methodChannel);

  Future startListening() async {
    await _methodChannel.invokeMethod("start");
  }
}

class SphinxStateListening extends SphinxState {
  final MethodChannel _methodChannel;
  final EventChannel _listeningChannel;
  late Stream<String> _partialResultStream;

  SphinxStateListening(this._methodChannel, this._listeningChannel);

  Stream<String> partialResults() {
    if (_partialResultStream != null) {
      return _partialResultStream;
    }
    _partialResultStream = _listeningChannel.receiveBroadcastStream()
            .distinct()
            .where((s) => s != null && s.length > 0)
            .map<String>((message) {
          // we get a big string back of the partial results, we just need to send out the last item
          print(message);
          return message.trim().split(" ").last;
        }).startWith("").asBroadcastStream();
    return _partialResultStream;
  }

  Future stopListening() async {
    await _methodChannel.invokeMethod("stop");
  }

  Future nextPhrase(String phrase) async {
    writeKeywordSearchFile([phrase]);
    await _methodChannel.invokeMethod("word", phrase);
  }
}

Future<void> writeKeywordSearchFile(List<String> keywords) async {
  Directory directory = await getApplicationSupportDirectory();
  String filePath = join(directory.path, "keyword_list.lst");

  // Create the directory if needed
  String fileDir = filePath.substring(0, filePath.lastIndexOf("/"));
  print("Creating directory: $fileDir");
  await Directory(fileDir).create(recursive: true);
  print("Writing out the file");

  await File(filePath).writeAsString(keywords.map( (keyword) => "$keyword /1e-1/" ).join("\n"));
}

Future<void> copyAssetsToDocumentsDir(
    [String assetsDir = "assets/sync"]) async {

  try {
    //final manifestContent = await rootBundle.loadString('AssetManifest.json');

    //final Map<String, dynamic> manifestMap = json.decode(manifestContent);
    // >> To get paths you need these 2 lines

    //final pfmPaths = manifestMap.keys
    //    .where((String key) => key.contains('sync/'))
    //    .toList();
    //print(pfmPaths);

    String syncListString =  await rootBundle.loadString("$assetsDir/assets.lst");
    List<String> syncList = syncListString.split("\n");
      for (String path in syncList) {
        print("Copying file: $assetsDir/$path");
        //print(await File("$assetsDir/$path").exists());

        Directory directory = await getApplicationSupportDirectory();
        print(directory);
        String filePath = join(directory.path, path);
        if (FileSystemEntity.typeSync(filePath) ==
            FileSystemEntityType.notFound) {
          ByteData data = await rootBundle.load("$assetsDir/$path");
          List<int> bytes = data.buffer.asUint8List(
              data.offsetInBytes, data.lengthInBytes);

          // Create the directory if needed
          String fileDir = filePath.substring(0, filePath.lastIndexOf("/"));
          print("Creating directory: $fileDir");
          await Directory(fileDir).create(recursive: true);
          print("Writing out the file");
          await File(filePath).writeAsBytes(bytes);
        } else {
          print("File already exists");
        }
      }
  } on PlatformException {
    print('Failed to copy the File.');
    return;
  }
}

