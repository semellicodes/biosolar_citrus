/// Contratos do dominio do aplicativo.
///
/// Leitura e comando sao interfaces separadas (segregacao de interface): uma
/// tela que so observa nao precisa depender de metodos de escrita.
library;

import 'package:compartilhado/modelos.dart';

abstract interface class LeitorTelemetria {
  Future<Telemetria> obterTelemetria();
  Future<List<Evento>> obterEventos({int limite, int deslocamento});
}

abstract interface class EmissorComando {
  /// Lanca [FalhaBloqueio] quando o servidor recusa com 409.
  Future<Telemetria> acionarBomba(String bombaId, {required bool ligar});

  Future<void> definirVelocidade({required bool acelerada});
  Future<Telemetria> reiniciarSimulacao();
}
