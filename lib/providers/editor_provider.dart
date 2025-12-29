import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EditorState {
  DateTime date;
  final TextEditingController controller;
  EditorState({required this.date, required this.controller});
}

class EditorStateNotifier extends Notifier<EditorState> {
  late final TextEditingController _controller;

  @override
  EditorState build() {
    _controller = TextEditingController();
    return EditorState(date: DateTime.now(), controller: _controller);
  }

  void setDate(DateTime date) {
    state = EditorState(date: date, controller: state.controller);
  }

  void setText(String text) {
    state.controller.text = text;
  }

  void disposeController() {
    _controller.dispose();
  }
}

final editorProvider = NotifierProvider<EditorStateNotifier, EditorState>(EditorStateNotifier.new);
