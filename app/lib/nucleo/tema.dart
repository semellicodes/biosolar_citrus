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

  /// Canto totalmente arredondado, para o botao de acionamento.
  static const double pilula = 999;
}

abstract final class Cores {
  // Cinza de papel técnico: neutro para os estados de irrigação aparecerem.
  static const Color fundo = Color(0xFFEFF1EC);

  // Superfície de leitura, quase branca sem parecer uma tela genérica.
  static const Color superficie = Color(0xFFFBFCF8);

  // Elementos secundários.
  static const Color superficieAlta = Color(0xFFE3E8DC);

  // Borda oliva discreta.
  static const Color borda = Color(0xFFC7D0C1);

  // Gráficos inativos.
  static const Color grafico = Color(0xFFAEBE9E);

  // Textos.
  static const Color texto = Color(0xFF152017);
  static const Color textoSecundario = Color(0xFF4A594B);
  static const Color textoTerciario = Color(0xFF6D796C);

  // Folha madura.
  static const Color verde = Color(0xFF17633A);

  // Casca de citrus.
  static const Color ambar = Color(0xFFF2A900);

  // Crítico.
  static const Color vermelho = Color(0xFFC33A1F);

  // Água da irrigação.
  static const Color azulAgua = Color(0xFF2878A8);

  // Marca.
  static const Color laranjaMarca = Color(0xFFE27B18);

  static Color da(Faixa faixa) => switch (faixa) {
    Faixa.verde => verde,
    Faixa.amarelo => ambar,
    Faixa.vermelho => vermelho,
  };

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
  /// Interface inteira, menos o nome do aplicativo e os valores numéricos.
  static const String familia = 'CreatoDisplay';

  /// Só o nome do aplicativo, no cabeçalho.
  static const String marca = 'Coolvetica';

  /// Valores que mudam a cada ciclo continuam em Inter.
  ///
  /// A Creato Display não tem dígitos de largura fixa nem o recurso de figuras
  /// tabulares, e sem isso o número grande dança horizontalmente a cada
  /// atualização, que é justamente o que faz um painel parecer instável.
  static TextStyle valor(double tamanho, Color cor) => GoogleFonts.inter(
    fontSize: tamanho,
    height: 1,
    color: cor,
    fontWeight: FontWeight.w700,
    letterSpacing: -tamanho * 0.025,
    fontFeatures: _tabular,
  );

  /// Nome do aplicativo. Único lugar em que a Coolvetica aparece.
  static TextStyle nomeDoAplicativo(double tamanho) => TextStyle(
    fontFamily: marca,
    fontSize: tamanho,
    color: Cores.verde,
    height: 1.1,
  );

  /// Única caixa alta do aplicativo: título de seção.
  static TextStyle secao() => const TextStyle(
    fontFamily: familia,
    fontSize: 13,
    color: Cores.textoTerciario,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );

  static TextStyle titulo(Color cor, {double tamanho = 18}) => TextStyle(
    fontFamily: familia,
    fontSize: tamanho,
    color: cor,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
  );

  static TextStyle corpo(Color cor, {double tamanho = 15}) => TextStyle(
    fontFamily: familia,
    fontSize: tamanho,
    color: cor,
    height: 1.35,
  );
}

ThemeData construirTema() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: Cores.fundo,
    colorScheme: base.colorScheme.copyWith(
      surface: Cores.superficie,
      primary: Cores.verde,
      secondary: Cores.laranjaMarca,
      tertiary: Cores.azulAgua,
      error: Cores.vermelho,
    ),
    textTheme: base.textTheme.apply(fontFamily: Fontes.familia),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: Fontes.familia),
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
        decoration: BoxDecoration(
          color: Cores.da(faixa),
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: Espaco.p),
      // Crítico chega com peso maior, porque é o que precisa ser visto de
      // relance e de longe.
      Text(
        texto ?? rotulos[faixa]!,
        style: Fontes.titulo(
          faixa == Faixa.vermelho ? Cores.da(faixa) : Cores.texto,
          tamanho: 17,
        ),
      ),
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
      Text(
        valor,
        style: Fontes.corpo(
          cor ?? Cores.texto,
          tamanho: 12,
        ).copyWith(fontWeight: FontWeight.w500),
      ),
    ],
  );
}

/// Barra de nível. Fina, sem brilho e sem raio grande.
class BarraNivel extends StatelessWidget {
  const BarraNivel({
    required this.fracao,
    required this.cor,
    this.altura = 10,
    super.key,
  });

  final double fracao;
  final Color cor;
  final double altura;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(altura / 2),
    child: Stack(
      children: [
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
      ],
    ),
  );
}

/// Botão de acionamento, no lugar do Switch do Material.
///
/// Feito para ser tocado com uma mão, de pé no meio do pomar: 56 pixels de
/// altura e o rótulo dizendo a ação que vai acontecer, não o estado, porque o
/// estado já está escrito acima dele.
///
/// Acionar é a ação de destaque, então vem preenchida. Desligar é a de recuo,
/// então vem vazada. Durante o bloqueio mostra cadeado, em vez de ficar apenas
/// cinza, que é como um Switch desabilitado se parece com um Switch qualquer.
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

  /// Altura do alvo de toque. Encolheu para o botão parar de competir com o
  /// número de umidade, que é o elemento mais pesado do cartão, mas fica no
  /// mínimo de 44 recomendado para toque.
  static const double altura = 44;

  @override
  Widget build(BuildContext context) {
    if (travado) {
      return Container(
        height: altura,
        padding: const EdgeInsets.symmetric(horizontal: Espaco.m),
        decoration: BoxDecoration(
          color: Cores.superficieAlta,
          borderRadius: BorderRadius.circular(Raio.pilula),
          border: Border.all(color: Cores.borda),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 16,
              color: Cores.textoSecundario,
            ),
            const SizedBox(width: Espaco.p - 2),
            Text(
              'Travado pelo bloqueio',
              style: Fontes.titulo(Cores.textoSecundario, tamanho: 14),
            ),
          ],
        ),
      );
    }

    final cor = ligado ? Cores.texto : Colors.white;

    return GestureDetector(
      onTap: () => aoAlternar(!ligado),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: altura,
        padding: const EdgeInsets.symmetric(horizontal: Espaco.m),
        decoration: BoxDecoration(
          color: ligado ? Colors.transparent : Cores.verde,
          borderRadius: BorderRadius.circular(Raio.pilula),
          border: Border.all(
            color: ligado ? Cores.borda : Cores.verde,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ligado ? Icons.stop_circle_outlined : Icons.water_drop,
              size: 16,
              color: cor,
            ),
            const SizedBox(width: Espaco.p - 2),
            Text(
              ligado ? 'Desligar irrigação' : 'Acionar irrigação',
              style: Fontes.titulo(cor, tamanho: 14),
            ),
          ],
        ),
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
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (indice, rotulo) in opcoes.indexed)
          GestureDetector(
            onTap: () => aoSelecionar(indice),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: Espaco.m,
                vertical: Espaco.p - 2,
              ),
              decoration: BoxDecoration(
                color: indice == selecionado
                    ? Cores.superficieAlta
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(Raio.interno - 2),
              ),
              child: Text(
                rotulo,
                style: Fontes.corpo(
                  indice == selecionado ? Cores.texto : Cores.textoTerciario,
                  tamanho: 12,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Número que percorre a distância até o valor novo, em vez de trocar.
///
/// Com AnimatedSwitcher os dois valores coexistiam por 300ms e o número
/// aparecia fantasma a cada ciclo. Interpolar o próprio valor resolve isso e
/// ainda lê melhor como telemetria.
class ValorAnimado extends StatelessWidget {
  const ValorAnimado({
    required this.valor,
    required this.cor,
    this.tamanho = 48,
    super.key,
  });

  final double valor;
  final Color cor;
  final double tamanho;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: valor, end: valor),
    duration: const Duration(milliseconds: 400),
    curve: Curves.easeOut,
    builder: (_, atual, _) =>
        Text('${atual.toStringAsFixed(1)}%', style: Fontes.valor(tamanho, cor)),
  );
}
