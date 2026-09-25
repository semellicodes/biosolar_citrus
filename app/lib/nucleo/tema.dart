/// Tokens do painel. Cor, espaço, raio e tipografia vivem só aqui.
///
/// Pensado para uso em campo: o produtor lê no sol, de relance e com uma mão.
/// Isso manda fundo claro, contraste alto, texto grande e alvo de toque grande,
/// que é o oposto do painel escuro de sala de controle.
library;

import 'package:compartilhado/modelos.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class Espaco {
  static const double xs = 4;
  static const double p = 8;
  static const double m = 16;
  static const double g = 24;
  static const double xg = 32;
}

/// Dois valores, e só. Card e elemento interno. Raio grande foi removido de
/// propósito, para não voltar por acidente.
abstract final class Raio {
  static const double card = 10;
  static const double interno = 6;
}

abstract final class Cores {
  static const Color fundo = Color(0xFFF4F6F3);
  static const Color superficie = Color(0xFFFFFFFF);

  /// Um tom abaixo da superfície, para faixas e realces.
  static const Color superficieAlta = Color(0xFFEBEEE8);
  static const Color borda = Color(0xFFDCE0D8);

  /// Cinza de gráfico, com contraste suficiente sobre a superfície branca.
  static const Color grafico = Color(0xFFC3CABE);

  static const Color texto = Color(0xFF161C18);
  static const Color textoSecundario = Color(0xFF4A554E);
  static const Color textoTerciario = Color(0xFF6B756E);

  /// Escuras o bastante para sobreviver ao sol batendo na tela: tom claro de
  /// estado sobre fundo claro some lá fora.
  static const Color verde = Color(0xFF16803C);
  static const Color ambar = Color(0xFF9A5B00);
  static const Color vermelho = Color(0xFFBC1C13);

  static Color da(Faixa faixa) => switch (faixa) {
        Faixa.verde => verde,
        Faixa.amarelo => ambar,
        Faixa.vermelho => vermelho,
      };

  /// Temperatura ambiente da tela por estado. Discreta em fundo claro, onde
  /// uma lavada de cor forte atrapalha a leitura em vez de ajudar.
  static double brilhoDa(Faixa faixa) => switch (faixa) {
        Faixa.verde => 0,
        Faixa.amarelo => 0.05,
        Faixa.vermelho => 0.10,
      };
}

/// RNF04: o estado é identificável por texto, não só por cor. Em caixa normal.
const Map<Faixa, String> rotulos = {
  Faixa.verde: 'Normal',
  Faixa.amarelo: 'Atenção',
  Faixa.vermelho: 'Crítico',
};

const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

abstract final class Fontes {
  /// Números que mudam a cada ciclo precisam de largura fixa por algarismo,
  /// senão o valor dança e o painel parece instável.
  static TextStyle valor(double tamanho, Color cor) => GoogleFonts.inter(
        fontSize: tamanho,
        height: 1,
        color: cor,
        fontWeight: FontWeight.w700,
        letterSpacing: -tamanho * 0.025,
        fontFeatures: _tabular,
      );

  /// Única caixa alta do aplicativo: título de seção.
  static TextStyle secao() => GoogleFonts.inter(
        fontSize: 13,
        color: Cores.textoTerciario,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      );

  static TextStyle titulo(Color cor, {double tamanho = 18}) =>
      GoogleFonts.inter(
        fontSize: tamanho,
        color: cor,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      );

  static TextStyle corpo(Color cor, {double tamanho = 15}) => GoogleFonts.inter(
        fontSize: tamanho,
        color: cor,
        height: 1.35,
        fontFeatures: _tabular,
      );
}

ThemeData construirTema() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: Cores.fundo,
    colorScheme: base.colorScheme.copyWith(
      surface: Cores.superficie,
      primary: Cores.verde,
      error: Cores.vermelho,
    ),
    textTheme: GoogleFonts.interTextTheme(base.textTheme),
    dividerColor: Cores.borda,
    appBarTheme: const AppBarTheme(
      backgroundColor: Cores.fundo,
      foregroundColor: Cores.texto,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
  );
}

/// Contêiner padrão. Um raio, uma borda, em toda a tela.
class Cartao extends StatelessWidget {
  const Cartao({required this.child, this.preenchimento, super.key});

  final Widget child;
  final EdgeInsets? preenchimento;

  @override
  Widget build(BuildContext context) => Container(
        padding: preenchimento ?? const EdgeInsets.all(Espaco.m),
        decoration: BoxDecoration(
          color: Cores.superficie,
          borderRadius: BorderRadius.circular(Raio.card),
          border: Border.all(color: Cores.borda),
        ),
        child: child,
      );
}

/// Estado como ponto e texto, no lugar de cápsula tingida.
///
/// O ponto carrega a cor, o texto carrega o significado, e quem não distingue
/// cor continua lendo.
class PontoEstado extends StatelessWidget {
  const PontoEstado(this.faixa, {this.texto, super.key});

  final Faixa faixa;
  final String? texto;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration:
                BoxDecoration(color: Cores.da(faixa), shape: BoxShape.circle),
          ),
          const SizedBox(width: Espaco.p),
          // Crítico chega com peso maior, porque é o que precisa ser visto de
          // relance e de longe.
          Text(texto ?? rotulos[faixa]!,
              style: Fontes.titulo(
                  faixa == Faixa.vermelho ? Cores.da(faixa) : Cores.texto,
                  tamanho: 17)),
        ],
      );
}

/// Par rótulo e valor, alinhado em coluna. É o que faz a leitura parecer
/// instrumento em vez de cartaz.
class ParDado extends StatelessWidget {
  const ParDado(this.rotulo, this.valor, {this.cor, super.key});

  final String rotulo;
  final String valor;
  final Color? cor;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(rotulo, style: Fontes.corpo(Cores.textoTerciario, tamanho: 12)),
          const SizedBox(width: Espaco.m),
          Text(valor,
              style: Fontes.corpo(cor ?? Cores.texto, tamanho: 12)
                  .copyWith(fontWeight: FontWeight.w500)),
        ],
      );
}

/// Barra de nível. Fina, sem brilho e sem raio grande.
class BarraNivel extends StatelessWidget {
  const BarraNivel(
      {required this.fracao, required this.cor, this.altura = 10, super.key});

  final double fracao;
  final Color cor;
  final double altura;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(altura / 2),
        child: Stack(children: [
          Container(height: altura, color: Cores.borda),
          LayoutBuilder(
            builder: (_, limites) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              height: altura,
              width: limites.maxWidth * fracao.clamp(0, 1),
              color: cor,
            ),
          ),
        ]),
      );
}

/// Botão de acionamento, no lugar do Switch do Material.
///
/// Feito para ser tocado com uma mão, de pé no meio do pomar: ocupa a largura
/// do cartão, tem 56 pixels de altura e o rótulo diz a ação que vai acontecer,
/// não o estado, porque o estado já está escrito acima dele. Durante o bloqueio
/// mostra cadeado, em vez de ficar apenas cinza, que é como um Switch
/// desabilitado se parece com um Switch qualquer.
class Interruptor extends StatelessWidget {
  const Interruptor({
    required this.ligado,
    required this.travado,
    required this.aoAlternar,
    super.key,
  });

  final bool ligado;
  final bool travado;
  final ValueChanged<bool> aoAlternar;

  /// Alvo de toque confortável de luva, e bem acima dos 48 recomendados.
  static const double altura = 56;

  @override
  Widget build(BuildContext context) {
    if (travado) {
      return Container(
        height: altura,
        decoration: BoxDecoration(
          color: Cores.superficieAlta,
          borderRadius: BorderRadius.circular(Raio.interno),
          border: Border.all(color: Cores.borda),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.lock_outline, size: 20, color: Cores.textoSecundario),
          const SizedBox(width: Espaco.p),
          Text('Travado pelo bloqueio',
              style: Fontes.titulo(Cores.textoSecundario, tamanho: 17)),
        ]),
      );
    }

    // Ligar e a acao de destaque, entao ela vem solida. Desligar e a acao de
    // recuo, entao vem contornada: as duas com o mesmo tamanho de alvo.
    return GestureDetector(
      onTap: () => aoAlternar(!ligado),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: altura,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ligado ? Cores.superficie : Cores.verde,
          borderRadius: BorderRadius.circular(Raio.interno),
          border: Border.all(
              color: ligado ? Cores.textoSecundario : Cores.verde,
              width: 2),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(ligado ? Icons.stop_circle_outlined : Icons.water_drop,
              size: 22,
              color: ligado ? Cores.texto : Colors.white),
          const SizedBox(width: Espaco.p),
          Text(ligado ? 'Desligar irrigação' : 'Ligar irrigação',
              style: Fontes.titulo(ligado ? Cores.texto : Colors.white,
                  tamanho: 18)),
        ]),
      ),
    );
  }
}

/// Seletor segmentado próprio.
///
/// O ChoiceChip do Material media o rótulo antes de a fonte carregar e cortava
/// o texto ("Tud", "Operad"). Aqui a largura sai do próprio texto.
class Segmentado extends StatelessWidget {
  const Segmentado({
    required this.opcoes,
    required this.selecionado,
    required this.aoSelecionar,
    super.key,
  });

  final List<String> opcoes;
  final int selecionado;
  final ValueChanged<int> aoSelecionar;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Cores.superficie,
          borderRadius: BorderRadius.circular(Raio.interno),
          border: Border.all(color: Cores.borda),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final (indice, rotulo) in opcoes.indexed)
            GestureDetector(
              onTap: () => aoSelecionar(indice),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: Espaco.m, vertical: Espaco.p - 2),
                decoration: BoxDecoration(
                  color: indice == selecionado
                      ? Cores.superficieAlta
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(Raio.interno - 2),
                ),
                child: Text(
                  rotulo,
                  style: Fontes.corpo(
                      indice == selecionado
                          ? Cores.texto
                          : Cores.textoTerciario,
                      tamanho: 12),
                ),
              ),
            ),
        ]),
      );
}

/// Número que percorre a distância até o valor novo, em vez de trocar.
///
/// Com AnimatedSwitcher os dois valores coexistiam por 300ms e o número
/// aparecia fantasma a cada ciclo. Interpolar o próprio valor resolve isso e
/// ainda lê melhor como telemetria.
class ValorAnimado extends StatelessWidget {
  const ValorAnimado(
      {required this.valor, required this.cor, this.tamanho = 48, super.key});

  final double valor;
  final Color cor;
  final double tamanho;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: valor, end: valor),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        builder: (_, atual, _) => Text('${atual.toStringAsFixed(1)}%',
            style: Fontes.valor(tamanho, cor)),
      );
}
