/// Painel de monitoramento. So desenha e envia comandos.
///
/// Nenhuma decisao de automacao acontece aqui: as faixas de alerta vem
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
          emTempoReal:
              estado is TelemetriaCarregada && estado.emTempoReal,
        ),
      ),
    );
  }

  void _avisar(BuildContext context, String mensagem) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Cores.vermelho,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(Espaco.m),
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
        // A temperatura da tela inteira acompanha o estado do reservatorio.
        // Gradiente radial no lugar de blur real: mesmo efeito, sem o custo de
        // desfoque em cada quadro no Android.
        _Brilho(cor: Cores.da(faixa)),
        SafeArea(
          child: telemetria == null
              ? Center(
                  child: desconectado
                      ? Text('Sem contato com o servidor. Tentando de novo...',
                          style: Fontes.corpo(Cores.textoFraco))
                      : const CircularProgressIndicator(color: Cores.verde),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Espaco.m, Espaco.p, Espaco.m, Espaco.xg),
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
                      aoReiniciar: () =>
                          comandos.add(const ReinicioSolicitado()),
                    ),
                    const SizedBox(height: Espaco.m),
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
                        titulo: 'BLOQUEIO DE EMERGENCIA',
                        texto: 'Reservatorio critico. Nenhuma bomba pode ser '
                            'acionada.',
                        acao: 'Tentar mesmo assim',
                        aoAgir: () => comandos.add(AcionamentoSolicitado(
                            telemetria.bombas.first.id,
                            ligar: true)),
                      ),
                    _CartaoReservatorio(telemetria: telemetria),
                    const SizedBox(height: Espaco.g),
                    Padding(
                      padding: const EdgeInsets.only(
                          left: Espaco.xs, bottom: Espaco.p),
                      child: Text('TALHOES',
                          style: Fontes.rotulo(Cores.textoFraco)),
                    ),
                    for (final talhao in telemetria.talhoes) ...[
                      _CartaoTalhao(
                        talhao: talhao,
                        bomba: telemetria.bombaDo(talhao.id),
                        // RF11. O servidor recusa de qualquer jeito (RN08);
                        // travar aqui e conveniencia, nao seguranca.
                        travado: bloqueado || desconectado,
                        aoAlternar: (bomba, ligar) => comandos
                            .add(AcionamentoSolicitado(bomba.id, ligar: ligar)),
                      ),
                      const SizedBox(height: Espaco.p),
                    ],
                  ],
                ),
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
                  style: Fontes.titulo(Cores.texto, tamanho: 20)),
              const SizedBox(height: Espaco.xs),
              _Conexao(desconectado: desconectado, emTempoReal: emTempoReal),
            ],
          ),
        ),
        _Botao(Icons.history_outlined, 'Historico', aoAbrirHistorico),
        _Botao(Icons.fast_forward_outlined, 'Modo demonstracao', aoAcelerar),
        _Botao(Icons.slow_motion_video_outlined, 'Velocidade normal',
            aoNormalizar),
        _Botao(Icons.restart_alt_outlined, 'Reiniciar cenario', aoReiniciar),
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

/// Ponto que pulsa devagar enquanto o canal esta de pe. Ele nao mente: quando
/// quem entrega as leituras e a consulta de reserva, o rotulo muda.
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
              child: Text(acao!,
                  style: Fontes.titulo(cor, tamanho: 13)),
            ),
          ],
        ]),
      );
}

class _CartaoReservatorio extends StatelessWidget {
  const _CartaoReservatorio({required this.telemetria});

  final Telemetria telemetria;

  @override
  Widget build(BuildContext context) {
    final reservatorio = telemetria.reservatorio;
    final cor = Cores.da(reservatorio.faixa);

    return Cartao(
      preenchimento: const EdgeInsets.all(Espaco.g),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text('RESERVATORIO',
                style: Fontes.rotulo(Cores.textoFraco))),
            Text(rotulos[reservatorio.faixa]!, style: Fontes.rotulo(cor)),
          ],
        ),
        const SizedBox(height: Espaco.p),
        ValorAnimado(valor: reservatorio.nivel, cor: cor, tamanho: 64),
        const SizedBox(height: Espaco.m),
        BarraNivel(fracao: reservatorio.nivel / 100, cor: cor, altura: 8),
        const SizedBox(height: Espaco.g),
        _ArcoSolar(telemetria: telemetria),
      ]),
    );
  }
}

/// Posicao do sol no dia da fazenda simulada. RN12: e esta curva que repoe o
/// reservatorio, e e o unico motivo de o bloqueio conseguir ser liberado.
class _ArcoSolar extends StatelessWidget {
  const _ArcoSolar({required this.telemetria});

  final Telemetria telemetria;

  @override
  Widget build(BuildContext context) {
    final fator = telemetria.fatorSolarAtual;
    final noite = fator == 0;

    return Row(children: [
      Icon(noite ? Icons.nightlight_outlined : Icons.wb_sunny_outlined,
          size: 16, color: noite ? Cores.textoFraco : Cores.ambar),
      const SizedBox(width: Espaco.p),
      Text('${telemetria.horaSimulada.floor().toString().padLeft(2, '0')}h',
          style: Fontes.corpo(Cores.texto)),
      const SizedBox(width: Espaco.m),
      Expanded(
        child: SizedBox(
          height: 30,
          child: CustomPaint(
            painter: _PintorArco(
                hora: telemetria.horaSimulada, ativo: !noite),
            size: Size.infinite,
          ),
        ),
      ),
      const SizedBox(width: Espaco.m),
      Text(
        noite ? 'captacao parada' : 'captacao ${(fator * 100).round()}%',
        style: Fontes.corpo(noite ? Cores.textoFraco : Cores.ambar),
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
    final trilho = Paint()
      // Um pouco acima da cor de borda, senao a curva some no fundo escuro.
      ..color = ativo
          ? Cores.ambar.withValues(alpha: 0.30)
          : Cores.textoFraco.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // Meia elipse do amanhecer ao anoitecer.
    final caminho = Path()
      ..moveTo(0, size.height)
      ..arcToPoint(Offset(size.width, size.height),
          radius: Radius.elliptical(size.width / 2, size.height),
          clockwise: true);
    canvas.drawPath(caminho, trilho);

    final progresso = ((hora - Limiares.amanhecer) /
            (Limiares.anoitecer - Limiares.amanhecer))
        .clamp(0.0, 1.0);
    final angulo = 3.14159265 * progresso;
    final centro = Offset(
      size.width / 2 - (size.width / 2) * _cos(angulo),
      size.height - size.height * _sin(angulo),
    );

    // Halo discreto para o sol nao sumir em cima da propria curva.
    if (ativo) {
      canvas.drawCircle(
          centro, 9, Paint()..color = Cores.ambar.withValues(alpha: 0.25));
    }
    canvas.drawCircle(
      centro,
      4.5,
      Paint()..color = ativo ? Cores.ambar : Cores.textoFraco,
    );
  }

  static double _cos(double x) => _sin(x + 1.5707963);
  static double _sin(double x) {
    // Aproximacao de Bhaskara, suficiente para posicionar um ponto de 4 pixels
    // e evitar importar dart:math so para isto.
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

class _CartaoTalhao extends StatelessWidget {
  const _CartaoTalhao({
    required this.talhao,
    required this.bomba,
    required this.travado,
    required this.aoAlternar,
  });

  final Talhao talhao;
  final Bomba bomba;
  final bool travado;
  final void Function(Bomba, bool) aoAlternar;

  @override
  Widget build(BuildContext context) {
    final cor = Cores.da(talhao.faixa);

    return Cartao(
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(talhao.nome.toUpperCase(),
                  style: Fontes.rotulo(Cores.textoFraco)),
              const SizedBox(height: Espaco.p),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic, children: [
                ValorAnimado(valor: talhao.umidade, cor: cor, tamanho: 34),
                const SizedBox(width: Espaco.p),
                Text(rotulos[talhao.faixa]!, style: Fontes.rotulo(cor)),
              ]),
              const SizedBox(height: Espaco.p),
              BarraNivel(fracao: talhao.umidade / 100, cor: cor),
              const SizedBox(height: Espaco.p),
              Text(
                bomba.ligada
                    ? 'Irrigando por ordem do '
                        '${bomba.origemUltimoAcionamento == Origem.operador ? 'operador' : 'sistema'}'
                    : talhao.cultura,
                style: Fontes.corpo(
                    bomba.ligada ? Cores.verde : Cores.textoFraco, tamanho: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: Espaco.m),
        Switch(
          value: bomba.ligada,
          activeThumbColor: Cores.verde,
          onChanged: travado ? null : (ligar) => aoAlternar(bomba, ligar),
        ),
      ]),
    );
  }
}
