// Testes de bloc. O objetivo nao e cobertura alta, e cobrir exatamente o que a
// banca pode questionar: telemetria recebida vira estado carregado, queda de
// conexao nao perde o ultimo dado, e a recusa do servidor chega inteira na
// interface.
//
// Nenhum servidor sobe aqui: os contratos do dominio sao substituidos por
// falsos, que e o ganho pratico da inversao de dependencia.

import 'dart:async';

import 'package:app/funcionalidades/monitoramento/apresentacao/comando_bloc.dart';
import 'package:app/funcionalidades/monitoramento/apresentacao/telemetria_bloc.dart';
import 'package:app/funcionalidades/monitoramento/dominio/contratos.dart';
import 'package:app/nucleo/falhas.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compartilhado/modelos.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// Fonte falsa: um controlador que o teste alimenta a mao, no lugar do canal.
class FonteFalsa implements FonteTelemetria {
  final controlador = StreamController<Telemetria>.broadcast();
  var conectou = false;

  @override
  bool get emTempoReal => true;

  @override
  Stream<Telemetria> get atualizacoes => controlador.stream;

  @override
  void conectar() => conectou = true;

  @override
  Future<void> encerrar() => controlador.close();
}

class EmissorFalso extends Mock implements EmissorComando {}

final telemetria = Telemetria(
  reservatorio:
      const Reservatorio(nivel: 70, capacidadeLitros: 50000, bloqueioAtivo: false),
  talhoes: const [
    Talhao(id: 't1', nome: 'Norte', cultura: 'Laranja', umidade: 60)
  ],
  bombas: const [Bomba(id: 'b1', talhaoId: 't1', ligada: false)],
  hora: DateTime(2026, 9, 24, 12),
);

/// O bloc processa MonitoramentoIniciado de forma assincrona. Sem esperar, o
/// teste empurraria o dado antes de a inscricao na fonte existir.
Future<void> _inscrever() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late FonteFalsa fonte;
  late EmissorFalso emissor;

  setUp(() {
    fonte = FonteFalsa();
    emissor = EmissorFalso();
  });

  blocTest<TelemetriaBloc, EstadoTelemetria>(
    'telemetria empurrada pela fonte produz o estado carregado',
    build: () => TelemetriaBloc(fonte),
    act: (bloc) async {
      bloc.add(const MonitoramentoIniciado());
      await _inscrever();
      fonte.controlador.add(telemetria);
    },
    wait: const Duration(milliseconds: 50),
    expect: () => [isA<TelemetriaCarregada>()],
    verify: (_) => expect(fonte.conectou, isTrue),
  );

  blocTest<TelemetriaBloc, EstadoTelemetria>(
    'perda de contato desconecta sem perder a ultima leitura conhecida',
    build: () => TelemetriaBloc(fonte),
    seed: () => TelemetriaCarregada(telemetria),
    act: (bloc) async {
      bloc.add(const MonitoramentoIniciado());
      await _inscrever();
      fonte.controlador
          .addError(const FalhaComunicacao('Servidor inacessível.'));
    },
    wait: const Duration(milliseconds: 50),
    expect: () => [
      isA<TelemetriaDesconectada>()
          .having((e) => e.ultima, 'ultima leitura', telemetria)
    ],
  );

  blocTest<TelemetriaBloc, EstadoTelemetria>(
    'depois da queda, a leitura seguinte reconecta a tela sozinha',
    build: () => TelemetriaBloc(fonte),
    act: (bloc) async {
      bloc.add(const MonitoramentoIniciado());
      await _inscrever();
      fonte.controlador
          .addError(const FalhaComunicacao('Servidor inacessível.'));
      await _inscrever();
      fonte.controlador.add(telemetria);
    },
    wait: const Duration(milliseconds: 50),
    expect: () => [isA<TelemetriaDesconectada>(), isA<TelemetriaCarregada>()],
  );

  blocTest<ComandoBloc, EstadoComando>(
    'recusa do servidor vira estado de bloqueio com a mensagem original',
    build: () {
      when(() => emissor.acionarBomba(any(), ligar: any(named: 'ligar')))
          .thenThrow(const FalhaBloqueio('Bloqueio de emergencia ativo.'));
      return ComandoBloc(emissor);
    },
    act: (bloc) =>
        bloc.add(const AcionamentoSolicitado('b1', ligar: true)),
    expect: () => [
      isA<ComandoEnviando>(),
      isA<ComandoRecusado>()
          .having((e) => e.mensagem, 'mensagem', 'Bloqueio de emergencia ativo.')
    ],
  );

  blocTest<ComandoBloc, EstadoComando>(
    'pausa manual pede a interrupção do ciclo ao servidor',
    build: () {
      when(() => emissor.pausarSimulacao()).thenAnswer((_) async {});
      return ComandoBloc(emissor);
    },
    act: (bloc) => bloc.add(const PausaSolicitada()),
    expect: () => [isA<ComandoEnviando>(), isA<ComandoOcioso>()],
    verify: (_) => verify(() => emissor.pausarSimulacao()).called(1),
  );
}
