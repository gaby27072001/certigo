import 'package:flutter/material.dart';
import 'package:prism_ui/prism_ui.dart';

/// Écran transitoire affiché pendant la **restauration de session** au
/// démarrage : le temps de lire le stockage sécurisé et de décider entre
/// auto-connexion et écran de connexion. Évite tout clignotement d'UI.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    return Scaffold(
      body: AuroraBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                  gradient: LinearGradient(
                    colors: <Color>[p.primary, p.ember],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Text(
                    'M',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: PrismSpacing.lg),
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(p.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
