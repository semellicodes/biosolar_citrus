import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'funcionalidades/eventos/apresentacao/eventos_bloc.dart';
import 'funcionalidades/eventos/apresentacao/tela_eventos.dart';
import 'funcionalidades/monitoramento/apresentacao/comando_bloc.dart';
import 'funcionalidades/monitoramento/apresentacao/tela_monitoramento.dart';
import 'funcionalidades/monitoramento/apresentacao/telemetria_bloc.dart';
import 'nucleo/injecao.dart';
import 'nucleo/tema.dart';

void main() {
  registrarDependencias();

  runApp(MaterialApp(
    title: 'BioSolar Citrus',
    debugShowCheckedModeBanner: false,
    theme: construirTema(),
    initialRoute: '/',
    routes: {
      '/': (_) => MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => servicos<TelemetriaBloc>()
                  ..add(const MonitoramentoIniciado()),
              ),
              BlocProvider(create: (_) => servicos<ComandoBloc>()),
            ],
            child: const TelaMonitoramento(),
          ),
      TelaEventos.rota: (_) => BlocProvider(
            create: (_) =>
                servicos<EventosBloc>()..add(const HistoricoAberto()),
            child: const TelaEventos(),
          ),
    },
  ));
}
