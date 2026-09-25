/// Canal que empurra o estado a cada ciclo.
///
/// Transporte puro: o que trafega aqui e o mesmo JSON do GET /telemetria, e
/// nenhuma decisao acontece neste arquivo.
library;

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../aplicacao/servico_simulacao.dart';

Handler canalWebSocket(ServicoSimulacao simulacao) =>
    webSocketHandler((WebSocketChannel canal, _) {
      // Estado imediato, para o painel nao ficar vazio esperando o proximo
      // ciclo logo depois de conectar.
      canal.sink.add(jsonEncode(simulacao.telemetria.toJson()));

      final inscricao = simulacao.atualizacoes
          .listen((estado) => canal.sink.add(jsonEncode(estado.toJson())));

      // Sem cancelar a inscricao o servidor acumula ouvintes mortos a cada
      // aplicativo que fecha.
      canal.stream.listen(
        null,
        onDone: inscricao.cancel,
        onError: (_) => inscricao.cancel(),
        cancelOnError: true,
      );
    });
