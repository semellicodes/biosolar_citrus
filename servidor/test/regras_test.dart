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

  test('T11 RN12: a captacao solar segue a curva do sol e nunca compensa a '
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
    expect(depois.reservatorio.nivel, lessThan(80),
        reason: 'com tudo ligado o nivel cai mesmo no pico do sol');
    expect(Limiares.recargaSolarPico,
        lessThan(4 * Limiares.consumoPorBombaPorTick),
        reason: 'a captacao no pico nao cobre a irrigacao plena, entao o '
            'bloqueio continua sendo alcancavel');
  });

  test('T13 RN12: na media do dia a captacao cobre a manutencao dos talhoes',
      () {
    // Este e o teste que separa escassez de colapso. A captacao no pico perde
    // para quatro bombas, mas a irrigacao e intermitente: em regime, cada
    // talhao precisa de bomba durante queda / (ganho + queda) do tempo. Se a
    // captacao media do dia nao cobrir isso, todos os talhoes acabam presos em
    // estado critico depois do primeiro bloqueio, que foi o que aconteceu com a
    // calibragem anterior.
    const ciclosDeSol = 48; // das 6h as 18h, a 0,25h por ciclo
    const ciclosDoDia = 96;
    const mediaDoSeno = 2 / 3.14159265; // media de sin sobre meio periodo

    final captacaoPorDia =
        Limiares.recargaSolarPico * mediaDoSeno * ciclosDeSol;

    final fracaoIrrigando = Limiares.quedaUmidadePorTick /
        (Limiares.ganhoUmidadePorTick + Limiares.quedaUmidadePorTick);
    final consumoPorDia = 4 *
        fracaoIrrigando *
        Limiares.consumoPorBombaPorTick *
        ciclosDoDia;

    expect(captacaoPorDia, greaterThan(consumoPorDia),
        reason: 'captacao de ${captacaoPorDia.toStringAsFixed(1)} pontos por '
            'dia contra consumo de manutencao de '
            '${consumoPorDia.toStringAsFixed(1)}');
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

    // Ligar a bomba em solo que ja passou do patamar tambem avisa, uma vez, no
    // proprio comando. Sem isso este caso nunca seria alertado, porque o
    // cruzamento do patamar ja tinha acontecido antes de a bomba ligar.
    final encharcado = fazenda(umidade: Limiares.umidadeSegura + 20);
    final comando = avaliarComandoManual(encharcado, 'b1', true, agora);
    expect(comando.aceito, isTrue);
    expect(comando.telemetria.bombas.single.ligada, isTrue);
    expect(
        comando.eventos
            .where((e) => e.tipo == TipoEvento.alertaDesperdicio)
            .single
            .motivo,
        contains('mesmo assim'));

    // O aviso nao se repete ao longo de uma sessao inteira, inclusive depois de
    // o solo saturar em 100%, onde a umidade para de crescer e um teste de
    // cruzamento ingenuo passaria a valer em todos os ciclos seguintes. No modo
    // demonstracao sao muitos ciclos por segundo, entao isso se prova em vez de
    // supor.
    var estado = fazenda(umidade: 20, ligada: true, origem: Origem.operador);
    final alertas = <Evento>[];
    for (var ciclo = 0; ciclo < 200; ciclo++) {
      estado = atualizarSensores(estado, agora);
      final decisao = avaliarIrrigacaoCritica(estado, agora);
      estado = decisao.telemetria;
      alertas.addAll(decisao.eventos
          .where((e) => e.tipo == TipoEvento.alertaDesperdicio));
    }
    expect(estado.talhoes.single.umidade, 100, reason: 'o solo saturou');
    expect(alertas, hasLength(1),
        reason: 'um unico aviso, no ciclo em que o patamar foi cruzado');
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
    expect(decisao.motivoRecusa, contains('Bloqueio de emergência'));
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

  // T13 esta reservado para o teste do equilibrio hidrico, que vem do branch
  // campo e e anterior a este na ordem logica das regras.
  test('T14 RN13: durante a chuva o solo sobe sem bomba, e a irrigacao '
      'critica continua valendo', () {
    // A chuva nao desliga nada: ela muda o que a fisica faz com o solo, e as
    // regras de decisao continuam sendo avaliadas do mesmo jeito.
    final chovendo =
        fazenda(umidade: 30, nivel: 60).copiarCom(chovendo: true);

    // Sobe sem nenhuma bomba ligada, e menos do que subiria irrigando.
    final depois = atualizarSensores(chovendo, agora);
    expect(depois.bombas.single.ligada, isFalse);
    expect(depois.talhoes.single.umidade,
        closeTo(30 + Limiares.ganhoChuvaPorTick, 0.001));
    expect(Limiares.ganhoChuvaPorTick,
        lessThan(Limiares.ganhoUmidadePorTick),
        reason: 'chuva molha o pomar, nao substitui o aspersor');

    // O reservatorio recebe chuva, respeitando o teto.
    expect(depois.reservatorio.nivel,
        closeTo(60 + Limiares.captacaoChuvaPorTick, 0.001));
    final quaseCheio = fazenda(nivel: Limiares.tetoChuvaReservatorio - 0.3)
        .copiarCom(chovendo: true);
    expect(atualizarSensores(quaseCheio, agora).reservatorio.nivel,
        closeTo(Limiares.tetoChuvaReservatorio, 0.001),
        reason: 'a chuva para no teto em vez de encher a fazenda');

    // RN04 continua valendo: se mesmo chovendo um talhao estiver abaixo do
    // gatilho, o aspersor e acionado.
    final secoNaChuva =
        fazenda(umidade: 10, nivel: 60).copiarCom(chovendo: true);
    final decisao = avaliarIrrigacaoCritica(secoNaChuva, agora);
    expect(decisao.telemetria.bombas.single.ligada, isTrue);
    expect(decisao.eventos.single.tipo, TipoEvento.irrigacaoIniciada);

    // RN07 continua tendo precedencia: com o reservatorio critico, chuva
    // nenhuma faz uma bomba ligar.
    final bloqueado =
        fazenda(umidade: 10, nivel: 12).copiarCom(chovendo: true);
    final ciclo = executarCiclo(bloqueado, agora);
    expect(ciclo.telemetria.reservatorio.bloqueioAtivo, isTrue);
    expect(ciclo.telemetria.bombas.single.ligada, isFalse);

    // O comando e do operador e aparece no historico como tal (RN11).
    final ligou = definirChuva(fazenda(), true, agora);
    expect(ligou.telemetria.chovendo, isTrue);
    expect(ligou.eventos.single.tipo, TipoEvento.chuvaIniciada);
    expect(ligou.eventos.single.origem, Origem.operador);
    expect(definirChuva(ligou.telemetria, true, agora).eventos, isEmpty,
        reason: 'ligar de novo o que ja esta ligado nao gera evento');
    final desligou = definirChuva(ligou.telemetria, false, agora);
    expect(desligou.telemetria.chovendo, isFalse);
    expect(desligou.eventos.single.tipo, TipoEvento.chuvaEncerrada);
  });

  test('T10 RN11: todo evento identifica se a origem foi operador ou sistema',
      () {
    // Solo seco de proposito: aqui interessa so a origem do comando, sem o
    // alerta de desperdicio entrando na conta.
    final manual = avaliarComandoManual(fazenda(umidade: 20), 'b1', true, agora);
    expect(manual.eventos.single.tipo, TipoEvento.comandoAceito);
    expect(manual.eventos.single.origem, Origem.operador);

    final automatico =
        avaliarIrrigacaoCritica(fazenda(umidade: 10), agora);
    expect(automatico.eventos.single.origem, Origem.sistema);
  });
}
