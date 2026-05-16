/// Type discriminators that mirror the server's `SearchEntityType`. Keeping
/// these as plain strings simplifies forward-compat — unknown values
/// fall through gracefully at render time.
class SearchEntityType {
  static const topicHub = 'topic_hub';
  static const knowledgeBlock = 'knowledge_block';
  static const room = 'room';
  static const post = 'post';
  static const eventCard = 'event_card';
  static const reference = 'reference';

  static const all = <String>[
    topicHub,
    knowledgeBlock,
    room,
    post,
    eventCard,
    reference,
  ];

  static String label(String type) {
    switch (type) {
      case topicHub:
        return 'Topic Hub';
      case knowledgeBlock:
        return '지식';
      case room:
        return '방';
      case post:
        return '글';
      case eventCard:
        return '이벤트';
      case reference:
        return '레퍼런스';
      default:
        return type;
    }
  }
}

/// Server-shaped per-hit payload. `context` is intentionally a Map so the
/// client doesn't have to fan out per-type classes — the result tile reads
/// the keys it cares about based on `type`.
class SearchHitDto {
  const SearchHitDto({
    required this.type,
    required this.id,
    required this.title,
    required this.snippet,
    required this.context,
  });

  final String type;
  final String id;
  final String title;
  final String snippet;
  final Map<String, dynamic> context;

  String? ctxString(String key) {
    final v = context[key];
    return v is String ? v : null;
  }

  factory SearchHitDto.fromJson(Map<String, dynamic> json) => SearchHitDto(
        type: json['type'] as String,
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        snippet: json['snippet'] as String? ?? '',
        context: ((json['context'] as Map?) ?? const {}).cast<String, dynamic>(),
      );
}

class SearchGroupDto {
  const SearchGroupDto({required this.type, required this.items});
  final String type;
  final List<SearchHitDto> items;

  factory SearchGroupDto.fromJson(Map<String, dynamic> json) => SearchGroupDto(
        type: json['type'] as String,
        items: ((json['items'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(SearchHitDto.fromJson)
            .toList(growable: false),
      );
}

class SearchResponseDto {
  const SearchResponseDto({required this.query, required this.groups});
  final String query;
  final List<SearchGroupDto> groups;

  int get totalHits => groups.fold(0, (sum, g) => sum + g.items.length);

  factory SearchResponseDto.fromJson(Map<String, dynamic> json) => SearchResponseDto(
        query: json['query'] as String? ?? '',
        groups: ((json['groups'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(SearchGroupDto.fromJson)
            .toList(growable: false),
      );
}
