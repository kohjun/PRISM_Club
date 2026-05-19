import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme.dart';
import '../../data/search_dto.dart';

class SearchResultTile extends StatelessWidget {
  const SearchResultTile({super.key, required this.hit, this.returnTo});
  final SearchHitDto hit;

  /// Optional internal route to pass through as `?returnTo=...` when
  /// the user taps into a Topic Hub. Lets the Hub's back button bring
  /// them back to the same Search state (query + filter) instead of
  /// dropping them on /spaces. Caller is responsible for shaping a
  /// safe internal route; the receiving screen validates again.
  final String? returnTo;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _onTap(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: PrismColors.soft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_iconFor(hit.type),
                    color: PrismColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hit.title,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hit.snippet.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        hit.snippet,
                        style: const TextStyle(
                            color: PrismColors.muted, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _contextLine(hit),
                      style: const TextStyle(
                          color: PrismColors.muted, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: PrismColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onTap(BuildContext context) async {
    switch (hit.type) {
      case SearchEntityType.topicHub:
      case SearchEntityType.knowledgeBlock: {
        final slug = hit.ctxString('category_slug');
        if (slug != null && slug.isNotEmpty) {
          final dest = StringBuffer('/categories/$slug');
          if (returnTo != null && returnTo!.isNotEmpty) {
            dest
              ..write('?returnTo=')
              ..write(Uri.encodeQueryComponent(returnTo!));
          }
          context.go(dest.toString());
        }
        break;
      }
      case SearchEntityType.room: {
        final slug = hit.ctxString('room_slug');
        if (slug != null && slug.isNotEmpty) context.go('/rooms/$slug');
        break;
      }
      case SearchEntityType.post: {
        final id = hit.ctxString('post_id');
        if (id != null && id.isNotEmpty) context.go('/posts/$id');
        break;
      }
      case SearchEntityType.eventCard:
        context.go('/events/${hit.id}');
        break;
      case SearchEntityType.reference: {
        final url = hit.ctxString('url');
        if (url == null || url.isEmpty) break;
        final uri = Uri.tryParse(url);
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (uri == null) {
          messenger?.showSnackBar(const SnackBar(content: Text('잘못된 URL입니다.')));
          return;
        }
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok && context.mounted) {
          messenger?.showSnackBar(
            SnackBar(content: Text('URL을 열지 못했어요: $url')),
          );
        }
        break;
      }
      default:
        break;
    }
  }

  static IconData _iconFor(String type) {
    switch (type) {
      case SearchEntityType.topicHub:
        return Icons.topic_outlined;
      case SearchEntityType.knowledgeBlock:
        return Icons.lightbulb_outline;
      case SearchEntityType.room:
        return Icons.forum_outlined;
      case SearchEntityType.post:
        return Icons.description_outlined;
      case SearchEntityType.eventCard:
        return Icons.event;
      case SearchEntityType.reference:
        return Icons.link;
      default:
        return Icons.search;
    }
  }

  static String _contextLine(SearchHitDto hit) {
    switch (hit.type) {
      case SearchEntityType.topicHub:
        return 'Topic Hub · ${hit.ctxString('category_slug') ?? ''}';
      case SearchEntityType.knowledgeBlock:
        return '지식 블록 · ${hit.ctxString('block_type') ?? ''}';
      case SearchEntityType.room: {
        final origin = hit.ctxString('origin');
        final owner = hit.ctxString('owner_nickname');
        final base = origin == 'USER' ? '유저 생성 방' : '기본 방';
        return owner != null && owner.isNotEmpty ? '$base · $owner' : base;
      }
      case SearchEntityType.post: {
        final room = hit.ctxString('room_name') ?? '';
        final author = hit.ctxString('author_nickname') ?? '';
        return '글 · $room${author.isNotEmpty ? " · $author" : ""}';
      }
      case SearchEntityType.eventCard: {
        final region = hit.ctxString('region') ?? '';
        final status = hit.ctxString('event_status') == 'COMPLETED' ? '완료' : '예정';
        return '이벤트 · $status${region.isNotEmpty ? " · $region" : ""}';
      }
      case SearchEntityType.reference: {
        final src = hit.ctxString('source_name');
        return src != null && src.isNotEmpty ? '레퍼런스 · $src' : '레퍼런스';
      }
      default:
        return hit.type;
    }
  }
}
