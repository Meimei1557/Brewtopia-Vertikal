import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.coffee, size: 72, color: Colors.white70),
          const SizedBox(height: 12),
          Text('BREWTOPIA',
              style: GoogleFonts.playfairDisplay(
                  fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: 2)),
          const SizedBox(height: 24),
          const SizedBox(
              width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
        ]),
      ),
    );
  }
}
