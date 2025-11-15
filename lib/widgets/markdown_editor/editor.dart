import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

class Editor extends StatefulWidget {
  const Editor({super.key});

  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  late final MutableDocument _document;
  late final DocumentComposer _composer;
  late final DocumentEditor _editor;

  @override
  void initState() {
    super.initState();

    // A MutableDocument is an in-memory Document. Create the starting
    // content that you want your editor to display.
    //
    // To start with an empty document, create a MutableDocument with a
    // single ParagraphNode that holds an empty string.
    _document = MutableDocument(
      nodes: [
        ParagraphNode(
          id: DocumentEditor.createNodeId(),
          text: AttributedText('This is a header'),
          metadata: {'blockType': header1Attribution},
        ),
        ParagraphNode(
          id: DocumentEditor.createNodeId(),
          text: AttributedText('This is the first paragraph'),
        ),
      ],
    );

    // A DocumentComposer holds the user's selection. Your editor will likely want
    // to observe, and possibly change the user's selection. Therefore, you should
    // hold onto your own DocumentComposer and pass it to your Editor.
    _composer = DocumentComposer();

    // With a MutableDocument, create an Editor, which knows how to apply changes
    // to the MutableDocument.
    _editor = DocumentEditor(document: _document);
  }

  @override
  SuperEditor build(context) {
    return SuperEditor(
      // document: _document,
      composer: _composer,
      editor: _editor,
    );
  }
}
