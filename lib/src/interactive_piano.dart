import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:collection/collection.dart';

import 'note_position.dart';
import 'note_range.dart';
import 'recorder.dart';

typedef OnNotePositionTapped = void Function(NotePosition position);
typedef CallbackRecordMelody = void Function(PianoMelody melody);

/// Renders a scrollable interactive piano.
class InteractivePiano extends StatefulWidget {
  /// The range of notes to create interactive keys for.
  final NoteRange noteRange;

  /// The range of notes to highlight.
  final List<NotePosition> highlightedNotes;

  /// The color with which to draw highlighted notes; blended with the color of the key.
  final Color highlightColor;

  /// Color to render "natural" notes—typically white.
  final Color naturalColor;

  /// Color to render "accidental" notes (sharps and flats)—typically black.
  final Color accidentalColor;

  /// Whether to apply a repeating press animation to highlighted notes.
  final bool animateHighlightedNotes;

  /// Whether to treat tapped notes as flats instead of sharps. Affects the value passed to `onNotePositionTapped`.
  final bool useAlternativeAccidentals;

  /// Whether to hide note names on keys.
  final bool hideNoteNames;

  /// Whether to hide the scroll bar, that appears below the keys.
  final bool hideScrollbar;

  /// Leave as `null` to have keys sized automatically to fit the width of the widget.
  final double? keyWidth;

  /// Callback for interacting with piano keys.
  final OnNotePositionTapped? onNotePositionTapped;

  /// Set and change at any time (i.e. with `setState`) to cause the piano to scroll so that the desired note is centered.
  final NotePosition? noteToScrollTo;

  /// Set and control InteractivePiano for playing, recording melodies, ...
  final PianoPlayRecorderController? playRecorderController;

  /// Callback for playing melody
  final VoidCallback? onStartPlayMelody;
  final VoidCallback? onStopPlayMelody;

  /// Callback for retrieve recording melody
  final VoidCallback? onStartRecordMelody;
  final CallbackRecordMelody? onStopRecordMelody;

  /// See individual parameters for more information. The only required parameter
  /// is `noteRange`. Since the widget wraps a scroll view and therefore has no
  /// "intrinsic" size, be sure to use inside a parent that specifies one.
  ///
  /// For example:
  /// ```
  /// SizedBox(
  ///   width: 300,
  ///   height: 100,
  ///   child: InteractivePiano(
  ///     noteRange: NoteRange.forClefs(
  ///       [Clef.Treble],
  ///       extended: true
  ///     )
  ///   )
  /// )
  /// ```
  ///
  /// Normally you'll want to pass `keyWidth`—if you don't, the entire range of notes
  /// will be squashed into the width of the widget.
  InteractivePiano(
      {Key? key,
      required this.noteRange,
      this.highlightedNotes = const [],
      this.highlightColor = Colors.red,
      this.naturalColor = Colors.white,
      this.accidentalColor = Colors.black,
      this.animateHighlightedNotes = false,
      this.useAlternativeAccidentals = false,
      this.hideNoteNames = false,
      this.hideScrollbar = false,
      this.onNotePositionTapped,
      this.noteToScrollTo,
      this.keyWidth,
      this.playRecorderController,
      this.onStartPlayMelody,
      this.onStopPlayMelody,
      this.onStartRecordMelody,
      this.onStopRecordMelody})
      : super(key: key);

  @override
  _InteractivePianoState createState() => _InteractivePianoState();
}

class _InteractivePianoState extends State<InteractivePiano> {
  /// We group notes into blocks of contiguous accidentals, since they need to be stacked
  late List<List<NotePosition>> _noteGroups;

  ScrollController? _scrollController;
  double _lastWidth = 0.0, _lastKeyWidth = 0.0;

  // current melody recording
  late PianoMelody currentMelody;
  PianoMelodyNote? currentNote;
  int currentTimestamp = -1;

  @override
  void initState() {
    _updateNotePositions();
    super.initState();

    // create temp melody
    currentMelody = PianoMelody(name: "", melody: [])..reset();

    if (widget.playRecorderController != null) {
      widget.playRecorderController!.addListener(() async {
        // check control
        switch(widget.playRecorderController!.mode) {
          case "play":
            /// start a melody playing
            // check
            if (widget.playRecorderController!.playingMelody == null) {
              // no melody!
              break;
            }

            // playing melody
            await playMelody(widget.playRecorderController!.playingMelody!);
            break;

          case "record-start":
            /// start a record
            currentMelody.reset();
            setState(() {
              widget.playRecorderController!.isRecordingMelody = true;
              currentTimestamp = -1;
            });
            if (widget.onStartRecordMelody != null) {
              widget.onStartRecordMelody!();
            };
            break;

          case "record-stop":
            /// stop a record
            setState(() {
              widget.playRecorderController!.isRecordingMelody = false;
            });
            if (widget.onStopRecordMelody != null) {
              widget.onStopRecordMelody!(currentMelody);
            };
            break;

        }

        // reset mode
        widget.playRecorderController!.mode = "";
      });
    }
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant InteractivePiano oldWidget) {
    if (oldWidget.noteRange != widget.noteRange ||
        oldWidget.useAlternativeAccidentals !=
            widget.useAlternativeAccidentals) {
      _updateNotePositions();
    }

    final noteToScrollTo = widget.noteToScrollTo;
    if (noteToScrollTo != null && oldWidget.noteToScrollTo != noteToScrollTo) {
      _scrollController?.animateTo(
          _computeScrollOffsetForNotePosition(noteToScrollTo),
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut);
    }

    super.didUpdateWidget(oldWidget);
  }

  double _computeScrollOffsetForNotePosition(NotePosition notePosition) {
    final closestNatural = notePosition.copyWith(accidental: Accidental.None);

    final int index = widget.noteRange.naturalPositions.indexOf(closestNatural);

    if (index == -1 || _lastWidth == 0.0 || _lastKeyWidth == 0.0) {
      return 0.0;
    }

    return (index * _lastKeyWidth + _lastKeyWidth / 2 - _lastWidth / 2);
  }

  _updateNotePositions() {
    final notePositions = widget.noteRange.allPositions;

    if (widget.useAlternativeAccidentals) {
      for (int i = 0; i < notePositions.length; i++) {
        notePositions[i] =
            notePositions[i].alternativeAccidental ?? notePositions[i];
      }
    }

    _noteGroups = notePositions
        .splitBeforeIndexed((index, _) =>
            _.accidental == Accidental.None &&
            notePositions[index - 1].accidental == Accidental.None)
        .toList();
  }

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.black,
        padding: EdgeInsets.only(top: 2, bottom: 10),
        child: Center(
          child: LayoutBuilder(builder: (context, constraints) {
            _lastWidth = constraints.maxWidth;

            final numberOfKeys = widget.noteRange.naturalPositions.length;
            _lastKeyWidth = widget.keyWidth ?? (_lastWidth - 2) / numberOfKeys;

            if (_scrollController == null) {
              double scrollOffset = _computeScrollOffsetForNotePosition(
                  widget.noteToScrollTo ?? NotePosition.middleC);
              _scrollController =
                  ScrollController(initialScrollOffset: scrollOffset);
            }

            final showScrollbar = !widget.hideScrollbar &&
                (numberOfKeys * _lastKeyWidth) > _lastWidth;

            return _MaybeScrollbar(
                scrollController: showScrollbar ? _scrollController : null,
                child: ListView.builder(
                    shrinkWrap: true,
                    physics: widget.hideScrollbar
                        ? NeverScrollableScrollPhysics()
                        : ClampingScrollPhysics(),
                    itemCount: _noteGroups.length,
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (BuildContext context, int index) {
                      final naturals = _noteGroups[index]
                          .where((_) => _.accidental == Accidental.None);
                      final accidentals = _noteGroups[index]
                          .where((_) => _.accidental != Accidental.None);

                      return Stack(
                        children: [
                          Row(
                            children: naturals
                                .map((note) => _PianoKey(
                                    notePosition: note,
                                    color: widget.naturalColor,
                                    hideNoteName: widget.hideNoteNames,
                                    isAnimated: widget
                                            .animateHighlightedNotes &&
                                        widget.highlightedNotes.contains(note),
                                    highlightColor:
                                        widget.highlightedNotes.contains(note)
                                            ? widget.highlightColor
                                            : null,
                                    keyWidth: _lastKeyWidth,
                                    // onTap: _onNoteTapped(note),
                                    onTapDown: () => _onNoteTappedDown(note),
                                    onTapUp: () => _onNoteTappedUp(note),
                            ))
                                .toList(),
                          ),
                          Positioned(
                              top: 0.0,
                              bottom: 0.0,
                              left:
                                  _lastKeyWidth / 2.0 + (_lastKeyWidth * 0.02),
                              child: FractionallySizedBox(
                                  alignment: Alignment.topCenter,
                                  heightFactor: 0.55,
                                  child: Row(
                                    children: accidentals
                                        .map(
                                          (note) => _PianoKey(
                                            notePosition: note,
                                            color: widget.accidentalColor,
                                            hideNoteName: widget.hideNoteNames,
                                            isAnimated: widget
                                                    .animateHighlightedNotes &&
                                                widget.highlightedNotes
                                                    .contains(note),
                                            highlightColor: widget
                                                    .highlightedNotes
                                                    .contains(note)
                                                ? widget.highlightColor
                                                : null,
                                            keyWidth: _lastKeyWidth,
                                            // onTap: _onNoteTapped(note),
                                            onTapDown: () => _onNoteTappedDown(note),
                                            onTapUp: () => _onNoteTappedUp(note),
                                          ),
                                        )
                                        .toList(),
                                  ))),
                        ],
                      );
                    }));
          }),
        ),
      );

  // cancel because of redondance
  // void Function()? _onNoteTapped(NotePosition notePosition) =>
  //     widget.onNotePositionTapped == null
  //         ? null
  //         : () => widget.onNotePositionTapped!(notePosition);

  void Function()? _onNoteTappedDown(NotePosition notePosition) {
    // record new note
    if (widget.playRecorderController!.isRecordingMelody) {
      // set silence
      if (currentTimestamp > 0) {
        currentMelody.add(PianoMelodyNote(duration: Duration(milliseconds: DateTime.now().millisecondsSinceEpoch - currentTimestamp)));
      }

      // set new note
      currentNote = PianoMelodyNote(note: notePosition, duration: const Duration());

      // set timer
      currentTimestamp = DateTime.now().millisecondsSinceEpoch;
    }

    // other stuff, redirect to normal activation
    if (widget.onNotePositionTapped != null) {
      widget.onNotePositionTapped!(notePosition);
    }
    return null;
  }

  void Function()? _onNoteTappedUp(NotePosition notePosition) {
    // release previous note "downed"
    if (widget.playRecorderController!.isRecordingMelody && currentNote != null) {
      // ajust timer and record in melody
      currentNote!.duration = Duration(milliseconds: DateTime.now().millisecondsSinceEpoch - currentTimestamp);
      currentMelody.add(currentNote!);

      // get silence
      currentTimestamp = DateTime.now().millisecondsSinceEpoch;
    }

    return null;
  }

  ///
  /// Play a melody
  ///
  Future<void> playMelody(PianoMelody melody) async {
    // check
    if (widget.playRecorderController!.isRecordingMelody || widget.playRecorderController!.isPlayingMelody) {
      return;
    }

    // playing melody
    widget.playRecorderController!.isPlayingMelody = true;
    if (kDebugMode) {
      print("Piano: playing; '${melody.name}'");
    }

    // callback on start
    if (widget.onStartPlayMelody != null) {
      widget.onStartPlayMelody!();
    }

    // parse notes
    for(PianoMelodyNote note in melody.melody) {
      // silence or note
      // if (kDebugMode) {
      //   print("Piano: play; '${note.note} / ${note.duration}'");
      // }

      // callback
      if (widget.onNotePositionTapped != null && note.note != null) {
        widget.onNotePositionTapped!(note.note!);
      }

      // pause for duration note/silence
      await Future.delayed(note.duration);
    }

    // end playing
    widget.playRecorderController!.isPlayingMelody = false;
    if (kDebugMode) {
      print("Piano: end playing: '${melody.name}'");
    }

    // callback on stop
    if (widget.onStopPlayMelody != null) {
      // little sleep before callback (display note ...)
      await Future.delayed(const Duration(milliseconds: 500));

      // callback
      widget.onStopPlayMelody!();
    }
  }
}

class _PianoKey extends StatefulWidget {
  final NotePosition notePosition;
  final double keyWidth;
  final BorderRadius _borderRadius;
  final bool hideNoteName;
  final VoidCallback? onTap;
  final bool isAnimated;
  final VoidCallback? onTapDown;
  final VoidCallback? onTapUp;

  final Color _color;

  _PianoKey({
    Key? key,
    required this.notePosition,
    required this.keyWidth,
    required this.hideNoteName,
    this.onTap,
    required this.isAnimated,
    required Color color,
    Color? highlightColor,
    this.onTapDown,
    this.onTapUp,
  })  : _borderRadius = BorderRadius.only(
            bottomLeft: Radius.circular(keyWidth * 0.2),
            bottomRight: Radius.circular(keyWidth * 0.2)),
        _color = (highlightColor != null)
            ? Color.lerp(color, highlightColor, 0.5) ?? highlightColor
            : color,
        super(key: key);

  @override
  __PianoKeyState createState() => __PianoKeyState();
}

class __PianoKeyState extends State<_PianoKey>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    final animationBegin = 1.0;
    final animationEnd = 0.95;
    _controller = AnimationController(
        duration: const Duration(milliseconds: 2000), vsync: this);

    _animation = TweenSequence(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: animationBegin, end: animationEnd)
            .chain(CurveTween(curve: Curves.decelerate)),
        weight: 30.0,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: animationEnd, end: animationBegin)
            .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 20.0,
      ),
      TweenSequenceItem(tween: ConstantTween(animationBegin), weight: 50)
    ]).animate(_controller);

    _startOrStopAnimation();
  }

  @override
  void didUpdateWidget(covariant _PianoKey oldWidget) {
    if (widget.isAnimated != oldWidget.isAnimated) {
      _startOrStopAnimation();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  void _startOrStopAnimation() {
    if (widget.isAnimated) {
      _controller.repeat(reverse: false);
    } else {
      _controller.reset();
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        width: widget.keyWidth,
        padding: EdgeInsets.symmetric(
            horizontal: (widget.keyWidth *
                    (widget.notePosition.accidental == Accidental.None
                        ? 0.02
                        : 0.04))
                .ceilToDouble()),
        child: ScaleTransition(
          scale: _animation,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Semantics(
                  button: true,
                  hint: widget.notePosition.name,
                  child: Material(
                      borderRadius: widget._borderRadius,
                      elevation:
                          widget.notePosition.accidental != Accidental.None
                              ? 3.0
                              : 0.0,
                      shadowColor: Colors.black,
                      color: widget._color,
                      child: InkWell(
                        borderRadius: widget._borderRadius,
                        highlightColor: Colors.grey,
                        onTap: widget.onTap == null ? null : () => widget.onTap!(),
                        onTapUp: widget.onTapUp == null ? null : (_) => widget.onTapUp!(),
                        onTapDown: widget.onTapDown == null ? null : (_) => widget.onTapDown!(),
                        // onTap: widget.onTap == null ? null : () {},
                        // onTapDown: widget.onTap == null
                        //     ? null
                        //     : (_) {
                        //         widget.onTap!();
                        //       },
                      ))),
              Positioned(
                left: 0.0,
                right: 0.0,
                bottom: widget.keyWidth / 3,
                child: IgnorePointer(
                  child: Container(
                    decoration: (widget.notePosition == NotePosition.middleC)
                        ? BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          )
                        : null,
                    child: widget.hideNoteName
                        ? Container(
                            width: widget.keyWidth / 2,
                            height: widget.keyWidth / 2,
                          )
                        : Padding(
                            padding: EdgeInsets.all(2),
                            child: Text(
                              widget.notePosition.name,
                              textAlign: TextAlign.center,
                              textScaleFactor: 1.0,
                              style: TextStyle(
                                fontSize: widget.keyWidth / 3.5,
                                color: widget.notePosition.accidental ==
                                        Accidental.None
                                    ? (widget.notePosition ==
                                            NotePosition.middleC)
                                        ? Colors.white
                                        : Colors.black
                                    : Colors.white,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _MaybeScrollbar extends StatelessWidget {
  final ScrollController? scrollController;
  final Widget child;

  const _MaybeScrollbar(
      {Key? key, required this.scrollController, required this.child})
      : super(key: key);

  @override
  Widget build(BuildContext context) => (scrollController == null)
      ? Container(child: child)
      : RawScrollbar(
          thumbColor: Colors.grey.shade600,
          radius: Radius.circular(16),
          thickness: 16,
          thumbVisibility: true,
          controller: scrollController,
          child: Container(
              color: Colors.black,
              padding: EdgeInsets.only(bottom: 24),
              child: child));
}
