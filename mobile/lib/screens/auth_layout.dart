import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

/// Mise en page des écrans d'authentification : logo, titre, puis une carte
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 384),
              child: Column(
                children: [
                  SvgPicture.asset('assets/icon.svg', width: 80, height: 80),
                  const SizedBox(height: 12),
                  const Text('Pas ce soir', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('Le journal des réveils de votre enfant', style: TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 32),
                  Card(child: Padding(padding: const EdgeInsets.all(20), child: child)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
