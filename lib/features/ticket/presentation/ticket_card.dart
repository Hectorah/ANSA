import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/tts_service.dart';
import '../domain/ticket_model.dart';

// Secuencia:
//  1. _Phase.success  → lottie success a pantalla completa (se reproduce 1 vez)
//  2. _Phase.info     → info del ticket + overlay de confeti (1 vez)

enum _Phase { success, info }

class TicketCard extends StatefulWidget {
  final TicketResult result;
  final VoidCallback onDismiss;

  const TicketCard({
    super.key,
    required this.result,
    required this.onDismiss,
  });

  @override
  State<TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends State<TicketCard> {
  _Phase _phase = _Phase.success;
  Timer? _autoDismissTimer;

  void _advanceToInfo() {
    if (_phase == _Phase.success && mounted) {
      setState(() => _phase = _Phase.info);
      // Hablar mensaje de bienvenida cuando se muestra la info del ticket
      _speakWelcomeMessage();
      
      // Iniciar temporizador de 3 minutos para cierre automático
      _startAutoDismissTimer();
    }
  }
  
  void _startAutoDismissTimer() {
    // Cancelar timer existente si hay uno
    _autoDismissTimer?.cancel();
    
    // Crear nuevo timer de 3 minutos (180 segundos)
    _autoDismissTimer = Timer(const Duration(minutes: 3), () {
      if (mounted) {
        // Cerrar automáticamente después de 3 minutos
        widget.onDismiss();
      }
    });
  }
  
  void _cancelAutoDismissTimer() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
  }

  void _speakWelcomeMessage() {
    final participantNames = widget.result.participantes
        .map((p) => p.nombre)
        .where((name) => name.isNotEmpty)
        .toList();
    
    // Usar la razón social de la empresa si está disponible
    final razonSocial = widget.result.empresa?.razonSocial ?? '';
    
    TTSService.speakWelcomeMessage(participantNames, razonSocial: razonSocial);
  }
  
  @override
  void dispose() {
    // Cancelar timer al desmontar el widget
    _cancelAutoDismissTimer();
    super.dispose();
  }
  
  void _handleManualDismiss() {
    // Cancelar timer cuando el usuario cierra manualmente
    _cancelAutoDismissTimer();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    // Siempre usar azul para el borde del card
    final mainColor = Color(0xFF1976D2); // Azul

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: _phase == _Phase.success
          ? _SuccessPhase(key: const ValueKey('success'), onComplete: _advanceToInfo)
          : _InfoPhase(
              key: const ValueKey('info'),
              result: widget.result,
              mainColor: mainColor,
              onDismiss: _handleManualDismiss,
            ),
    );
  }
}

// ─── Phase 1: Success Lottie ──────────────────────────────────────────────────
class _SuccessPhase extends StatelessWidget {
  final VoidCallback onComplete;
  const _SuccessPhase({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.6.sh,
      constraints: BoxConstraints(maxHeight: 500.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(32.r),
      ),
      child: Center(
        child: Lottie.asset(
          'assets/animations/lottie/success.json',
          width: 280.r,
          height: 280.r,
          repeat: false,
          onLoaded: (composition) {
            // Avanzar a info cuando termine la animación
            Future.delayed(composition.duration, onComplete);
          },
        ),
      ),
    );
  }
}

// ─── Phase 2: Info + Confeti overlay ─────────────────────────────────────────
class _InfoPhase extends StatefulWidget {
  final TicketResult result;
  final Color mainColor;
  final VoidCallback onDismiss;

  const _InfoPhase({
    super.key,
    required this.result,
    required this.mainColor,
    required this.onDismiss,
  });

  @override
  State<_InfoPhase> createState() => _InfoPhaseState();
}

class _InfoPhaseState extends State<_InfoPhase> {
  int _confettiPlayCount = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Ticket info card ──
        Container(
          constraints: BoxConstraints(
            maxHeight: 0.85.sh,
            minHeight: 200.h,
            minWidth: MediaQuery.of(context).size.width * 0.9,
            maxWidth: 800.w,
          ),
          padding: EdgeInsets.all(28.w), // Padding aumentado
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(32.r),
            border: Border.all(color: widget.mainColor.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: widget.mainColor.withValues(alpha: 0.12),
                blurRadius: 40,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 12.h), // Espacio aumentado
              _buildQuantityBadge(),
              SizedBox(height: 24.h), // Espacio aumentado
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 8.w), // Padding horizontal aumentado
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('TIPOS DE ENTRADA'),
                      _buildEntranceCards(),
                      SizedBox(height: 24.h), // Espacio aumentado
                      _sectionTitle('PARTICIPANTES CONFIRMADOS'),
                      ...widget.result.participantes.map((p) => _participantItem(p)),
                      SizedBox(height: 24.h), // Espacio aumentado
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Confeti overlay (2 repeticiones, sin fondo) ──
        Positioned.fill(
          child: IgnorePointer(
            child: Lottie.asset(
              'assets/animations/lottie/Confetti.json',
              key: ValueKey(_confettiPlayCount),
              fit: BoxFit.cover,
              repeat: false,
              onLoaded: (composition) {
                // Reproducir 2 veces
                if (_confettiPlayCount < 1) {
                  Future.delayed(composition.duration, () {
                    if (mounted) {
                      setState(() => _confettiPlayCount++);
                    }
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuantityBadge() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600; // Para pantallas de kiosko grandes
    
    // Obtener la razón social de la empresa
    final razonSocial = widget.result.empresa?.razonSocial ?? '';
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: isLargeScreen ? 24.h : 20.h, // Padding aumentado para pantallas grandes
        horizontal: isLargeScreen ? 32.w : 0, // Padding horizontal para pantallas grandes
      ),
      decoration: BoxDecoration(
        color: widget.mainColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(isLargeScreen ? 24.r : 20.r), // Radio aumentado
        border: Border.all(color: widget.mainColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          // Razón Social resaltada arriba
          if (razonSocial.isNotEmpty) ...[
            Text(
              razonSocial.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isLargeScreen ? 22.sp : 18.sp, // Fuente grande y resaltada
                fontWeight: FontWeight.w900,
                color: widget.mainColor,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: isLargeScreen ? 12.h : 8.h), // Espacio entre razón social y entradas
          ],
          Text(
            'ENTRADAS TOTALES',
            style: TextStyle(
              fontSize: isLargeScreen ? 14.sp : 12.sp, // Fuente aumentada
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: const Color(0xFF1976D2), // Azul en vez del color principal
            ),
          ),
          Text(
            widget.result.totalQuantity.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: isLargeScreen ? 96.sp : 80.sp, // Número mucho más grande
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              height: 1.0,
            ),
          ),
          Text(
            'ACCESO AUTORIZADO',
            style: TextStyle(
              fontSize: isLargeScreen ? 14.sp : 13.sp, // Fuente aumentada
              fontWeight: FontWeight.w700,
              color: AppColors.success,
              letterSpacing: 1.2, // Espaciado aumentado
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;
    
    return Padding(
      padding: EdgeInsets.only(bottom: isLargeScreen ? 14.h : 12.h),
      child: Text(
        title,
        style: TextStyle(
          fontSize: isLargeScreen ? 12.sp : 11.sp, // Fuente aumentada
          fontWeight: FontWeight.bold,
          color: AppColors.textMuted,
          letterSpacing: 1.8, // Espaciado aumentado
        ),
      ),
    );
  }

  Widget _buildEntranceCards() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;
    final entrances = widget.result.entradas;
    
    if (entrances.isEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        child: Center(
          child: Text(
            'No hay entradas disponibles',
            style: TextStyle(
              fontSize: isLargeScreen ? 14.sp : 12.sp,
              color: AppColors.textMuted,
            ),
          ),
        ),
      );
    }
    
    // Limitar a máximo 3 mini cards
    final displayEntrances = entrances.length > 3 ? entrances.sublist(0, 3) : entrances;
    
    return Container(
      margin: EdgeInsets.only(bottom: isLargeScreen ? 20.h : 16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: displayEntrances.map((entrance) => _buildMiniCard(entrance)).toList(),
      ),
    );
  }
  
  Widget _buildMiniCard(Entrance entrance) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;
    final nombreLower = entrance.nombre.toLowerCase();
    final isVIP = nombreLower.contains('vip');
    final isPoniente = nombreLower.contains('poniente');
    
    // Determinar icono según tipo de entrada
    final IconData icon;
    if (isVIP) {
      icon = Icons.star; // VIP: estrella
    } else if (isPoniente) {
      icon = Icons.wb_sunny; // Poniente: sol
    } else {
      icon = Icons.confirmation_number; // Regular: ticket
    }
    
    return Container(
      width: isLargeScreen ? 80.w : 70.w,
      padding: EdgeInsets.symmetric(
        vertical: isLargeScreen ? 16.h : 12.h,
        horizontal: isLargeScreen ? 8.w : 6.w,
      ),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(isLargeScreen ? 16.r : 12.r),
        border: Border.all(
          color: entrance.parsedColor.withValues(alpha: 0.3),
          width: isLargeScreen ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: entrance.parsedColor.withValues(alpha: 0.1),
            blurRadius: isLargeScreen ? 8 : 6,
            offset: Offset(0, isLargeScreen ? 3 : 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Título (tipo de entrada)
          Text(
            entrance.nombre.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isLargeScreen ? 9.sp : 8.sp,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: 0.4,
            ),
          ),
          SizedBox(height: isLargeScreen ? 8.h : 6.h),
          
          // Figura geométrica centrada según tipo
          Container(
            width: isLargeScreen ? 36.r : 32.r,
            height: isLargeScreen ? 36.r : 32.r,
            decoration: BoxDecoration(
              color: entrance.parsedColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                icon,
                size: isLargeScreen ? 24.r : 20.r,
                color: entrance.parsedColor,
              ),
            ),
          ),
          SizedBox(height: isLargeScreen ? 8.h : 6.h),
          
          // Cantidad de entradas
          Text(
            'x${entrance.cantidad}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isLargeScreen ? 20.sp : 18.sp,
              fontWeight: FontWeight.w900,
              color: entrance.parsedColor,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _participantItem(Participant participant) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;
    
    return Container(
      margin: EdgeInsets.only(bottom: isLargeScreen ? 12.h : 10.h),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: widget.mainColor.withValues(alpha: 0.35), 
            width: isLargeScreen ? 3 : 2, // Borde más ancho
          ),
        ),
      ),
      child: ListTile(
        dense: !isLargeScreen, // Menos denso en pantallas grandes
        contentPadding: EdgeInsets.symmetric(
          horizontal: isLargeScreen ? 20.w : 16.w,
          vertical: isLargeScreen ? 8.h : 4.h,
        ),
        title: Text(
          participant.nombre.toUpperCase(), // Mostrar en mayúscula
          style: TextStyle(
            fontSize: isLargeScreen ? 16.sp : 14.sp, // Fuente aumentada
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${participant.cargo} • ${participant.telefono}',
          style: TextStyle(
            fontSize: isLargeScreen ? 13.sp : 12.sp, // Fuente aumentada
          ),
        ),
        trailing: Icon(
          Icons.person_outline, 
          size: isLargeScreen ? 22 : 20, // Icono aumentado
          color: widget.mainColor.withValues(alpha: 0.5)
        ),
      ),
    );
  }
}
