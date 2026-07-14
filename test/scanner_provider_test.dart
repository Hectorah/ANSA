import 'package:flutter_test/flutter_test.dart';
import 'package:klk_entradas/features/scanner/data/scanner_repository.dart';
import 'package:klk_entradas/features/scanner/presentation/scanner_provider.dart';
import 'package:klk_entradas/features/ticket/domain/ticket_model.dart';

class MockScannerRepository implements ScannerRepository {
  TicketResult? mockResult;
  Object? mockError;

  @override
  Future<TicketResult> validateQR(String rawData) async {
    if (mockError != null) {
      throw mockError!;
    }
    if (mockResult != null) {
      return mockResult!;
    }
    throw Exception('No mock result configured');
  }
}

void main() {
  group('ScannerNotifier State Behavior Tests', () {
    late MockScannerRepository mockRepository;
    late ScannerNotifier notifier;

    setUp(() {
      mockRepository = MockScannerRepository();
      notifier = ScannerNotifier(mockRepository);
    });

    test('Debe cambiar a estado SUCCESS cuando el QR no ha sido escaneado aún', () async {
      // JSON simulado donde escaneado es false
      final jsonNoEscaneado = {
        "Participante": {
          "Id": 90,
          "Nombre": "Danny Jardim",
          "Cargo": "Desarrollador",
          "CorreoElectronico": "d.jardim@klk.com.ve",
          "Telefono": "04243567729",
          "escaneado": false // Aún no escaneado
        },
        "Empresa": {
          "Rif": "V-28249780",
          "RazonSocial": "Danny Jardim"
        },
        "Entrada": {
          "Nombre": "Asistente a las Conferencias",
          "Color": "#F7FF82"
        }
      };

      mockRepository.mockResult = TicketResult.fromJson(jsonNoEscaneado);

      // Verificación de estado inicial
      expect(notifier.state.status, ScannerStatus.initial);

      // Procesar código
      final future = notifier.processCode("90|123");
      
      // Debe pasar transicionalmente por scanning
      expect(notifier.state.status, ScannerStatus.scanning);

      await future;

      // Debe terminar en success
      expect(notifier.state.status, ScannerStatus.success);
      expect(notifier.state.result, isNotNull);
      expect(notifier.state.result!.escaneado, isFalse);
      expect(notifier.state.result!.participantes.first.nombre, "Danny Jardim");
      expect(notifier.state.result!.entradas.first.nombre, "Asistente a las Conferencias");
    });

    test('Debe cambiar a estado ALREADY_SCANNED cuando el QR ya fue procesado', () async {
      // JSON simulado donde escaneado es true
      final jsonYaEscaneado = {
        "Participante": {
          "Id": 90,
          "Nombre": "Danny Jardim",
          "Cargo": "Desarrollador",
          "CorreoElectronico": "d.jardim@klk.com.ve",
          "Telefono": "04243567729",
          "escaneado": true // Ya escaneado
        },
        "Empresa": {
          "Rif": "V-28249780",
          "RazonSocial": "Danny Jardim"
        },
        "Entrada": {
          "Nombre": "Asistente a las Conferencias",
          "Color": "#F7FF82"
        }
      };

      mockRepository.mockResult = TicketResult.fromJson(jsonYaEscaneado);

      // Procesar código
      await notifier.processCode("90|123");

      // Debe terminar en alreadyScanned para activar el diálogo de seguridad en la UI
      expect(notifier.state.status, ScannerStatus.alreadyScanned);
      expect(notifier.state.result, isNotNull);
      expect(notifier.state.result!.escaneado, isTrue);
    });

    test('Debe cambiar a estado ERROR cuando falla la validación en la API', () async {
      mockRepository.mockError = Exception('Código QR inválido o no encontrado');

      // Procesar código
      await notifier.processCode("QR_INVALIDO");

      // Debe terminar en error
      expect(notifier.state.status, ScannerStatus.error);
      expect(notifier.state.errorMessage, 'Código QR inválido o no encontrado');
    });
  });
}
