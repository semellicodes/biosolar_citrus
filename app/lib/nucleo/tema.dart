/// Tema do painel: sala de controle, escuro e sem enfeite que nao seja dado.
///
/// Um arquivo so, porque cor e espacamento espalhados pela arvore de widgets
/// sao o comeco de uma interface que ninguem consegue ajustar depois.
library;



import 'package:compartilhado/modelos.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Escala fixa de espacamento. Toda margem e todo respiro do aplicativo sai
/// daqui, nunca de um numero solto no meio do widget.
abstract final class Espaco {
  static const double xs = 4;
  static const double p = 8;
  static const double m = 16;
  static const double g = 24;
  static const double xg = 32;
}

abstract final class Cores {
  static const Color fundo = Color(0xFF0D1117);
  static const Color superficie = Color(0xFF161C24);
  static const Color borda = Color(0xFF232C36);
  static const Color texto = Color(0xFFE8EDF2);
  static const Color textoFraco = Color(0xFF8A97A5);

  /// A paleta esta amarrada ao estado, nao ao gosto.
  static const Color verde = Color(0xFF3DD68C);
  static const Color ambar = Color(0xFFF5B841);
  static const Color vermelho = Color(0xFFF2545B);

  static Color da(Faixa faixa) => switch (faixa) {
        Faixa.verde => verde,
        Faixa.amarelo => ambar,
        Faixa.vermelho => vermelho,
      };
}

/// RNF04: o estado critico e identificavel por texto, nao so por cor.
const Map<Faixa, String> rotulos = {
  Faixa.verde: 'NORMAL',
  Faixa.amarelo: 'ATENCAO',
  Faixa.vermelho: 'CRITICO',
};

/// Numeros que mudam a cada ciclo precisam de largura fixa por algarismo,
/// senao o valor dança horizontalmente e o painel parece instavel justo
/// quando deveria parecer confiavel.
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

abstract final class Fontes {
  static TextStyle valor(double tamanho, Color cor) => GoogleFonts.inter(
        fontSize: tamanho,
        height: 1,
        color: cor,
        fontWeight: FontWeight.w700,
        letterSpacing: -tamanho * 0.03,
        fontFeatures: _tabular,
      );

  static TextStyle rotulo(Color cor) => GoogleFonts.inter(
        fontSize: 11,
        color: cor,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      );

  static TextStyle titulo(Color cor, {double tamanho = 16}) => GoogleFonts.inter(
        fontSize: tamanho,
        color: cor,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      );

  static TextStyle corpo(Color cor, {double tamanho = 13}) => GoogleFonts.inter(
        fontSize: tamanho,
        color: cor,
        height: 1.4,
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

/// Cartao padrao do painel. Existe para que o raio, a borda e o respiro sejam
/// os mesmos em toda a tela sem ninguem precisar lembrar dos numeros.
class Cartao extends StatelessWidget {
  const Cartao({required this.child, this.preenchimento, super.key});

  final Widget child;
  final EdgeInsets? preenchimento;

  @override
  Widget build(BuildContext context) => Container(
        padding: preenchimento ?? const EdgeInsets.all(Espaco.m),
        decoration: BoxDecoration(
          color: Cores.superficie,
          borderRadius: BorderRadius.circular(Espaco.m),
          border: Border.all(color: Cores.borda),
        ),
        child: child,
      );
}

/// Barra de nivel com transicao suave. Valor que pula seco parece defeito,
/// valor que desliza parece telemetria.
class BarraNivel extends StatelessWidget {
  const BarraNivel(
      {required this.fracao, required this.cor, this.altura = 6, super.key});

  final double fracao;
  final Color cor;
  final double altura;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(altura),
        child: Stack(children: [
          Container(height: altura, color: Cores.borda),
          LayoutBuilder(
            builder: (_, limites) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              height: altura,
              width: limites.maxWidth * fracao.clamp(0, 1),
              decoration: BoxDecoration(
                color: cor,
                borderRadius: BorderRadius.circular(altura),
              ),
            ),
          ),
        ]),
      );
}

/// Numero grande que troca deslizando, em vez de piscar.
class ValorAnimado extends StatelessWidget {
  const ValorAnimado(
      {required this.valor, required this.cor, this.tamanho = 56, super.key});

  final double valor;
  final Color cor;
  final double tamanho;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (filho, animacao) => FadeTransition(
          opacity: animacao,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.25), end: Offset.zero)
                .animate(animacao),
            child: filho,
          ),
        ),
        child: Text(
          '${valor.toStringAsFixed(1)}%',
          key: ValueKey(valor.toStringAsFixed(1)),
          style: Fontes.valor(tamanho, cor),
        ),
      );
}
