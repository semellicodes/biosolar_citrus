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

/// Acima disto o conteúdo para de crescer e se centraliza. O fundo continua
/// cobrindo a janela inteira.
const double _larguraMaxima = 1100;

/// Abaixo disto o cartão do reservatório deixa de ser duas colunas.
const double _corteColunas = 700;

/// Abaixo disto é tela de celular: números menores, cartões com menos respiro e
/// o cabeçalho em duas linhas. Nada de lógica muda, só o que cabe na tela.
const double _corteCelular = 480;

/// Abaixo disto o cabeçalho vai para duas linhas. É um corte próprio, e maior
/// que o de celular, porque quem manda aqui é a largura do nome do aplicativo:
/// a Matcha Home é bem mais larga que a fonte de interface e, na mesma linha
/// que o estado de conexão e os cinco botões, o nome era truncado bem antes
/// dos 480.
const double _corteCabecalho = 600;

const double _opacidadeDoVeu = 0.42;

class TelaMonitoramento extends StatelessWidget {
  const TelaMonitoramento({super.key});

  @override
  Widget build(BuildContext context) {
    final telemetriaBloc = context.read<TelemetriaBloc>();

    return BlocListener<ComandoBloc, EstadoComando>(
      listener: (context, estado) => switch (estado) {
        ComandoAceito(:final telemetria) => telemetriaBloc.add(
          TelemetriaRecebida(telemetria),
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Cores.superficieAlta,
          behavior: SnackBarBehavior.floating,
          width: 520,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Raio.card),
            side: const BorderSide(color: Cores.vermelho),
          ),
          content: Text(mensagem, style: Fontes.corpo(Cores.texto)),
          duration: const Duration(seconds: 6),
        ),
      );
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
    final bloqueado = telemetria?.reservatorio.bloqueioAtivo ?? false;

    return Scaffold(
      body: Stack(
        children: [
          const _FundoDoPomar(),
          SafeArea(
            child: telemetria == null
                ? Center(
                    child: desconectado
                        ? Text(
                            'Sem contato com o servidor. Tentando de novo.',
                            style: Fontes.corpo(Cores.textoSecundario),
                          )
                        : const CircularProgressIndicator(
                            color: Cores.verde,
                            strokeWidth: 2,
                          ),
                  )
                : LayoutBuilder(
                    builder: (context, limites) {
                      final celular = limites.maxWidth < _corteCelular;
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: _larguraMaxima,
                          ),
                          child: ListView(
                            padding: EdgeInsets.fromLTRB(
                              celular ? Espaco.m : Espaco.g,
                              Espaco.g,
                              celular ? Espaco.m : Espaco.g,
                              Espaco.xg,
                            ),
                            children: [
                              _Topo(
                                celular: celular,
                                telemetria: telemetria,
                                desconectado: desconectado,
                                emTempoReal: emTempoReal,
                                aoAbrirHistorico: () => Navigator.of(
                                  context,
                                ).pushNamed(TelaEventos.rota),
                                aoAcelerar: () => comandos.add(
                                  const VelocidadeSolicitada(acelerada: true),
                                ),
                                aoNormalizar: () => comandos.add(
                                  const VelocidadeSolicitada(acelerada: false),
                                ),
                                aoPausar: () =>
                                    comandos.add(const PausaSolicitada()),
                                aoReiniciar: () =>
                                    comandos.add(const ReinicioSolicitado()),
                                chovendo: telemetria.chovendo,
                                aoAlternarChuva: () => comandos.add(
                                  ChuvaSolicitada(
                                    chovendo: !telemetria.chovendo,
                                  ),
                                ),
                              ),
                              const SizedBox(height: Espaco.g),

                              // Sem contato, o bloqueio que a tela mostra é
                              // informação velha: o aviso de defasagem vence e o de
                              // bloqueio sai.
                              if (desconectado)
                                _FaixaDefasagem(
                                  'Defasado desde ${_hora(telemetria.hora)}. '
                                  'Reconectando.',
                                )
                              else if (bloqueado)
                                _FaixaBloqueio(
                                  aoTentar: () => comandos.add(
                                    AcionamentoSolicitado(
                                      telemetria.bombas.first.id,
                                      ligar: true,
                                    ),
                                  ),
                                ),

                              _CartaoReservatorio(
                                telemetria: telemetria,
                                celular: celular,
                              ),
                              SizedBox(height: celular ? Espaco.m : Espaco.g),
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: Espaco.xs,
                                  bottom: Espaco.p,
                                ),
                                child: Text('TALHÕES', style: Fontes.secao()),
                              ),
                              _ListaTalhoes(
                                celular: celular,
                                telemetria: telemetria,
                                // RF11. O servidor recusa de qualquer jeito (RN08);
                                // travar aqui é conveniência, não segurança.
                                travado: bloqueado || desconectado,
                                aoAlternar: (bomba, ligar) => comandos.add(
                                  AcionamentoSolicitado(bomba.id, ligar: ligar),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

String _hora(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}:'
    '${d.second.toString().padLeft(2, '0')}';

class _FundoDoPomar extends StatelessWidget {
  const _FundoDoPomar();

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/imagens/fundo-irrigacao.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          ColoredBox(color: Cores.fundo.withValues(alpha: _opacidadeDoVeu)),
        ],
      ),
    ),
  );
}

/// Uma linha: título à esquerda, estado e ações à direita, e embaixo a linha
/// de contexto em texto terciário.
class _Topo extends StatelessWidget {
  const _Topo({
    required this.celular,
    required this.telemetria,
    required this.desconectado,
    required this.emTempoReal,
    required this.aoAbrirHistorico,
    required this.aoAcelerar,
    required this.aoNormalizar,
    required this.aoPausar,
    required this.aoReiniciar,
    required this.chovendo,
    required this.aoAlternarChuva,
  });

  final bool celular;
  final Telemetria telemetria;
  final bool desconectado;
  final bool emTempoReal;
  final VoidCallback aoAbrirHistorico;
  final VoidCallback aoAcelerar;
  final VoidCallback aoNormalizar;
  final VoidCallback aoPausar;
  final VoidCallback aoReiniciar;
  final bool chovendo;
  final VoidCallback aoAlternarChuva;

  @override
  Widget build(BuildContext context) {
    final tamanhoTitulo = celular ? 26.0 : 25.0;
    final titulo = Text.rich(
      TextSpan(
        style: Fontes.nomeDoAplicativo(tamanhoTitulo),
        children: [
          const TextSpan(text: 'Bi'),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _LaranjaDaMarca(tamanho: tamanhoTitulo),
          ),
          const TextSpan(text: 'Solar Citrus'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      semanticsLabel: 'BioSolar Citrus',
    );

    final acoes = <Widget>[
      // RN13: chuva manual. Aceso enquanto está chovendo, para o botão ser
      // também o indicador de que o modo está ligado.
      _Acao(
        chovendo ? Icons.water : Icons.water_outlined,
        chovendo ? 'Encerrar chuva' : 'Simular chuva',
        aoAlternarChuva,
        destacado: chovendo,
      ),
      _Acao(Icons.history, 'Histórico', aoAbrirHistorico),
      _Acao(Icons.fast_forward, 'Modo demonstração', aoAcelerar),
      _Acao(Icons.slow_motion_video, 'Velocidade normal', aoNormalizar),
      _Acao(Icons.power_settings_new, 'Desligar sistema', aoPausar),
      _Acao(Icons.restart_alt, 'Reiniciar cenário', aoReiniciar),
    ];

    // Em celular a linha de contexto fica só com a hora da fazenda: o horário
    // da última leitura não cabe junto e é o menos útil dos dois lá.
    final contexto = Text(
      celular
          ? 'Monitoramento de irrigação  ·  '
                '${telemetria.horaSimulada.floor().toString().padLeft(2, '0')}h '
                'na fazenda'
          : 'Monitoramento de irrigação  ·  '
                '${telemetria.horaSimulada.floor().toString().padLeft(2, '0')}h na '
                'fazenda  ·  Última leitura ${_hora(telemetria.hora)}',
      style: Fontes.corpo(Cores.textoTerciario, tamanho: 12),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final conexao = _Conexao(
      desconectado: desconectado,
      emTempoReal: emTempoReal,
    );

    return LayoutBuilder(
      builder: (context, limites) {
        if (limites.maxWidth < _corteCabecalho) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titulo,
              const SizedBox(height: Espaco.xs),
              contexto,
              const SizedBox(height: Espaco.p),
              Row(children: [conexao, const Spacer(), ...acoes]),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: titulo),
                conexao,
                const SizedBox(width: Espaco.p),
                ...acoes,
              ],
            ),
            const SizedBox(height: Espaco.xs),
            contexto,
          ],
        );
      },
    );
  }
}

class _LaranjaDaMarca extends StatelessWidget {
  const _LaranjaDaMarca({required this.tamanho});

  final double tamanho;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: tamanho * 1.12,
    height: tamanho * 1.46,
    child: Transform.translate(
      offset: Offset(0, -tamanho * 0.18),
      child: Image.asset(
        'assets/imagens/marca-laranja.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    ),
  );
}

class _Acao extends StatelessWidget {
  const _Acao(this.icone, this.dica, this.aoTocar, {this.destacado = false});

  final IconData icone;
  final String dica;
  final VoidCallback aoTocar;
  final bool destacado;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: dica,
    onPressed: aoTocar,
    icon: Icon(
      icone,
      size: 18,
      color: destacado ? Cores.verde : Cores.textoSecundario,
    ),
    visualDensity: VisualDensity.compact,
    padding: const EdgeInsets.all(Espaco.p),
    constraints: const BoxConstraints(),
  );
}

/// Ponto que pulsa devagar enquanto o canal está de pé. Ele não mente: quando
/// quem entrega as leituras é a consulta de reserva, o texto muda.
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
      (true, _) => (Cores.vermelho, 'Sem contato'),
      (false, true) => (Cores.verde, 'Ao vivo'),
      (false, false) => (Cores.ambar, 'Reserva'),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: widget.desconectado
              ? const AlwaysStoppedAnimation(1.0)
              : Tween<double>(begin: 0.35, end: 1).animate(_pulso),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: Espaco.p),
        Text(rotulo, style: Fontes.corpo(Cores.textoSecundario)),
      ],
    );
  }
}

/// Tira de uma linha. O ponto do topo já diz que o contato caiu; repetir isso
/// em um bloco grande é redundância, não ênfase.
class _FaixaDefasagem extends StatelessWidget {
  const _FaixaDefasagem(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Container(
    height: 38,
    margin: const EdgeInsets.only(bottom: Espaco.m),
    padding: const EdgeInsets.symmetric(horizontal: Espaco.m),
    decoration: const BoxDecoration(
      color: Cores.superficieAlta,
      border: Border(left: BorderSide(color: Cores.textoSecundario, width: 2)),
    ),
    alignment: Alignment.centerLeft,
    child: Text(
      texto,
      style: Fontes.corpo(Cores.textoSecundario),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

class _FaixaBloqueio extends StatelessWidget {
  const _FaixaBloqueio({required this.aoTentar});

  final VoidCallback aoTentar;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: Espaco.m),
    padding: const EdgeInsets.all(Espaco.m),
    decoration: BoxDecoration(
      color: Cores.vermelho.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(Raio.card),
      border: Border.all(color: Cores.vermelho, width: 2),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.block, size: 22, color: Cores.vermelho),
            const SizedBox(width: Espaco.p),
            Expanded(
              child: Text(
                'Bloqueio de emergência',
                style: Fontes.titulo(Cores.vermelho, tamanho: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: Espaco.p),
        Text(
          'Reservatório crítico. Nenhuma bomba pode ser acionada.',
          style: Fontes.corpo(Cores.texto, tamanho: 16),
        ),
        const SizedBox(height: Espaco.m),
        // Passo 7 do roteiro: com os botões travados não dá para provar que
        // a recusa vem do servidor. Este passa por cima da trava da interface
        // e o 409 chega do domínio.
        SizedBox(
          height: Interruptor.altura,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: aoTentar,
            style: OutlinedButton.styleFrom(
              foregroundColor: Cores.vermelho,
              side: const BorderSide(color: Cores.vermelho, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Raio.interno),
              ),
            ),
            child: Text(
              'Tentar ligar mesmo assim',
              style: Fontes.titulo(Cores.vermelho, tamanho: 17),
            ),
          ),
        ),
      ],
    ),
  );
}

class _CartaoReservatorio extends StatelessWidget {
  const _CartaoReservatorio({required this.telemetria, required this.celular});

  final Telemetria telemetria;
  final bool celular;

  @override
  Widget build(BuildContext context) {
    final reservatorio = telemetria.reservatorio;
    final cor = Cores.da(reservatorio.faixa);
    final fator = telemetria.fatorSolarAtual;
    final noite = fator == 0;

    final nivel = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('RESERVATÓRIO', style: Fontes.secao()),
        const SizedBox(height: Espaco.p),
        // Uma linha, um número: é o que o produtor quer saber de relance.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: ValorAnimado(
            valor: reservatorio.nivel,
            cor: cor,
            tamanho: celular ? 52 : 72,
          ),
        ),
        const SizedBox(height: Espaco.p),
        PontoEstado(reservatorio.faixa),
        const SizedBox(height: Espaco.m),
        BarraNivel(fracao: reservatorio.nivel / 100, cor: cor, altura: 14),
        // RN13: indicador visível enquanto chove, sem cápsula e em caixa
        // normal, como os outros estados da tela.
        if (telemetria.chovendo) ...[
          const SizedBox(height: Espaco.m),
          Row(
            children: [
              const Icon(Icons.water, size: 18, color: Cores.verde),
              const SizedBox(width: Espaco.p),
              Expanded(
                child: Text(
                  'Chovendo na fazenda',
                  style: Fontes.titulo(Cores.verde, tamanho: 16),
                ),
              ),
              Text(
                '+${Limiares.ganhoChuvaPorTick.toStringAsFixed(1)} por ciclo',
                style: Fontes.corpo(Cores.verde, tamanho: 14),
              ),
            ],
          ),
        ],
      ],
    );

    Widget captacaoCom(double alturaGrafico) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: Text('CAPTAÇÃO SOLAR', style: Fontes.secao())),
            Text(
              noite ? 'parada, é noite' : '${(fator * 100).round()}%',
              style: Fontes.titulo(
                noite ? Cores.textoSecundario : Cores.ambar,
                tamanho: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: Espaco.m),
        _BarrasSolares(telemetria: telemetria, altura: alturaGrafico),
      ],
    );

    return Cartao(
      preenchimento: EdgeInsets.all(celular ? Espaco.m : Espaco.g),
      child: LayoutBuilder(
        builder: (context, limites) {
          if (limites.maxWidth < _corteColunas) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                nivel,
                SizedBox(height: celular ? Espaco.m : Espaco.g),
                captacaoCom(celular ? 52 : 64),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: nivel),
              const SizedBox(width: Espaco.xg),
              Expanded(child: captacaoCom(130)),
            ],
          );
        },
      ),
    );
  }
}

/// Doze barras, uma por hora de sol, com a altura vinda da mesma senoide que
/// alimenta a RN12. A hora atual fica em âmbar, o resto em cinza: nenhuma série
/// precisa ser guardada para desenhar isto.
///
/// Desenhado em CustomPaint em vez de montado com widgets: encadear Expanded,
/// Align e Container para doze barras rendeu alturas todas iguais, e aqui cada
/// retângulo é explícito.
class _BarrasSolares extends StatelessWidget {
  const _BarrasSolares({required this.telemetria, required this.altura});

  final Telemetria telemetria;
  final double altura;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: altura,
    width: double.infinity,
    child: CustomPaint(
      painter: _PintorBarras(horaAtual: telemetria.horaSimulada.floor()),
    ),
  );
}

class _PintorBarras extends CustomPainter {
  const _PintorBarras({required this.horaAtual});

  final int horaAtual;

  static const double _alturaRotulo = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final primeira = Limiares.amanhecer.toInt();
    final ultima = Limiares.anoitecer.toInt();
    final quantas = ultima - primeira;
    final passo = size.width / quantas;
    const vao = 3.0;
    final alturaUtil = size.height - _alturaRotulo;

    for (var indice = 0; indice < quantas; indice++) {
      final hora = primeira + indice;
      final atual = hora == horaAtual;
      final altura = 3 + (alturaUtil - 3) * fatorSolar(hora + 0.5);
      final esquerda = passo * indice + vao / 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(esquerda, alturaUtil - altura, passo - vao, altura),
          const Radius.circular(1),
        ),
        Paint()..color = atual ? Cores.ambar : Cores.grafico,
      );

      final rotulo = TextPainter(
        text: TextSpan(
          text: '$hora',
          style: Fontes.corpo(
            atual ? Cores.ambar : Cores.textoTerciario,
            tamanho: 9,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      rotulo.paint(
        canvas,
        Offset(esquerda + (passo - vao - rotulo.width) / 2, alturaUtil + 3),
      );
    }
  }

  @override
  bool shouldRepaint(_PintorBarras anterior) => anterior.horaAtual != horaAtual;
}

class _ListaTalhoes extends StatelessWidget {
  const _ListaTalhoes({
    required this.celular,
    required this.telemetria,
    required this.travado,
    required this.aoAlternar,
  });

  final bool celular;
  final Telemetria telemetria;
  final bool travado;
  final void Function(Bomba, bool) aoAlternar;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, limites) {
      // Cartao alto e largo, um por talhao. Lista densa lê bem sentado na
      // frente do monitor e mal de pé no pomar com o sol na tela.
      final colunas = limites.maxWidth >= _corteColunas ? 2 : 1;
      final largura = (limites.maxWidth - Espaco.m * (colunas - 1)) / colunas;

      return Wrap(
        spacing: Espaco.m,
        runSpacing: Espaco.m,
        children: [
          for (final talhao in telemetria.talhoes)
            SizedBox(
              width: largura,
              child: _LinhaTalhao(
                celular: celular,
                talhao: talhao,
                bomba: telemetria.bombaDo(talhao.id),
                travado: travado,
                aoAlternar: aoAlternar,
              ),
            ),
        ],
      );
    },
  );
}

class _LinhaTalhao extends StatelessWidget {
  const _LinhaTalhao({
    required this.celular,
    required this.talhao,
    required this.bomba,
    required this.travado,
    required this.aoAlternar,
  });

  final bool celular;
  final Talhao talhao;
  final Bomba bomba;
  final bool travado;
  final void Function(Bomba, bool) aoAlternar;

  /// Diz o tempo todo de quem partiu o que está acontecendo, que é a tese
  /// central do projeto: a autonomia mora no servidor.
  String get _situacao =>
      switch ((bomba.ligada, bomba.origemUltimoAcionamento)) {
        (false, _) => 'Aguardando',
        (true, Origem.operador) => 'Você ligou esta bomba',
        (true, _) => 'O sistema ligou sozinho',
      };

  @override
  Widget build(BuildContext context) {
    final cor = Cores.da(talhao.faixa);

    return Container(
      padding: EdgeInsets.all(celular ? Espaco.m : Espaco.g),
      decoration: BoxDecoration(
        color: Cores.superficie,
        borderRadius: BorderRadius.circular(Raio.card),
        border: Border.all(color: Cores.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            talhao.nome,
            style: Fontes.titulo(Cores.texto, tamanho: celular ? 19 : 22),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            talhao.cultura,
            style: Fontes.corpo(Cores.textoTerciario, tamanho: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: Espaco.m),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: ValorAnimado(
                    valor: talhao.umidade,
                    cor: cor,
                    tamanho: celular ? 32 : 52,
                  ),
                ),
              ),
              const SizedBox(width: Espaco.m),
              PontoEstado(talhao.faixa),
            ],
          ),
          SizedBox(height: celular ? Espaco.p : Espaco.m),
          BarraNivel(fracao: talhao.umidade / 100, cor: cor, altura: 12),
          SizedBox(height: celular ? Espaco.p : Espaco.m),
          Text(
            _situacao,
            style: Fontes.corpo(
              bomba.ligada ? Cores.verde : Cores.textoTerciario,
              tamanho: 15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: celular ? Espaco.p : Espaco.m),
          // Alinhado à direita: o botão tem a largura do próprio rótulo, e o
          // canto de leitura do cartão continua sendo a esquerda.
          Align(
            alignment: Alignment.centerRight,
            child: Interruptor(
              ligado: bomba.ligada,
              travado: travado,
              aoAlternar: (ligar) => aoAlternar(bomba, ligar),
            ),
          ),
        ],
      ),
    );
  }
}
