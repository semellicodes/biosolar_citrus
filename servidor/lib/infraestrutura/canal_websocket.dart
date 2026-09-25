library;

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../aplicacao/servico_simulacao.dart';

Handler canalWebSocket(ServicoSimulacao simulacao) =>
    webSocketHandler((WebSocketChannel canal, _) {

      canal.sink.add(jsonEncode(simulacao.telemetria.toJson()));

      final inscricao = simulacao.atualizacoes
          .listen((estado) => canal.sink.add(jsonEncode(estado.toJson())));

      canal.stream.listen(
        null,
        onDone: inscricao.cancel,
        onError: (_) => inscricao.cancel(),
        cancelOnError: true,
      );
    });
