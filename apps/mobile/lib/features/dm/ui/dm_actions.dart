import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_error.dart';
import '../data/dm_repository.dart';

/// P6.9 — resolve-or-create a workflow-scoped DM channel then open the
/// thread. Shared by the recruitment / contribution entry points. The
/// server is the real gate (party-only, workflow-live); a 403/409 here
/// surfaces as a snackbar.
Future<void> openScopedDm(
  BuildContext context,
  WidgetRef ref, {
  required String scope,
  required String refId,
  String? counterpartId,
  String? peerName,
}) async {
  try {
    final channel = await ref.read(dmRepositoryProvider).resolveOrCreate(
          scope: scope,
          refId: refId,
          counterpartId: counterpartId,
        );
    if (!context.mounted) return;
    final q = (peerName != null && peerName.isNotEmpty)
        ? '?peer=${Uri.encodeComponent(peerName)}'
        : '';
    context.push('/dm/${channel.id}$q');
  } on ApiError catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('대화를 열지 못했어요: ${e.message}')),
      );
    }
  }
}
