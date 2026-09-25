library;

import 'dart:math' as math;

enum Faixa { verde, amarelo, vermelho }

enum Origem { operador, sistema }

enum TipoEvento {
  irrigacaoIniciada,
  irrigacaoEncerrada,
  bloqueioAtivado,
  bloqueioLiberado,
  comandoAceito,
  comandoRecusado,
  alertaDesperdicio,
  chuvaIniciada,
  chuvaEncerrada,
  simulacaoReiniciada,
  velocidadeAlterada,
  simulacaoPausada,
}

class Limiares {

  static const double umidadeCritica = 25;

  static const double umidadeSegura = 45;

  static const double umidadeAtencao = 35;

  static const double reservatorioCritico = 15;

  static const double reservatorioSeguro = 25;

  static const double reservatorioAtencao = 40;

  static const double quedaUmidadePorTick = 1.2;

  static const double ganhoUmidadePorTick = 3.0;

  static const double consumoPorBombaPorTick = 0.40;

  static const double recargaSolarPico = 1.5;

  static const double horasPorTick = 0.25;

  static const double amanhecer = 6;
  static const double anoitecer = 18;

  static const double ganhoChuvaPorTick = 1.5;

  static const double captacaoChuvaPorTick = 1.2;

  static const double tetoChuvaReservatorio = 70;
}

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

  final double umidade;

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

  final double nivel;
  final double capacidadeLitros;

  final bool bloqueioAtivo;

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

class Telemetria {
  const Telemetria({
    required this.reservatorio,
    required this.talhoes,
    required this.bombas,
    required this.hora,
    this.horaSimulada = Limiares.amanhecer,
    this.chovendo = false,
  });

  final Reservatorio reservatorio;
  final List<Talhao> talhoes;
  final List<Bomba> bombas;

  final DateTime hora;

  final double horaSimulada;

  double get fatorSolarAtual => fatorSolar(horaSimulada);

  final bool chovendo;

  Bomba bombaDo(String talhaoId) =>
      bombas.firstWhere((b) => b.talhaoId == talhaoId);

  Telemetria copiarCom({
    Reservatorio? reservatorio,
    List<Talhao>? talhoes,
    List<Bomba>? bombas,
    DateTime? hora,
    double? horaSimulada,
    bool? chovendo,
  }) =>
      Telemetria(
        reservatorio: reservatorio ?? this.reservatorio,
        talhoes: talhoes ?? this.talhoes,
        bombas: bombas ?? this.bombas,
        hora: hora ?? this.hora,
        horaSimulada: horaSimulada ?? this.horaSimulada,
        chovendo: chovendo ?? this.chovendo,
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
        chovendo: json['chovendo'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'reservatorio': reservatorio.toJson(),
        'talhoes': talhoes.map((e) => e.toJson()).toList(),
        'bombas': bombas.map((e) => e.toJson()).toList(),
        'hora': hora.toIso8601String(),
        'horaSimulada': horaSimulada,
        'fatorSolar': fatorSolarAtual,
        'chovendo': chovendo,
      };
}
