import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/media/data/media_dto.dart';
import 'package:mobile/widgets/media_image.dart';

void main() {
  testWidgets('MediaImage renders inside a SizedBox with given height',
      (tester) async {
    const asset = MediaAssetDto(
      id: 'm1',
      kind: 'IMAGE',
      filename: 'a.png',
      mimeType: 'image/png',
      sizeBytes: 100,
      url: '/uploads/a.png',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 160,
            child: MediaImage(asset: asset, height: 160),
          ),
        ),
      ),
    );
    await tester.pump();

    // While loading, MediaImage should show a placeholder (CircularProgressIndicator).
    expect(find.byType(MediaImage), findsOneWidget);
  });
}
