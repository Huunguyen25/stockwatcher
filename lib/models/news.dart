class NewsArticle {
  final String category;
  final int datetime;
  final String headline;
  final int id;
  final String image;
  final String related;
  final String source;
  final String summary;
  final String url;

  NewsArticle({
    required this.category,
    required this.datetime,
    required this.headline,
    required this.id,
    required this.image,
    required this.related,
    required this.source,
    required this.summary,
    required this.url,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      category: json['category'] ?? '',
      datetime: json['datetime'] ?? 0,
      headline: json['headline'] ?? '',
      id: json['id'] ?? 0,
      image: json['image'] ?? '',
      related: json['related'] ?? '',
      source: json['source'] ?? '',
      summary: json['summary'] ?? '',
      url: json['url'] ?? '',
    );
  }
}
