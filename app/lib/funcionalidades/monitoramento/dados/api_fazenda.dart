library;

import 'dart:convert';

import 'package:compartilhado/modelos.dart';
import 'package:http/http.dart' as http;

import '../../../nucleo/falhas.dart';
import '../../eventos/dominio/contratos.dart';
import '../dominio/contratos.dart';

const String enderecoServidor =
    String.fromEnvironment('SERVIDOR', defaultValue: 'http://localhost:8080');

class ApiFazenda implements LeitorTelemetria, LeitorEventos, EmissorComando {
  ApiFazenda({http.Client? cliente, this.endereco = enderecoServidor})
      : _cliente = cliente ?? http.Client();

  final http.Client _cliente;
  final String endereco;

  @override
  Future<Telemetria> obterTelemetria() async {
    final resposta = await _pegar('/telemetria');
    return Telemetria.fromJson(jsonDecode(resposta) as Map<String, dynamic>);
  }

  @override
  Future<List<Evento>> obterEventos({int limite = 50, int deslocamento = 0}) async {
    final resposta =
        await _pegar('/eventos?limite=$limite&deslocamento=$deslocamento');
    return (jsonDecode(resposta) as List)
        .map((e) => Evento.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Telemetria> acionarBomba(String bombaId, {required bool ligar}) async {
    final resposta = await _postar(
        '/bombas/acionar', {'bombaId': bombaId, 'ligar': ligar});

    if (resposta.statusCode == 409) {
      final corpo = jsonDecode(resposta.body) as Map<String, dynamic>;
      throw FalhaBloqueio(corpo['mensagem'] as String);
    }
    if (resposta.statusCode != 200) {
      throw FalhaComunicacao('Servidor respondeu ${resposta.statusCode}.');
    }
    return Telemetria.fromJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  @override
  Future<void> definirVelocidade({required bool acelerada}) =>
      _postar('/simulacao/velocidade', {'acelerada': acelerada});

  @override
  Future<void> pausarSimulacao() async {
    final resposta = await _postar('/simulacao/pausar', const {});
    if (resposta.statusCode != 200) {
      throw FalhaComunicacao('Servidor respondeu ${resposta.statusCode}.');
    }
  }

  @override
  Future<Telemetria> definirChuva({required bool chovendo}) async {
    final resposta = await _postar('/simulacao/chuva', {'chovendo': chovendo});
    if (resposta.statusCode != 200) {
      throw FalhaComunicacao('Servidor respondeu ${resposta.statusCode}.');
    }
    return Telemetria.fromJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  @override
  Future<Telemetria> reiniciarSimulacao() async {
    final resposta = await _postar('/simulacao/reset', const {});
    return Telemetria.fromJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<String> _pegar(String caminho) async {
    try {
      final resposta = await _cliente
          .get(Uri.parse('$endereco$caminho'))
          .timeout(const Duration(seconds: 5));
      if (resposta.statusCode != 200) {
        throw FalhaComunicacao('Servidor respondeu ${resposta.statusCode}.');
      }
      return resposta.body;
    } on FalhaComunicacao {
      rethrow;
    } catch (_) {
      throw const FalhaComunicacao('Servidor inacessível.');
    }
  }

  Future<http.Response> _postar(String caminho, Map<String, Object?> corpo) async {
    try {
      return await _cliente
          .post(Uri.parse('$endereco$caminho'),
              headers: const {'content-type': 'application/json'},
              body: jsonEncode(corpo))
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      throw const FalhaComunicacao('Servidor inacessível.');
    }
  }
}
