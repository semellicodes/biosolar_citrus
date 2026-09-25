/// Painel de monitoramento. So desenha e envia comandos.
///
/// Nenhuma decisao de automacao acontece aqui: as cores vem da faixa calculada
/// no servidor e a recusa de comando vem da mensagem que o servidor devolveu.
library;

import 'package:compartilhado/modelos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../eventos/apresentacao/eventos_bloc.dart';
import '../../eventos/apresentacao/tela_eventos.dart';
import '../../../nucleo/injecao.dart';
import 'comando_bloc.dart';
import 'telemetria_bloc.dart';

const _cores = {
  Faixa.verde: Color(0xFF2E7D32),
  Faixa.amarelo: Color(0xFFF9A825),
  Faixa.vermelho: Color(0xFFC62828),
};

/// RNF04: o estado critico precisa ser identificavel sem depender so da cor.
String _horaDe(DateTime instante) =>
    '${instante.hour.toString().padLeft(2, '0')}:'
    '${instante.minute.toString().padLeft(2, '0')}:'
    '${instante.second.toString().padLeft(2, '0')}';

const _rotulos = {
  Faixa.verde: 'Normal',
  Faixa.amarelo: 'Atencao',
  Faixa.vermelho: 'Critico',
};

class TelaMonitoramento extends StatelessWidget {
  const TelaMonitoramento({super.key});

  @override
  Widget build(BuildContext context) {
    final telemetriaBloc = context.read<TelemetriaBloc>();

    // A recusa e a falha viram aviso na tela; a telemetria que volta de um
    // comando aceito e empurrada para o painel sem esperar a proxima consulta.
    return BlocListener<ComandoBloc, EstadoComando>(
      listener: (context, estado) => switch (estado) {
        ComandoAceito(:final telemetria) =>
          telemetriaBloc.add(TelemetriaRecebida(telemetria)),
        ComandoRecusado(:final mensagem) => _avisar(context, mensagem),
        ComandoFalhou(:final mensagem) => _avisar(context, mensagem),
        _ => null,
      },
      child: BlocBuilder<TelemetriaBloc, EstadoTelemetria>(
        builder: (context, estado) => _Painel(
          telemetria: estado.ultima,
          desconectado: estado is TelemetriaDesconectada,
        ),
      ),
    );
  }

  void _avisar(BuildContext context, String mensagem) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: _cores[Faixa.vermelho],
        content: Text(mensagem),
        duration: const Duration(seconds: 5),
      ));
}

class _Painel extends StatelessWidget {
  const _Painel({required this.telemetria, required this.desconectado});

  final Telemetria? telemetria;
  final bool desconectado;

  @override
  Widget build(BuildContext context) {
    final comandos = context.read<ComandoBloc>();
    final telemetria = this.telemetria;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BioSolar Citrus'),
        actions: [
          IconButton(
            tooltip: 'Historico de decisoes',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => BlocProvider(
                create: (_) =>
                    servicos<EventosBloc>()..add(const HistoricoAberto()),
                child: const TelaEventos(),
              ),
            )),
          ),
          IconButton(
            tooltip: 'Modo demonstracao',
            icon: const Icon(Icons.fast_forward),
            onPressed: () =>
                comandos.add(const VelocidadeSolicitada(acelerada: true)),
          ),
          IconButton(
            tooltip: 'Reiniciar cenario',
            icon: const Icon(Icons.restart_alt),
            onPressed: () => comandos.add(const ReinicioSolicitado()),
          ),
        ],
      ),
      body: telemetria == null
          ? Center(
              child: desconectado
                  ? const Text('Servidor inacessivel. Tentando de novo...')
                  : const CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (desconectado)
                  // RNF05. Numero velho sem aviso e pior que tela vazia num
                  // painel que a banca olha procurando tempo real, entao o
                  // aviso diz de quando e a leitura e que ela nao anda mais.
                  _Aviso(
                    icone: Icons.cloud_off,
                    texto: 'SEM CONTATO COM O SERVIDOR. Dados defasados, '
                        'parados na leitura das '
                        '${_horaDe(telemetria.hora)}. Reconectando...',
                    cor: const Color(0xFF616161),
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
                    aoAgir: () => comandos.add(AcionamentoSolicitado(
                        telemetria.bombas.first.id,
                        ligar: true)),
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
                    bloqueado:
                        telemetria.reservatorio.bloqueioAtivo || desconectado,
                    aoAlternar: (bomba, ligar) => comandos
                        .add(AcionamentoSolicitado(bomba.id, ligar: ligar)),
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
  final void Function(Bomba, bool) aoAlternar;

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
