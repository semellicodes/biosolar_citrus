import 'package:flutter/material.dart';

import 'funcionalidades/monitoramento/dados/api_fazenda.dart';
import 'funcionalidades/monitoramento/apresentacao/tela_monitoramento.dart';

void main() {
  // Registro manual por enquanto. O GetIt entra na fase seguinte, junto com os
  // blocs, quando houver mais de uma tela para servir.
  final api = ApiFazenda();

  runApp(MaterialApp(
    title: 'BioSolar Citrus',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorSchemeSeed: const Color(0xFF2E7D32),
      useMaterial3: true,
    ),
    home: TelaMonitoramento(leitor: api, emissor: api),
  ));
}
