import 'package:dio/dio.dart';
import '../../ticket/domain/ticket_model.dart';
import 'package:flutter/material.dart';

abstract class ScannerRepository {
  Future<TicketResult> validateQR(String rawData);
}

class ScannerRepositoryImpl implements ScannerRepository {
  final Dio _dio;

  ScannerRepositoryImpl(this._dio);

  static const _baseUrl = 'https://ansa2026.duckdns.org/consultarentradas';

  @override
  Future<TicketResult> validateQR(String rawData) async {
    debugPrint('[SCANNER] Validando código: $rawData');

    final Map<String, dynamic> queryParams = {};
    final cleanData = rawData.trim();

    if (RegExp(r'^\d{10}$').hasMatch(cleanData)) {
      queryParams['QrLegacy'] = cleanData;
      debugPrint('[SCANNER] Formato QR Legacy detectado -> QrLegacy: $cleanData');
    } else if (cleanData.contains('|')) {
      final parts = cleanData.split('|');
      final idParticipante = parts[0].trim();
      final idTransaccion = parts[1].trim();

      queryParams['IdTransaccion'] = idTransaccion;
      queryParams['IdParticipante'] = idParticipante;

      debugPrint('[SCANNER] Formato Nuevo detectado -> IdParticipante: $idParticipante, IdTransaccion: $idTransaccion');
    } else {
      queryParams['IdParticipante'] = cleanData;

      debugPrint('[SCANNER] Formato Antiguo detectado -> IdParticipante: $cleanData');
    }

    debugPrint('[SCANNER] URL: $_baseUrl con parámetros: $queryParams');

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _baseUrl,
        queryParameters: queryParams,
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          validateStatus: (status) => status != null && status < 500,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );

      debugPrint('[SCANNER] Response status: ${response.statusCode}');
      debugPrint('[SCANNER] Response data: ${response.data}');

      final data = response.data;

      if (data == null) {
        throw Exception('Respuesta vacía del servidor');
      }

      if (data['success'] == true) {
        final result = data['result'];
        if (result == null) {
          throw Exception('Datos de resultado no encontrados');
        }
        return TicketResult.fromJson(result as Map<String, dynamic>);
      } else {
        final message = data['message'] ?? 'Código QR inválido o no encontrado';
        throw Exception(message);
      }
    } on DioException catch (e) {
      debugPrint('[SCANNER] DioException type: ${e.type}');
      debugPrint('[SCANNER] DioException message: ${e.message}');
      debugPrint('[SCANNER] DioException response: ${e.response?.data}');

      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          throw Exception('Tiempo de espera agotado. Verifique su conexión a internet.');
        case DioExceptionType.connectionError:
          throw Exception('Sin conexión al servidor. Verifique que el dispositivo tenga acceso a internet.');
        case DioExceptionType.badResponse:
          final status = e.response?.statusCode;
          final message = e.response?.data?['message'] ?? 'Error del servidor';
          throw Exception('Error del servidor ($status): $message');
        case DioExceptionType.badCertificate:
          throw Exception('Error de certificado SSL. Contacte al administrador.');
        case DioExceptionType.cancel:
          throw Exception('Solicitud cancelada.');
        default:
          throw Exception('Error de red: ${e.message ?? "Desconocido"}');
      }
    } catch (e) {
      debugPrint('[SCANNER] Unexpected error: $e');
      if (e is Exception) rethrow;
      throw Exception('Error inesperado: $e');
    }
  }
}
