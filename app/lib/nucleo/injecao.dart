/// Registro manual das dependencias.
///
/// Sem geracao de codigo de proposito: gerador no meio de prazo curto adiciona
/// risco sem trazer beneficio, e sao poucos registros.
library;

import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

import '../funcionalidades/monitoramento/apresentacao/comando_bloc.dart';
import '../funcionalidades/monitoramento/apresentacao/telemetria_bloc.dart';
import '../funcionalidades/monitoramento/dados/api_fazenda.dart';
import '../funcionalidades/monitoramento/dados/canal_fazenda.dart';
import '../funcionalidades/monitoramento/dominio/contratos.dart';

final GetIt servicos = GetIt.instance;

void registrarDependencias() {
  // Singleton preguicoso: a instancia so nasce no primeiro uso, o que deixa a
  // abertura do aplicativo mais leve.
  servicos.registerLazySingleton<http.Client>(http.Client.new);
  servicos.registerLazySingleton<ApiFazenda>(
      () => ApiFazenda(cliente: servicos()));

  // Os dois contratos apontam para a mesma instancia. Quem so observa depende
  // apenas de LeitorTelemetria e nunca enxerga os metodos de escrita, e nos
  // testes basta registrar um falso no lugar para exercitar a tela inteira sem
  // subir servidor.
  servicos.registerLazySingleton<LeitorTelemetria>(() => servicos<ApiFazenda>());
  servicos.registerLazySingleton<EmissorComando>(() => servicos<ApiFazenda>());
  servicos.registerFactory<FonteTelemetria>(() => CanalFazenda(servicos()));

  // Fabrica: cada tela recebe um bloc novo, evitando estado compartilhado
  // indevido entre telas.
  servicos.registerFactory(() => TelemetriaBloc(servicos()));
  servicos.registerFactory(() => ComandoBloc(servicos()));
}
