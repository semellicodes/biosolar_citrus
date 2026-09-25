library;

import 'package:compartilhado/modelos.dart';

abstract interface class RepositorioFazenda {

  Telemetria get telemetria;

  void salvar(Telemetria estado);

  void registrarEventos(Iterable<Evento> eventos);

  List<Evento> eventos({int limite = 50, int deslocamento = 0});

  void reiniciar();
}
