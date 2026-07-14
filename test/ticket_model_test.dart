import 'package:flutter_test/flutter_test.dart';
import 'package:klk_entradas/features/ticket/domain/ticket_model.dart';

void main() {
  group('TicketResult Deserialization Tests', () {
    test('Debe deserializar correctamente el formato singular (nuevo)', () {
      final json = {
        "Participante": {
          "Id": 90,
          "Nombre": "Danny Jardim",
          "Cargo": "Desarrollador",
          "CorreoElectronico": "d.jardim@klk.com.ve",
          "Telefono": "04243567729",
          "escaneado": true
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

      final ticket = TicketResult.fromJson(json);

      // Verificaciones de Empresa
      expect(ticket.empresa, isNotNull);
      expect(ticket.empresa!.rif, "V-28249780");
      expect(ticket.empresa!.razonSocial, "Danny Jardim");

      // Verificaciones de Participantes
      expect(ticket.participantes, hasLength(1));
      expect(ticket.participantes.first.nombre, "Danny Jardim");
      expect(ticket.participantes.first.cargo, "Desarrollador");
      expect(ticket.participantes.first.escaneado, isTrue);

      // Verificaciones de Entrada
      expect(ticket.entradas, hasLength(1));
      expect(ticket.entradas.first.nombre, "Asistente a las Conferencias");
      expect(ticket.entradas.first.color, "#F7FF82");
      expect(ticket.entradas.first.cantidad, 1); // Por defecto
      expect(ticket.totalQuantity, 1);

      // Verificación de estado Escaneado
      expect(ticket.escaneado, isTrue);
    });

    test('Debe deserializar correctamente el formato plural (antiguo)', () {
      final json = {
        "Participantes": [
          {
            "Nombre": "Danny Jardim",
            "Cargo": "Desarrollador",
            "CorreoElectronico": "d.jardim@klk.com.ve",
            "Telefono": "04243567729",
            "escaneado": false
          }
        ],
        "Empresa": {
          "Rif": "V-28249780",
          "RazonSocial": "Danny Jardim",
          "escaneado": true
        },
        "Entradas": [
          {
            "Nombre": "Asistente a las Conferencias",
            "Color": "#F7FF82",
            "Cantidad": 2
          }
        ],
        "escaneado": false
      };

      final ticket = TicketResult.fromJson(json);

      expect(ticket.participantes, hasLength(1));
      expect(ticket.participantes.first.nombre, "Danny Jardim");
      
      expect(ticket.entradas, hasLength(1));
      expect(ticket.entradas.first.cantidad, 2);
      expect(ticket.totalQuantity, 2);

      // Debería ser true porque la empresa tiene escaneado en true
      expect(ticket.escaneado, isTrue);
    });
  });
}
