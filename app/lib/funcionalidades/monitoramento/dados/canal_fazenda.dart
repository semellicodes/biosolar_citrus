/// Fonte de telemetria: WebSocket com consulta REST de reserva.
///
/// Toda a conversa com o mundo mora aqui. O bloc so recebe leitura ou erro, e
/// nunca sabe por qual caminho ela chegou.
library;

import 'dart:async';
import 'dart:convert';

import 'package:compartilhado/modelos.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../dominio/contratos.dart';
import 'api_fazenda.dart';

class CanalFazenda implements FonteTelemetria {
  CanalFazenda(this._leitor, {this.endereco = enderecoServidor});

  /// Ritmo da consulta de reserva, igual ao que o app usava antes do canal.
  static const Duration intervaloReserva = Duration(seconds: 2);

  /// Teto da espera entre tentativas. Baixo de proposito: com o servidor fora
  /// do ar isto evita a enxurrada de tentativas sem deixar a volta lenta.
  static const Duration esperaMaxima = Duration(seconds: 5);

  final LeitorTelemetria _leitor;
  final String endereco;

  final StreamController<Telemetria> _saida =
      StreamController<Telemetria>.broadcast();

  StreamSubscription<dynamic>? _inscricaoCanal;
  Timer? _reserva;
  Timer? _reconexao;
  int _tentativas = 0;
  bool _encerrado = false;

  @override
  Stream<Telemetria> get atualizacoes => _saida.stream;

  @override
  void conectar() {
    _encerrado = false;
    unawaited(_abrirCanal());
  }

  @override
  Future<void> encerrar() async {
    _encerrado = true;
    _reserva?.cancel();
    _reconexao?.cancel();
    await _inscricaoCanal?.cancel();
    await _saida.close();
  }

  Future<void> _abrirCanal() async {
    if (_encerrado) return;
    try {
      final canal = WebSocketChannel.connect(
          Uri.parse('${endereco.replaceFirst('http', 'ws')}/stream'));
      await canal.ready;
      if (_encerrado) return unawaited(canal.sink.close());

      // Canal de pe: a consulta de reserva sai de cena e a espera zera.
      _tentativas = 0;
      _pararReserva();

      _inscricaoCanal = canal.stream.listen(
        (mensagem) => _saida.add(Telemetria.fromJson(
            jsonDecode(mensagem as String) as Map<String, dynamic>)),
        onDone: _cair,
        onError: (_) => _cair(),
        cancelOnError: true,
      );
    } catch (_) {
      _cair();
    }
  }

  /// Canal caiu ou nem abriu: a consulta de reserva assume imediatamente e a
  /// reconexao fica tentando por baixo, com espera crescente.
  void _cair() {
    _inscricaoCanal?.cancel();
    _inscricaoCanal = null;
    if (_encerrado) return;
    _iniciarReserva();
    _agendarReconexao();
  }

  void _iniciarReserva() {
    if (_reserva != null) return;
    unawaited(_consultar());
    _reserva = Timer.periodic(intervaloReserva, (_) => unawaited(_consultar()));
  }

  void _pararReserva() {
    _reserva?.cancel();
    _reserva = null;
  }

  Future<void> _consultar() async {
    try {
      _saida.add(await _leitor.obterTelemetria());
    } catch (erro) {
      // Nem o canal nem a consulta responderam: quem ouve decide o que mostrar.
      if (!_saida.isClosed) _saida.addError(erro);
    }
  }

  void _agendarReconexao() {
    _reconexao?.cancel();
    // 1s, 2s, 4s e dai em diante o teto.
    final espera = Duration(seconds: 1 << _tentativas);
    _tentativas++;
    _reconexao = Timer(
      espera > esperaMaxima ? esperaMaxima : espera,
      () => unawaited(_abrirCanal()),
    );
  }
}
