/// Bloc do painel: recebe telemetria e publica o estado da tela.
///
/// Nao decide nada sobre irrigacao. Ele so traduz o que chegou do servidor em
/// um estado que a tela sabe desenhar.
library;

import 'dart:async';

import 'package:compartilhado/modelos.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../nucleo/falhas.dart';
import '../dominio/contratos.dart';

sealed class EventoTelemetria {
  const EventoTelemetria();
}

class MonitoramentoIniciado extends EventoTelemetria {
  const MonitoramentoIniciado();
}

/// Telemetria que chegou de fora, por consulta ou por resposta de comando.
/// Quando o WebSocket entrar, e por aqui que o canal vai empurrar o estado.
class TelemetriaRecebida extends EventoTelemetria {
  const TelemetriaRecebida(this.telemetria);
  final Telemetria telemetria;
}

class _ConsultaDisparada extends EventoTelemetria {
  const _ConsultaDisparada();
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
  const TelemetriaCarregada(this.telemetria);
  final Telemetria telemetria;

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
  TelemetriaBloc(this._leitor, {this.intervalo = const Duration(seconds: 2)})
      : super(const TelemetriaCarregando()) {
    on<MonitoramentoIniciado>((_, _) {
      _relogio?.cancel();
      add(const _ConsultaDisparada());
      _relogio = Timer.periodic(intervalo, (_) => add(const _ConsultaDisparada()));
    });

    on<_ConsultaDisparada>((_, emit) async {
      try {
        emit(TelemetriaCarregada(await _leitor.obterTelemetria()));
      } on Falha {
        emit(TelemetriaDesconectada(state.ultima));
      }
    });

    on<TelemetriaRecebida>((evento, emit) =>
        emit(TelemetriaCarregada(evento.telemetria)));
  }

  final LeitorTelemetria _leitor;

  /// RNF03: a tela reflete uma mudanca em menos de dois segundos.
  final Duration intervalo;

  Timer? _relogio;

  @override
  Future<void> close() {
    // Sem isto o aplicativo vaza memoria e ainda tenta emitir estado depois de
    // a tela ter sido destruida.
    _relogio?.cancel();
    return super.close();
  }
}
