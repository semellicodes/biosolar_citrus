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

class TelemetriaRecebida extends EventoTelemetria {
  const TelemetriaRecebida(this.telemetria);
  final Telemetria telemetria;
}

class ContatoPerdido extends EventoTelemetria {
  const ContatoPerdido();
}

sealed class EstadoTelemetria {
  const EstadoTelemetria();

  Telemetria? get ultima => null;
}

class TelemetriaCarregando extends EstadoTelemetria {
  const TelemetriaCarregando();
}

class TelemetriaCarregada extends EstadoTelemetria {
  const TelemetriaCarregada(this.telemetria, {this.emTempoReal = true});
  final Telemetria telemetria;

  final bool emTempoReal;

  @override
  Telemetria get ultima => telemetria;
}

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

    _inscricao?.cancel();
    _fonte.encerrar();
    return super.close();
  }
}
