/// Tokens do painel. Cor, espaço, raio e tipografia vivem só aqui.
///
/// Sala de controle, não produto de consumo: estados dessaturados, raio curto,
/// caixa alta apenas em título de seção.
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
  static const Color fundo = Color(0xFF0D1117);
  static const Color superficie = Color(0xFF12171F);

  /// Um tom acima da superfície, para faixas e realces discretos.
  static const Color superficieAlta = Color(0xFF1A212B);
  static const Color borda = Color(0xFF1F2630);

  /// Cinza de gráfico. A cor de borda desaparece sobre a superfície do card, e
  /// uma barra que não se distingue do fundo não informa nada.
  static const Color grafico = Color(0xFF39434F);

  static const Color texto = Color(0xFFE6EDF3);
  static const Color textoSecundario = Color(0xFF8B949E);
  static const Color textoTerciario = Color(0xFF6E7681);

  /// Estados dessaturados. Neon é metade da cara de template.
  static const Color verde = Color(0xFF3FB950);
  static const Color ambar = Color(0xFFD29922);
  static const Color vermelho = Color(0xFFF85149);

  static Color da(Faixa faixa) => switch (faixa) {
        Faixa.verde => verde,
        Faixa.amarelo => ambar,
        Faixa.vermelho => vermelho,
      };

  /// Opacidade da temperatura ambiente da tela por estado (item 9).
  static double brilhoDa(Faixa faixa) => switch (faixa) {
        Faixa.verde => 0,
        Faixa.amarelo => 0.04,
        Faixa.vermelho => 0.08,
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
        fontWeight: FontWeight.w600,
        letterSpacing: -tamanho * 0.025,
        fontFeatures: _tabular,
      );

  /// Única caixa alta do aplicativo: título de seção.
  static TextStyle secao() => GoogleFonts.inter(
        fontSize: 11,
        color: Cores.textoTerciario,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      );

  static TextStyle titulo(Color cor, {double tamanho = 15}) =>
      GoogleFonts.inter(
        fontSize: tamanho,
        color: cor,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      );

  static TextStyle corpo(Color cor, {double tamanho = 13}) => GoogleFonts.inter(
        fontSize: tamanho,
        color: cor,
        height: 1.35,
        fontFeatures: _tabular,
      );
}

ThemeData construirTema() {
  final base = ThemeData.dark(useMaterial3: true);
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
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: Cores.da(faixa), shape: BoxShape.circle),
          ),
          const SizedBox(width: Espaco.p),
          Text(texto ?? rotulos[faixa]!,
              style: Fontes.corpo(Cores.textoSecundario)),
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
      {required this.fracao, required this.cor, this.altura = 4, super.key});

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

/// Interruptor próprio, no lugar do Switch do Material.
///
/// É o único elemento que a banca vai tocar, então ele diz em palavras em que
/// estado está, e quando o bloqueio trava a operação mostra cadeado em vez de
/// ficar apenas cinza, que é como um Switch desabilitado se parece com um
/// Switch qualquer.
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

  @override
  Widget build(BuildContext context) {
    if (travado) {
      return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Espaco.p + 2, vertical: Espaco.xs + 2),
        decoration: BoxDecoration(
          color: Cores.fundo,
          borderRadius: BorderRadius.circular(Raio.interno),
          border: Border.all(color: Cores.borda),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outline, size: 12, color: Cores.textoTerciario),
          const SizedBox(width: Espaco.p - 2),
          Text('Travado', style: Fontes.corpo(Cores.textoTerciario, tamanho: 12)),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Cores.fundo,
        borderRadius: BorderRadius.circular(Raio.interno),
        border: Border.all(color: Cores.borda),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _Lado('Desligado',
            ativo: !ligado,
            cor: Cores.textoSecundario,
            aoTocar: () => aoAlternar(false)),
        _Lado('Ligado',
            ativo: ligado, cor: Cores.verde, aoTocar: () => aoAlternar(true)),
      ]),
    );
  }
}

class _Lado extends StatelessWidget {
  const _Lado(this.texto,
      {required this.ativo, required this.cor, required this.aoTocar});

  final String texto;
  final bool ativo;
  final Color cor;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: ativo ? null : aoTocar,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
              horizontal: Espaco.p + 2, vertical: Espaco.xs),
          decoration: BoxDecoration(
            color: ativo ? cor.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(Raio.interno - 2),
          ),
          child: Text(texto,
              style: Fontes.corpo(ativo ? cor : Cores.textoTerciario,
                  tamanho: 12)),
        ),
      );
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
