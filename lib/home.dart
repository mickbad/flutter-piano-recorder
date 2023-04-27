import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:piano/piano.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<NoteImage> currentNotes = [];
  List<NotePosition> currentHighlightNotes = [];
  NotePosition? currentScrollTo;

  late PianoMelody currentMelody;
  PianoPlayRecorderController controller = PianoPlayRecorderController();

  @override
  void initState() {
    super.initState();

    // create song
    currentMelody = PianoMelody.AmCm;

    // check this
    if (kDebugMode) {
      print("currentMelody: " + currentMelody.toJson());
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return SafeArea(
      child: Scaffold(
        body: Center(
          child: Column(
            children: [
              SizedBox(
                height: height / 30,
              ),
              //=============CLEFIMAGE===========
              Container(
                color: Colors.white,
                height: height / 5,
                child: ClefImage(
                    clef: Clef.Bass,
                    size: Size(height / 5, height / 5),
                    noteRange: NoteRange.forClefs([Clef.Bass]),
                    noteImages: [
                      NoteImage(notePosition: NotePosition.middleC),
                    ],
                    clefColor: Colors.red,
                    noteRangeToClip: NoteRange.forClefs([Clef.Bass, Clef.Alto, Clef.Treble]),
                    noteColor: Colors.blue),
                width: height / 5,
              ),
              Container(
                height: height / 5,
                child: CustomPaint(
                    size: Size.fromHeight(
                      height / 5,
                    ),
                    painter: ClefPainter(
                        lineHeight: height ~/ 300,
                        clefColor: Colors.green,
                        clef: Clef.Treble,
                        noteImages: currentNotes,
                        noteRange: NoteRange.forClefs(
                          [Clef.Treble],
                        ))),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton(onPressed: () {}, child: Text("Record this")),
                  OutlinedButton(onPressed: () => controller.playMelody(currentMelody), child: Text("Listen last song")),
                ],
              ),

              SizedBox(
                height: height / 30,
              ),

              Container(
                height: 300,
                child: InteractivePiano(
                  playRecorderController: controller,
                  // highlightedNotes: [NotePosition(note: Note.C, octave: 3)],
                  naturalColor: Colors.white,
                  accidentalColor: Colors.black,
                  keyWidth: 60,
                  noteRange: NoteRange.forClefs([
                    Clef.Treble,
                  ]),

                  highlightColor: Colors.orangeAccent,
                  highlightedNotes: currentHighlightNotes,
                  noteToScrollTo: currentScrollTo,

                  onNotePositionTapped: (position) {
                    // Use an audio library like flutter_midi to play the sound

                    // silence or note
                    if (position == null) {
                      // silence
                      setState(() {
                        currentNotes = [];
                        currentHighlightNotes = [];
                        currentScrollTo = null; // NotePosition.middleC;
                      });
                    }

                    else {
                      // notes
                      setState(() {
                        currentNotes = [
                          NoteImage(notePosition: position),
                        ];

                        currentHighlightNotes = [
                          position,
                        ];
                        currentScrollTo = position;
                      });
                    }

                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

  }
}
