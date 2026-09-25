/// Contratos de dados falados pelo servidor e pelo aplicativo.
///
/// Dart puro: nada de Flutter, de cliente HTTP ou de framework aqui.
library;

import 'dart:math' as math;

/// Faixa de alerta cromatica de um indicador (RN10).
enum Faixa { verde, amarelo, vermelho }

/// Quem originou uma acao registrada no historico (RN11).
enum Origem { operador, sistema }

enum TipoEvento {
  irrigacaoIniciada,
  irrigacaoEncerrada,
  bloqueioAtivado,
  bloqueioLiberado,
  comandoAceito,
  comandoRecusado,
  alertaDesperdicio,
  simulacaoReiniciada,
  velocidadeAlterada,
}

/// Limiares que definem o comportamento da simulacao.
///
/// Ficam no compartilhado porque tanto o servidor (para decidir) quanto o
/// aplicativo (para rotular faixas) precisam falar dos mesmos numeros. Decidir
/// continua sendo exclusividade do servidor.
class Limiares {
  /// RN04: abaixo disso o aspersor do talhao e acionado automaticamente.
  static const double umidadeCritica = 25;

  /// RN05: patamar de seguranca que encerra a irrigacao automatica. Fica acima
  /// do gatilho de proposito, para criar histerese e evitar liga e desliga.
  static const double umidadeSegura = 45;

  /// Fronteira entre a faixa amarela e a verde de um talhao.
  static const double umidadeAtencao = 35;

  /// RN06: abaixo disso o bloqueio de emergencia e ativado.
  static const double reservatorioCritico = 15;

  /// RN09: o bloqueio so e liberado quando o nivel volta acima disso.
  static const double reservatorioSeguro = 25;

  /// Fronteira entre a faixa amarela e a verde do reservatorio.
  static const double reservatorioAtencao = 40;

  /// RN01: queda natural da umidade por ciclo, em pontos percentuais.
  static const double quedaUmidadePorTick = 1.2;

  /// RN02: recuperacao da umidade por ciclo com aspersor ligado.
  static const double ganhoUmidadePorTick = 3.0;

  /// RN03: consumo do reservatorio por bomba ligada, por ciclo.
  static const double consumoPorBombaPorTick = 0.40;

  /// RN12: vazao maxima da captacao solar, no pico do dia.
  ///
  /// Calibrado logo abaixo do consumo com as quatro bombas ligadas, que e
  /// 4 x 0,40 = 1,60. No pico do sol, portanto, irrigar tudo ao mesmo tempo
  /// ainda derruba o reservatorio, e o bloqueio continua sendo possivel.
  ///
  /// Mas a captacao e nula a noite e a irrigacao e intermitente, entao na media
  /// do dia ela cobre a manutencao dos quatro talhoes: a fazenda se paga sem
  /// deixar de ser vulneravel a irrigacao plena. O T13 prova esse equilibrio.
  // ponytail: numero de calibragem. Subir se o sistema nao se recuperar depois
  // do bloqueio, baixar se o bloqueio deixar de acontecer.
  static const double recargaSolarPico = 1.5;

  /// Quanto o relogio da fazenda avanca a cada ciclo. Um dia inteiro leva 96
  /// ciclos, cerca de meio minuto no modo demonstracao.
  static const double horasPorTick = 0.25;

  static const double amanhecer = 6;
  static const double anoitecer = 18;
}

/// Intensidade da geracao solar em uma hora do dia, de 0 a 1.
///
/// Zero antes do amanhecer e depois do anoitecer, pico ao meio dia. E a mesma
/// curva usada pela captacao de agua (RN12) e pelo balanco energetico (F08).
double fatorSolar(double hora) {
  if (hora <= Limiares.amanhecer || hora >= Limiares.anoitecer) return 0;
  return math.sin(math.pi *
      (hora - Limiares.amanhecer) /
      (Limiares.anoitecer - Limiares.amanhecer));
}

double _limitar(double v) => v < 0 ? 0 : (v > 100 ? 100 : v);

class Talhao {
  const Talhao({
    required this.id,
    required this.nome,
    required this.cultura,
    required this.umidade,
  });

  final String id;
  final String nome;
  final String cultura;

  /// Umidade do solo em percentual, de 0 a 100.
  final double umidade;

  /// RN10: faixa de alerta derivada da umidade atual.
  Faixa get faixa => umidade < Limiares.umidadeCritica
      ? Faixa.vermelho
      : umidade < Limiares.umidadeAtencao
          ? Faixa.amarelo
          : Faixa.verde;

  Talhao copiarCom({double? umidade}) => Talhao(
        id: id,
        nome: nome,
        cultura: cultura,
        umidade: _limitar(umidade ?? this.umidade),
      );

  factory Talhao.fromJson(Map<String, dynamic> json) => Talhao(
        id: json['id'] as String,
        nome: json['nome'] as String,
        cultura: json['cultura'] as String,
        umidade: (json['umidade'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'cultura': cultura,
        'umidade': umidade,
        'faixa': faixa.name,
      };
}

class Bomba {
  const Bomba({
    required this.id,
    required this.talhaoId,
    required this.ligada,
    this.origemUltimoAcionamento,
  });

  final String id;
  final String talhaoId;
  final bool ligada;

  /// RN11: quem foi responsavel pelo ultimo acionamento desta bomba.
  final Origem? origemUltimoAcionamento;

  Bomba copiarCom({bool? ligada, Origem? origemUltimoAcionamento}) => Bomba(
        id: id,
        talhaoId: talhaoId,
        ligada: ligada ?? this.ligada,
        origemUltimoAcionamento:
            origemUltimoAcionamento ?? this.origemUltimoAcionamento,
      );

  factory Bomba.fromJson(Map<String, dynamic> json) => Bomba(
        id: json['id'] as String,
        talhaoId: json['talhaoId'] as String,
        ligada: json['ligada'] as bool,
        origemUltimoAcionamento: json['origemUltimoAcionamento'] == null
            ? null
            : Origem.values.byName(json['origemUltimoAcionamento'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'talhaoId': talhaoId,
        'ligada': ligada,
        'origemUltimoAcionamento': origemUltimoAcionamento?.name,
      };
}

class Reservatorio {
  const Reservatorio({
    required this.nivel,
    required this.capacidadeLitros,
    required this.bloqueioAtivo,
  });

  /// Nivel atual em percentual, de 0 a 100.
  final double nivel;
  final double capacidadeLitros;

  /// RN06: enquanto verdadeiro nenhuma bomba pode operar.
  final bool bloqueioAtivo;

  /// RN10: faixa de alerta derivada do nivel atual.
  Faixa get faixa => nivel < Limiares.reservatorioCritico
      ? Faixa.vermelho
      : nivel < Limiares.reservatorioAtencao
          ? Faixa.amarelo
          : Faixa.verde;

  Reservatorio copiarCom({double? nivel, bool? bloqueioAtivo}) => Reservatorio(
        nivel: _limitar(nivel ?? this.nivel),
        capacidadeLitros: capacidadeLitros,
        bloqueioAtivo: bloqueioAtivo ?? this.bloqueioAtivo,
      );

  factory Reservatorio.fromJson(Map<String, dynamic> json) => Reservatorio(
        nivel: (json['nivel'] as num).toDouble(),
        capacidadeLitros: (json['capacidadeLitros'] as num).toDouble(),
        bloqueioAtivo: json['bloqueioAtivo'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'nivel': nivel,
        'capacidadeLitros': capacidadeLitros,
        'bloqueioAtivo': bloqueioAtivo,
        'faixa': faixa.name,
      };
}

class Evento {
  const Evento({
    required this.hora,
    required this.tipo,
    required this.origem,
    required this.descricao,
    required this.motivo,
  });

  final DateTime hora;
  final TipoEvento tipo;
  final Origem origem;
  final String descricao;
  final String motivo;

  factory Evento.fromJson(Map<String, dynamic> json) => Evento(
        hora: DateTime.parse(json['hora'] as String),
        tipo: TipoEvento.values.byName(json['tipo'] as String),
        origem: Origem.values.byName(json['origem'] as String),
        descricao: json['descricao'] as String,
        motivo: json['motivo'] as String,
      );

  Map<String, dynamic> toJson() => {
        'hora': hora.toIso8601String(),
        'tipo': tipo.name,
        'origem': origem.name,
        'descricao': descricao,
        'motivo': motivo,
      };
}

/// Estado completo da fazenda em um instante. E o que trafega no GET
/// /telemetria e no WS /stream.
class Telemetria {
  const Telemetria({
    required this.reservatorio,
    required this.talhoes,
    required this.bombas,
    required this.hora,
    this.horaSimulada = Limiares.amanhecer,
  });

  final Reservatorio reservatorio;
  final List<Talhao> talhoes;
  final List<Bomba> bombas;

  /// Instante real da leitura.
  final DateTime hora;

  /// Hora do dia na fazenda simulada, de 0 a 24. E ela que define a curva
  /// solar, e nao o relogio do servidor, para que a demonstracao funcione a
  /// qualquer hora em que a banca assistir.
  final double horaSimulada;

  double get fatorSolarAtual => fatorSolar(horaSimulada);

  Bomba bombaDo(String talhaoId) =>
      bombas.firstWhere((b) => b.talhaoId == talhaoId);

  Telemetria copiarCom({
    Reservatorio? reservatorio,
    List<Talhao>? talhoes,
    List<Bomba>? bombas,
    DateTime? hora,
    double? horaSimulada,
  }) =>
      Telemetria(
        reservatorio: reservatorio ?? this.reservatorio,
        talhoes: talhoes ?? this.talhoes,
        bombas: bombas ?? this.bombas,
        hora: hora ?? this.hora,
        horaSimulada: horaSimulada ?? this.horaSimulada,
      );

  factory Telemetria.fromJson(Map<String, dynamic> json) => Telemetria(
        reservatorio:
            Reservatorio.fromJson(json['reservatorio'] as Map<String, dynamic>),
        talhoes: (json['talhoes'] as List)
            .map((e) => Talhao.fromJson(e as Map<String, dynamic>))
            .toList(),
        bombas: (json['bombas'] as List)
            .map((e) => Bomba.fromJson(e as Map<String, dynamic>))
            .toList(),
        hora: DateTime.parse(json['hora'] as String),
        horaSimulada: (json['horaSimulada'] as num?)?.toDouble() ??
            Limiares.amanhecer,
      );

  Map<String, dynamic> toJson() => {
        'reservatorio': reservatorio.toJson(),
        'talhoes': talhoes.map((e) => e.toJson()).toList(),
        'bombas': bombas.map((e) => e.toJson()).toList(),
        'hora': hora.toIso8601String(),
        'horaSimulada': horaSimulada,
        'fatorSolar': fatorSolarAtual,
      };
}
