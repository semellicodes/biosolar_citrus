import 'package:flutter/material.dart';

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
    home: TelaMonitoramento(leitor: servicos(), emissor: servicos()),
  ));
}
