import 'package:flutter/material.dart';

abstract class AppTypography {
  static const String fontFamily = 'Morn';

  // Title
  static final title24Medium = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w600,
    fontSize: 24.0,
  );

  static final title20Medium = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w600,
    fontSize: 20.0,
    letterSpacing: 20.0 * 0.01,
  );

  // Body
  static final body20Light = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 20.0,
    letterSpacing: 20.0 * 0.01,
  );

  static final body16Light = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 16.0,
  );

  // Link
  static final link16Medium = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w600,
    fontSize: 16.0,
    height: 1.0,
    letterSpacing: 0.0,
  );

  static final link16Regular = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 16.0,
  );
}
