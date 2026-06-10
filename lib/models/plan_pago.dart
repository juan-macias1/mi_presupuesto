import 'deuda.dart';

class DetallePago {
  final int deudaId;
  final String acreedor;
  final double saldoActual;
  final double cuotaMensual;
  final double pagoExtraPromedio;
  final int mesesParaPagar;
  final DateTime fechaEstimadaPago;
  final bool esPrioridad;

  DetallePago({
    required this.deudaId,
    required this.acreedor,
    required this.saldoActual,
    required this.cuotaMensual,
    required this.pagoExtraPromedio,
    required this.mesesParaPagar,
    required this.fechaEstimadaPago,
    required this.esPrioridad,
  });

  double get pagoTotalMensual => cuotaMensual + pagoExtraPromedio;

  @override
  String toString() => 'DetallePago(acreedor: $acreedor, '
      'meses: $mesesParaPagar, prioridad: $esPrioridad)';
}

class PlanPago {
  final List<Deuda> deudas;
  final double totalDeuda;
  final double disponibleMensual;
  final int mesesParaLiberarse;
  final DateTime? fechaLiberacion;
  final String estrategia;
  final String mensajeEstrategia;
  final List<DetallePago> detallePorDeuda;
  final double excedenteMensual;
  final double ahorroEnIntereses;

  PlanPago({
    required this.deudas,
    required this.totalDeuda,
    required this.disponibleMensual,
    required this.mesesParaLiberarse,
    required this.fechaLiberacion,
    required this.estrategia,
    required this.mensajeEstrategia,
    required this.detallePorDeuda,
    required this.excedenteMensual,
    required this.ahorroEnIntereses,
  });

  factory PlanPago.sinDeudas() {
    return PlanPago(
      deudas: [],
      totalDeuda: 0,
      disponibleMensual: 0,
      mesesParaLiberarse: 0,
      fechaLiberacion: null,
      estrategia: 'LIBERTAD',
      mensajeEstrategia:
          '🎉 ¡Sin deudas! Es momento de construir tu patrimonio.',
      detallePorDeuda: [],
      excedenteMensual: 0,
      ahorroEnIntereses: 0,
    );
  }

  bool get estaEnModoLibertad => estrategia == 'LIBERTAD';
  bool get esInsuficiente => estrategia == 'INSUFICIENTE';
  bool get tieneDeudas => deudas.isNotEmpty && totalDeuda > 0;

  Deuda? get deudaPrioritaria =>
      detallePorDeuda.isNotEmpty ? deudas.first : null;

  @override
  String toString() => 'PlanPago(total: $totalDeuda, '
      'meses: $mesesParaLiberarse, estrategia: $estrategia)';
}
