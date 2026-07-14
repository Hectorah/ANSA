import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ResponsiveHelper {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1024;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;

  static bool isLandscape(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  static double sp(double size) => size.sp;
  static double w(double size) => size.w;
  static double h(double size) => size.h;
  static double r(double size) => size.r;

  static double getAdaptiveSize({
    required double mobile,
    double? tablet,
    double? desktop,
    required BuildContext context,
  }) {
    if (isDesktop(context)) return (desktop ?? tablet ?? mobile).w;
    if (isTablet(context)) return (tablet ?? mobile).w;
    return mobile.w;
  }
}
