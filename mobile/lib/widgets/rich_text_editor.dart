import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../theme.dart';
import '../utils/rich_text.dart';

/// Contrôleur d'éditeur initialisé depuis un commentaire HTML
QuillController quillControllerFromHtml(String html) => QuillController(
      document: Document.fromJson(htmlToDelta(html)),
      selection: const TextSelection.collapsed(offset: 0),
    );

/// Contenu de l'éditeur en HTML (format stocké) ; chaîne vide si rien n'est saisi
String quillControllerToHtml(QuillController controller) => deltaToHtml(controller.document.toDelta().toJson());

/// Éditeur du commentaire : gras, italique, souligné, barré, listes, citation
class RichTextEditor extends StatelessWidget {
  const RichTextEditor({super.key, required this.controller, this.placeholder});

  final QuillController controller;
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuillSimpleToolbar(
            controller: controller,
            config: const QuillSimpleToolbarConfig(
              multiRowsDisplay: false,
              showDividers: true,
              showFontFamily: false,
              showFontSize: false,
              showBoldButton: true,
              showItalicButton: true,
              showUnderLineButton: true,
              showStrikeThrough: true,
              showSmallButton: false,
              showLineHeightButton: false,
              showInlineCode: false,
              showColorButton: false,
              showBackgroundColorButton: false,
              showClearFormat: false,
              showAlignmentButtons: false,
              showHeaderStyle: false,
              showListNumbers: true,
              showListBullets: true,
              showListCheck: false,
              showCodeBlock: false,
              showQuote: true,
              showIndent: false,
              showLink: false,
              showUndo: true,
              showRedo: true,
              showDirection: false,
              showSearchButton: false,
              showSubscript: false,
              showSuperscript: false,
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          QuillEditor.basic(
            controller: controller,
            config: QuillEditorConfig(
              placeholder: placeholder,
              padding: const EdgeInsets.all(12),
              minHeight: 112,
            ),
          ),
        ],
      ),
    );
  }
}
