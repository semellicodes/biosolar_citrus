library;

import 'package:compartilhado/modelos.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../nucleo/falhas.dart';
import '../dominio/contratos.dart';

sealed class EventoComando {
  const EventoComando();
}

class AcionamentoSolicitado extends EventoComando {
  const AcionamentoSolicitado(this.bombaId, {required this.ligar});
  final String bombaId;
  final bool ligar;
}

class VelocidadeSolicitada extends EventoComando {
  const VelocidadeSolicitada({required this.acelerada});
  final bool acelerada;
}

class PausaSolicitada extends EventoComando {
  const PausaSolicitada();
}

class ReinicioSolicitado extends EventoComando {
  const ReinicioSolicitado();
}

class ChuvaSolicitada extends EventoComando {
  const ChuvaSolicitada({required this.chovendo});
  final bool chovendo;
}

sealed class EstadoComando {
  const EstadoComando();
}

class ComandoOcioso extends EstadoComando {
  const ComandoOcioso();
}

class SistemaPausado extends EstadoComando {
  const SistemaPausado();
}

class ComandoEnviando extends EstadoComando {
  const ComandoEnviando();
}

class ComandoAceito extends EstadoComando {
  const ComandoAceito(this.telemetria);
  final Telemetria telemetria;
}

class ComandoRecusado extends EstadoComando {
  const ComandoRecusado(this.mensagem);
  final String mensagem;
}

class ComandoFalhou extends EstadoComando {
  const ComandoFalhou(this.mensagem);
  final String mensagem;
}

class ComandoBloc extends Bloc<EventoComando, EstadoComando> {
  ComandoBloc(this._emissor) : super(const ComandoOcioso()) {
    on<AcionamentoSolicitado>((evento, emit) async {
      emit(const ComandoEnviando());
      await _executar(emit,
          () => _emissor.acionarBomba(evento.bombaId, ligar: evento.ligar));
    });

    on<VelocidadeSolicitada>((evento, emit) async {
      emit(const ComandoEnviando());
      await _executar(emit, () async {
        await _emissor.definirVelocidade(acelerada: evento.acelerada);
        return null;
      });
    });

    on<PausaSolicitada>((_, emit) async {
      emit(const ComandoEnviando());
      try {
        await _emissor.pausarSimulacao();
        emit(const SistemaPausado());
      } on Falha catch (falha) {
        emit(ComandoFalhou(falha.mensagem));
      }
    });

    on<ChuvaSolicitada>((evento, emit) async {
      emit(const ComandoEnviando());
      await _executar(
          emit, () => _emissor.definirChuva(chovendo: evento.chovendo));
    });

    on<ReinicioSolicitado>((_, emit) async {
      emit(const ComandoEnviando());
      await _executar(emit, _emissor.reiniciarSimulacao);
    });
  }

  final EmissorComando _emissor;

  Future<void> _executar(
    Emitter<EstadoComando> emit,
    Future<Telemetria?> Function() acao,
  ) async {
    try {
      final telemetria = await acao();
      emit(telemetria == null
          ? const ComandoOcioso()
          : ComandoAceito(telemetria));
    } on FalhaBloqueio catch (falha) {
      emit(ComandoRecusado(falha.mensagem));
    } on Falha catch (falha) {
      emit(ComandoFalhou(falha.mensagem));
    }
  }
}
