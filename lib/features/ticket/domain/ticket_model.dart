import 'dart:ui';

class TicketResult {
  final Empresa? empresa;
  final List<Entrance> entradas;
  final List<Participant> participantes;
  final bool escaneado;

  TicketResult({
    this.empresa,
    required this.entradas,
    required this.participantes,
    this.escaneado = false,
  });

  int get totalQuantity => entradas.fold(0, (sum, e) => sum + e.cantidad);

  factory TicketResult.fromJson(Map<String, dynamic> json) {
    // Parsear participantes de forma flexible (singular o plural)
    List<Participant> parsedParticipantes = [];
    if (json['Participantes'] != null && json['Participantes'] is List) {
      parsedParticipantes = (json['Participantes'] as List)
          .map((e) => Participant.fromJson(e))
          .toList();
    } else if (json['Participante'] != null && json['Participante'] is Map<String, dynamic>) {
      parsedParticipantes = [Participant.fromJson(json['Participante'])];
    }

    // Parsear entradas de forma flexible (singular o plural)
    List<Entrance> parsedEntradas = [];
    if (json['Entradas'] != null && json['Entradas'] is List) {
      parsedEntradas = (json['Entradas'] as List)
          .map((e) => Entrance.fromJson(e))
          .toList();
    } else if (json['Entrada'] != null && json['Entrada'] is Map<String, dynamic>) {
      parsedEntradas = [Entrance.fromJson(json['Entrada'])];
    }

    // Determinar si el ticket ya ha sido escaneado buscando en múltiples lugares
    bool isEscaneado = _parseBool(json['escaneado'] ?? json['Escaneado']);
    
    if (!isEscaneado) {
      // Buscar en participante singular
      if (json['Participante'] != null && json['Participante'] is Map<String, dynamic>) {
        isEscaneado = _parseBool(json['Participante']['escaneado'] ?? json['Participante']['Escaneado']);
      }
    }
    
    if (!isEscaneado) {
      // Buscar en cualquier participante de la lista
      isEscaneado = parsedParticipantes.any((p) => p.escaneado);
    }
    
    if (!isEscaneado && json['Empresa'] != null) {
      // Buscar en la empresa
      isEscaneado = _parseBool(json['Empresa']['escaneado'] ?? json['Empresa']['Escaneado']);
    }

    return TicketResult(
      empresa: json['Empresa'] != null 
          ? Empresa.fromJson(json['Empresa']) 
          : null,
      entradas: parsedEntradas,
      participantes: parsedParticipantes,
      escaneado: isEscaneado,
    );
  }

  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      final normalized = value.toLowerCase().trim();
      return normalized == 'true' || normalized == '1';
    }
    return false;
  }
}

class Empresa {
  final String rif;
  final String razonSocial;
  final bool escaneado;

  Empresa({
    required this.rif,
    required this.razonSocial,
    this.escaneado = false,
  });

  factory Empresa.fromJson(Map<String, dynamic> json) {
    return Empresa(
      rif: json['Rif'] ?? '',
      razonSocial: json['RazonSocial'] ?? '',
      escaneado: TicketResult._parseBool(json['escaneado'] ?? json['Escaneado']),
    );
  }
}

class Entrance {
  final int cantidad;
  final String nombre;
  final String color;

  Entrance({
    required this.cantidad,
    required this.nombre,
    required this.color,
  });

  factory Entrance.fromJson(Map<String, dynamic> json) {
    return Entrance(
      cantidad: json['Cantidad'] ?? 1,
      nombre: json['Nombre'] ?? '',
      color: json['Color'] ?? '#6366F1',
    );
  }

  Color get parsedColor {
    try {
      final hex = color.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF6366F1);
    }
  }
}

class Participant {
  final String nombre;
  final String cargo;
  final String correoElectronico;
  final String telefono;
  final bool escaneado;

  Participant({
    required this.nombre,
    required this.cargo,
    required this.correoElectronico,
    required this.telefono,
    this.escaneado = false,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      nombre: json['Nombre'] ?? '',
      cargo: json['Cargo'] ?? '',
      correoElectronico: json['CorreoElectronico'] ?? '',
      telefono: json['Telefono'] ?? '',
      escaneado: TicketResult._parseBool(json['escaneado'] ?? json['Escaneado']),
    );
  }
}
