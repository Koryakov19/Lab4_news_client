import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart'; // Импортируем пакет intl
import 'package:intl/date_symbol_data_local.dart'; // Импортируем для локализации

void main() {
  // Инициализация локализации
  initializeDateFormatting('ru_RU', null).then((_) {
    runApp(MyApp());
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'News Client',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: GoogleFonts.robotoTextTheme(Theme.of(context).textTheme),
      ),
      home: NewsPage(),
    );
  }
}

class NewsPage extends StatefulWidget {
  @override
  _NewsPageState createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  List<dynamic> news = [];
  String filterTag = '';
  bool sortByDate = false;
  late Database db;

  @override
  void initState() {
    super.initState();
    initDb();
    fetchNews();
  }

  Future<void> initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'news.db');

    db = await openDatabase(
      path,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE News(id INTEGER PRIMARY KEY, title TEXT, description TEXT, url TEXT, date TEXT, tag TEXT)',
        );
      },
      version: 1,
    );
  }

  Future<void> fetchNews() async {
    List<String> categories = ['general', 'business', 'sports', 'technology'];

    for (var category in categories) {
      final response = await http.get(Uri.parse('https://newsapi.org/v2/top-headlines?country=us&category=$category&apiKey=5972211672f6422c87bbdb3f1051478e'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          news.addAll(data['articles'].where((article) {
            return article['title'] != '[Removed]' && article['publishedAt'] != '1970-01-01T00:00:00Z';
          }).map((article) => {
            'title': article['title'] ?? '',
            'description': article['description'] ?? '',
            'url': article['url'] ?? '',
            'publishedAt': article['publishedAt'] ?? '',
            'tag': category,
          }).toList());
        });
        saveNewsOffline(news);
      } else {
        loadOfflineNews();
      }
    }
  }

  Future<void> saveNewsOffline(List<dynamic> news) async {
    await db.delete('News');
    for (var article in news) {
      await db.insert(
        'News',
        {
          'title': article['title'] ?? '',
          'description': article['description'] ?? '',
          'url': article['url'] ?? '',
          'date': article['publishedAt'] ?? '',
          'tag': article['tag'] ?? '',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> loadOfflineNews() async {
    final List<Map<String, dynamic>> maps = await db.query('News');
    setState(() {
      news = List.generate(maps.length, (i) {
        return {
          'title': maps[i]['title'] ?? '',
          'description': maps[i]['description'] ?? '',
          'url': maps[i]['url'] ?? '',
          'publishedAt': maps[i]['date'] ?? '',
          'tag': maps[i]['tag'] ?? '',
        };
      });
    });
  }

  String getLocalizedTag(String tag) {
    switch (tag) {
      case 'sports':
        return 'спорт';
      case 'business':
        return 'бизнес';
      case 'technology':
        return 'технологии';
      case 'general':
        return 'общие';
      default:
        return 'все';
    }
  }

  String formatDateTime(String dateTime) {
    final date = DateTime.parse(dateTime);
    final formattedDate = DateFormat('EEEE, d MMMM y H:mm', 'ru_RU').format(date);
    return formattedDate;
  }

  List<dynamic> get sortedAndFilteredNews {
    List<dynamic> filtered = news.where((article) {
      return filterTag.isEmpty || article['tag'] == filterTag;
    }).toList();

    if (sortByDate) {
      filtered.sort((a, b) => DateTime.parse(b['publishedAt']).compareTo(DateTime.parse(a['publishedAt'])));
    } else {
      filtered.sort((a, b) => DateTime.parse(a['publishedAt']).compareTo(DateTime.parse(b['publishedAt'])));
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('News Client', style: GoogleFonts.roboto(fontSize: 24, fontWeight: FontWeight.bold)),
        actions: [
          DropdownButton<String>(
            value: filterTag,
            items: <String>['', 'general', 'business', 'sports', 'technology']
                .map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(getLocalizedTag(value.isEmpty ? 'all' : value)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                filterTag = value!;
                print("Selected tag: $filterTag");
              });
            },
          ),
          IconButton(
            icon: Icon(sortByDate ? Icons.arrow_downward : Icons.arrow_upward),
            tooltip: 'Сортировка по дате',
            onPressed: () {
              setState(() {
                sortByDate = !sortByDate;
                print("Sort by date: $sortByDate");
              });
            },
          ),
        ],
      ),
      body: news.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/background.jpg"),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: MasonryGridView.count(
            crossAxisCount: 2,
            itemCount: sortedAndFilteredNews.length,
            itemBuilder: (context, index) {
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 8,
                shadowColor: Colors.black54,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NewsDetailPage(news: sortedAndFilteredNews[index]),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sortedAndFilteredNews[index]['title'],
                          style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 8),
                        Text(
                          formatDateTime(sortedAndFilteredNews[index]['publishedAt']),
                          style: GoogleFonts.roboto(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            mainAxisSpacing: 8.0,
            crossAxisSpacing: 8.0,
          ),
        ),
      ),
    );
  }
}

class NewsDetailPage extends StatelessWidget {
  final dynamic news;

  NewsDetailPage({required this.news});

  String formatDateTime(String dateTime) {
    final date = DateTime.parse(dateTime);
    final formattedDate = DateFormat('EEEE, d MMMM y H:mm', 'ru_RU').format(date);
    return formattedDate;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(news['title'], style: GoogleFonts.roboto(fontSize: 24, fontWeight: FontWeight.bold)),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/background.jpg"),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            color: Colors.black.withOpacity(0.5), // Полупрозрачный фон
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(news['title'], style: GoogleFonts.roboto(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text(formatDateTime(news['publishedAt']), style: GoogleFonts.roboto(fontSize: 18, color: Colors.grey[300], fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                Text(news['description'], style: GoogleFonts.roboto(fontSize: 20, color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
