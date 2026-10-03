import 'dart:convert';
import 'package:flutter/services.dart';

typedef J = Map<String, dynamic>;

const sectionNames = {
  'introd': 'Introdução',
  'proleg': 'Prolegômenos',
  'concl': 'Conclusão',
};

/// Minúsculas e sem acentos, para busca.
String norm(String s) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString();
}

class TitleHit {
  TitleHit(this.chapter, this.theme, this.page);
  final J chapter;
  final String? theme;
  final int? page;
}

class Book {
  Book(this.raw) {
    for (final p in raw['parts'] as List) {
      for (final c in p['chapters'] as List) {
        chapters[c['id'] as String] = c as J;
        partOf[c['id'] as String] = p as J;
      }
    }
    for (final q in raw['questions'] as List) {
      qByN[q['n'] as int] = q as J;
      (qsByChapter[q['chapter'] as String] ??= []).add(q);
    }
  }

  final J raw;
  final Map<int, J> qByN = {};
  final Map<String, J> chapters = {};
  final Map<String, J> partOf = {};
  final Map<String, List<J>> qsByChapter = {};
  final Map<int, String> _hay = {};

  static Future<Book> load() async {
    final s = await rootBundle.loadString('assets/data.json');
    return Book(jsonDecode(s) as J);
  }

  List<J> get parts => (raw['parts'] as List).cast<J>();
  List<J> get questions => (raw['questions'] as List).cast<J>();
  List<J> get index => (raw['index'] as List).cast<J>();
  List<J> section(String key) => ((raw['sections'] as J)[key] as List).cast<J>();

  String _hayOf(J q) => _hay[q['n'] as int] ??= norm(
      '${q['q']} ${q['a']} ${(q['c'] as List).join(' ')} ${(q['notes'] as List).join(' ')}');

  List<String> _tokens(String s) =>
      norm(s).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

  List<J> searchQuestions(String query, {int limit = 300}) {
    final t = _tokens(query);
    if (t.isEmpty) return [];
    final n = int.tryParse(query.trim());
    if (n != null) {
      final q = qByN[n];
      return q == null ? [] : [q];
    }
    final out = <J>[];
    for (final q in questions) {
      final h = _hayOf(q);
      if (t.every(h.contains)) {
        out.add(q);
        if (out.length >= limit) break;
      }
    }
    return out;
  }

  List<TitleHit> searchTitles(String query) {
    final t = _tokens(query);
    if (t.isEmpty) return [];
    bool m(String s) {
      final h = norm(s);
      return t.every(h.contains);
    }

    final out = <TitleHit>[];
    for (final p in parts) {
      for (final c in (p['chapters'] as List).cast<J>()) {
        if (m(c['title'] as String)) out.add(TitleHit(c, null, null));
        for (final th in (c['themes'] as List).cast<J>()) {
          if (m(th['title'] as String)) {
            out.add(TitleHit(c, th['title'] as String, th['page'] as int?));
          }
        }
      }
    }
    return out;
  }

  List<J> searchIndex(String query) {
    final t = _tokens(query);
    if (t.isEmpty) return index;
    bool m(String s) {
      final h = norm(s);
      return t.every(h.contains);
    }

    return index
        .where((e) =>
            m(e['term'] as String) ||
            (e['subs'] as List).any((s) => m((s as J)['label'] as String)))
        .toList();
  }
}
