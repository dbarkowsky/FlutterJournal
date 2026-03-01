import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal/helpers/formatters.dart';

class EditorState {
  String date;
  final TextEditingController controller;
  EditorState({required this.date, required this.controller});
}

class EditorStateNotifier extends Notifier<EditorState> {
  late final TextEditingController _controller;

  @override
  EditorState build() {
    _controller = TextEditingController();
    return EditorState(date: Formatters.date(DateTime.now()), controller: _controller);
  }

  void setDate(DateTime date, {int? retainDay}) {
    int day = retainDay ?? date.day;
    int year = date.year;
    int month = date.month;
    // Last day of month must be a valid date
    int lastDayOfMonth = DateTime(year, month + 1, 0).day;
    int newDay = day <= lastDayOfMonth ? day : lastDayOfMonth;
    final newDate = DateTime(year, month, newDay);
    state = EditorState(date: Formatters.date(newDate), controller: state.controller);
  }

  void setText(String text) {
    state.controller.text = text;
    // Emit a new EditorState instance so widgets watching this provider
    // rebuild and re-read controller.text (e.g. the view-mode Markdown widget).
    state = EditorState(date: state.date, controller: state.controller);
  }

  void disposeController() {
    _controller.dispose();
  }
}

final editorProvider = NotifierProvider<EditorStateNotifier, EditorState>(EditorStateNotifier.new);
