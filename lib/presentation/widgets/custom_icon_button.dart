import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CustomIconButton extends StatelessWidget {
  const CustomIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  final Widget icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Platform.isAndroid
        ? IconButton(onPressed: onPressed, icon: icon)
        : CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onPressed,
            child: icon,
          );
  }
}
