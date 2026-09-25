library;

import 'package:compartilhado/modelos.dart';

abstract interface class LeitorTelemetria {
  Future<Telemetria> obterTelemetria();
}

abstract interface class FonteTelemetria {

  Stream<Telemetria> get atualizacoes;

  bool get emTempoReal;

  void conectar();
  Future<void> encerrar();
}

abstract interface class EmissorComando {

  Future<Telemetria> acionarBomba(String bombaId, {required bool ligar});

  Future<void> definirVelocidade({required bool acelerada});
  Future<void> pausarSimulacao();

  Future<Telemetria> definirChuva({required bool chovendo});
  Future<Telemetria> reiniciarSimulacao();
}
