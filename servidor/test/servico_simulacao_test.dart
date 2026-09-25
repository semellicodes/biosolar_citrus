import 'package:compartilhado/modelos.dart';
import 'package:servidor/aplicacao/servico_simulacao.dart';
import 'package:servidor/infraestrutura/repositorio_memoria.dart';
import 'package:test/test.dart';

void main() {
  test('pausa manual interrompe o relogio e registra o comando', () async {
    final repositorio = RepositorioMemoria();
    final simulacao = ServicoSimulacao(repositorio)..iniciar();

    simulacao.pausar();

    expect(simulacao.ativa, isFalse);
    expect(repositorio.eventos().single.tipo, TipoEvento.simulacaoPausada);
    await simulacao.parar();
  });
}
