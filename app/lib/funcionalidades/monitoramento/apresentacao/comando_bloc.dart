/// Bloc dos comandos do operador.
///
/// O estado de recusa carrega a mensagem que veio do servidor. A interface
/// exibe exatamente essa mensagem, o que deixa claro que a regra vive la.
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

class ReinicioSolicitado extends EventoComando {
  const ReinicioSolicitado();
}

sealed class EstadoComando {
  const EstadoComando();
}

class ComandoOcioso extends EstadoComando {
  const ComandoOcioso();
}

class ComandoEnviando extends EstadoComando {
  const ComandoEnviando();
}

class ComandoAceito extends EstadoComando {
  const ComandoAceito(this.telemetria);
  final Telemetria telemetria;
}

/// RN08. A causa vem do servidor, nunca de uma checagem local.
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
