///
/// Recorder song from keys
///

import "dart:convert";

import "package:flutter/material.dart";

import "../piano.dart";

///
/// Controller
///

class PianoPlayRecorderController extends ChangeNotifier {
  /// mode controller
  String mode = "";

  /// current melody to play
  bool isPlayingMelody = false;
  PianoMelody? playingMelody;

  ///
  /// Play a melody in InteractivePiano
  ///
  playMelody(PianoMelody? melody) {
    mode = "play";
    playingMelody = melody;
    notifyListeners();
  }

}

///
/// Melody object
///

const String SAMPLE_AMCM = '[{"note": "A4", "duration": 300}, {"note": "CS5", "duration": 150}, {"note": "E5", "duration": 150}, {"note": "A4", "duration": 300}, {"duration": 600}, {"note": "C4", "duration": 300}, {"note": "EF4", "duration": 300}, {"note": "G4", "duration": 600}]';
const String SAMPLE_MISC = '[{"note": "C4", "duration": 300}, {"note": "EB4", "duration": 300}, {"note": "G4", "duration": 300}, {"note": "B3", "duration": 300}, {"note": "C4", "duration": 300},{"note": "C5", "duration": 300}]';

class PianoMelody {
  bool isImported = false;
  final String name;
  final List<PianoMelodyNote> melody;

  // properties
  bool get isEmpty => melody.isEmpty;
  bool get isNotEmpty => melody.isNotEmpty;
  int get length => melody.length;

  ///
  /// Samples
  ///
  static PianoMelody get AmCm => PianoMelody.fromJson("AmCm", jsonDecode(SAMPLE_AMCM));
  static PianoMelody get CmMisc => PianoMelody.fromJson("Sample Misc", jsonDecode(SAMPLE_MISC));

  // factories
  PianoMelody({required this.name, required this.melody});

  ///
  /// import melody from json
  /// sample:
  /// [{"note": "A4", "duration": 300}, {"note": "CS5", "duration": 150}, {"note": "E5", "duration": 1500}, {"note": "A4", "duration": 600}]
  ///
  factory PianoMelody.fromJson(String name, List<dynamic> parsedJson) {
    List<PianoMelodyNote> importMelody = [];
    for(Map<String, dynamic> item in parsedJson) {
      PianoMelodyNote note = PianoMelodyNote.fromJson(item);
      importMelody.add(note);
    }

    // final silence
    importMelody.add(PianoMelodyNote(duration: const Duration(milliseconds: 10)));

    PianoMelody mymelody = PianoMelody(name: name, melody: importMelody);
    mymelody.isImported = true;
    return mymelody;
  }

  ///
  /// Export melody to json
  /// sample:
  /// [{"note": "A4", "duration": 300}, {"note": "CS5", "duration": 150}, {"note": "E5", "duration": 150}, {"note": "A4", "duration": 600}]
  ///
  String toJson() {
    List<dynamic> export = [];
    for(var item in melody) {
      export.add(jsonDecode(item.toJson()));
    }

    // remove last silence (importated)
    if (isImported) {
      export.removeLast();
    }

    return jsonEncode(export);
  }

}

class PianoMelodyNote {
  NotePosition? note;
  Duration duration;

  ///
  /// factory
  ///
  PianoMelodyNote({this.note, required this.duration});

  ///
  /// import note from json
  /// samples
  /// A4 (300ms): {"note": "A4", "duration": 300}
  /// C#2 (150ms): {"note": "CS2", "duration": 150}
  /// Eb2 (300ms): {"note": "EB2", "duration": 300}
  /// Bb4 (300ms): {"note": "BF4", "duration": 300}
  /// Silent (600ms): {"duration": 600} // {"note": "--", "duration": 300}
  ///
  factory PianoMelodyNote.fromJson(Map<String, dynamic> parsedJson) {
    assert(parsedJson.containsKey("duration"));
    NotePosition? importedNote;

    // extract note instead of silent
    if (parsedJson.containsKey("note")) {
      // get note
      String data = parsedJson["note"].toString().toUpperCase();

      // get real note
      Note? importNote;
      if (data.length >= 2 && data.length <= 3) {
        switch (data[0]) {
          case "A":
            importNote = Note.A;
            break;

          case "B":
            importNote = Note.B;
            break;

          case "C":
            importNote = Note.C;
            break;

          case "D":
            importNote = Note.D;
            break;

          case "E":
            importNote = Note.E;
            break;

          case "F":
            importNote = Note.F;
            break;

          case "G":
            importNote = Note.G;
            break;
        }
      }

      // affectation
      if (importNote != null) {
        // extract octave
        int octave = int.parse((data.length == 2) ? data[1] : data[2]);

        // extract accident
        Accidental accidental = Accidental.None;
        if (data.length == 3) {
          if (data[1] == "S")
            accidental = Accidental.Sharp;
          else if (data[1] == "B" || data[1] == "F")
            accidental = Accidental.Flat;
        }

        // set note position
        importedNote = NotePosition(note: importNote, octave: octave, accidental: accidental);
      }
    }

    return PianoMelodyNote(
        note : importedNote,
        duration: Duration(milliseconds: parsedJson['duration'])
    );
  }

  ///
  /// Export to JSON
  ///
  String toJson() {
    // export silent
    if (note == null) {
      return jsonEncode({
        "duration": duration.inMilliseconds,
      });
    }

    // export real note
    String exportNote = note!.name[0].toUpperCase();

    if (exportNote == "S") {
      // make silence
      exportNote = "";
    }
    else {
      if (note!.accidental == Accidental.Sharp) {
        exportNote = "${exportNote}S";
      }

      if (note!.accidental == Accidental.Flat) {
        exportNote = "${exportNote}B";
      }

      exportNote = "${exportNote}${note!.octave}";
    }

    return jsonEncode({
      "note": exportNote,
      "duration": duration.inMilliseconds,
    });
  }
}
