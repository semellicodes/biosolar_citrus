library;

import 'package:compartilhado/modelos.dart';

import '../dominio/repositorio_fazenda.dart';

Telemetria estadoInicial(DateTime agora) => Telemetria(
      reservatorio: const Reservatorio(
          nivel: 26, capacidadeLitros: 50000, bloqueioAtivo: false),
      talhoes: const [
        Talhao(
            id: 't1',
            nome: 'Talhão Norte',
            cultura: 'Laranja Pera',
            umidade: 24),
        Talhao(
            id: 't2', nome: 'Talhão Leste', cultura: 'Limão Taiti', umidade: 22),
        Talhao(
            id: 't3',
            nome: 'Talhão Sul',
            cultura: 'Laranja Valência',
            umidade: 20),
        Talhao(
            id: 't4',
            nome: 'Talhão Oeste',
            cultura: 'Limão Siciliano',
            umidade: 26),
      ],
      bombas: const [
        Bomba(id: 'b1', talhaoId: 't1', ligada: false),
        Bomba(id: 'b2', talhaoId: 't2', ligada: false),
        Bomba(id: 'b3', talhaoId: 't3', ligada: false),
        Bomba(id: 'b4', talhaoId: 't4', ligada: false),
      ],
      hora: agora,
      horaSimulada: 3,
    );

class RepositorioMemoria implements RepositorioFazenda {
  RepositorioMemoria() : _telemetria = estadoInicial(DateTime.now());

  static const int maximoEventos = 500;

  Telemetria _telemetria;
  final List<Evento> _eventos = [];

  @override
  Telemetria get telemetria => _telemetria;

  @override
  void salvar(Telemetria estado) => _telemetria = estado;

  @override
  void registrarEventos(Iterable<Evento> eventos) {
    _eventos.insertAll(0, eventos.toList().reversed);
    if (_eventos.length > maximoEventos) {
      _eventos.removeRange(maximoEventos, _eventos.length);
    }
  }

  @override
  List<Evento> eventos({int limite = 50, int deslocamento = 0}) =>
      _eventos.skip(deslocamento).take(limite).toList();

  @override
  void reiniciar() {
    _telemetria = estadoInicial(DateTime.now());
    _eventos.clear();
  }
}
