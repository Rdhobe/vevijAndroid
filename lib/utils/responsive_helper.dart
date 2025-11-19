import 'package:flutter/material.dart';

class ResponsiveHelper {
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;
  static const double desktopBreakpoint = 1200;

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  static EdgeInsets getResponsivePadding(BuildContext context) {
    if (isMobile(context)) {
      return EdgeInsets.all(12);
    } else if (isTablet(context)) {
      return EdgeInsets.all(16);
    } else {
      return EdgeInsets.all(20);
    }
  }

  static double getResponsiveFontSize(
    BuildContext context, {
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    if (isMobile(context)) {
      return mobile;
    } else if (isTablet(context)) {
      return tablet;
    } else {
      return desktop;
    }
  }

  static int getResponsiveColumns(
    BuildContext context, {
    required int mobile,
    required int tablet,
    required int desktop,
  }) {
    if (isMobile(context)) {
      return mobile;
    } else if (isTablet(context)) {
      return tablet;
    } else {
      return desktop;
    }
  }

  static double getResponsiveCardWidth(BuildContext context) {
    if (isMobile(context)) {
      return double.infinity;
    } else if (isTablet(context)) {
      return 300;
    } else {
      return 350;
    }
  }

  static EdgeInsets getResponsiveMargin(BuildContext context) {
    if (isMobile(context)) {
      return EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    } else if (isTablet(context)) {
      return EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    } else {
      return EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    }
  }

  static double getResponsiveIconSize(BuildContext context) {
    if (isMobile(context)) {
      return 20;
    } else if (isTablet(context)) {
      return 24;
    } else {
      return 28;
    }
  }

  static double getResponsiveButtonHeight(BuildContext context) {
    if (isMobile(context)) {
      return 40;
    } else if (isTablet(context)) {
      return 44;
    } else {
      return 48;
    }
  }

  static EdgeInsets getResponsiveButtonPadding(BuildContext context) {
    if (isMobile(context)) {
      return EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    } else if (isTablet(context)) {
      return EdgeInsets.symmetric(horizontal: 16, vertical: 10);
    } else {
      return EdgeInsets.symmetric(horizontal: 20, vertical: 12);
    }
  }

  static Widget buildResponsiveLayout({
    required BuildContext context,
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
  }) {
    if (isDesktop(context) && desktop != null) {
      return desktop;
    } else if (isTablet(context) && tablet != null) {
      return tablet;
    } else {
      return mobile;
    }
  }

  static Widget buildResponsiveGrid({
    required BuildContext context,
    required List<Widget> children,
    int? mobileColumns,
    int? tabletColumns,
    int? desktopColumns,
    double? childAspectRatio,
    double? crossAxisSpacing,
    double? mainAxisSpacing,
  }) {
    final columns = getResponsiveColumns(
      context,
      mobile: mobileColumns ?? 1,
      tablet: tabletColumns ?? 2,
      desktop: desktopColumns ?? 3,
    );

    return GridView.count(
      crossAxisCount: columns,
      childAspectRatio: childAspectRatio ?? 1.0,
      crossAxisSpacing: crossAxisSpacing ?? 8,
      mainAxisSpacing: mainAxisSpacing ?? 8,
      children: children,
    );
  }

  static Widget buildResponsiveRow({
    required BuildContext context,
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
  }) {
    if (isMobile(context)) {
      return Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: children,
      );
    } else {
      return Row(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: children,
      );
    }
  }

  static Widget buildResponsiveCard({
    required BuildContext context,
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    double? elevation,
    Color? color,
    BorderRadius? borderRadius,
  }) {
    return Card(
      elevation: elevation ?? 2,
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(12),
      ),
      margin: margin ?? getResponsiveMargin(context),
      child: Padding(
        padding: padding ?? getResponsivePadding(context),
        child: child,
      ),
    );
  }

  static Widget buildResponsiveDataTable({
    required BuildContext context,
    required List<DataColumn> columns,
    required List<DataRow> rows,
    double? columnSpacing,
    double? horizontalMargin,
    double? dataRowMinHeight,
    double? dataRowMaxHeight,
    double? headingRowHeight,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          columnSpacing: columnSpacing ?? (isMobile(context) ? 8 : 12),
          horizontalMargin: horizontalMargin ?? (isMobile(context) ? 8 : 16),
          dataRowMinHeight: dataRowMinHeight ?? (isMobile(context) ? 35 : 40),
          dataRowMaxHeight: dataRowMaxHeight ?? (isMobile(context) ? 45 : 50),
          headingRowHeight: headingRowHeight ?? (isMobile(context) ? 40 : 45),
          headingTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: getResponsiveFontSize(
              context,
              mobile: 11,
              tablet: 12,
              desktop: 13,
            ),
          ),
          dataTextStyle: TextStyle(
            fontSize: getResponsiveFontSize(
              context,
              mobile: 10,
              tablet: 11,
              desktop: 12,
            ),
          ),
          columns: columns,
          rows: rows,
        ),
      ),
    );
  }
}
