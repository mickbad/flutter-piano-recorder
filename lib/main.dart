import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:piano/piano.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
        title: 'Piano Demo',
        home: Center(
          child: Column(
            children: [
              Container(
                color: Colors.white,
                height: 150,
                child: ClefImage(
                    clef: Clef.Alto,
                    size: Size(200, 100),
                    noteRange: NoteRange.forClefs([Clef.Alto]),
                    noteImages: [NoteImage(notePosition: NotePosition.middleC)],
                    clefColor: Colors.green,
                    noteColor: Colors.blue),
              ),
              Container(
                height: 250,
                child: CustomPaint(
                    painter: ClefPainter(
                        lineHeight: 5,
                        clefColor: Colors.pink,
                        clef: Clef.Treble,
                        noteRange:
                            NoteRange.forClefs([Clef.Treble], extended: true))),
              ),
              Container(
                height: 150,
                child: InteractivePiano(
                  highlightedNotes: [NotePosition(note: Note.C, octave: 3)],
                  naturalColor: Colors.white,
                  accidentalColor: Colors.black,
                  keyWidth: 60,
                  noteRange: NoteRange.forClefs([
                    Clef.Treble,
                  ]),
                  onNotePositionTapped: (position) {
                    // Use an audio library like flutter_midi to play the sound
                  },
                ),
              ),
            ],
          ),
        ));
  }
}
