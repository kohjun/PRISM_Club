import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_error.dart';
import 'package:mobile/core/dio_provider.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Dio _dio({required bool succeed}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://fake'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      if (options.path.endsWith('/auth/login')) {
        if (succeed) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'access_token': 'fake-jwt',
              'session': {
                'user_id': 'u-1',
                'nickname': 'tester',
                'roles': ['MEMBER'],
                'status': 'ACTIVE',
                'issued_at': '2026-05-17T00:00:00Z',
                'expires_at': '2026-05-24T00:00:00Z',
              },
            },
          ));
        } else {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 401,
            data: {'error': {'message': 'Unauthorized'}},
          ));
        }
      } else {
        handler.resolve(Response(
            requestOptions: options, statusCode: 200, data: {}));
      }
    },
  ));
  return dio;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('AuthRepository.login returns LoginResult on success', () async {
    final container = ProviderContainer(overrides: [
      dioProvider.overrideWith((_) => _dio(succeed: true)),
    ]);
    addTearDown(container.dispose);

    final result =
        await container.read(authRepositoryProvider).login('u-1');
    expect(result.accessToken, 'fake-jwt');
    expect(result.userId, 'u-1');
    expect(result.nickname, 'tester');
    expect(result.roles, contains('MEMBER'));
  });

  test('AuthRepository.login throws ApiError on 401', () async {
    final container = ProviderContainer(overrides: [
      dioProvider.overrideWith((_) => _dio(succeed: false)),
    ]);
    addTearDown(container.dispose);

    await expectLater(
      container.read(authRepositoryProvider).login('u-1'),
      throwsA(isA<ApiError>()),
    );
  });
}
