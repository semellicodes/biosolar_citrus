/// Painel de monitoramento. So desenha e envia comandos.
///
/// Nenhuma decisao de automacao acontece aqui: as cores vem da faixa calculada
/// no servidor e a recusa de comando vem da mensagem que o servidor devolveu.
library;

import 'dart:async';

import 'package:compartilhado/modelos.dart';
import 'package:flutter/material.dart';

import '../../../nucleo/falhas.dart';
import '../dominio/contratos.dart';

const _cores = {
  Faixa.verde: Color(0xFF2E7D32),
  Faixa.amarelo: Color(0xFFF9A825),
  Faixa.vermelho: Color(0xFFC62828),
};

/// RNF04: o estado critico precisa ser identificavel sem depender so da cor.
const _rotulos = {
  Faixa.verde: 'Normal',
  Faixa.amarelo: 'Atencao',
  Faixa.vermelho: 'Critico',
};

class TelaMonitoramento extends StatefulWidget {
  const TelaMonitoramento({
    required this.leitor,
    required this.emissor,
    super.key,
  });

  final LeitorTelemetria leitor;
  final EmissorComando emissor;

  @override
  State<TelaMonitoramento> createState() => _TelaMonitoramentoState();
}

class _TelaMonitoramentoState extends State<TelaMonitoramento> {
  /// RNF03: a tela precisa refletir uma mudanca em menos de dois segundos.
  /// O polling e a fase 3, o WebSocket entra na fase 4 e substitui isto.
  static const Duration _intervaloConsulta = Duration(seconds: 2);

  Timer? _consulta;

  /// Cache de exibicao, apenas em memoria, para a tela nao piscar vazia entre
  /// duas leituras. Nao e persistencia local de telemetria (RNF02).
  Telemetria? _ultimaTelemetria;
  bool _desconectado = false;

  @override
  void initState() {
    super.initState();
    _atualizar();
    _consulta = Timer.periodic(_intervaloConsulta, (_) => _atualizar());
  }

  @override
  void dispose() {
    _consulta?.cancel();
    super.dispose();
  }

  Future<void> _atualizar() async {
    try {
      final telemetria = await widget.leitor.obterTelemetria();
      if (!mounted) return;
      setState(() {
        _ultimaTelemetria = telemetria;
        _desconectado = false;
      });
    } on Falha {
      // RNF05: a queda da conexao nao trava o aplicativo. O ultimo dado
      // conhecido continua na tela e o proximo ciclo tenta de novo sozinho.
      if (!mounted) return;
      setState(() => _desconectado = true);
    }
  }

  Future<void> _acionar(Bomba bomba, bool ligar) async {
    try {
      final telemetria =
          await widget.emissor.acionarBomba(bomba.id, ligar: ligar);
      if (!mounted) return;
      setState(() => _ultimaTelemetria = telemetria);
    } on Falha catch (falha) {
      if (!mounted) return;
      // A mensagem exibida e exatamente a que veio do servidor.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: _cores[Faixa.vermelho],
        content: Text(falha.mensagem),
        duration: const Duration(seconds: 5),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final telemetria = _ultimaTelemetria;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BioSolar Citrus'),
        actions: [
          IconButton(
            tooltip: 'Modo demonstracao',
            icon: const Icon(Icons.fast_forward),
            onPressed: () => widget.emissor.definirVelocidade(acelerada: true),
          ),
          IconButton(
            tooltip: 'Reiniciar cenario',
            icon: const Icon(Icons.restart_alt),
            onPressed: () async {
              await widget.emissor.reiniciarSimulacao();
              await _atualizar();
            },
          ),
        ],
      ),
      body: telemetria == null
          ? Center(
              child: _desconectado
                  ? const Text('Servidor inacessivel. Tentando de novo...')
                  : const CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_desconectado)
                  const _Aviso(
                    icone: Icons.cloud_off,
                    texto: 'Desconectado. Exibindo a ultima leitura conhecida.',
                    cor: Color(0xFF616161),
                  ),
                if (telemetria.reservatorio.bloqueioAtivo)
                  // RF11: o bloqueio e sinalizado e os interruptores travam.
                  _Aviso(
                    icone: Icons.block,
                    texto: 'BLOQUEIO DE EMERGENCIA. Reservatorio critico, '
                        'nenhuma bomba pode ser acionada.',
                    cor: _cores[Faixa.vermelho]!,
                    // Passo 7 do roteiro de apresentacao: com os interruptores
                    // travados nao da para provar que a recusa vem do servidor.
                    // Este botao passa por cima da trava da interface e mostra
                    // o 409 chegando do dominio.
                    acao: 'Tentar mesmo assim',
                    aoAgir: () => _acionar(telemetria.bombas.first, true),
                  ),
                _Indicador(
                  titulo: 'Reservatorio',
                  valor: telemetria.reservatorio.nivel,
                  faixa: telemetria.reservatorio.faixa,
                  // RN03: a captacao solar e o que repoe o reservatorio, e e
                  // ela que permite a liberacao do bloqueio. Quando o sol some
                  // a captacao para, e a tela precisa dizer isso com todas as
                  // letras: a espera e consequencia fisica, nao travamento.
                  rodape: telemetria.fatorSolarAtual == 0
                      ? '${telemetria.horaSimulada.floor()}h  -  noite, '
                          'captacao solar parada (0%)'
                      : '${telemetria.horaSimulada.floor()}h  -  captacao '
                          'solar ${(telemetria.fatorSolarAtual * 100).round()}%',
                  icone: telemetria.fatorSolarAtual == 0
                      ? Icons.nightlight_round
                      : Icons.wb_sunny,
                ),
                const SizedBox(height: 8),
                for (final talhao in telemetria.talhoes)
                  _LinhaTalhao(
                    talhao: talhao,
                    bomba: telemetria.bombaDo(talhao.id),
                    bloqueado: telemetria.reservatorio.bloqueioAtivo,
                    aoAlternar: _acionar,
                  ),
              ],
            ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.icone,
    required this.texto,
    required this.cor,
    this.acao,
    this.aoAgir,
  });

  final IconData icone;
  final String texto;
  final Color cor;
  final String? acao;
  final VoidCallback? aoAgir;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(icone, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(texto,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          if (acao != null)
            TextButton(
              onPressed: aoAgir,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: Text(acao!),
            ),
        ]),
      );
}

class _Indicador extends StatelessWidget {
  const _Indicador(
      {required this.titulo,
      required this.valor,
      required this.faixa,
      this.rodape,
      this.icone});

  final String titulo;
  final double valor;
  final Faixa faixa;
  final String? rodape;
  final IconData? icone;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(titulo),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                value: valor / 100,
                color: _cores[faixa],
                backgroundColor: Colors.black12,
              ),
              if (rodape != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    if (icone != null) ...[
                      Icon(icone, size: 14, color: Colors.black54),
                      const SizedBox(width: 6),
                    ],
                    Text(rodape!,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                  ]),
                ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${valor.toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _cores[faixa])),
              Text(_rotulos[faixa]!,
                  style: TextStyle(fontSize: 12, color: _cores[faixa])),
            ],
          ),
        ),
      );
}

class _LinhaTalhao extends StatelessWidget {
  const _LinhaTalhao({
    required this.talhao,
    required this.bomba,
    required this.bloqueado,
    required this.aoAlternar,
  });

  final Talhao talhao;
  final Bomba bomba;
  final bool bloqueado;
  final Future<void> Function(Bomba, bool) aoAlternar;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text('${talhao.nome} (${talhao.cultura})'),
          subtitle: Text(
            '${talhao.umidade.toStringAsFixed(1)}%  -  '
            '${_rotulos[talhao.faixa]}'
            '${bomba.ligada ? '  -  irrigando (${bomba.origemUltimoAcionamento?.name ?? ''})' : ''}',
            style: TextStyle(color: _cores[talhao.faixa]),
          ),
          leading: CircleAvatar(
            backgroundColor: _cores[talhao.faixa],
            child: Text(talhao.umidade.toStringAsFixed(0),
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          trailing: Switch(
            value: bomba.ligada,
            // RF11. O servidor recusa de qualquer jeito (RN08), isto aqui e so
            // conveniencia para o operador nao tentar em vao.
            onChanged: bloqueado ? null : (ligar) => aoAlternar(bomba, ligar),
          ),
        ),
      );
}
