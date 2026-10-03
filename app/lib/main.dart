import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data.dart';

const developerName = 'Joel Queiroz';
const certSha256 = '97dbaa35 4f5c6792 96ebf0bb 2893bcdf 4f829505 8b333207 61277da9 eefa3be9';

class Settings extends ChangeNotifier {
  ThemeMode mode = ThemeMode.system;
  double fontScale = 1.0;
  late final SharedPreferences _p;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    mode = ThemeMode.values[(_p.getInt('mode') ?? 0).clamp(0, 2)];
    fontScale = (_p.getDouble('font') ?? 1.0).clamp(0.8, 2.0);
  }

  void setMode(ThemeMode m) {
    mode = m;
    _p.setInt('mode', m.index);
    notifyListeners();
  }

  void setFont(double v) {
    fontScale = v;
    _p.setDouble('font', v);
    notifyListeners();
  }
}

final settings = Settings();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await settings.load();
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final Future<Book> _book = Book.load();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: settings, builder: (context, _) => MaterialApp(
      title: 'O Livro dos Espíritos',
      debugShowCheckedModeBanner: false,
      themeMode: settings.mode,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF5B4B8A), useMaterial3: true),
      darkTheme: ThemeData(
          colorSchemeSeed: const Color(0xFF5B4B8A), brightness: Brightness.dark, useMaterial3: true),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(settings.fontScale)),
        child: child!,
      ),
      home: FutureBuilder<Book>(
        future: _book,
        builder: (context, snap) {
          if (snap.hasError) return Scaffold(body: Center(child: Text('${snap.error}')));
          if (!snap.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return CoverGate(book: snap.data!);
        },
      ),
    ));
  }
}

void showSettings(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (_) => ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Aparência', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto), label: Text('Auto')),
              ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Dia')),
              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Noite')),
            ],
            selected: {settings.mode},
            onSelectionChanged: (s) => settings.setMode(s.first),
          ),
          const SizedBox(height: 20),
          Text('Tamanho da fonte (${(settings.fontScale * 100).round()}%)',
              style: Theme.of(context).textTheme.titleMedium),
          Row(children: [
            const Text('A', style: TextStyle(fontSize: 12)),
            Expanded(
              child: Slider(
                value: settings.fontScale,
                min: 0.8,
                max: 2.0,
                divisions: 12,
                onChanged: settings.setFont,
              ),
            ),
            const Text('A', style: TextStyle(fontSize: 24)),
          ]),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: const Text('Sobre'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'O Livro dos Espíritos',
              applicationVersion: '1.0.0',
              applicationLegalese: 'Desenvolvido por $developerName',
              children: const [
                SizedBox(height: 12),
                SelectableText('GitHub: github.com/queirozsume/kardecEspiritos'),
                SizedBox(height: 8),
                SelectableText('SHA-256 do certificado:\n$certSha256'),
                SizedBox(height: 8),
                Text('Retrato: Bibliothèque nationale de France, domínio público.'),
              ],
            ),
          ),
        ]),
      ),
    ),
  );
}

// ---------- navegação ----------

void openQuestion(BuildContext c, Book b, int n) {
  final q = b.qByN[n];
  if (q == null) return;
  Navigator.push(c, MaterialPageRoute(
      builder: (_) => ChapterPage(book: b, chapterId: q['chapter'] as String, focus: n)));
}

void openChapter(BuildContext c, Book b, String id, {String? theme}) {
  Navigator.push(c, MaterialPageRoute(
      builder: (_) => ChapterPage(book: b, chapterId: id, focusTheme: theme)));
}

void openSection(BuildContext c, Book b, String key, {String? label}) {
  Navigator.push(c, MaterialPageRoute(
      builder: (_) => SectionPage(book: b, sectionKey: key, focusLabel: label)));
}

void scrollTo(GlobalKey? k) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final ctx = k?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.05);
    }
  });
}

Widget refChip(BuildContext context, Book b, List r) {
  switch (r[0]) {
    case 'q':
      return ActionChip(label: Text('${r[2]}'), onPressed: () => openQuestion(context, b, r[1] as int));
    case 'r':
      return ActionChip(label: Text('${r[3]}'), onPressed: () => openQuestion(context, b, r[1] as int));
    case 's':
      final lab = r[2] == '' ? '' : ' ${r[2]}';
      return ActionChip(
          label: Text('${sectionNames[r[1]]}$lab'),
          onPressed: () => openSection(context, b, r[1] as String, label: r[2] == '' ? null : r[2] as String));
    default:
      return Chip(label: Text('${r[1]}'));
  }
}

// ---------- capa ----------

class CoverGate extends StatefulWidget {
  const CoverGate({super.key, required this.book});
  final Book book;
  @override
  State<CoverGate> createState() => _CoverGateState();
}

class _CoverGateState extends State<CoverGate> {
  bool open = false;

  @override
  Widget build(BuildContext context) {
    if (open) return Home(book: widget.book);
    return Scaffold(
      backgroundColor: const Color(0xFF1E1830),
      body: SafeArea(
        child: InkWell(
          onTap: () => setState(() => open = true),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(children: [
              const SizedBox(height: 8),
              const Text('O LIVRO DOS',
                  style: TextStyle(color: Color(0xFFE8D9A8), fontSize: 20, letterSpacing: 6)),
              const Text('ESPÍRITOS',
                  style: TextStyle(
                      color: Color(0xFFE8D9A8), fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: 4)),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE8D9A8), width: 2),
                    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
                  ),
                  child: Image.asset('assets/kardec.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter, width: double.infinity),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Allan Kardec',
                  style: TextStyle(color: Color(0xFFE8D9A8), fontSize: 22, fontStyle: FontStyle.italic)),
              const SizedBox(height: 12),
              const Text('Toque para abrir', style: TextStyle(color: Colors.white54, fontSize: 13)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------- início ----------

class Home extends StatefulWidget {
  const Home({super.key, required this.book});
  final Book book;
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final b = widget.book;
    return Scaffold(
      appBar: AppBar(
        title: const Text('O Livro dos Espíritos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_fields),
            tooltip: 'Aparência e fonte',
            onPressed: () => showSettings(context),
          ),
        ],
      ),
      body: IndexedStack(index: tab, children: [
        BookTab(book: b),
        SearchTab(book: b),
        IndexTab(book: b),
        SectionsTab(book: b),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Livro'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Busca'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Índice'),
          NavigationDestination(icon: Icon(Icons.article), label: 'Textos'),
        ],
      ),
    );
  }
}

class BookTab extends StatelessWidget {
  const BookTab({super.key, required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      for (final p in book.parts)
        ExpansionTile(
          title: Text('Parte ${p['id']} – ${p['title']}'),
          children: [
            for (final c in (p['chapters'] as List).cast<J>())
              ListTile(
                title: Text('Capítulo ${c['num']} – ${c['title']}'),
                onTap: () => openChapter(context, book, c['id'] as String),
              ),
          ],
        ),
    ]);
  }
}

class SectionsTab extends StatelessWidget {
  const SectionsTab({super.key, required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      for (final e in sectionNames.entries)
        ListTile(title: Text(e.value), onTap: () => openSection(context, book, e.key)),
    ]);
  }
}

// ---------- busca ----------

class SearchTab extends StatefulWidget {
  const SearchTab({super.key, required this.book});
  final Book book;
  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  static const scopes = ['Perguntas', 'Capítulos e temas', 'Palavras-chave'];
  final ctrl = TextEditingController();
  int scope = 0;

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  List<Widget> results() {
    final b = widget.book;
    final q = ctrl.text;
    if (q.trim().isEmpty) return [];
    switch (scope) {
      case 0:
        return [
          for (final x in b.searchQuestions(q))
            ListTile(
              title: Text('${x['n']}. ${x['q']}', maxLines: 3, overflow: TextOverflow.ellipsis),
              subtitle: Text('${x['theme']}'.isEmpty
                  ? 'Capítulo ${x['chapter']}'
                  : 'Capítulo ${x['chapter']} · ${x['theme']}'),
              onTap: () => openQuestion(context, b, x['n'] as int),
            ),
        ];
      case 1:
        return [
          for (final h in b.searchTitles(q))
            ListTile(
              title: Text(h.theme ?? 'Capítulo ${h.chapter['num']} – ${h.chapter['title']}'),
              subtitle: h.theme == null ? null : Text('Capítulo ${h.chapter['num']} – ${h.chapter['title']}'),
              onTap: () => openChapter(context, b, h.chapter['id'] as String, theme: h.theme),
            ),
        ];
      default:
        return [
          for (final e in b.searchIndex(q))
            ListTile(
              title: Text('${e['term']}'),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => EntryPage(book: b, entry: e))),
            ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = results();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: ctrl,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Palavra ou número da pergunta (1–1019)',
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
            suffixIcon: ctrl.text.isEmpty
                ? null
                : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(ctrl.clear)),
          ),
        ),
      ),
      Wrap(spacing: 8, children: [
        for (var i = 0; i < scopes.length; i++)
          ChoiceChip(label: Text(scopes[i]), selected: scope == i, onSelected: (_) => setState(() => scope = i)),
      ]),
      const SizedBox(height: 4),
      Expanded(
        child: res.isEmpty
            ? Center(child: Text(ctrl.text.trim().isEmpty ? '' : 'Nenhum resultado'))
            : ListView(children: res),
      ),
    ]);
  }
}

// ---------- índice remissivo ----------

class IndexTab extends StatefulWidget {
  const IndexTab({super.key, required this.book});
  final Book book;
  @override
  State<IndexTab> createState() => _IndexTabState();
}

class _IndexTabState extends State<IndexTab> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.book.searchIndex(q);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          onChanged: (v) => setState(() => q = v),
          decoration: const InputDecoration(
              hintText: 'Filtrar índice', prefixIcon: Icon(Icons.filter_list), border: OutlineInputBorder()),
        ),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: list.length,
          itemBuilder: (_, i) => ListTile(
            title: Text('${list[i]['term']}'),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => EntryPage(book: widget.book, entry: list[i]))),
          ),
        ),
      ),
    ]);
  }
}

class EntryPage extends StatelessWidget {
  const EntryPage({super.key, required this.book, required this.entry});
  final Book book;
  final J entry;

  @override
  Widget build(BuildContext context) {
    final refs = (entry['refs'] as List).cast<List>();
    final subs = (entry['subs'] as List).cast<J>();
    return Scaffold(
      appBar: AppBar(title: Text('${entry['term']}')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (refs.isNotEmpty)
          Wrap(spacing: 8, children: [for (final r in refs) refChip(context, book, r)]),
        for (final s in subs) ...[
          const SizedBox(height: 16),
          Text('${s['label']}', style: Theme.of(context).textTheme.titleMedium),
          Wrap(spacing: 8, children: [
            for (final r in (s['refs'] as List).cast<List>()) refChip(context, book, r),
          ]),
        ],
      ]),
    );
  }
}

// ---------- capítulo ----------

class ChapterPage extends StatefulWidget {
  const ChapterPage({super.key, required this.book, required this.chapterId, this.focus, this.focusTheme});
  final Book book;
  final String chapterId;
  final int? focus;
  final String? focusTheme;
  @override
  State<ChapterPage> createState() => _ChapterPageState();
}

class _ChapterPageState extends State<ChapterPage> {
  final _keys = <String, GlobalKey>{};
  GlobalKey key(String k) => _keys.putIfAbsent(k, () => GlobalKey());

  @override
  void initState() {
    super.initState();
    if (widget.focus != null) scrollTo(key('q${widget.focus}'));
    if (widget.focusTheme != null) scrollTo(key('th${widget.focusTheme}'));
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.book;
    final ch = b.chapters[widget.chapterId]!;
    final part = b.partOf[widget.chapterId]!;
    final qs = b.qsByChapter[widget.chapterId] ?? <J>[];
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final texts = ((ch['texts'] ?? []) as List)
        .cast<J>()
        .where((t) => !((t['p'] as List).isNotEmpty && (t['p'] as List).first.toString().startsWith('•')))
        .toList();
    // Textos livres entram depois da última pergunta com número <= 'after'.
    final buckets = <int, List<J>>{};
    for (final t in texts) {
      var idx = -1;
      for (var i = 0; i < qs.length; i++) {
        if ((qs[i]['n'] as int) <= (t['after'] as int)) idx = i;
      }
      (buckets[idx] ??= []).add(t);
    }

    final items = <Widget>[];
    String? lastTheme;
    void theme(String? t) {
      if (t == null || t.isEmpty || t == lastTheme) return;
      lastTheme = t;
      items.add(Padding(
        key: key('th$t'),
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
        child: Text(t, style: tt.titleLarge?.copyWith(color: cs.primary)),
      ));
    }

    void textBlock(J t) {
      theme(t['theme'] as String?);
      for (final p in (t['p'] as List)) {
        items.add(Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('$p', style: tt.bodyLarge?.copyWith(height: 1.5))));
      }
      for (final n in (t['notes'] as List)) {
        items.add(Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('$n', style: tt.bodySmall?.copyWith(fontStyle: FontStyle.italic))));
      }
    }

    (buckets[-1] ?? []).forEach(textBlock);
    for (var i = 0; i < qs.length; i++) {
      final q = qs[i];
      theme(q['theme'] as String?);
      items.add(QuestionCard(key: key('q${q['n']}'), q: q, highlight: q['n'] == widget.focus));
      (buckets[i] ?? []).forEach(textBlock);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Cap. ${ch['num']} – ${ch['title']}'),
        actions: [IconButton(icon: const Icon(Icons.text_fields), onPressed: () => showSettings(context))],
      ),
      body: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Parte ${part['id']} – ${part['title']}', style: tt.labelLarge),
            const SizedBox(height: 4),
            Text('${ch['title']}', style: tt.headlineSmall),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Temas do capítulo'),
              children: [
                for (final th in (ch['themes'] as List).cast<J>())
                  ListTile(
                    dense: true,
                    title: Text('${th['title']}'),
                    onTap: () => scrollTo(_keys['th${th['title']}']),
                  ),
              ],
            ),
            ...items,
          ]),
        ),
      ),
    );
  }
}

class QuestionCard extends StatelessWidget {
  const QuestionCard({super.key, required this.q, this.highlight = false});
  final J q;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      color: highlight ? cs.tertiaryContainer : null,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${q['n']}.', style: tt.titleMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Expanded(child: Text('${q['q']}', style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600, fontStyle: FontStyle.italic))),
          ]),
          const SizedBox(height: 8),
          Text('${q['a']}', style: tt.bodyLarge?.copyWith(height: 1.5)),
          for (final c in (q['c'] as List))
            Padding(padding: const EdgeInsets.only(top: 8), child: Text('$c', style: tt.bodyMedium?.copyWith(height: 1.5))),
          for (final n in (q['notes'] as List))
            Padding(padding: const EdgeInsets.only(top: 8), child: Text('$n', style: tt.bodySmall?.copyWith(fontStyle: FontStyle.italic))),
        ]),
      ),
    );
  }
}

// ---------- introdução, conclusão etc. ----------

class SectionPage extends StatefulWidget {
  const SectionPage({super.key, required this.book, required this.sectionKey, this.focusLabel});
  final Book book;
  final String sectionKey;
  final String? focusLabel;
  @override
  State<SectionPage> createState() => _SectionPageState();
}

class _SectionPageState extends State<SectionPage> {
  final _keys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    if (widget.focusLabel != null) scrollTo(_keys.putIfAbsent(widget.focusLabel!, () => GlobalKey()));
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final items = widget.book.section(widget.sectionKey);
    return Scaffold(
      appBar: AppBar(
        title: Text(sectionNames[widget.sectionKey]!),
        actions: [IconButton(icon: const Icon(Icons.text_fields), onPressed: () => showSettings(context))],
      ),
      body: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final it in items) ...[
              if ((it['label'] as String).isNotEmpty)
                Padding(
                  key: _keys.putIfAbsent(it['label'] as String, () => GlobalKey()),
                  padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
                  child: Text(it['label'] as String, style: tt.titleLarge?.copyWith(color: cs.primary)),
                ),
              for (final p in (it['p'] as List))
                Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('$p', style: tt.bodyLarge?.copyWith(height: 1.5))),
              for (final n in (it['notes'] as List))
                Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('$n', style: tt.bodySmall?.copyWith(fontStyle: FontStyle.italic))),
            ],
          ]),
        ),
      ),
    );
  }
}
