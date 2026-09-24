/// Tipos de erro que o dominio do aplicativo sabe nomear.
library;

sealed class Falha implements Exception {
  const Falha(this.mensagem);
  final String mensagem;
}

/// RN08. A mensagem vem inteira do servidor, e a interface a exibe tal como
/// veio, para nao inventar um texto proprio sobre uma regra que nao e dela.
class FalhaBloqueio extends Falha {
  const FalhaBloqueio(super.mensagem);
}

class FalhaComunicacao extends Falha {
  const FalhaComunicacao(super.mensagem);
}
