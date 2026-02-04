import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CustomIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback onPressed;

  const CustomIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

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
