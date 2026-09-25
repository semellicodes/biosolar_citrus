library;

import 'package:compartilhado/modelos.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:servidor/aplicacao/servico_simulacao.dart';
import 'package:servidor/infraestrutura/repositorio_memoria.dart';
import 'package:servidor/infraestrutura/rotas_http.dart';

const _cores = {
  Faixa.verde: '\x1b[32m',
  Faixa.amarelo: '\x1b[33m',
  Faixa.vermelho: '\x1b[31m',
};

String _pinta(Faixa faixa, String texto) => '${_cores[faixa]}$texto\x1b[0m';

String _hora(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}:'
    '${d.second.toString().padLeft(2, '0')}';

Future<void> main(List<String> argumentos) async {
  final repositorio = RepositorioMemoria();
  final simulacao = ServicoSimulacao(repositorio);

  simulacao.atualizacoes.listen((estado) {
    final reservatorio = estado.reservatorio;
    final bombas =
        estado.bombas.where((b) => b.ligada).map((b) => b.id).join(' ');

    final sol = (estado.fatorSolarAtual * 10).round();
    print('${_hora(estado.hora)} | '
        '${estado.horaSimulada.floor().toString().padLeft(2, '0')}h '
        '${('*' * sol).padRight(10)} | '
        'reservatorio ${_pinta(reservatorio.faixa, '${reservatorio.nivel.toStringAsFixed(1).padLeft(5)}%')}'
        '${reservatorio.bloqueioAtivo ? ' \x1b[41m BLOQUEIO \x1b[0m' : '          '} | '
        '${estado.talhoes.map((t) => _pinta(t.faixa, '${t.nome.split(' ').last.padRight(6)}${t.umidade.toStringAsFixed(1).padLeft(5)}%')).join('  ')}'
        ' | bombas: ${bombas.isEmpty ? '-' : bombas}');
  });

  simulacao.novosEventos.listen((evento) =>
      print('           \x1b[36m> ${evento.descricao}: ${evento.motivo}\x1b[0m'));

  if (argumentos.contains('--demo')) {
    simulacao.definirVelocidade(acelerada: true);
  } else {
    simulacao.iniciar();
  }
  final servidor = await io.serve(
      criarRotas(simulacao, repositorio), '0.0.0.0', 8080);
  print('Servidor em http://${servidor.address.host}:${servidor.port}, '
      'ciclo a cada ${simulacao.intervalo.inMilliseconds} ms. '
      'Ctrl+C para encerrar.');
}
