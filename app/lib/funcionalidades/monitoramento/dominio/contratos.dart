/// Contratos do dominio do aplicativo.
///
/// Leitura e comando sao interfaces separadas (segregacao de interface): uma
/// tela que so observa nao precisa depender de metodos de escrita.
library;

import 'package:compartilhado/modelos.dart';

abstract interface class LeitorTelemetria {
  Future<Telemetria> obterTelemetria();
}

/// Fonte contínua de telemetria. Quem consome nao sabe nem precisa saber se o
/// que chega veio do canal em tempo real ou da consulta de reserva.
abstract interface class FonteTelemetria {
  /// Emite cada leitura nova. Emite erro quando a fonte perde contato, mas
  /// nunca fecha: o proprio canal cuida de voltar sozinho.
  Stream<Telemetria> get atualizacoes;

  /// Verdadeiro enquanto o canal em tempo real esta de pe. Falso quando quem
  /// esta entregando as leituras e a consulta de reserva.
  bool get emTempoReal;

  void conectar();
  Future<void> encerrar();
}

abstract interface class EmissorComando {
  /// Lanca [FalhaBloqueio] quando o servidor recusa com 409.
  Future<Telemetria> acionarBomba(String bombaId, {required bool ligar});

  Future<void> definirVelocidade({required bool acelerada});
  Future<Telemetria> reiniciarSimulacao();
}
