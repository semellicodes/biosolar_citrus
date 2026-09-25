library;

import 'package:compartilhado/modelos.dart';

class Decisao {
  const Decisao(this.telemetria, this.eventos, {this.motivoRecusa});

  final Telemetria telemetria;
  final List<Evento> eventos;
  final String? motivoRecusa;

  bool get aceito => motivoRecusa == null;
}

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

double _variacaoDaUmidade({required bool irrigando, required bool chovendo}) {
  if (irrigando) return Limiares.ganhoUmidadePorTick;
  if (chovendo) return Limiares.ganhoChuvaPorTick;
  return -Limiares.quedaUmidadePorTick;
}

double _captacaoDeChuva(Telemetria estado) {
  if (!estado.chovendo) return 0;
  final espaco =
      Limiares.tetoChuvaReservatorio - estado.reservatorio.nivel;
  if (espaco <= 0) return 0;
  return espaco < Limiares.captacaoChuvaPorTick
      ? espaco
      : Limiares.captacaoChuvaPorTick;
}

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

Decisao avaliarBloqueioHidrico(Telemetria estado, DateTime agora) {
  final reservatorio = estado.reservatorio;
  final eventos = <Evento>[];

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

  return Decisao(estado, eventos);
}

Decisao avaliarIrrigacaoCritica(Telemetria estado, DateTime agora) {

  if (estado.reservatorio.bloqueioAtivo) return Decisao(estado, const []);

  final eventos = <Evento>[];
  final bombas = <Bomba>[];

  for (final bomba in estado.bombas) {
    final talhao = estado.talhoes.firstWhere((t) => t.id == bomba.talhaoId);

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

Decisao executarCiclo(Telemetria estado, DateTime agora) {
  final aposSensores = atualizarSensores(estado, agora);
  final aposBloqueio = avaliarBloqueioHidrico(aposSensores, agora);
  final aposIrrigacao = avaliarIrrigacaoCritica(aposBloqueio.telemetria, agora);
  return Decisao(
    aposIrrigacao.telemetria,
    [...aposBloqueio.eventos, ...aposIrrigacao.eventos],
  );
}

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
