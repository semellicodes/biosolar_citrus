/// RF01: o estado da fazenda vive na memoria do servidor, nunca no dispositivo.
library;

import 'package:compartilhado/modelos.dart';

import '../dominio/repositorio_fazenda.dart';

/// Estado inicial da fazenda demonstrada.
///
/// O Talhao 3 comeca proximo do gatilho de proposito, para que o primeiro
/// cenario da apresentacao (irrigacao automatica) apareca em poucos ciclos.
Telemetria estadoInicial(DateTime agora) => Telemetria(
      reservatorio: const Reservatorio(
          nivel: 70, capacidadeLitros: 50000, bloqueioAtivo: false),
      talhoes: const [
        Talhao(
            id: 't1',
            nome: 'Talhao Norte',
            cultura: 'Laranja Pera',
            umidade: 58),
        Talhao(
            id: 't2', nome: 'Talhao Leste', cultura: 'Limao Taiti', umidade: 41),
        Talhao(
            id: 't3',
            nome: 'Talhao Sul',
            cultura: 'Laranja Valencia',
            umidade: 30),
        Talhao(
            id: 't4',
            nome: 'Talhao Oeste',
            cultura: 'Limao Siciliano',
            umidade: 62),
      ],
      bombas: const [
        Bomba(id: 'b1', talhaoId: 't1', ligada: false),
        Bomba(id: 'b2', talhaoId: 't2', ligada: false),
        Bomba(id: 'b3', talhaoId: 't3', ligada: false),
        Bomba(id: 'b4', talhaoId: 't4', ligada: false),
      ],
      hora: agora,
    );

class RepositorioMemoria implements RepositorioFazenda {
  RepositorioMemoria() : _telemetria = estadoInicial(DateTime.now());

  /// Teto do historico em memoria, para que uma sessao longa nao cresca sem
  /// limite. Os mais antigos sao descartados.
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
