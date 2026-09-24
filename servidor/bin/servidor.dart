import 'package:compartilhado/modelos.dart';

void main() {
  final talhao = Talhao(
      id: 't1', nome: 'Talhao 1', cultura: 'laranja', umidade: 62.0);
  print('${talhao.nome}: ${talhao.umidade}% (${talhao.faixa.name})');
}
