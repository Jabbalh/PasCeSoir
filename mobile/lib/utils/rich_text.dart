import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

// Les commentaires sont stockés en HTML (format de l'éditeur TipTap de la PWA) :
// <p>, <strong>, <em>, <u>, <s>, <ul>/<ol> avec <li><p>…</p></li>, <blockquote><p>…</p></blockquote>.
// L'éditeur Flutter (flutter_quill) travaille en Delta : conversion dans les deux sens.

/// Texte brut d'un commentaire HTML (aperçu)
String htmlToPlainText(String html) {
  final text = html_parser.parseFragment(html.replaceAll(RegExp(r'<[^>]+>'), ' ')).text ?? '';
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

const _marks = {
  'strong': 'bold',
  'b': 'bold',
  'em': 'italic',
  'i': 'italic',
  'u': 'underline',
  's': 'strike',
  'strike': 'strike',
  'del': 'strike',
};

const _blockTags = {'p', 'ul', 'ol', 'blockquote', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6'};

/// HTML -> opérations Delta (`Document.fromJson`)
List<Map<String, dynamic>> htmlToDelta(String html) {
  final ops = <Map<String, dynamic>>[];

  void insert(String text, [Map<String, dynamic>? attrs]) {
    if (text.isEmpty) return;
    ops.add({'insert': text, if (attrs != null && attrs.isNotEmpty) 'attributes': attrs});
  }

  void inline(dom.Node node, Map<String, dynamic> attrs) {
    if (node is dom.Text) {
      insert(node.text.replaceAll('\n', ' '), attrs);
      return;
    }
    if (node is! dom.Element) return;
    if (node.localName == 'br') {
      insert('\n');
      return;
    }
    final mark = _marks[node.localName];
    final nested = mark == null ? attrs : {...attrs, mark: true};
    for (final child in node.nodes) {
      inline(child, nested);
    }
  }

  void line(dom.Node node, Map<String, dynamic>? lineAttrs) {
    for (final child in node.nodes) {
      inline(child, const {});
    }
    insert('\n', lineAttrs);
  }

  void block(dom.Node node, Map<String, dynamic>? lineAttrs) {
    if (node is dom.Text) {
      if (node.text.trim().isEmpty) return;
      insert(node.text.replaceAll('\n', ' '));
      insert('\n', lineAttrs);
      return;
    }
    if (node is! dom.Element) return;
    switch (node.localName) {
      case 'ul' || 'ol':
        final list = {'list': node.localName == 'ul' ? 'bullet' : 'ordered'};
        for (final li in node.children) {
          block(li, list);
        }
      case 'li':
        // TipTap : <li><p>…</p></li> ; les sous-listes sont aplaties
        if (node.children.any((c) => _blockTags.contains(c.localName))) {
          for (final child in node.nodes) {
            block(child, child is dom.Element && child.localName == 'p' ? lineAttrs : null);
          }
        } else {
          line(node, lineAttrs);
        }
      case 'blockquote':
        for (final child in node.nodes) {
          block(child, const {'blockquote': true});
        }
      case final tag when _blockTags.contains(tag):
        line(node, lineAttrs);
      default:
        inline(node, const {});
        insert('\n', lineAttrs);
    }
  }

  for (final node in html_parser.parseFragment(html).nodes) {
    block(node, null);
  }
  final last = ops.lastOrNull?['insert'];
  if (last is! String || !last.endsWith('\n')) ops.add({'insert': '\n'});
  return ops;
}

String _escape(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

String _wrapInline(String text, Map<String, dynamic> attrs) {
  var out = text;
  if (attrs['strike'] == true) out = '<s>$out</s>';
  if (attrs['underline'] == true) out = '<u>$out</u>';
  if (attrs['italic'] == true) out = '<em>$out</em>';
  if (attrs['bold'] == true) out = '<strong>$out</strong>';
  return out;
}

/// Opérations Delta (`document.toDelta().toJson()`) -> HTML ; chaîne vide si le texte est vide
String deltaToHtml(List<dynamic> ops) {
  // Lignes : contenu HTML + attributs de ligne (portés par le « \n » qui la termine)
  final lines = <(String, Map<String, dynamic>)>[];
  final buf = StringBuffer();
  for (final op in ops) {
    final text = (op as Map)['insert'];
    if (text is! String) continue; // images et autres objets : non gérés
    final attrs = (op['attributes'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final parts = text.split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) buf.write(_wrapInline(_escape(parts[i]), attrs));
      if (i < parts.length - 1) {
        lines.add((buf.toString(), attrs));
        buf.clear();
      }
    }
  }
  if (buf.isNotEmpty) lines.add((buf.toString(), const {}));
  if (lines.every((l) => l.$1.trim().isEmpty)) return '';

  final out = StringBuffer();
  String? openList;
  var inQuote = false;
  void close() {
    if (openList != null) out.write('</$openList>');
    if (inQuote) out.write('</blockquote>');
    openList = null;
    inQuote = false;
  }

  for (final (content, attrs) in lines) {
    final p = '<p>$content</p>';
    final list = switch (attrs['list']) { 'bullet' => 'ul', 'ordered' => 'ol', _ => null };
    if (list != null) {
      if (openList != list) {
        close();
        out.write('<$list>');
        openList = list;
      }
      out.write('<li>$p</li>');
    } else if (attrs['blockquote'] == true) {
      if (!inQuote) {
        close();
        out.write('<blockquote>');
        inQuote = true;
      }
      out.write(p);
    } else {
      close();
      out.write(p);
    }
  }
  close();
  return out.toString();
}
