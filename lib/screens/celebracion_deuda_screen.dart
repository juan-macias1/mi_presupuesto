import 'dart:math' as math;
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';

/// Pantalla de celebración full-screen.
///
/// Se muestra cuando el usuario termina de pagar una deuda — el momento
/// más emocional de la app. Es intencionalmente cinematográfica: ocupa
/// toda la pantalla, sin AppBar, con confetti continuo, mensaje en
/// primera persona y un hint discreto "toca para continuar" que aparece
/// fade-in a los 3 segundos para que el usuario sepa cómo cerrarla sin
/// romper la magia inicial.
///
/// Si era la última deuda activa, el mensaje cambia para celebrar el
/// salto a modo libertad: "Sin deudas. Ahora construimos."
class CelebracionDeudaScreen extends StatefulWidget {
  final String acreedor;
  final double montoSaldado;
  final bool esLaUltimaDeuda;

  const CelebracionDeudaScreen({
    super.key,
    required this.acreedor,
    required this.montoSaldado,
    required this.esLaUltimaDeuda,
  });

  @override
  State<CelebracionDeudaScreen> createState() =>
      _CelebracionDeudaScreenState();
}

class _CelebracionDeudaScreenState extends State<CelebracionDeudaScreen>
    with TickerProviderStateMixin {
  late final ConfettiController _confettiCenter;
  late final ConfettiController _confettiLeft;
  late final ConfettiController _confettiRight;

  late final AnimationController _entradaCtrl;
  late final Animation<double> _entradaFade;
  late final Animation<double> _entradaScale;

  late final AnimationController _hintCtrl;
  late final Animation<double> _hintFade;

  static final _fmt = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();

    // Tres controllers de confetti para que las partículas vengan desde
    // varios puntos: centro hacia arriba, esquinas hacia el centro.
    _confettiCenter = ConfettiController(duration: const Duration(seconds: 4));
    _confettiLeft = ConfettiController(duration: const Duration(seconds: 4));
    _confettiRight = ConfettiController(duration: const Duration(seconds: 4));

    // Entrada del contenido — fade + scale suave.
    _entradaCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _entradaFade = CurvedAnimation(
      parent: _entradaCtrl,
      curve: Curves.easeOut,
    );
    _entradaScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _entradaCtrl, curve: Curves.easeOutBack),
    );

    // El hint "toca para continuar" aparece a los 3 segundos. Antes, la
    // celebración respira sola. Si el usuario toca antes, el hint nunca
    // llega a mostrarse — perfecto.
    _hintCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _hintFade = CurvedAnimation(parent: _hintCtrl, curve: Curves.easeIn);

    // Disparar todo en orden: confetti primero, entrada del texto a la par,
    // hint diferido.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confettiCenter.play();
      _confettiLeft.play();
      _confettiRight.play();
      _entradaCtrl.forward();
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _hintCtrl.forward();
    });
  }

  @override
  void dispose() {
    _confettiCenter.dispose();
    _confettiLeft.dispose();
    _confettiRight.dispose();
    _entradaCtrl.dispose();
    _hintCtrl.dispose();
    super.dispose();
  }

  // Paleta para el confetti: verdes y dorados sobre el fondo de marca.
  static const _colores = <Color>[
    Color(0xFFFFD54F), // dorado
    Color(0xFFFFB300), // dorado oscuro
    Color(0xFFE3F2FD), // crema claro
    Color(0xFFC8E6C9), // verde claro
    Color(0xFFFFFFFF), // blanco
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: GestureDetector(
        // Toda la pantalla es tap-target para cerrar — la 3 que elegimos.
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            // Confetti desde el centro hacia arriba.
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiCenter,
                blastDirection: math.pi / 2, // hacia abajo (parte arriba)
                emissionFrequency: 0.05,
                numberOfParticles: 30,
                maxBlastForce: 30,
                minBlastForce: 10,
                gravity: 0.15,
                colors: _colores,
              ),
            ),
            // Confetti desde la esquina inferior izquierda.
            Align(
              alignment: Alignment.bottomLeft,
              child: ConfettiWidget(
                confettiController: _confettiLeft,
                blastDirection: -math.pi / 4, // arriba-derecha
                emissionFrequency: 0.04,
                numberOfParticles: 20,
                maxBlastForce: 35,
                minBlastForce: 15,
                gravity: 0.2,
                colors: _colores,
              ),
            ),
            // Confetti desde la esquina inferior derecha.
            Align(
              alignment: Alignment.bottomRight,
              child: ConfettiWidget(
                confettiController: _confettiRight,
                blastDirection: -3 * math.pi / 4, // arriba-izquierda
                emissionFrequency: 0.04,
                numberOfParticles: 20,
                maxBlastForce: 35,
                minBlastForce: 15,
                gravity: 0.2,
                colors: _colores,
              ),
            ),

            // Contenido principal — el mensaje. Centrado y con entrada
            // animada para que se sienta cinematográfico.
            Center(
              child: FadeTransition(
                opacity: _entradaFade,
                child: ScaleTransition(
                  scale: _entradaScale,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '🎉',
                          style: TextStyle(fontSize: 84),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.esLaUltimaDeuda
                              ? 'Sin deudas'
                              : 'Saldé con ${widget.acreedor}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _fmt.format(widget.montoSaldado),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          widget.esLaUltimaDeuda
                              ? 'Ahora construimos.'
                              : 'Una menos.\nSigo en el camino.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: Colors.white.withValues(alpha: 0.95),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Hint diferido: aparece a los 3 segundos sin romper la magia.
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: FadeTransition(
                  opacity: _hintFade,
                  child: Text(
                    'toca para continuar',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.7),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
