/// Contrato de acesso ao estado da fazenda.
///
/// Declarado no dominio e implementado la fora (inversao de dependencia). O
/// servico de simulacao depende desta interface e nunca da implementacao
/// concreta, o que permite trocar memoria por qualquer outra coisa sem tocar
/// em uma linha de regra.
library;

import 'package:compartilhado/modelos.dart';

abstract interface class RepositorioFazenda {
  /// Estado completo e consistente da fazenda neste instante.
  Telemetria get telemetria;

  /// Substitui o estado pelo resultado de uma decisao.
  void salvar(Telemetria estado);

  /// RF08: acrescenta eventos ao historico, do mais recente para o mais antigo.
  void registrarEventos(Iterable<Evento> eventos);

  /// Historico paginado. O historico e a unica lista que cresce sem limite,
  /// por isso e a unica que precisa de limite e deslocamento.
  List<Evento> eventos({int limite = 50, int deslocamento = 0});

  /// F12: devolve a simulacao ao estado inicial para repetir a demonstracao.
  void reiniciar();
}
