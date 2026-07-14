import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/tts_service.dart';
import 'scanner_provider.dart';
import '../../ticket/presentation/ticket_card.dart';
import '../../../core/utils/text_formatters.dart';

// ─── Kiosk ANSA color paleta     ────────────────────────────────────────────────────
const _kBluePrimary = Color(0xFF24306E);
const _kBlueMid = Color(0xFF010A23);
const _kGreen = Color(0xFF2E7D32);
const _kWhite = Colors.white;
const _kBgLight = Color(0xFFEFF0F4);
// ─── Clave de administrador (cableada) ──────────────────────────────────────
// Modifique este valor manualmente para establecer la clave de autorización.
// Acepta entrada por teclado, QR o código de barras.
const _kAdminPassword = 'ADMIN2024';
// ─── Carousel images ─────────────────────────────────────────────────────────
const _carouselImages = [
  'assets/carrousel/KLKPOS.jpg',
  'assets/carrousel/KLKSISTEMAS.jpg',
  'assets/carrousel/OSM.jpg',
  'assets/carrousel/RESTAURANTE.jpg',
  'assets/carrousel/WMS.jpg',
];

// ─── Logo Item Class (para carrusel de texto/imágenes) ──────────────────────
class _LogoItem {
  final String value;
  final bool isImage;
  _LogoItem._(this.value, this.isImage);

  factory _LogoItem.text(String text) => _LogoItem._(text, false);
  factory _LogoItem.image(String imagePath) => _LogoItem._(imagePath, true);
}

// ─── Screen ──────────────────────────────────────────────────────────────────
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with TickerProviderStateMixin {
  // Controllers
  final _hiddenScannerController = TextEditingController();
  final _scannerFocusNode = FocusNode();
  final _manualInputController = TextEditingController();
  late PageController _pageController;
  late PageController _logoCarouselController;

  // Carousel state
  Timer? _carouselTimer;
  Timer? _logoCarouselTimer;

  // Pulse animation para botón comprar ticket
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  // Buffer para capturar input del lector físico
  String _inputBuffer = '';
  DateTime _lastInputTime = DateTime.now();
  // Flag para evitar múltiples diálogos simultáneos
  bool _isShowingDialog = false;
  String _scanBuffer = '';
  Timer? _scanBufferTimer;

  @override
  void initState() {
    super.initState();

    // Configurar modo inmersivo (Immersive Mode) al iniciar
    _setImmersiveMode();
    // Escuchar cambios de estado de la aplicación
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver(this));
    // Inicializar PageController con página inicial en el medio para efecto infinito
    _pageController = PageController(
      initialPage: 1000, // Empezar en el medio para scroll infinito
    );
    // Carrusel de logos
    _logoCarouselController = PageController(
      viewportFraction: 0.25,
      initialPage: 0,
    );
    // Pulse animation para botón comprar ticket
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startCarousel();
    _startLogoCarousel();
  }

  // Configurar modo inmersivo (Immersive Mode)
  void _setImmersiveMode() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Restaurar modo inmersivo cuando la aplicación recupera el foco
  void _restoreImmersiveMode() {
    if (mounted) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _setImmersiveMode();
        }
      });
    }
  }

  void _startCarousel() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    });
  }

  void _startLogoCarousel() {
    _logoCarouselTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      // Mucho más rápido: 10ms vs 20ms
      if (!mounted || !_logoCarouselController.hasClients) return;

      // Scroll continuo más rápido
      final currentOffset = _logoCarouselController.offset;
      final maxScroll = _logoCarouselController.position.maxScrollExtent;

      if (maxScroll.isInfinite || maxScroll == 0) return;

      // Cuando llega al final, vuelve al inicio sin animación
      if (currentOffset >= maxScroll - 100) {
        _logoCarouselController.jumpTo(0);
      } else {
        _logoCarouselController.jumpTo(
          currentOffset + 4.0,
        ); // Mucho más rápido: 4.0 vs 2.0
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _logoCarouselTimer?.cancel();
    _scanBufferTimer?.cancel();
    _pulseController.dispose();
    _pageController.dispose();
    _logoCarouselController.dispose();
    _scannerFocusNode.dispose();
    _hiddenScannerController.dispose();
    _manualInputController.dispose();
    // Eliminar observer del lifecycle
    WidgetsBinding.instance.removeObserver(_AppLifecycleObserver(this));

    // Restaurar configuración normal al salir
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations([]);

    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final char = event.character;
      if (char != null && char.isNotEmpty) {
        _scanBuffer += char;
        // Resetear timer - el lector físico envía caracteres rápidamente
        _scanBufferTimer?.cancel();
        _scanBufferTimer = Timer(const Duration(milliseconds: 100), () {
          if (_scanBuffer.isNotEmpty) {
            _onScannerInput(_scanBuffer);
            _scanBuffer = '';
          }
        });
      }
    }
  }

  void _onScannerInput(String code) {
    final trimmed = code.trim();
    if (trimmed.isNotEmpty) {
      ref.read(scannerProvider.notifier).processCode(trimmed);
      _hiddenScannerController.clear();
      _scanBuffer = '';
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final scannerState = ref.watch(scannerProvider);
    ref.listen<ScannerState>(scannerProvider, (previous, next) {
      if (!mounted) return;

      // Si el estado no cambió en lo relevante para diálogos, ignorar
      if (previous?.status == next.status) return;

      if (next.status == ScannerStatus.success && next.result != null) {
        if (_isShowingDialog) {
          debugPrint(
            '[SCANNER] Ignorando success porque ya hay un diálogo activo',
          );
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isShowingDialog) _showTicketDialog(next.result!);
        });
      } else if (next.status == ScannerStatus.error) {
        if (_isShowingDialog) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isShowingDialog)
            _showErrorDialog(next.errorMessage ?? 'Error desconocido');
        });
      } else if (next.status == ScannerStatus.alreadyScanned) {
        if (_isShowingDialog) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isShowingDialog) _showAlreadyScannedDialog();
        });
      }
    });

    return KeyboardListener(
      focusNode: _scannerFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: () => _scannerFocusNode.requestFocus(),
        child: Scaffold(
          backgroundColor: _kBgLight,
          resizeToAvoidBottomInset:
              false, // Evitar que el teclado cause overflow
          body: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    _Header(),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: Column(
                          children: [
                            SizedBox(height: 16.h),
                            _buildCarouselSection(),
                            SizedBox(height: 16.h),
                            _buildCombinedSection(),
                          ],
                        ),
                      ),
                    ),
                    // Carrusel de texto pegado al final
                    _buildLogoCarousel(),
                  ],
                ),
              ),

              if (scannerState.status == ScannerStatus.scanning)
                _buildLoadingOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Carousel ─────────────────────────────────────────────────────────────
  Widget _buildCarouselSection() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.r),
      child: SizedBox(
        height: 260.h,
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: (_) {},
          itemBuilder: (_, i) {
            final index = i % _carouselImages.length;
            return Image.asset(
              _carouselImages[index],
              width: double.infinity,
              height: 260.h,
              fit: BoxFit.cover,
            );
          },
        ),
      ),
    );
  }

  // ─── Logo Carousel ────────────────────────────────────────────────────────
  Widget _buildLogoCarousel() {
    // Lista de logos de marcas con soporte para texto e imágenes
    final logoItems = [
      _LogoItem.image('assets/logo/ansa.png'),
      _LogoItem.text('KLK'),
      _LogoItem.image('assets/logo/solux.png'),
      _LogoItem.image('assets/logo/klk.png'),
      _LogoItem.text('Sistemas'),
      _LogoItem.text('POS'),
      _LogoItem.image('assets/logo/solux.png'),
      _LogoItem.text('KLKPOS'),
      _LogoItem.image('assets/logo/ansa.png'),
      _LogoItem.image('assets/logo/klk.png'),
    ];
    // Duplicar la lista para efecto infinito
    final infiniteItems = [...logoItems, ...logoItems, ...logoItems];
    return Container(
      height: 60.h, // Altura aumentada (de 40.h a 60.h)
      color: _kWhite,
      margin: EdgeInsets.only(bottom: 2.h), // Margen inferior reducido
      child: ListView.builder(
        controller: _logoCarouselController,
        scrollDirection: Axis.horizontal,
        itemCount: infiniteItems.length,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (_, i) {
          final item = infiniteItems[i];
          return Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            child: Center(
              child: item.isImage
                  ? Image.asset(
                      item.value,
                      width: 80.r, // Aumentado de 60.r
                      height: 40.r, // Aumentado de 30.r
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Text(
                        'SOLUX',
                        style: TextStyle(
                          fontSize: 18.sp, // Aumentado de 16.sp
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                          letterSpacing: 0.6, // Aumentado
                        ),
                      ),
                    )
                  : Text(
                      item.value,
                      style: TextStyle(
                        fontSize: 18.sp, // Aumentado de 16.sp
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                        letterSpacing: 0.6, // Aumentado
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  // ─── Combined Section (QR + Buttons + Arrow) ──────────────────────────────
  Widget _buildCombinedSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _kBluePrimary,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: _kBluePrimary.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Columna izquierda: QR + Lottie + Arrow_blue (reducido)
          Expanded(
            flex: isSmallScreen
                ? 4
                : 3, // Reducido para dar más espacio a botones
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Stack con QR abajo y Lottie scanner encima (reducido)
                SizedBox(
                  height: isSmallScreen ? 110.h : 130.h, // Altura reducida
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // QR Code en el fondo (reducido)
                      Positioned(
                        bottom: 6.h,
                        child: Container(
                          padding: EdgeInsets.all(isSmallScreen ? 4.r : 6.r),
                          decoration: BoxDecoration(
                            color: _kWhite,
                            borderRadius: BorderRadius.circular(
                              isSmallScreen ? 8.r : 10.r,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/qr/klk_qr.png',
                            width: isSmallScreen ? 60.r : 70.r, // QR reducido
                            height: isSmallScreen ? 60.r : 70.r, // QR reducido
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  width: isSmallScreen ? 60.r : 70.r,
                                  height: isSmallScreen ? 60.r : 70.r,
                                  color: _kWhite,
                                  child: Center(
                                    child: Icon(
                                      Icons.qr_code_2,
                                      size: isSmallScreen
                                          ? 48.r
                                          : 56.r, // Icono reducido
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                          ),
                        ),
                      ),
                      // Lottie scanner encima del QR (reducido)
                      Positioned.fill(
                        child: Lottie.asset(
                          'assets/animations/lottie/scanner.json',
                          width: isSmallScreen
                              ? 110.r
                              : 130.r, // Lottie reducido
                          height: isSmallScreen
                              ? 110.r
                              : 130.r, // Lottie reducido
                          fit: BoxFit.contain,
                          repeat: true,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isSmallScreen ? 4.h : 6.h),
                // Arrow_blue debajo del QR (movido a la izquierda)
                Transform.translate(
                  offset: Offset(-30.w, 0), // Mueve 30 unidades a la izquierda
                  child: Container(
                    alignment: Alignment.centerLeft,
                    child: Lottie.asset(
                      'assets/animations/lottie/arrow_blue.json',
                      width:
                          screenWidth *
                          (isSmallScreen ? 0.4 : 0.45), // Ancho aumentado
                      height: isSmallScreen ? 120.h : 190.h, // Altura aumentada
                      fit: BoxFit.fitHeight,
                      repeat: true,
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: isSmallScreen ? 12.w : 16.w),
          // Columna derecha: Botones más anchos
          Expanded(
            flex: isSmallScreen ? 5 : 6, // Aumentado para botones más anchos
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(height: isSmallScreen ? 4.h : 8.h),
                _buildShopButtonResponsive(),
                SizedBox(height: isSmallScreen ? 12.h : 16.h),
                _buildManualButtonResponsive(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Botones Responsive ──────────────────────────────────────────────────
  Widget _buildManualButtonResponsive() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return SizedBox(
      height: isSmallScreen ? 140.h : 150.h, // Aumentado: 120/130.h → 140/150.h
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _showManualInputDialog,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kBlueMid,
          foregroundColor: _kWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              isSmallScreen ? 16.r : 18.r,
            ), // Radio aumentado
          ),
          elevation: isSmallScreen ? 6 : 8, // Elevación aumentada
          padding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 16.h : 18.h, // Padding aumentado
            horizontal: isSmallScreen ? 16.w : 20.w, // Padding aumentado
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.keyboard,
              size: isSmallScreen ? 36.r : 40.r, // Icono aumentado
            ),
            SizedBox(
              height: isSmallScreen ? 8.h : 10.h,
            ), // Espacio vertical aumentado
            Text(
              'INGRESO MANUAL',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isSmallScreen ? 14.sp : 16.sp, // Fuente aumentada
                fontWeight: FontWeight.w900,
                letterSpacing: isSmallScreen ? 0.7 : 0.9, // Espaciado aumentado
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopButtonResponsive() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) =>
          Transform.scale(scale: _pulseAnim.value, child: child),
      child: SizedBox(
        height: isSmallScreen
            ? 140.h
            : 150.h, // Aumentado: 120/130.h → 140/150.h
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            _scannerFocusNode.unfocus();
            context.push('/shop').then((_) {
              if (mounted) {
                _scannerFocusNode.requestFocus();
                _restoreImmersiveMode();
              }
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _kGreen,
            foregroundColor: _kWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                isSmallScreen ? 16.r : 18.r,
              ), // Radio aumentado
            ),
            elevation: isSmallScreen ? 8 : 10, // Elevación aumentada
            shadowColor: _kGreen.withValues(
              alpha: isSmallScreen ? 0.8 : 0.9,
            ), // Sombra más intensa
            padding: EdgeInsets.symmetric(
              vertical: isSmallScreen ? 16.h : 18.h, // Padding aumentado
              horizontal: isSmallScreen ? 16.w : 20.w, // Padding aumentado
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                size: isSmallScreen ? 36.r : 40.r, // Icono aumentado
              ),
              SizedBox(
                height: isSmallScreen ? 8.h : 10.h,
              ), // Espacio vertical aumentado
              Text(
                'COMPRAR TICKET',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isSmallScreen ? 14.sp : 16.sp, // Fuente aumentada
                  fontWeight: FontWeight.w900,
                  letterSpacing: isSmallScreen
                      ? 0.7
                      : 0.9, // Espaciado aumentado
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Loading overlay ──────────────────────────────────────────────────────
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/animations/lottie/scanner.json',
              width: 200.r,
              height: 200.r,
              repeat: true,
            ),
            SizedBox(height: 16.h),
            Text(
              'VALIDANDO CÓDIGO...',
              style: TextStyle(
                color: _kWhite,
                fontSize: 18.sp,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Dialogs ──────────────────────────────────────────────────────────────
  void _showManualInputDialog() async {
    // Solo aquí se pierde el focus intencionalmente
    _scannerFocusNode.unfocus();
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width:
              MediaQuery.of(ctx).size.width * 0.7, // 70% del ancho de pantalla
          constraints: BoxConstraints(
            maxWidth: 600.w, // Máximo para pantallas muy grandes
            minWidth: 400.w, // Mínimo para pantallas pequeñas
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          padding: EdgeInsets.all(32.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'INGRESO MANUAL',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 24.sp,
                      color: AppColors.primary,
                      letterSpacing: 1,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(Icons.close, size: 32.r, color: Colors.white70),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),
              Text(
                'Ingrese el código de QR:',
                style: TextStyle(
                  fontSize: 16.sp,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: _manualInputController,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [UpperCaseTextFormatter()],
                style: TextStyle(
                  fontSize: 24.sp,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: 'EJ: ANSA_12345',
                  hintStyle: TextStyle(
                    fontSize: 20.sp,
                    color: Colors.white38,
                    letterSpacing: 1.5,
                  ),
                  prefixIcon: Padding(
                    padding: EdgeInsets.all(16.r),
                    child: Icon(
                      Icons.vpn_key,
                      size: 28.r,
                      color: AppColors.primary,
                    ),
                  ),
                  suffixIcon: Padding(
                    padding: EdgeInsets.all(8.r),
                    child: IconButton(
                      icon: Icon(
                        Icons.send_rounded,
                        size: 28.r,
                        color: AppColors.primary,
                      ),
                      onPressed: () => _submitManualInput(ctx),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    borderSide: BorderSide(color: Colors.white24, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    borderSide: BorderSide(color: Colors.white24, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    borderSide: BorderSide(color: AppColors.primary, width: 3),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 20.h,
                    horizontal: 20.w,
                  ),
                ),
                onSubmitted: (_) => _submitManualInput(ctx),
              ),
              SizedBox(height: 32.h),
              ElevatedButton(
                onPressed: () => _submitManualInput(ctx),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 60.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  backgroundColor: AppColors.primary,
                  elevation: 8,
                ),
                child: Text(
                  'VALIDAR ACCESO',
                  style: TextStyle(
                    fontSize: 18.sp,
                    color: _kWhite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // Restaurar focus y modo inmersivo al cerrar el modal manual
    if (mounted) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _scannerFocusNode.requestFocus();
          _restoreImmersiveMode();
        }
      });
    }
  }

  void _submitManualInput(BuildContext ctx) {
    final code = _manualInputController.text.trim();
    if (code.isNotEmpty) {
      Navigator.pop(ctx);
      ref.read(scannerProvider.notifier).processCode(code);
      _manualInputController.clear();
    }
  }

  void _showTicketDialog(dynamic result) async {
    if (_isShowingDialog) return;
    _isShowingDialog = true;
    try {
      await _showCustomModalDialog(
        context: context,
        child: TicketCard(
          key: ValueKey(
            'ticket_${result.hashCode}_${DateTime.now().millisecondsSinceEpoch}',
          ),
          result: result,
          onDismiss: () {
            ref.read(scannerProvider.notifier).reset();
            if (mounted) Navigator.of(context).pop();
          },
        ),
        widthPercentage: 0.85,
        maxWidthPercentage: 0.95,
        minWidth: 280.w,
        padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 0.r),
      );
    } catch (e, stack) {
      debugPrint('[TICKET_DIALOG] Error: $e');
      debugPrint('[TICKET_DIALOG] Stack: $stack');
      if (mounted) {
        ref.read(scannerProvider.notifier).reset();
      }
    } finally {
      _isShowingDialog = false;
    }
    _restoreFocusAndImmersive();
  }

  // ─── Helper: restaurar focus y modo inmersivo ─────────────────────────────
  void _restoreFocusAndImmersive() {
    if (!mounted) return;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _scannerFocusNode.requestFocus();
        _restoreImmersiveMode();
      }
    });
  }

  Future<void> _showCustomModalDialog({
    required BuildContext context,
    required Widget child,
    double widthPercentage = 0.85,
    double maxWidthPercentage = 0.95,
    double minWidth = 280,
    EdgeInsetsGeometry? padding,
    Color barrierColor = Colors.black54,
    bool barrierDismissible = true,
    Curve animationCurve = Curves.easeOutBack,
    Duration animationDuration = const Duration(milliseconds: 300),
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierColor: barrierColor,
      barrierDismissible: barrierDismissible,
      barrierLabel: '',
      transitionDuration: animationDuration,
      pageBuilder: (context, animation, secondaryAnimation) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * widthPercentage,
                constraints: BoxConstraints(
                  maxWidth:
                      MediaQuery.of(context).size.width * maxWidthPercentage,
                  minWidth: minWidth,
                  // Forzar un límite físico si .sh o .height fallan por alguna razón
                  maxHeight: MediaQuery.of(context).size.height > 0
                      ? MediaQuery.of(context).size.height * 0.90
                      : 800,
                ),
                padding: padding,
                child: child,
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: animationCurve),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  void _showErrorDialog(String error) async {
    if (_isShowingDialog) return;
    _isShowingDialog = true;

    // Hablar mensaje de error
    TTSService.speakErrorMessage();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Text(
          'Error de Validación',
          style: TextStyle(fontSize: 20.sp, color: _kWhite),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 64.r),
            SizedBox(height: 16.h),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16.sp, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(scannerProvider.notifier).reset();
              Navigator.of(ctx).pop();
            },
            child: Text(
              'REINTENTAR',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
    _isShowingDialog = false;
    _restoreFocusAndImmersive();
  }

  // ─── NUEVA IMPLEMENTACIÓN DE DIÁLOGO ACORDE AL CICLO DE VIDA ───
  void _showAlreadyScannedDialog() async {
    if (_isShowingDialog) return;
    _isShowingDialog = true;

    final authorized = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'AlreadyScanned',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: FadeTransition(
            opacity: anim1,
            child: ScaleTransition(
              scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
              child: Dialog(
                backgroundColor: Colors.transparent,
                // El contenido ahora maneja de forma segura su propio estado
                child: _AlreadyScannedDialogContent(
                  onCancel: () {
                    ref.read(scannerProvider.notifier).reset();
                    if (ctx.mounted) Navigator.of(ctx).pop(false);
                  },
                  onAuthorized: () {
                    if (ctx.mounted) Navigator.of(ctx).pop(true);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );

    _isShowingDialog = false;

    if (authorized == true && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        ref.read(scannerProvider.notifier).authorizeAccess();
      }
    } else {
      ref.read(scannerProvider.notifier).reset();
      _restoreFocusAndImmersive();
    }
  }
}

// ─── WIDGET EXTRACTO PARA EVITAR ERRORES DE CONTROLADOR DISPUESTO MAL ───
class _AlreadyScannedDialogContent extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onAuthorized;

  const _AlreadyScannedDialogContent({
    required this.onCancel,
    required this.onAuthorized,
  });

  @override
  State<_AlreadyScannedDialogContent> createState() =>
      _AlreadyScannedDialogContentState();
}

class _AlreadyScannedDialogContentState
    extends State<_AlreadyScannedDialogContent> {
  late final TextEditingController _adminCtrl;
  Timer? _dialogTimer;

  bool _showPasswordInput = false;
  bool _showError = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _adminCtrl = TextEditingController();

    // El temporizador vive de forma segura dentro del ciclo de este widget
    _dialogTimer = Timer(const Duration(seconds: 120), () {
      if (mounted) {
        widget.onCancel();
      }
    });
  }

  @override
  void dispose() {
    // Se cancela y destruye exactamente cuando el Widget visual sale del árbol
    _dialogTimer?.cancel();
    _adminCtrl.dispose();
    super.dispose();
  }

  void _validateKey() {
    final input = _adminCtrl.text.trim();
    if (input == _kAdminPassword) {
      _dialogTimer?.cancel();
      FocusScope.of(context).unfocus();
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) widget.onAuthorized();
      });
    } else {
      setState(() {
        _showError = true;
        _adminCtrl.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        padding: EdgeInsets.all(32.r),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28.r),
          border: Border.all(
            color: _showPasswordInput
                ? AppColors.primary.withValues(alpha: 0.3)
                : Colors.orange.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 25,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(
                color: _showPasswordInput
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _showPasswordInput
                    ? Icons.admin_panel_settings_rounded
                    : Icons.qr_code_scanner_rounded,
                color: _showPasswordInput ? AppColors.primary : Colors.orange,
                size: 64.r,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              _showPasswordInput
                  ? 'CLAVE DE ADMINISTRADOR'
                  : 'EL CÓDIGO SUMINISTRADO YA FUE PROCESADO ',
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w900,
                color: _kWhite,
                letterSpacing: 1,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              _showPasswordInput
                  ? 'Ingrese o escanee la clave para autorizar el acceso:'
                  : 'Este código ya fue validado anteriormente en nuestro sistema.',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.white70,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (_showPasswordInput) ...[
              SizedBox(height: 20.h),
              TextField(
                controller: _adminCtrl,
                autofocus: true,
                obscureText: _obscure,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [UpperCaseTextFormatter()],
                style: TextStyle(
                  fontSize: 22.sp,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  hintStyle: TextStyle(fontSize: 20.sp, color: Colors.white24),
                  prefixIcon: Padding(
                    padding: EdgeInsets.all(12.r),
                    child: Icon(
                      Icons.lock,
                      size: 24.r,
                      color: AppColors.primary,
                    ),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      size: 22.r,
                      color: Colors.white38,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide(
                      color: _showError ? Colors.redAccent : Colors.white24,
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide(
                      color: _showError ? Colors.redAccent : Colors.white24,
                      width: 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide(
                      color: _showError ? Colors.redAccent : AppColors.primary,
                      width: 3,
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 16.h,
                    horizontal: 16.w,
                  ),
                ),
                onSubmitted: (_) => _validateKey(),
                onChanged: (_) {
                  if (_showError) {
                    setState(() => _showError = false);
                  }
                },
              ),
              if (_showError) ...[
                SizedBox(height: 8.h),
                Text(
                  'Clave incorrecta. Intente nuevamente.',
                  style: TextStyle(fontSize: 13.sp, color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ],
              SizedBox(height: 10.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    size: 14.r,
                    color: Colors.white30,
                  ),
                  SizedBox(width: 6.w),
                  Flexible(
                    child: Text(
                      'QR · Código de barras · Teclado',
                      style: TextStyle(fontSize: 11.sp, color: Colors.white30),
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: 28.h),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      if (_showPasswordInput) {
                        setState(() {
                          _showPasswordInput = false;
                          _showError = false;
                          _adminCtrl.clear();
                        });
                      } else {
                        widget.onCancel();
                      }
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                    ),
                    child: Text(
                      _showPasswordInput ? 'VOLVER' : 'CANCELAR',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white54,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _showPasswordInput
                        ? _validateKey
                        : () {
                            setState(() {
                              _showPasswordInput = true;
                            });
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: _kWhite,
                      elevation: 8,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _showPasswordInput
                              ? Icons.check_circle_rounded
                              : Icons.vpn_key_rounded,
                          size: 18.r,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          _showPasswordInput ? 'VALIDAR' : 'AUTORIZAR',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header Widget ────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // KLK y ANSA comparten tamaño, Solux es independiente para ajustar
    final logoSize = screenWidth * 0.14;
    final soluxLogoSize =
        screenWidth * 0.32; // Modificar este valor para ajustar Solux
    final logoSpacing = screenWidth * 0.05;

    final screenHeight = MediaQuery.of(context).size.height;
    // Altura fija del header: no afecta al carrusel al cambiar tamaño de logos
    final headerHeight = screenHeight * 0.15;

    return Container(
      width: double.infinity,
      height: headerHeight,
      color: _kWhite,
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo KLK (izquierda)
          SizedBox(
            height: logoSize,
            width: logoSize,
            child: Container(
              decoration: BoxDecoration(
                color: _kWhite,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.asset(
                'assets/logo/klk.png',
                fit: BoxFit.contain,
                isAntiAlias: true,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
          SizedBox(width: logoSpacing),
          // Logo ANSA (centro - principal)
          SizedBox(
            height: logoSize,
            width: logoSize,
            child: Container(
              decoration: BoxDecoration(
                color: _kWhite,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.asset(
                'assets/logo/ansa.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  decoration: BoxDecoration(
                    color: _kBluePrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'A',
                      style: TextStyle(
                        color: _kWhite,
                        fontSize: logoSize * 0.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: logoSpacing),
          // Logo Solux (derecha)
          SizedBox(
            height: soluxLogoSize,
            width: soluxLogoSize,
            child: Container(
              decoration: BoxDecoration(
                color: _kWhite,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.asset(
                'assets/logo/solux.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  decoration: BoxDecoration(
                    color: _kBluePrimary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      'S',
                      style: TextStyle(
                        color: _kWhite,
                        fontSize: soluxLogoSize * 0.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── App Lifecycle Observer ──────────────────────────────────────────────────
class _AppLifecycleObserver extends WidgetsBindingObserver {
  final _ScannerScreenState _screenState;

  _AppLifecycleObserver(this._screenState);
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _screenState._restoreImmersiveMode();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }
}
