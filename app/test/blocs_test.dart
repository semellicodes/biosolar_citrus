// Testes de bloc. O objetivo nao e cobertura alta, e cobrir exatamente o que a
// banca pode questionar: telemetria recebida vira estado carregado, queda de
// conexao nao perde o ultimo dado, e a recusa do servidor chega inteira na
// interface.
//
// Nenhum servidor sobe aqui: os contratos do dominio sao substituidos por
// falsos, que e o ganho pratico da inversao de dependencia.

import 'package:app/funcionalidades/monitoramento/apresentacao/comando_bloc.dart';
import 'package:app/funcionalidades/monitoramento/apresentacao/telemetria_bloc.dart';
import 'package:app/funcionalidades/monitoramento/dominio/contratos.dart';
import 'package:app/nucleo/falhas.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compartilhado/modelos.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class LeitorFalso extends Mock implements LeitorTelemetria {}

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

void main() {
  late LeitorFalso leitor;
  late EmissorFalso emissor;

  setUp(() {
    leitor = LeitorFalso();
    emissor = EmissorFalso();
  });

  blocTest<TelemetriaBloc, EstadoTelemetria>(
    'telemetria recebida produz o estado carregado',
    build: () {
      when(leitor.obterTelemetria).thenAnswer((_) async => telemetria);
      return TelemetriaBloc(leitor);
    },
    act: (bloc) => bloc.add(const MonitoramentoIniciado()),
    wait: const Duration(milliseconds: 50),
    expect: () => [isA<TelemetriaCarregada>()],
  );

  blocTest<TelemetriaBloc, EstadoTelemetria>(
    'queda de conexao desconecta sem perder a ultima leitura conhecida',
    build: () => TelemetriaBloc(leitor),
    seed: () => TelemetriaCarregada(telemetria),
    setUp: () => when(leitor.obterTelemetria)
        .thenThrow(const FalhaComunicacao('Servidor inacessivel.')),
    act: (bloc) => bloc.add(const MonitoramentoIniciado()),
    wait: const Duration(milliseconds: 50),
    expect: () => [
      isA<TelemetriaDesconectada>()
          .having((e) => e.ultima, 'ultima leitura', telemetria)
    ],
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
}
