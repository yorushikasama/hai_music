import 'package:flutter/material.dart';

class Responsive {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 650;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 650 &&
      MediaQuery.of(context).size.width < 1100;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1100;

  static double getWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double getHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static EdgeInsets getHorizontalPadding(BuildContext context) {
    if (isDesktop(context)) {
      return const EdgeInsets.symmetric(horizontal: 40);
    } else if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 30);
    } else {
      return const EdgeInsets.symmetric(horizontal: 20);
    }
  }

  static int getCrossAxisCount(BuildContext context) {
    if (isDesktop(context)) {
      return 4;
    } else if (isTablet(context)) {
      return 3;
    } else {
      return 2;
    }
  }

  static double getCardWidth(BuildContext context) {
    if (isDesktop(context)) {
      return 200;
    } else if (isTablet(context)) {
      return 180;
    } else {
      return 160;
    }
  }
}
