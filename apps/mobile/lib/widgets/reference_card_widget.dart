import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../features/reference/data/reference_dto.dart';

class ReferenceCardWidget extends StatelessWidget {
  const ReferenceCardWidget({super.key, required this.reference, this.compact = false});
  final ReferenceDto reference;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: PrismColors.soft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.link,
                  color: PrismColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reference.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    '${_typeLabel(reference.type)}'
                    '${reference.sourceName != null ? ' · ${reference.sourceName}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: PrismColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'TV_SHOW':
        return '예능 프로그램';
      case 'YOUTUBE':
        return '유튜브';
      case 'GAME_RULE':
        return '게임 룰';
      case 'ARTICLE':
        return '기사';
      case 'IDEA':
        return '아이디어';
      default:
        return type;
    }
  }
}
