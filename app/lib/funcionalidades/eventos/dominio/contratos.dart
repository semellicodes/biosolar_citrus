library;

import 'package:compartilhado/modelos.dart';

abstract interface class LeitorEventos {

  Future<List<Evento>> obterEventos({int limite, int deslocamento});
}
