import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import '../../features/scanner/data/scanner_repository.dart';

final getIt = GetIt.instance;

Future<void> setupInjection() async {
  // Network
  getIt.registerLazySingleton<Dio>(() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
        logPrint: (obj) => debugPrint('[DIO] $obj'),
      ),
    );

    return dio;
  });

  // Features
  getIt.registerLazySingleton<ScannerRepository>(
    () => ScannerRepositoryImpl(getIt<Dio>()),
  );
}
