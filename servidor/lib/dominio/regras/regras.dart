/// Motor de regras do BioSolar Citrus, RN01 ate RN13.
///
/// Todas as funcoes aqui sao puras: recebem o estado e devolvem o estado
/// seguinte junto com os eventos gerados. Nao existe rede, nao existe tela e
/// nao existe relogio proprio, o instante chega por parametro. E por isso que
/// a suite de testes deste arquivo roda em milissegundos e e a prova direta de
/// que as exigencias do caderno foram cumpridas (RNF07, RNF09).
library;

import 'package:compartilhado/modelos.dart';

/// Resultado de uma avaliacao: o estado seguinte e o que foi decidido.
///
/// Quando [motivoRecusa] vem preenchido, a [telemetria] e a mesma que entrou,
/// porque a decisao foi nao alterar nada (RN08).
class Decisao {
  const Decisao(this.telemetria, this.eventos, {this.motivoRecusa});

  final Telemetria telemetria;
  final List<Evento> eventos;
  final String? motivoRecusa;

  bool get aceito => motivoRecusa == null;
}

/// RN01, RN02, RN03, RN12 e RN13: avanco fisico da simulacao.
///
/// A umidade cai nos talhoes sem aspersor e sobe nos irrigados. O reservatorio
/// perde agua proporcionalmente ao numero de bombas ligadas e ganha agua pela
/// captacao solar, cuja vazao acompanha a curva do sol e e nula a noite. No
/// pico do dia a reposicao equivale a um quinto do consumo com todas as bombas
/// ligadas, ou seja, ela nunca compensa a irrigacao plena: o reservatorio
/// continua caindo ate o bloqueio. Com as bombas paradas ela repoe devagar, e
/// e isso que permite a liberacao do bloqueio (RN09) acontecer de verdade.
Telemetria atualizarSensores(Telemetria estado, DateTime agora) {
  final talhoes = [
    for (final talhao in estado.talhoes)
      talhao.copiarCom(
        umidade: talhao.umidade +
            _variacaoDaUmidade(
              irrigando: estado.bombaDo(talhao.id).ligada,
              chovendo: estado.chovendo,
            ),
      ),
  ];

  // RN03 e RN12: consumo das bombas contra a captacao solar.
  final horaSimulada =
      (estado.horaSimulada + Limiares.horasPorTick) % 24;
  final bombasLigadas = estado.bombas.where((b) => b.ligada).length;
  final consumo = bombasLigadas * Limiares.consumoPorBombaPorTick;
  final captacao = Limiares.recargaSolarPico * fatorSolar(horaSimulada);
  final chuva = _captacaoDeChuva(estado);
  final reservatorio = estado.reservatorio
      .copiarCom(nivel: estado.reservatorio.nivel - consumo + captacao + chuva);

  return estado.copiarCom(
    talhoes: talhoes,
    reservatorio: reservatorio,
    hora: agora,
    horaSimulada: horaSimulada,
  );
}

/// RN01, RN02 e RN13: quanto a umidade de um talhao muda em um ciclo.
///
/// A ordem e de precedencia fisica: aspersor ligado molha mais que chuva, e
/// chuva molha mais do que o sol seca. Nenhuma regra de decisao passa por aqui;
/// isto e so o que o mundo faz com o solo.
double _variacaoDaUmidade({required bool irrigando, required bool chovendo}) {
  if (irrigando) return Limiares.ganhoUmidadePorTick; // RN02
  if (chovendo) return Limiares.ganhoChuvaPorTick; // RN13
  return -Limiares.quedaUmidadePorTick; // RN01
}

/// RN13: quanto a chuva acrescenta ao reservatorio neste ciclo.
///
/// Tem teto: acima de [Limiares.tetoChuvaReservatorio] a chuva nao acrescenta
/// mais nada, senao alguns segundos de chuva encheriam a fazenda e o cenario
/// perderia o sentido. A chuva tambem nunca desliga o bloqueio por conta
/// propria: ela so levanta o nivel, e quem decide liberar continua sendo a
/// RN09, avaliada no ciclo como sempre foi.
double _captacaoDeChuva(Telemetria estado) {
  if (!estado.chovendo) return 0;
  final espaco =
      Limiares.tetoChuvaReservatorio - estado.reservatorio.nivel;
  if (espaco <= 0) return 0;
  return espaco < Limiares.captacaoChuvaPorTick
      ? espaco
      : Limiares.captacaoChuvaPorTick;
}

/// RN13: liga ou desliga a chuva. E comando de operador, entao o evento sai com
/// origem de operador, e nenhuma regra de automacao muda de comportamento.
Decisao definirChuva(Telemetria estado, bool chovendo, DateTime agora) {
  if (estado.chovendo == chovendo) return Decisao(estado, const []);
  return Decisao(
    estado.copiarCom(chovendo: chovendo),
    [
      Evento(
        hora: agora,
        tipo: chovendo ? TipoEvento.chuvaIniciada : TipoEvento.chuvaEncerrada,
        origem: Origem.operador,
        descricao: chovendo ? 'Chuva iniciada' : 'Chuva encerrada',
        motivo: chovendo
            ? 'O solo passa a ganhar '
                '${Limiares.ganhoChuvaPorTick.toStringAsFixed(1)} por ciclo e o '
                'reservatório recebe chuva até '
                '${Limiares.tetoChuvaReservatorio.toStringAsFixed(0)}%'
            : 'O solo volta a secar normalmente',
      )
    ],
  );
}

/// RN06 e RN09: bloqueio de emergencia e sua liberacao.
///
/// Abaixo do limite critico o bloqueio e ativado e todas as bombas sao
/// desligadas de forma irrestrita. O bloqueio so cai quando o nivel volta
/// acima do patamar de seguranca, que e mais alto que o gatilho de proposito,
/// para nao ficar oscilando na fronteira.
Decisao avaliarBloqueioHidrico(Telemetria estado, DateTime agora) {
  final reservatorio = estado.reservatorio;
  final eventos = <Evento>[];

  // RN06
  if (reservatorio.nivel < Limiares.reservatorioCritico) {
    final bombasLigadas = estado.bombas.where((b) => b.ligada).toList();
    if (!reservatorio.bloqueioAtivo) {
      eventos.add(Evento(
        hora: agora,
        tipo: TipoEvento.bloqueioAtivado,
        origem: Origem.sistema,
        descricao: 'Bloqueio de emergência ativado',
        motivo: 'Reservatório em ${reservatorio.nivel.toStringAsFixed(1)}%, '
            'abaixo do limite crítico de '
            '${Limiares.reservatorioCritico.toStringAsFixed(0)}%',
      ));
    }
    for (final bomba in bombasLigadas) {
      eventos.add(Evento(
        hora: agora,
        tipo: TipoEvento.irrigacaoEncerrada,
        origem: Origem.sistema,
        descricao: 'Bomba ${bomba.id} desligada',
        motivo: 'Bloqueio de emergência hídrico',
      ));
    }
    return Decisao(
      estado.copiarCom(
        reservatorio: reservatorio.copiarCom(bloqueioAtivo: true),
        bombas: [
          for (final bomba in estado.bombas)
            bomba.ligada
                ? bomba.copiarCom(
                    ligada: false, origemUltimoAcionamento: Origem.sistema)
                : bomba,
        ],
      ),
      eventos,
    );
  }

  // RN09
  if (reservatorio.bloqueioAtivo &&
      reservatorio.nivel >= Limiares.reservatorioSeguro) {
    eventos.add(Evento(
      hora: agora,
      tipo: TipoEvento.bloqueioLiberado,
      origem: Origem.sistema,
      descricao: 'Bloqueio de emergência liberado',
      motivo: 'Reservatório recuperou para '
          '${reservatorio.nivel.toStringAsFixed(1)}%, acima do patamar de '
          'segurança de ${Limiares.reservatorioSeguro.toStringAsFixed(0)}%',
    ));
    return Decisao(
      estado.copiarCom(
          reservatorio: reservatorio.copiarCom(bloqueioAtivo: false)),
      eventos,
    );
  }

  // Entre o gatilho e o patamar de seguranca o bloqueio permanece como esta.
  return Decisao(estado, eventos);
}

/// RN04 e RN05: irrigacao critica automatica e seu encerramento.
///
/// Esta funcao pressupoe que o bloqueio ja foi avaliado. Ela nao liga nada com
/// bloqueio ativo, o que garante RN07 mesmo se for chamada fora de ordem.
Decisao avaliarIrrigacaoCritica(Telemetria estado, DateTime agora) {
  // RN07: precedencia absoluta do bloqueio sobre a irrigacao critica.
  if (estado.reservatorio.bloqueioAtivo) return Decisao(estado, const []);

  final eventos = <Evento>[];
  final bombas = <Bomba>[];

  for (final bomba in estado.bombas) {
    final talhao = estado.talhoes.firstWhere((t) => t.id == bomba.talhaoId);

    // RN04
    if (!bomba.ligada && talhao.umidade < Limiares.umidadeCritica) {
      eventos.add(Evento(
        hora: agora,
        tipo: TipoEvento.irrigacaoIniciada,
        origem: Origem.sistema,
        descricao: 'Irrigação iniciada em ${talhao.nome}',
        motivo: 'Umidade em ${talhao.umidade.toStringAsFixed(1)}%, abaixo do '
            'gatilho crítico de '
            '${Limiares.umidadeCritica.toStringAsFixed(0)}%',
      ));
      bombas.add(
          bomba.copiarCom(ligada: true, origemUltimoAcionamento: Origem.sistema));
      continue;
    }

    // RN05: o sistema alerta sobre desperdicio mas nao tira a decisao do
    // operador. A bomba que ele ligou continua ligada, so o bloqueio a derruba.
    //
    // O aviso sai uma unica vez, no ciclo em que a umidade cruza o patamar.
    // E um teste de cruzamento puro, sem guardar estado: como a bomba esta
    // ligada, a umidade so sobe, entao o patamar e atravessado uma vez so.
    //
    // O teto de 100 nao serve como segundo gatilho: la a umidade para de
    // crescer e o mesmo teste passaria a valer em todos os ciclos seguintes. O
    // caso do operador que liga uma bomba em solo ja encharcado e avisado no
    // proprio comando, em avaliarComandoManual.
    if (bomba.ligada && bomba.origemUltimoAcionamento == Origem.operador) {
      if (talhao.umidade >= Limiares.umidadeSegura &&
          talhao.umidade - Limiares.ganhoUmidadePorTick <
              Limiares.umidadeSegura) {
        eventos.add(_alertaDesperdicio(talhao, agora,
            'e a irrigação manual continua ligada'));
      }
      bombas.add(bomba);
      continue;
    }

    // RN05: so o proprio sistema encerra o que o sistema ligou.
    if (bomba.ligada &&
        bomba.origemUltimoAcionamento == Origem.sistema &&
        talhao.umidade >= Limiares.umidadeSegura) {
      eventos.add(Evento(
        hora: agora,
        tipo: TipoEvento.irrigacaoEncerrada,
        origem: Origem.sistema,
        descricao: 'Irrigação encerrada em ${talhao.nome}',
        motivo: 'Umidade atingiu o patamar de segurança de '
            '${Limiares.umidadeSegura.toStringAsFixed(0)}%',
      ));
      bombas.add(bomba.copiarCom(ligada: false));
      continue;
    }

    bombas.add(bomba);
  }

  return Decisao(estado.copiarCom(bombas: bombas), eventos);
}

Evento _alertaDesperdicio(Talhao talhao, DateTime agora, String complemento) =>
    Evento(
      hora: agora,
      tipo: TipoEvento.alertaDesperdicio,
      origem: Origem.sistema,
      descricao: 'Desperdício em ${talhao.nome}',
      motivo: 'Umidade em ${talhao.umidade.toStringAsFixed(1)}% ja passou do '
          'patamar de segurança de '
          '${Limiares.umidadeSegura.toStringAsFixed(0)}% $complemento',
    );

/// Um ciclo completo da simulacao, na ordem obrigatoria do capitulo 2.
///
/// sensores, depois seguranca hidrica, e so entao irrigacao. A ordem e o que
/// materializa RN07: com o reservatorio critico o bloqueio ja marcou o estado
/// antes de qualquer talhao seco ser considerado.
Decisao executarCiclo(Telemetria estado, DateTime agora) {
  final aposSensores = atualizarSensores(estado, agora);
  final aposBloqueio = avaliarBloqueioHidrico(aposSensores, agora);
  final aposIrrigacao = avaliarIrrigacaoCritica(aposBloqueio.telemetria, agora);
  return Decisao(
    aposIrrigacao.telemetria,
    [...aposBloqueio.eventos, ...aposIrrigacao.eventos],
  );
}

/// RN08: comando manual do operador, recusado durante o bloqueio.
///
/// A recusa e decidida aqui, no dominio do servidor, e nao na interface. O
/// botao desabilitado no aplicativo e conveniencia, esta funcao e a garantia.
Decisao avaliarComandoManual(
  Telemetria estado,
  String bombaId,
  bool ligar,
  DateTime agora,
) {
  if (ligar && estado.reservatorio.bloqueioAtivo) {
    final motivo = 'Bloqueio de emergência ativo: reservatório em '
        '${estado.reservatorio.nivel.toStringAsFixed(1)}%. Nenhuma bomba pode '
        'ser acionada até o nível voltar acima de '
        '${Limiares.reservatorioSeguro.toStringAsFixed(0)}%.';
    return Decisao(
      estado,
      [
        Evento(
          hora: agora,
          tipo: TipoEvento.comandoRecusado,
          origem: Origem.operador,
          descricao: 'Acionamento da bomba $bombaId recusado',
          motivo: motivo,
        )
      ],
      motivoRecusa: motivo,
    );
  }

  final eventos = [
    Evento(
      hora: agora,
      tipo: TipoEvento.comandoAceito,
      origem: Origem.operador,
      descricao: 'Bomba $bombaId ${ligar ? 'ligada' : 'desligada'} manualmente',
      motivo: 'Comando do operador',
    )
  ];

  // RN05: ligar uma bomba em solo que ja passou do patamar de seguranca e
  // desperdicio desde o primeiro ciclo. O sistema avisa aqui, uma vez, e nao
  // impede nada.
  if (ligar) {
    final bomba = estado.bombas.where((b) => b.id == bombaId).firstOrNull;
    final talhao =
        estado.talhoes.where((t) => t.id == bomba?.talhaoId).firstOrNull;
    if (talhao != null && talhao.umidade >= Limiares.umidadeSegura) {
      eventos.add(_alertaDesperdicio(
          talhao, agora, 'e o operador ligou a irrigação mesmo assim'));
    }
  }

  return Decisao(
    estado.copiarCom(bombas: [
      for (final bomba in estado.bombas)
        bomba.id == bombaId
            ? bomba.copiarCom(
                ligada: ligar, origemUltimoAcionamento: Origem.operador)
            : bomba,
    ]),
    eventos,
  );
}
