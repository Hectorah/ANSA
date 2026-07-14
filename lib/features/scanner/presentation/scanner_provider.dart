import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/injection.dart';
import '../data/scanner_repository.dart';
import '../../ticket/domain/ticket_model.dart';

enum ScannerStatus { initial, scanning, success, error, alreadyScanned }

class ScannerState {
  final ScannerStatus status;
  final TicketResult? result;
  final String? errorMessage;

  ScannerState({
    this.status = ScannerStatus.initial,
    this.result,
    this.errorMessage,
  });

  ScannerState copyWith({
    ScannerStatus? status,
    TicketResult? result,
    String? errorMessage,
  }) {
    return ScannerState(
      status: status ?? this.status,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ScannerNotifier extends StateNotifier<ScannerState> {
  final ScannerRepository _repository;

  ScannerNotifier(this._repository) : super(ScannerState());

  void reset() {
    state = ScannerState();
  }

  /// Autoriza el acceso a un QR ya escaneado (tras validar clave admin).
  /// Cambia el estado a [ScannerStatus.success] para que el listener
  /// en la UI muestre el ticket normalmente.
  void authorizeAccess() {
    if (state.result != null) {
      state = state.copyWith(status: ScannerStatus.success);
    }
  }

  Future<void> processCode(String code) async {
    if (state.status == ScannerStatus.scanning) return;

    state = state.copyWith(status: ScannerStatus.scanning, errorMessage: null);

    try {
      final result = await _repository.validateQR(code);
      
      if (result.escaneado) {
        state = state.copyWith(status: ScannerStatus.alreadyScanned, result: result);
      } else {
        state = state.copyWith(status: ScannerStatus.success, result: result);
      }
    } catch (e) {
      state = state.copyWith(
        status: ScannerStatus.error,
        errorMessage: e.toString().replaceAll("Exception: ", ""),
      );
    }
  }
}

final scannerProvider = StateNotifierProvider<ScannerNotifier, ScannerState>((ref) {
  return ScannerNotifier(getIt<ScannerRepository>());
});
