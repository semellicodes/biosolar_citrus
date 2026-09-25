import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'funcionalidades/monitoramento/apresentacao/comando_bloc.dart';
import 'funcionalidades/monitoramento/apresentacao/telemetria_bloc.dart';
import 'funcionalidades/monitoramento/apresentacao/tela_monitoramento.dart';
import 'nucleo/injecao.dart';

void main() {
  registrarDependencias();

  runApp(MaterialApp(
    title: 'BioSolar Citrus',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorSchemeSeed: const Color(0xFF2E7D32),
      useMaterial3: true,
    ),
    home: MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => servicos<TelemetriaBloc>()
            ..add(const MonitoramentoIniciado()),
        ),
        BlocProvider(create: (_) => servicos<ComandoBloc>()),
      ],
      child: const TelaMonitoramento(),
    ),
  ));
}
