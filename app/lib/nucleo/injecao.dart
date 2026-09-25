library;

import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

import '../funcionalidades/monitoramento/apresentacao/comando_bloc.dart';
import '../funcionalidades/monitoramento/apresentacao/telemetria_bloc.dart';
import '../funcionalidades/monitoramento/dados/api_fazenda.dart';
import '../funcionalidades/monitoramento/dados/canal_fazenda.dart';
import '../funcionalidades/eventos/apresentacao/eventos_bloc.dart';
import '../funcionalidades/eventos/dominio/contratos.dart';
import '../funcionalidades/monitoramento/dominio/contratos.dart';

final GetIt servicos = GetIt.instance;

void registrarDependencias() {

  servicos.registerLazySingleton<http.Client>(http.Client.new);
  servicos.registerLazySingleton<ApiFazenda>(
      () => ApiFazenda(cliente: servicos()));

  servicos.registerLazySingleton<LeitorTelemetria>(() => servicos<ApiFazenda>());
  servicos.registerLazySingleton<EmissorComando>(() => servicos<ApiFazenda>());
  servicos.registerLazySingleton<LeitorEventos>(() => servicos<ApiFazenda>());
  servicos.registerFactory<FonteTelemetria>(() => CanalFazenda(servicos()));

  servicos.registerFactory(() => TelemetriaBloc(servicos()));
  servicos.registerFactory(() => ComandoBloc(servicos()));
  servicos.registerFactory(() => EventosBloc(servicos()));
}
