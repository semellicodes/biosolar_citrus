library;

sealed class Falha implements Exception {
  const Falha(this.mensagem);
  final String mensagem;
}

class FalhaBloqueio extends Falha {
  const FalhaBloqueio(super.mensagem);
}

class FalhaComunicacao extends Falha {
  const FalhaComunicacao(super.mensagem);
}
