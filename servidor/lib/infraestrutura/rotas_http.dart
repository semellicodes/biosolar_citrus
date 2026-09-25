/// Transporte HTTP. Traduz requisicao em chamada de servico e resultado em
/// JSON, e nada alem disso. Nenhuma decisao acontece neste arquivo.
library;

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../aplicacao/servico_simulacao.dart';
import '../dominio/repositorio_fazenda.dart';
import 'canal_websocket.dart';

Response _json(Object corpo, {int status = 200}) => Response(
      status,
      body: jsonEncode(corpo),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// RNF06: a versao web do aplicativo e o plano de contingencia da
/// apresentacao, e ela so funciona com CORS liberado.
Middleware get _cors => (interno) => (requisicao) async {
      const cabecalhos = {
        'access-control-allow-origin': '*',
        'access-control-allow-methods': 'GET, POST, OPTIONS',
        'access-control-allow-headers': 'content-type',
      };
      if (requisicao.method == 'OPTIONS') {
        return Response.ok(null, headers: cabecalhos);
      }
      return (await interno(requisicao)).change(headers: cabecalhos);
    };

Handler criarRotas(ServicoSimulacao simulacao, RepositorioFazenda repositorio) {
  final rotas = Router();

  // RF02
  rotas.get('/telemetria', (Request _) => _json(simulacao.telemetria.toJson()));

  // RF03 e RN08. A recusa e 409 com o motivo vindo do dominio, e a interface
  // exibe exatamente essa mensagem em vez de inventar um texto proprio.
  rotas.post('/bombas/acionar', (Request requisicao) async {
    final corpo =
        jsonDecode(await requisicao.readAsString()) as Map<String, dynamic>;
    final bombaId = corpo['bombaId'] as String?;
    final ligar = corpo['ligar'] as bool?;
    if (bombaId == null || ligar == null) {
      return _json({
        'erro': 'requisicao_invalida',
        'mensagem': 'Informe bombaId (texto) e ligar (booleano).',
      }, status: 400);
    }

    final motivoRecusa = simulacao.acionarBomba(bombaId, ligar: ligar);
    if (motivoRecusa != null) {
      return _json({
        'erro': 'bloqueio_de_emergencia',
        'mensagem': motivoRecusa,
      }, status: 409);
    }
    return _json(simulacao.telemetria.toJson());
  });

  // F06, com limite e deslocamento porque e a unica lista que cresce sem fim.
  rotas.get('/eventos', (Request requisicao) {
    final parametros = requisicao.url.queryParameters;
    final eventos = repositorio.eventos(
      limite: int.tryParse(parametros['limite'] ?? '') ?? 50,
      deslocamento: int.tryParse(parametros['deslocamento'] ?? '') ?? 0,
    );
    return _json(eventos.map((e) => e.toJson()).toList());
  });

  // RF12 e F07
  rotas.post('/simulacao/velocidade', (Request requisicao) async {
    final corpo =
        jsonDecode(await requisicao.readAsString()) as Map<String, dynamic>;
    simulacao.definirVelocidade(acelerada: corpo['acelerada'] as bool? ?? false);
    return _json({
      'acelerada': simulacao.acelerada,
      'intervaloMs': simulacao.intervalo.inMilliseconds,
    });
  });

  // Pausa manual, sem encerrar o servidor ou os canais em tempo real.
  rotas.post('/simulacao/pausar', (Request _) {
    simulacao.pausar();
    return _json({'ativa': simulacao.ativa});
  });

  // RN13: chuva manual, comando do operador.
  rotas.post('/simulacao/chuva', (Request requisicao) async {
    final corpo =
        jsonDecode(await requisicao.readAsString()) as Map<String, dynamic>;
    final chovendo = corpo['chovendo'] as bool?;
    if (chovendo == null) {
      return _json({
        'erro': 'requisicao_invalida',
        'mensagem': 'Informe chovendo (booleano).',
      }, status: 400);
    }
    simulacao.definirChuva(chovendo: chovendo);
    return _json(simulacao.telemetria.toJson());
  });

  // Canal em tempo real. O REST continua inteiro no ar de proposito: e o
  // fallback do aplicativo quando o WebSocket nao abre ou cai.
  rotas.get('/stream', canalWebSocket(simulacao));

  // F12
  rotas.post('/simulacao/reset', (Request _) {
    simulacao.reiniciar();
    return _json(simulacao.telemetria.toJson());
  });

  return const Pipeline()
      .addMiddleware(_cors)
      .addMiddleware(logRequests())
      .addHandler(rotas.call);
}
