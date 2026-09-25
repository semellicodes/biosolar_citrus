/// Contrato do historico.
///
/// Separado do contrato de telemetria de proposito: o painel nao precisa saber
/// ler historico e a tela de historico nao precisa saber ler telemetria.
library;

import 'package:compartilhado/modelos.dart';

abstract interface class LeitorEventos {
  /// Paginado porque o historico e a unica lista que cresce sem limite.
  Future<List<Evento>> obterEventos({int limite, int deslocamento});
}
