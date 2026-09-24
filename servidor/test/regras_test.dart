// Testes T01 a T10 do capitulo 16, um por regra do capitulo 6.
//
// Como as regras sao funcoes puras, nenhum objeto falso e necessario aqui.
import 'package:compartilhado/modelos.dart';
import 'package:servidor/dominio/regras/regras.dart';
import 'package:test/test.dart';

final agora = DateTime(2026, 9, 24, 12);

/// Fazenda de um talhao, para isolar a regra sob teste.
Telemetria fazenda({
  double umidade = 60,
  double nivel = 80,
  bool ligada = false,
  bool bloqueio = false,
  Origem? origem,
  // Meia noite por padrao: sem captacao solar, para isolar a regra sob teste.
  double horaSimulada = 0,
}) =>
    Telemetria(
      horaSimulada: horaSimulada,
      reservatorio: Reservatorio(
          nivel: nivel, capacidadeLitros: 50000, bloqueioAtivo: bloqueio),
      talhoes: [
        Talhao(id: 't1', nome: 'Talhao 1', cultura: 'laranja', umidade: umidade)
      ],
      bombas: [
        Bomba(
            id: 'b1',
            talhaoId: 't1',
            ligada: ligada,
            origemUltimoAcionamento: origem)
      ],
      hora: agora,
    );

void main() {
  test('T01 RN01: umidade cai a cada ciclo em talhao sem irrigacao', () {
    final depois = atualizarSensores(fazenda(umidade: 60), agora);
    expect(depois.talhoes.single.umidade,
        closeTo(60 - Limiares.quedaUmidadePorTick, 0.001));
  });

  test('T02 RN02: umidade sobe a cada ciclo com aspersor ligado', () {
    final depois = atualizarSensores(fazenda(umidade: 30, ligada: true), agora);
    expect(depois.talhoes.single.umidade,
        closeTo(30 + Limiares.ganhoUmidadePorTick, 0.001));
  });

  test('T03 RN03: consumo proporcional as bombas, contra a captacao solar', () {
    // A noite nao ha captacao, entao o nivel so responde as bombas.
    expect(atualizarSensores(fazenda(nivel: 80), agora).reservatorio.nivel,
        closeTo(80, 0.001));
    expect(
        atualizarSensores(fazenda(nivel: 80, ligada: true), agora)
            .reservatorio
            .nivel,
        closeTo(80 - Limiares.consumoPorBombaPorTick, 0.001));

    // Ao meio dia, com as bombas paradas, a captacao repoe no pico.
    final meioDia = fazenda(nivel: 80, horaSimulada: 12 - Limiares.horasPorTick);
    expect(atualizarSensores(meioDia, agora).reservatorio.nivel,
        closeTo(80 + Limiares.recargaSolarPico, 0.001));
  });

  test('T11 RN03: a captacao solar segue a curva do sol e nunca compensa a '
      'irrigacao plena', () {
    expect(fatorSolar(3), 0, reason: 'madrugada');
    expect(fatorSolar(Limiares.amanhecer), 0);
    expect(fatorSolar(12), closeTo(1, 0.001), reason: 'pico ao meio dia');
    expect(fatorSolar(Limiares.anoitecer), 0);
    expect(fatorSolar(21), 0, reason: 'noite');

    // Quatro bombas ligadas no pico do sol: o reservatorio ainda cai, que e o
    // que garante que a demonstracao chegue ao bloqueio.
    final quatroBombas = Telemetria(
      horaSimulada: 12 - Limiares.horasPorTick,
      reservatorio: const Reservatorio(
          nivel: 80, capacidadeLitros: 50000, bloqueioAtivo: false),
      talhoes: [
        for (var i = 1; i <= 4; i++)
          Talhao(id: 't$i', nome: 'T$i', cultura: 'citros', umidade: 30)
      ],
      bombas: [
        for (var i = 1; i <= 4; i++)
          Bomba(id: 'b$i', talhaoId: 't$i', ligada: true)
      ],
      hora: agora,
    );

    final depois = atualizarSensores(quatroBombas, agora);
    expect(depois.reservatorio.nivel, lessThan(80));
    expect(Limiares.recargaSolarPico,
        closeTo(4 * Limiares.consumoPorBombaPorTick / 5, 0.001),
        reason: 'captacao calibrada em um quinto do consumo com carga total');
  });

  test('T12 RN05: irrigacao manual acima do patamar gera alerta sem desligar',
      () {
    // O operador ligou e a umidade acabou de cruzar o patamar de seguranca.
    final manual = fazenda(
        umidade: Limiares.umidadeSegura,
        ligada: true,
        origem: Origem.operador);
    final decisao = avaliarIrrigacaoCritica(manual, agora);

    expect(decisao.telemetria.bombas.single.ligada, isTrue,
        reason: 'a decisao continua sendo do operador');
    expect(decisao.eventos.single.tipo, TipoEvento.alertaDesperdicio);
    expect(decisao.eventos.single.origem, Origem.sistema);

    // O aviso nao se repete nos ciclos seguintes.
    final adiante = fazenda(
        umidade: Limiares.umidadeSegura + 10,
        ligada: true,
        origem: Origem.operador);
    expect(avaliarIrrigacaoCritica(adiante, agora).eventos, isEmpty);

    // Mas o solo saturado gera um segundo aviso.
    final saturado =
        fazenda(umidade: 100, ligada: true, origem: Origem.operador);
    expect(avaliarIrrigacaoCritica(saturado, agora).eventos.single.motivo,
        contains('saturado'));
  });

  test('T04 RN04: irrigacao aciona sozinha ao cruzar o limite critico', () {
    final seco = fazenda(umidade: Limiares.umidadeCritica - 0.1);
    final decisao = avaliarIrrigacaoCritica(seco, agora);
    expect(decisao.telemetria.bombas.single.ligada, isTrue);
    expect(decisao.telemetria.bombas.single.origemUltimoAcionamento,
        Origem.sistema);
    expect(decisao.eventos.single.tipo, TipoEvento.irrigacaoIniciada);
  });

  test('T05 RN05: irrigacao automatica so encerra no patamar de seguranca', () {
    // Entre o gatilho e o patamar de seguranca a bomba continua ligada, que e
    // exatamente o que impede o liga e desliga repetido.
    final entre = fazenda(
        umidade: Limiares.umidadeSegura - 1,
        ligada: true,
        origem: Origem.sistema);
    expect(avaliarIrrigacaoCritica(entre, agora).telemetria.bombas.single.ligada,
        isTrue);

    final segura = fazenda(
        umidade: Limiares.umidadeSegura, ligada: true, origem: Origem.sistema);
    final decisao = avaliarIrrigacaoCritica(segura, agora);
    expect(decisao.telemetria.bombas.single.ligada, isFalse);
    expect(decisao.eventos.single.tipo, TipoEvento.irrigacaoEncerrada);
  });

  test('T06 RN06: bloqueio desliga todas as bombas ao cruzar o limite', () {
    final critico = Telemetria(
      reservatorio: Reservatorio(
          nivel: Limiares.reservatorioCritico - 0.1,
          capacidadeLitros: 50000,
          bloqueioAtivo: false),
      talhoes: [
        Talhao(id: 't1', nome: 'T1', cultura: 'laranja', umidade: 20),
        Talhao(id: 't2', nome: 'T2', cultura: 'limao', umidade: 70),
      ],
      bombas: [
        Bomba(id: 'b1', talhaoId: 't1', ligada: true),
        Bomba(id: 'b2', talhaoId: 't2', ligada: true),
      ],
      hora: agora,
    );

    final decisao = avaliarBloqueioHidrico(critico, agora);
    expect(decisao.telemetria.reservatorio.bloqueioAtivo, isTrue);
    expect(decisao.telemetria.bombas.every((b) => !b.ligada), isTrue);
    expect(decisao.eventos.first.tipo, TipoEvento.bloqueioAtivado);
  });

  test('T07 RN07: reservatorio critico e talhao seco, nenhuma bomba liga', () {
    // O teste mais valioso da suite. Sem a precedencia o ciclo chegaria ao
    // estado absurdo de ligar uma bomba com o reservatorio em 12%.
    final critico = fazenda(umidade: 10, nivel: 12);
    final decisao = executarCiclo(critico, agora);

    expect(decisao.telemetria.reservatorio.bloqueioAtivo, isTrue);
    expect(decisao.telemetria.bombas.single.ligada, isFalse);
    expect(decisao.eventos.any((e) => e.tipo == TipoEvento.irrigacaoIniciada),
        isFalse);
  });

  test('T08 RN08: comando manual e recusado durante o bloqueio, com motivo',
      () {
    final bloqueada = fazenda(nivel: 10, bloqueio: true);
    final decisao = avaliarComandoManual(bloqueada, 'b1', true, agora);

    expect(decisao.aceito, isFalse);
    expect(decisao.motivoRecusa, contains('Bloqueio de emergencia'));
    expect(decisao.telemetria.bombas.single.ligada, isFalse);
    expect(decisao.eventos.single.tipo, TipoEvento.comandoRecusado);
  });

  test('T09 RN09: bloqueio so e liberado no patamar de seguranca', () {
    // Acima do gatilho mas abaixo do patamar, o bloqueio permanece.
    final recuperando =
        fazenda(nivel: Limiares.reservatorioSeguro - 1, bloqueio: true);
    expect(
        avaliarBloqueioHidrico(recuperando, agora)
            .telemetria
            .reservatorio
            .bloqueioAtivo,
        isTrue);

    final seguro = fazenda(nivel: Limiares.reservatorioSeguro, bloqueio: true);
    final decisao = avaliarBloqueioHidrico(seguro, agora);
    expect(decisao.telemetria.reservatorio.bloqueioAtivo, isFalse);
    expect(decisao.eventos.single.tipo, TipoEvento.bloqueioLiberado);
  });

  test('T10 RN11: todo evento identifica se a origem foi operador ou sistema',
      () {
    final manual = avaliarComandoManual(fazenda(), 'b1', true, agora);
    expect(manual.eventos.single.origem, Origem.operador);

    final automatico =
        avaliarIrrigacaoCritica(fazenda(umidade: 10), agora);
    expect(automatico.eventos.single.origem, Origem.sistema);
  });
}
