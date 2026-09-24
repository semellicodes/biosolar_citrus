/// Ponto de entrada do servidor.
///
/// Por enquanto so a simulacao, imprimindo o estado a cada ciclo. As rotas HTTP
/// entram na fase 2, e o projeto ja esta vivo antes de existir qualquer tela.
library;

import 'package:compartilhado/modelos.dart';
import 'package:servidor/aplicacao/servico_simulacao.dart';
import 'package:servidor/infraestrutura/repositorio_memoria.dart';

const _cores = {
  Faixa.verde: '\x1b[32m',
  Faixa.amarelo: '\x1b[33m',
  Faixa.vermelho: '\x1b[31m',
};

String _pinta(Faixa faixa, String texto) => '${_cores[faixa]}$texto\x1b[0m';

String _hora(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}:'
    '${d.second.toString().padLeft(2, '0')}';

void main(List<String> argumentos) {
  final repositorio = RepositorioMemoria();
  final simulacao = ServicoSimulacao(repositorio);

  simulacao.atualizacoes.listen((estado) {
    final reservatorio = estado.reservatorio;
    final bombas =
        estado.bombas.where((b) => b.ligada).map((b) => b.id).join(' ');

    print('${_hora(estado.hora)} | '
        'reservatorio ${_pinta(reservatorio.faixa, '${reservatorio.nivel.toStringAsFixed(1).padLeft(5)}%')}'
        '${reservatorio.bloqueioAtivo ? ' \x1b[41m BLOQUEIO \x1b[0m' : '          '} | '
        '${estado.talhoes.map((t) => _pinta(t.faixa, '${t.nome.split(' ').last.padRight(6)}${t.umidade.toStringAsFixed(1).padLeft(5)}%')).join('  ')}'
        ' | bombas: ${bombas.isEmpty ? '-' : bombas}');
  });

  // Cada decisao aparece logo abaixo do ciclo que a produziu.
  simulacao.novosEventos.listen((evento) =>
      print('           \x1b[36m> ${evento.descricao}: ${evento.motivo}\x1b[0m'));

  if (argumentos.contains('--demo')) {
    simulacao.definirVelocidade(acelerada: true);
  } else {
    simulacao.iniciar();
  }
  print('Simulacao iniciada, ciclo a cada ${simulacao.intervalo.inMilliseconds} ms. '
      'Ctrl+C para encerrar.');
}
