/// Painel de monitoramento. Só desenha e envia comandos.
///
/// Nenhuma decisão de automação acontece aqui: as faixas de alerta vêm
/// calculadas do servidor e a recusa de comando vem com a mensagem que o
/// servidor devolveu.
library;

import 'package:compartilhado/modelos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../nucleo/tema.dart';
import '../../eventos/apresentacao/tela_eventos.dart';
import 'comando_bloc.dart';
import 'telemetria_bloc.dart';

/// Cortes de layout. Abaixo do primeiro é coluna única de celular; entre os
/// dois, os talhões viram grade de duas colunas; acima do segundo, o
/// reservatório ocupa a faixa superior inteira e os talhões vão para três.
const double _corteMedio = 700;
const double _corteLargo = 1100;

class TelaMonitoramento extends StatelessWidget {
  const TelaMonitoramento({super.key});

  @override
  Widget build(BuildContext context) {
    final telemetriaBloc = context.read<TelemetriaBloc>();

    return BlocListener<ComandoBloc, EstadoComando>(
      listener: (context, estado) => switch (estado) {
        ComandoAceito(:final telemetria) =>
          telemetriaBloc.add(TelemetriaRecebida(telemetria)),
        ComandoRecusado(:final mensagem) => _avisar(context, mensagem),
        ComandoFalhou(:final mensagem) => _avisar(context, mensagem),
        _ => null,
      },
      child: BlocBuilder<TelemetriaBloc, EstadoTelemetria>(
        builder: (context, estado) => _Painel(
          telemetria: estado.ultima,
          desconectado: estado is TelemetriaDesconectada,
          emTempoReal: estado is TelemetriaCarregada && estado.emTempoReal,
        ),
      ),
    );
  }

  void _avisar(BuildContext context, String mensagem) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Cores.vermelho,
        behavior: SnackBarBehavior.floating,
        width: 520,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Espaco.p)),
        content: Text(mensagem,
            style: Fontes.corpo(Colors.white).copyWith(height: 1.3)),
        duration: const Duration(seconds: 6),
      ));
}

class _Painel extends StatelessWidget {
  const _Painel({
    required this.telemetria,
    required this.desconectado,
    required this.emTempoReal,
  });

  final Telemetria? telemetria;
  final bool desconectado;
  final bool emTempoReal;

  @override
  Widget build(BuildContext context) {
    final comandos = context.read<ComandoBloc>();
    final telemetria = this.telemetria;
    final faixa = telemetria?.reservatorio.faixa ?? Faixa.verde;
    final bloqueado = telemetria?.reservatorio.bloqueioAtivo ?? false;

    return Scaffold(
      body: Stack(children: [
        // A temperatura da tela inteira acompanha o estado do reservatório.
        // Gradiente radial no lugar de blur real: mesmo efeito, sem o custo de
        // desfoque a cada quadro no Android.
        _Brilho(cor: Cores.da(faixa)),
        SafeArea(
          child: LayoutBuilder(builder: (context, limites) {
            final largura = limites.maxWidth;
            final colunas = largura >= _corteLargo
                ? 3
                : largura >= _corteMedio
                    ? 2
                    : 1;
            final largo = largura >= _corteLargo;

            if (telemetria == null) {
              return Center(
                child: desconectado
                    ? Text('Sem contato com o servidor. Tentando de novo...',
                        style: Fontes.corpo(Cores.textoFraco))
                    : const CircularProgressIndicator(color: Cores.verde),
              );
            }

            final util = largura - Espaco.g * 2;
            final larguraCartao =
                (util - Espaco.m * (colunas - 1)) / colunas;

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                  Espaco.g, Espaco.m, Espaco.g, Espaco.xg),
              children: [
                _Cabecalho(
                  desconectado: desconectado,
                  emTempoReal: emTempoReal,
                  aoAbrirHistorico: () =>
                      Navigator.of(context).pushNamed(TelaEventos.rota),
                  aoAcelerar: () => comandos
                      .add(const VelocidadeSolicitada(acelerada: true)),
                  aoNormalizar: () => comandos
                      .add(const VelocidadeSolicitada(acelerada: false)),
                  aoReiniciar: () => comandos.add(const ReinicioSolicitado()),
                ),
                const SizedBox(height: Espaco.g),
                if (desconectado)
                  _Faixa(
                    icone: Icons.cloud_off_outlined,
                    cor: Cores.textoFraco,
                    titulo: 'SEM CONTATO COM O SERVIDOR',
                    texto: 'Dados defasados, parados na leitura das '
                        '${_hora(telemetria.hora)}. Reconectando.',
                  ),
                if (bloqueado)
                  _Faixa(
                    icone: Icons.block_outlined,
                    cor: Cores.vermelho,
                    titulo: 'BLOQUEIO DE EMERGÊNCIA',
                    texto:
                        'Reservatório crítico. Nenhuma bomba pode ser acionada.',
                    acao: 'Tentar mesmo assim',
                    aoAgir: () => comandos.add(AcionamentoSolicitado(
                        telemetria.bombas.first.id,
                        ligar: true)),
                  ),
                _CartaoReservatorio(telemetria: telemetria, largo: largo),
                const SizedBox(height: Espaco.xg),
                Padding(
                  padding:
                      const EdgeInsets.only(left: Espaco.xs, bottom: Espaco.m),
                  child: Text('TALHÕES', style: Fontes.rotulo(Cores.textoFraco)),
                ),
                Wrap(
                  spacing: Espaco.m,
                  runSpacing: Espaco.m,
                  children: [
                    for (final talhao in telemetria.talhoes)
                      SizedBox(
                        width: larguraCartao,
                        child: _LinhaTalhao(
                          talhao: talhao,
                          bomba: telemetria.bombaDo(talhao.id),
                          // RF11. O servidor recusa de qualquer jeito (RN08);
                          // travar aqui é conveniência, não segurança.
                          travado: bloqueado || desconectado,
                          aoAlternar: (bomba, ligar) => comandos.add(
                              AcionamentoSolicitado(bomba.id, ligar: ligar)),
                        ),
                      ),
                  ],
                ),
              ],
            );
          }),
        ),
      ]),
    );
  }
}

String _hora(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}:'
    '${d.second.toString().padLeft(2, '0')}';

class _Brilho extends StatelessWidget {
  const _Brilho({required this.cor});

  final Color cor;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Stack(children: [
          for (final (alinhamento, escala) in const [
            (Alignment(-0.9, -0.85), 0.9),
            (Alignment(1.1, -0.35), 0.7),
          ])
            Align(
              alignment: alinhamento,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                width: MediaQuery.sizeOf(context).width * escala,
                height: MediaQuery.sizeOf(context).width * escala,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    cor.withValues(alpha: 0.22),
                    cor.withValues(alpha: 0),
                  ]),
                ),
              ),
            ),
        ]),
      );
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({
    required this.desconectado,
    required this.emTempoReal,
    required this.aoAbrirHistorico,
    required this.aoAcelerar,
    required this.aoNormalizar,
    required this.aoReiniciar,
  });

  final bool desconectado;
  final bool emTempoReal;
  final VoidCallback aoAbrirHistorico;
  final VoidCallback aoAcelerar;
  final VoidCallback aoNormalizar;
  final VoidCallback aoReiniciar;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BioSolar Citrus',
                  style: Fontes.titulo(Cores.texto, tamanho: 22)),
              const SizedBox(height: Espaco.p),
              _Conexao(desconectado: desconectado, emTempoReal: emTempoReal),
            ],
          ),
        ),
        _Botao(Icons.history_outlined, 'Histórico', aoAbrirHistorico),
        _Botao(Icons.fast_forward_outlined, 'Modo demonstração', aoAcelerar),
        _Botao(
            Icons.slow_motion_video_outlined, 'Velocidade normal', aoNormalizar),
        _Botao(Icons.restart_alt_outlined, 'Reiniciar cenário', aoReiniciar),
      ]);
}

class _Botao extends StatelessWidget {
  const _Botao(this.icone, this.dica, this.aoTocar);

  final IconData icone;
  final String dica;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: dica,
        onPressed: aoTocar,
        icon: Icon(icone, size: 20, color: Cores.textoFraco),
        visualDensity: VisualDensity.compact,
      );
}

/// Ponto que pulsa devagar enquanto o canal está de pé. Ele não mente: quando
/// quem entrega as leituras é a consulta de reserva, o rótulo muda.
class _Conexao extends StatefulWidget {
  const _Conexao({required this.desconectado, required this.emTempoReal});

  final bool desconectado;
  final bool emTempoReal;

  @override
  State<_Conexao> createState() => _ConexaoState();
}

class _ConexaoState extends State<_Conexao>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (cor, rotulo) = switch ((widget.desconectado, widget.emTempoReal)) {
      (true, _) => (Cores.vermelho, 'SEM CONTATO'),
      (false, true) => (Cores.verde, 'AO VIVO'),
      (false, false) => (Cores.ambar, 'CONSULTA DE RESERVA'),
    };

    return Row(mainAxisSize: MainAxisSize.min, children: [
      FadeTransition(
        opacity: widget.desconectado
            ? const AlwaysStoppedAnimation(1.0)
            : Tween<double>(begin: 0.3, end: 1).animate(_pulso),
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
        ),
      ),
      const SizedBox(width: Espaco.p),
      Text(rotulo, style: Fontes.rotulo(cor)),
    ]);
  }
}

class _Faixa extends StatelessWidget {
  const _Faixa({
    required this.icone,
    required this.cor,
    required this.titulo,
    required this.texto,
    this.acao,
    this.aoAgir,
  });

  final IconData icone;
  final Color cor;
  final String titulo;
  final String texto;
  final String? acao;
  final VoidCallback? aoAgir;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: Espaco.m),
        padding: const EdgeInsets.all(Espaco.m),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Espaco.m),
          border: Border.all(color: cor.withValues(alpha: 0.45)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icone, color: cor, size: 20),
          const SizedBox(width: Espaco.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: Fontes.rotulo(cor)),
                const SizedBox(height: Espaco.xs),
                Text(texto, style: Fontes.corpo(Cores.texto)),
              ],
            ),
          ),
          if (acao != null) ...[
            const SizedBox(width: Espaco.p),
            TextButton(
              onPressed: aoAgir,
              style: TextButton.styleFrom(
                foregroundColor: cor,
                padding: const EdgeInsets.symmetric(horizontal: Espaco.m),
              ),
              child: Text(acao!, style: Fontes.titulo(cor, tamanho: 13)),
            ),
          ],
        ]),
      );
}

/// O reservatório é o protagonista da narrativa, então ele é visivelmente
/// maior que o resto: raio, respiro e tipografia próprios.
class _CartaoReservatorio extends StatelessWidget {
  const _CartaoReservatorio({required this.telemetria, required this.largo});

  final Telemetria telemetria;
  final bool largo;

  @override
  Widget build(BuildContext context) {
    final reservatorio = telemetria.reservatorio;
    final cor = Cores.da(reservatorio.faixa);

    final numero = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Text('RESERVATÓRIO', style: Fontes.rotulo(Cores.textoFraco)),
          const SizedBox(width: Espaco.m),
          Etiqueta(rotulos[reservatorio.faixa]!, cor),
        ]),
        const SizedBox(height: Espaco.m),
        ValorAnimado(
            valor: reservatorio.nivel, cor: cor, tamanho: largo ? 88 : 68),
        const SizedBox(height: Espaco.m),
        BarraNivel(fracao: reservatorio.nivel / 100, cor: cor, altura: 10),
      ],
    );

    final arco = _ArcoSolar(telemetria: telemetria, altura: largo ? 96 : 56);

    return Container(
      padding: EdgeInsets.all(largo ? Espaco.xg : Espaco.g),
      decoration: BoxDecoration(
        color: Cores.superficie,
        // Raio maior que o dos talhões, de propósito.
        borderRadius: BorderRadius.circular(Espaco.g),
        border: Border.all(color: cor.withValues(alpha: 0.28)),
      ),
      child: largo
          ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              SizedBox(width: 380, child: numero),
              const SizedBox(width: Espaco.xg),
              Expanded(child: arco),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              numero,
              const SizedBox(height: Espaco.g),
              arco,
            ]),
    );
  }
}

/// Posição do sol no dia da fazenda simulada. RN12: é esta curva que repõe o
/// reservatório, e é o único motivo de o bloqueio conseguir ser liberado.
class _ArcoSolar extends StatelessWidget {
  const _ArcoSolar({required this.telemetria, required this.altura});

  final Telemetria telemetria;
  final double altura;

  @override
  Widget build(BuildContext context) {
    final fator = telemetria.fatorSolarAtual;
    final noite = fator == 0;
    final cor = noite ? Cores.textoFraco : Cores.ambar;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(noite ? Icons.nightlight_outlined : Icons.wb_sunny_outlined,
            size: 15, color: cor),
        const SizedBox(width: Espaco.p),
        Text('CAPTAÇÃO SOLAR', style: Fontes.rotulo(Cores.textoFraco)),
        const Spacer(),
        Text(
          noite
              ? 'NOITE, CAPTAÇÃO PARADA'
              : '${(fator * 100).round()}%  ·  ${telemetria.horaSimulada.floor().toString().padLeft(2, '0')}H',
          style: Fontes.rotulo(cor),
        ),
      ]),
      const SizedBox(height: Espaco.m),
      SizedBox(
        height: altura,
        width: double.infinity,
        child: CustomPaint(
          painter:
              _PintorArco(hora: telemetria.horaSimulada, ativo: !noite),
        ),
      ),
    ]);
  }
}

class _PintorArco extends CustomPainter {
  const _PintorArco({required this.hora, required this.ativo});

  final double hora;
  final bool ativo;

  @override
  void paint(Canvas canvas, Size size) {
    final cor = ativo ? Cores.ambar : Cores.textoFraco;

    // Meia elipse do amanhecer ao anoitecer, com a linha do horizonte.
    final caminho = Path()
      ..moveTo(0, size.height)
      ..arcToPoint(Offset(size.width, size.height),
          radius: Radius.elliptical(size.width / 2, size.height),
          clockwise: true);

    canvas
      ..drawLine(
        Offset(0, size.height),
        Offset(size.width, size.height),
        Paint()
          ..color = Cores.borda
          ..strokeWidth = 1,
      )
      ..drawPath(
        caminho,
        Paint()
          ..color = cor.withValues(alpha: 0.32)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

    final progresso = ((hora - Limiares.amanhecer) /
            (Limiares.anoitecer - Limiares.amanhecer))
        .clamp(0.0, 1.0);
    final angulo = 3.14159265 * progresso;
    final centro = Offset(
      size.width / 2 - (size.width / 2) * _cos(angulo),
      size.height - size.height * _sin(angulo),
    );

    if (ativo) {
      canvas.drawCircle(
          centro, 14, Paint()..color = cor.withValues(alpha: 0.20));
    }
    canvas.drawCircle(centro, 6, Paint()..color = cor);
  }

  static double _cos(double x) => _sin(x + 1.5707963);

  /// Aproximação de Bhaskara: suficiente para posicionar um ponto e evitar
  /// importar dart:math só para isto.
  static double _sin(double x) {
    while (x < 0) {
      x += 6.2831853;
    }
    while (x > 6.2831853) {
      x -= 6.2831853;
    }
    final negativo = x > 3.1415927;
    if (negativo) x -= 3.1415927;
    final valor = 16 * x * (3.1415927 - x) /
        (5 * 3.1415927 * 3.1415927 - 4 * x * (3.1415927 - x));
    return negativo ? -valor : valor;
  }

  @override
  bool shouldRepaint(_PintorArco anterior) =>
      anterior.hora != hora || anterior.ativo != ativo;
}

/// Talhão como linha densa de lista: número menor que o do reservatório, raio
/// menor, menos respiro. A hierarquia é o que separa protagonista de apoio.
class _LinhaTalhao extends StatelessWidget {
  const _LinhaTalhao({
    required this.talhao,
    required this.bomba,
    required this.travado,
    required this.aoAlternar,
  });

  final Talhao talhao;
  final Bomba bomba;
  final bool travado;
  final void Function(Bomba, bool) aoAlternar;

  /// Diz o tempo todo de quem partiu o que está acontecendo, que é a tese
  /// central do projeto: a autonomia mora no servidor.
  (String, Color, IconData) get _situacao {
    if (!bomba.ligada) {
      return ('Aguardando', Cores.textoFraco, Icons.pause_circle_outline);
    }
    return bomba.origemUltimoAcionamento == Origem.operador
        ? ('Acionado pelo operador', Cores.texto, Icons.person_outline)
        : ('Irrigação automática em curso', Cores.verde, Icons.bolt_outlined);
  }

  @override
  Widget build(BuildContext context) {
    final cor = Cores.da(talhao.faixa);
    final (situacao, corSituacao, icone) = _situacao;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Espaco.m, vertical: Espaco.m),
      decoration: BoxDecoration(
        color: Cores.superficie,
        borderRadius: BorderRadius.circular(Espaco.p + Espaco.xs),
        border: Border.all(color: Cores.borda),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(talhao.nome.toUpperCase(),
                style: Fontes.rotulo(Cores.textoFraco)),
          ),
          Etiqueta(rotulos[talhao.faixa]!, cor),
        ]),
        const SizedBox(height: Espaco.p),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            ValorAnimado(valor: talhao.umidade, cor: cor, tamanho: 30),
            const SizedBox(width: Espaco.p),
            Expanded(
              child: Text(talhao.cultura,
                  style: Fontes.corpo(Cores.textoFraco, tamanho: 12),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: Espaco.p),
        BarraNivel(fracao: talhao.umidade / 100, cor: cor),
        const SizedBox(height: Espaco.m),
        Row(children: [
          Icon(icone, size: 14, color: corSituacao),
          const SizedBox(width: Espaco.p - 2),
          Expanded(
            child: Text(situacao,
                style: Fontes.corpo(corSituacao, tamanho: 12),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: Espaco.p),
          Interruptor(
            ligado: bomba.ligada,
            travado: travado,
            aoAlternar: (ligar) => aoAlternar(bomba, ligar),
          ),
        ]),
      ]),
    );
  }
}
