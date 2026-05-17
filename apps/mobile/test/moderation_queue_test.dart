import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/dio_provider.dart';
import 'package:mobile/features/moderation/data/moderation_dto.dart';
import 'package:mobile/features/moderation/data/moderation_repository.dart';
import 'package:mobile/features/moderation/ui/moderation_queue_screen.dart';

ReportListDto _two() => ReportListDto(items: [
      ReportDto(
        id: 'r1',
        reporterId: 'u-joon',
        reporterNickname: 'joon',
        targetType: 'POST',
        targetId: 'p-1234',
        reason: '스팸',
        details: null,
        status: 'OPEN',
        resolution: null,
        resolvedAt: null,
        resolverNote: null,
        createdAt: DateTime(2026),
      ),
      ReportDto(
        id: 'r2',
        reporterId: 'u-haneul',
        reporterNickname: 'haneul',
        targetType: 'REPLY',
        targetId: 'rp-9876',
        reason: '욕설/혐오',
        details: null,
        status: 'OPEN',
        resolution: null,
        resolvedAt: null,
        resolverNote: null,
        createdAt: DateTime(2026),
      ),
    ]);

Dio _fakeDio() {
  final dio = Dio(BaseOptions(baseUrl: 'http://fake'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) => handler.resolve(
      Response(requestOptions: options, statusCode: 200, data: {'items': []}),
    ),
  ));
  return dio;
}

void main() {
  testWidgets('queue screen renders two reports', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        moderationQueueProvider.overrideWith((_) async => _two()),
        dioProvider.overrideWith((_) => _fakeDio()),
      ],
      child: const MaterialApp(home: ModerationQueueScreen()),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('POST · 스팸'), findsOneWidget);
    expect(find.text('REPLY · 욕설/혐오'), findsOneWidget);
  });

  testWidgets('queue empty state', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        moderationQueueProvider
            .overrideWith((_) async => const ReportListDto(items: [])),
        dioProvider.overrideWith((_) => _fakeDio()),
      ],
      child: const MaterialApp(home: ModerationQueueScreen()),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('대기 중인 신고가 없습니다.'), findsOneWidget);
  });
}
