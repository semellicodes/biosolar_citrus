/// Bloc do historico. Busca a lista e guarda o filtro por origem.
library;

import 'dart:async';

import 'package:compartilhado/modelos.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../dominio/contratos.dart';

sealed class EventoHistorico {
  const EventoHistorico();
}

class HistoricoAberto extends EventoHistorico {
  const HistoricoAberto();
}

class HistoricoAtualizado extends EventoHistorico {
  const HistoricoAtualizado();
}

class FiltroAlterado extends EventoHistorico {
  const FiltroAlterado(this.origem);

  /// Nulo mostra tudo.
  final Origem? origem;
}

class EstadoHistorico {
  const EstadoHistorico({this.eventos = const [], this.filtro});

  final List<Evento> eventos;
  final Origem? filtro;

  List<Evento> get visiveis => filtro == null
      ? eventos
      : eventos.where((e) => e.origem == filtro).toList();

  EstadoHistorico copiarCom({List<Evento>? eventos, Origem? filtro, bool limparFiltro = false}) =>
      EstadoHistorico(
        eventos: eventos ?? this.eventos,
        filtro: limparFiltro ? null : (filtro ?? this.filtro),
      );
}

class EventosBloc extends Bloc<EventoHistorico, EstadoHistorico> {
  EventosBloc(this._leitor) : super(const EstadoHistorico()) {
    on<HistoricoAberto>((_, _) {
      add(const HistoricoAtualizado());
      _relogio?.cancel();
      _relogio = Timer.periodic(
          const Duration(seconds: 2), (_) => add(const HistoricoAtualizado()));
    });

    on<HistoricoAtualizado>((_, emit) async {
      try {
        emit(state.copiarCom(eventos: await _leitor.obterEventos(limite: 100)));
      } catch (_) {
        // Historico e tela secundaria: sem contato, mantem o que ja tem.
      }
    });

    on<FiltroAlterado>((evento, emit) => emit(state.copiarCom(
        filtro: evento.origem, limparFiltro: evento.origem == null)));
  }

  final LeitorEventos _leitor;
  Timer? _relogio;

  @override
  Future<void> close() {
    _relogio?.cancel();
    return super.close();
  }
}
