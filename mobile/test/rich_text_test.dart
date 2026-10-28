import 'package:flutter_test/flutter_test.dart';
import 'package:pas_ce_soir/utils/rich_text.dart';

void main() {
  group('Commentaires : HTML (TipTap) <-> Delta (Quill)', () {
    const samples = [
      '<p>Simple</p>',
      '<p><strong>Gras</strong> et <em>italique</em>, <u>souligné</u>, <s>barré</s></p>',
      '<p>Avant</p><ul><li><p>un</p></li><li><p>deux</p></li></ul><p>Après</p>',
      '<ol><li><p>premier</p></li><li><p>second</p></li></ol>',
      '<blockquote><p>Citation</p><p>sur deux lignes</p></blockquote>',
      '<p>a &lt; b &amp; c</p>',
    ];

    for (final html in samples) {
      test('aller-retour : $html', () {
        expect(deltaToHtml(htmlToDelta(html)), html);
      });
    }

    test('commentaire vide', () {
      expect(htmlToDelta(''), [
        {'insert': '\n'}
      ]);
      expect(deltaToHtml(htmlToDelta('')), '');
      expect(deltaToHtml(htmlToDelta('<p></p>')), '');
    });

    test('texte brut pour l’aperçu', () {
      expect(htmlToPlainText('<p>Il a <strong>pleuré</strong></p><p>10 min &amp; câlin</p>'),
          'Il a pleuré 10 min & câlin');
    });
  });

  test('marques imbriquées', () {
    expect(deltaToHtml(htmlToDelta('<p><strong><em>les deux</em></strong></p>')),
        '<p><strong><em>les deux</em></strong></p>');
  });
}
