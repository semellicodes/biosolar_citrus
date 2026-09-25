/// Servico de simulacao: controla o tempo, nao decide nada.
///
/// A responsabilidade unica aqui e disparar o ciclo no intervalo certo e
/// guardar o resultado. Toda decisao continua sendo do motor de regras.
library;

import 'dart:async';

import 'package:compartilhado/modelos.dart';

import '../dominio/regras/regras.dart';
import '../dominio/repositorio_fazenda.dart';

class ServicoSimulacao {
  ServicoSimulacao(this._repositorio);

  /// RF12: velocidade de operacao normal.
  static const Duration velocidadeNormal = Duration(seconds: 2);

  /// F07: modo demonstracao, para reproduzir os cenarios criticos em menos de
  /// um minuto na frente da banca.
  static const Duration velocidadeAcelerada = Duration(milliseconds: 300);

  final RepositorioFazenda _repositorio;
  final StreamController<Telemetria> _atualizacoes =
      StreamController<Telemetria>.broadcast();
  final StreamController<Evento> _novosEventos =
      StreamController<Evento>.broadcast();

  Timer? _relogio;
  Duration _intervalo = velocidadeNormal;

  /// Canal que o WebSocket consome para empurrar o estado a cada ciclo.
  Stream<Telemetria> get atualizacoes => _atualizacoes.stream;

  /// Decisoes recem tomadas, na ordem em que aconteceram.
  Stream<Evento> get novosEventos => _novosEventos.stream;

  Telemetria get telemetria => _repositorio.telemetria;
  Duration get intervalo => _intervalo;
  bool get acelerada => _intervalo == velocidadeAcelerada;

  void iniciar() {
    _relogio?.cancel();
    _relogio = Timer.periodic(_intervalo, (_) => _ciclo());
  }

  Future<void> parar() async {
    _relogio?.cancel();
    _relogio = null;
    await _atualizacoes.close();
    await _novosEventos.close();
  }

  /// RF12 e F07.
  void definirVelocidade({required bool acelerada}) {
    _intervalo = acelerada ? velocidadeAcelerada : velocidadeNormal;
    _registrar([
      Evento(
        hora: DateTime.now(),
        tipo: TipoEvento.velocidadeAlterada,
        origem: Origem.operador,
        descricao: acelerada
            ? 'Modo demonstração ativado'
            : 'Velocidade normal restaurada',
        motivo: 'Ciclo a cada ${_intervalo.inMilliseconds} ms',
      )
    ]);
    iniciar();
  }

  /// F12.
  void reiniciar() {
    _repositorio.reiniciar();
    _registrar([
      Evento(
        hora: DateTime.now(),
        tipo: TipoEvento.simulacaoReiniciada,
        origem: Origem.operador,
        descricao: 'Simulação reiniciada',
        motivo: 'Cenário devolvido ao estado inicial',
      )
    ]);
  }

  /// RF03 e RN08. Devolve o motivo quando o servidor recusa, para que a rota
  /// responda 409 com a mensagem que a interface vai exibir tal como veio.
  String? acionarBomba(String bombaId, {required bool ligar}) {
    final decisao = avaliarComandoManual(
        _repositorio.telemetria, bombaId, ligar, DateTime.now());
    if (decisao.aceito) _repositorio.salvar(decisao.telemetria);
    _registrar(decisao.eventos);
    return decisao.motivoRecusa;
  }

  void _ciclo() {
    final decisao = executarCiclo(_repositorio.telemetria, DateTime.now());
    _repositorio.salvar(decisao.telemetria);
    _registrar(decisao.eventos);
  }

  void _registrar(List<Evento> eventos) {
    _repositorio.registrarEventos(eventos);
    if (_atualizacoes.isClosed) return;
    _atualizacoes.add(_repositorio.telemetria);
    eventos.forEach(_novosEventos.add);
  }
}
