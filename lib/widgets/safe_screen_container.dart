import 'package:flutter/material.dart';

class SafeScreenContainer extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final bool addScaffold; // Para decidir si incluir un Scaffold
  final PreferredSizeWidget? appBar; // Si quieres un AppBar

  const SafeScreenContainer({
    super.key,
    required this.child,
    this.backgroundColor,
    this.addScaffold = true, // Por defecto, añade un Scaffold
    this.appBar,
  });

  @override
  Widget build(BuildContext context) {
    if (addScaffold) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: appBar,
        body: SafeArea(
          child: child,
        ),
      );
    } else {
      return SafeArea(
        child: child,
      );
    }
  }
}
