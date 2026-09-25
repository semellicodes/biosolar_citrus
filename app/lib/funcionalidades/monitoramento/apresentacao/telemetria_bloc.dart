/// Bloc do painel: recebe telemetria e publica o estado da tela.
///
/// Nao decide nada sobre irrigacao. Ele so traduz o que chegou do servidor em
/// um estado que a tela sabe desenhar.
library;

import 'dart:async';

import 'package:compartilhado/modelos.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../dominio/contratos.dart';

sealed class EventoTelemetria {
  const EventoTelemetria();
}

class MonitoramentoIniciado extends EventoTelemetria {
  const MonitoramentoIniciado();
}

/// Telemetria que chegou de fora: empurrada pelo canal, trazida pela consulta
/// de reserva ou devolvida por um comando aceito. O bloc nao distingue.
class TelemetriaRecebida extends EventoTelemetria {
  const TelemetriaRecebida(this.telemetria);
  final Telemetria telemetria;
}

class ContatoPerdido extends EventoTelemetria {
  const ContatoPerdido();
}

sealed class EstadoTelemetria {
  const EstadoTelemetria();

  /// Ultima leitura conhecida, se houver. Cache de exibicao em memoria, para a
  /// tela nao ficar vazia entre duas atualizacoes (RNF02: nao e persistencia).
  Telemetria? get ultima => null;
}

class TelemetriaCarregando extends EstadoTelemetria {
  const TelemetriaCarregando();
}

class TelemetriaCarregada extends EstadoTelemetria {
  const TelemetriaCarregada(this.telemetria, {this.emTempoReal = true});
  final Telemetria telemetria;

  /// Diz se a leitura veio do canal ou da consulta de reserva. So o indicador
  /// de conexao usa isso; o resto da tela nao precisa saber.
  final bool emTempoReal;

  @override
  Telemetria get ultima => telemetria;
}

/// RNF05: a queda da conexao nao trava o aplicativo. O ultimo dado conhecido
/// continua na tela e a proxima consulta reconecta sozinha.
class TelemetriaDesconectada extends EstadoTelemetria {
  const TelemetriaDesconectada(this.ultima);

  @override
  final Telemetria? ultima;
}

class TelemetriaBloc extends Bloc<EventoTelemetria, EstadoTelemetria> {
  TelemetriaBloc(this._fonte) : super(const TelemetriaCarregando()) {
    on<MonitoramentoIniciado>((_, _) {
      _inscricao?.cancel();
      _inscricao = _fonte.atualizacoes.listen(
        (telemetria) => add(TelemetriaRecebida(telemetria)),
        onError: (_) => add(const ContatoPerdido()),
      );
      _fonte.conectar();
    });

    on<TelemetriaRecebida>((evento, emit) => emit(TelemetriaCarregada(
        evento.telemetria,
        emTempoReal: _fonte.emTempoReal)));

    on<ContatoPerdido>((_, emit) => emit(TelemetriaDesconectada(state.ultima)));
  }

  final FonteTelemetria _fonte;

  StreamSubscription<Telemetria>? _inscricao;

  @override
  Future<void> close() {
    // Sem isto o aplicativo vaza memoria e ainda tenta emitir estado depois de
    // a tela ter sido destruida.
    _inscricao?.cancel();
    _fonte.encerrar();
    return super.close();
  }
}
