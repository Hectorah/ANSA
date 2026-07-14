import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late final WebViewController controller;
  bool isLoading = true;
  double loadingProgress = 0;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    // Configurar modo inmersivo también en esta pantalla
    _setImmersiveMode();
    
    try {
      controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(AppColors.background)
        ..setUserAgent('Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36')
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              setState(() => loadingProgress = progress / 100);
              debugPrint('WebView loading progress: $progress%');
            },
            onPageStarted: (String url) {
              debugPrint('WebView started loading: $url');
              setState(() {
                isLoading = true;
                loadingProgress = 0;
                errorMessage = null;
              });
            },
            onPageFinished: (String url) {
              debugPrint('WebView finished loading: $url');
              setState(() => isLoading = false);
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint('WebView Error: ${error.description}');
              debugPrint('Error code: ${error.errorCode}');
              debugPrint('Error type: ${error.errorType}');
              setState(() {
                isLoading = false;
                errorMessage = 'Error al cargar la página: ${error.description}';
              });
            },
            onNavigationRequest: (NavigationRequest request) {
              debugPrint('Navigation request to: ${request.url}');
              return NavigationDecision.navigate;
            },
          ),
        );
      
      _loadWebsite();
    } catch (e) {
      debugPrint('Error inicializando WebViewController: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Error inicializando el navegador: $e';
      });
    }
  }

  // Configurar modo inmersivo
  void _setImmersiveMode() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
  }

  void _loadWebsite() {
    const url = 'https://ansa2026.duckdns.org';
    debugPrint('Loading website: $url');
    try {
      controller.loadRequest(Uri.parse(url));
    } catch (e) {
      debugPrint('Error cargando website: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Error cargando la página: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "COMPRAR TICKETS", 
          style: TextStyle(
            fontSize: 18.sp, 
            fontWeight: FontWeight.bold,
            color: Colors.black, // Letras negras
          )
        ),
        backgroundColor: Colors.white, // Fondo blanco
        toolbarHeight: 64.h,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: 24.r, color: Colors.black), // Icono negro
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, size: 24.r, color: Colors.black), // Icono negro
            onPressed: () {
              setState(() {
                isLoading = true;
                errorMessage = null;
              });
              _loadWebsite();
            },
          ),
          SizedBox(width: 8.w),
        ],
        bottom: isLoading 
          ? PreferredSize(
              preferredSize: Size.fromHeight(2.h),
              child: LinearProgressIndicator(
                value: loadingProgress,
                backgroundColor: Colors.transparent,
                color: AppColors.primary,
                minHeight: 2.h,
              ),
            )
          : null,
      ),
      body: Stack(
        children: [
          if (errorMessage != null)
            _buildErrorView()
          else
            AnimatedOpacity(
              opacity: isLoading ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeIn,
              child: WebViewWidget(controller: controller),
            ),
          if (isLoading && errorMessage == null)
            _buildLoadingIndicator(),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3.w,
            ),
            SizedBox(height: 16.h),
            Text(
              "Cargando tienda...",
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14.sp,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              "${(loadingProgress * 100).toInt()}%",
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      color: AppColors.background,
      padding: EdgeInsets.all(24.r),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64.r,
              color: AppColors.error,
            ),
            SizedBox(height: 16.h),
            Text(
              "Error de Conexión",
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              errorMessage ?? "No se pudo cargar la página",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14.sp,
              ),
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  isLoading = true;
                  errorMessage = null;
                });
                _loadWebsite();
              },
              icon: Icon(Icons.refresh, size: 20.r),
              label: Text(
                "REINTENTAR",
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Restaurar configuración normal al salir
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }
}