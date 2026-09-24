/// Motor de regras do BioSolar Citrus, RN01 ate RN12.
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

/// RN01, RN02 e RN03: avanco fisico da simulacao.
///
/// A umidade cai nos talhoes sem aspersor e sobe nos irrigados. O reservatorio
/// perde agua proporcionalmente ao numero de bombas ligadas e nao se altera
/// quando todas estao desligadas.
Telemetria atualizarSensores(Telemetria estado, DateTime agora) {
  final talhoes = [
    for (final talhao in estado.talhoes)
      talhao.copiarCom(
        umidade: estado.bombaDo(talhao.id).ligada
            ? talhao.umidade + Limiares.ganhoUmidadePorTick // RN02
            : talhao.umidade - Limiares.quedaUmidadePorTick, // RN01
      ),
  ];

  // RN03
  final bombasLigadas = estado.bombas.where((b) => b.ligada).length;
  final reservatorio = estado.reservatorio.copiarCom(
    nivel: estado.reservatorio.nivel -
        bombasLigadas * Limiares.consumoPorBombaPorTick,
  );

  return estado.copiarCom(
    talhoes: talhoes,
    reservatorio: reservatorio,
    hora: agora,
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
        descricao: 'Bloqueio de emergencia ativado',
        motivo: 'Reservatorio em ${reservatorio.nivel.toStringAsFixed(1)}%, '
            'abaixo do limite critico de '
            '${Limiares.reservatorioCritico.toStringAsFixed(0)}%',
      ));
    }
    for (final bomba in bombasLigadas) {
      eventos.add(Evento(
        hora: agora,
        tipo: TipoEvento.irrigacaoEncerrada,
        origem: Origem.sistema,
        descricao: 'Bomba ${bomba.id} desligada',
        motivo: 'Bloqueio de emergencia hidrico',
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
      descricao: 'Bloqueio de emergencia liberado',
      motivo: 'Reservatorio recuperou para '
          '${reservatorio.nivel.toStringAsFixed(1)}%, acima do patamar de '
          'seguranca de ${Limiares.reservatorioSeguro.toStringAsFixed(0)}%',
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
        descricao: 'Irrigacao iniciada em ${talhao.nome}',
        motivo: 'Umidade em ${talhao.umidade.toStringAsFixed(1)}%, abaixo do '
            'gatilho critico de '
            '${Limiares.umidadeCritica.toStringAsFixed(0)}%',
      ));
      bombas.add(
          bomba.copiarCom(ligada: true, origemUltimoAcionamento: Origem.sistema));
      continue;
    }

    // RN05: so o proprio sistema encerra o que o sistema ligou. Uma bomba
    // acionada pelo operador continua sob responsabilidade dele.
    if (bomba.ligada &&
        bomba.origemUltimoAcionamento == Origem.sistema &&
        talhao.umidade >= Limiares.umidadeSegura) {
      eventos.add(Evento(
        hora: agora,
        tipo: TipoEvento.irrigacaoEncerrada,
        origem: Origem.sistema,
        descricao: 'Irrigacao encerrada em ${talhao.nome}',
        motivo: 'Umidade atingiu o patamar de seguranca de '
            '${Limiares.umidadeSegura.toStringAsFixed(0)}%',
      ));
      bombas.add(bomba.copiarCom(ligada: false));
      continue;
    }

    bombas.add(bomba);
  }

  return Decisao(estado.copiarCom(bombas: bombas), eventos);
}

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
    final motivo = 'Bloqueio de emergencia ativo: reservatorio em '
        '${estado.reservatorio.nivel.toStringAsFixed(1)}%. Nenhuma bomba pode '
        'ser acionada ate o nivel voltar acima de '
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

  return Decisao(
    estado.copiarCom(bombas: [
      for (final bomba in estado.bombas)
        bomba.id == bombaId
            ? bomba.copiarCom(
                ligada: ligar, origemUltimoAcionamento: Origem.operador)
            : bomba,
    ]),
    [
      Evento(
        hora: agora,
        tipo: TipoEvento.comandoAceito,
        origem: Origem.operador,
        descricao: 'Bomba $bombaId ${ligar ? 'ligada' : 'desligada'} '
            'manualmente',
        motivo: 'Comando do operador',
      )
    ],
  );
}
