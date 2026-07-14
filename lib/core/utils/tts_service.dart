import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/material.dart';

class TTSService {
  static final FlutterTts _tts = FlutterTts();
  static bool _isInitialized = false;

  static Future<void> _initialize() async {
    if (_isInitialized) return;
    
    try {
      // Intentar configurar el idioma, pero continuar si falla
      await _tts.setLanguage("es-ES");
    } catch (e) {
      debugPrint('Error configurando idioma TTS: $e');
      // Continuar sin configurar idioma específico
    }
    
    try {
      await _tts.setSpeechRate(0.5); // Velocidad moderada
    } catch (e) {
      debugPrint('Error configurando velocidad TTS: $e');
    }
    
    try {
      await _tts.setVolume(1.0); // Volumen máximo
    } catch (e) {
      debugPrint('Error configurando volumen TTS: $e');
    }
    
    try {
      await _tts.setPitch(1.0); // Tono normal
    } catch (e) {
      debugPrint('Error configurando tono TTS: $e');
    }
    
    _isInitialized = true;
  }

  static Future<void> speakWelcomeMessage(List<String> participantNames, {String razonSocial = ''}) async {
    try {
      await _initialize();
      
      String message;
      
      // Usar la razón social para el saludo si está disponible
      if (razonSocial.isNotEmpty) {
        message = "Hola $razonSocial, bienvenidos";
      } else if (participantNames.isEmpty) {
        message = "Hola, bienvenido estimado";
      } else if (participantNames.length == 1) {
        message = "Hola ${participantNames.first}, bienvenido";
      } else {
        final names = participantNames.join(", ");
        message = "Hola $names, bienvenidos";
      }
      
      await _tts.speak(message);
    } catch (e) {
      debugPrint('Error hablando mensaje de bienvenida: $e');
    }
  }

  static Future<void> speakErrorMessage() async {
    try {
      await _initialize();
      await _tts.speak("Error, verifique e intente de nuevo");
    } catch (e) {
      debugPrint('Error hablando mensaje de error: $e');
    }
  }

  static Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('Error deteniendo TTS: $e');
    }
  }
}