/// Historico de decisoes.
///
/// A lista e o print que prova a autonomia: no modo demonstracao ela enche de
/// eventos do sistema sem ninguem tocar em nada.
library;

import 'package:compartilhado/modelos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'eventos_bloc.dart';

const _vermelho = Color(0xFFC62828);
const _azul = Color(0xFF1565C0);
const _amarelo = Color(0xFFF9A825);
const _cinza = Color(0xFF616161);

/// Cor e icone por tipo, para achar o bloqueio no meio da lista sem ler.
({Color cor, IconData icone}) _aparencia(TipoEvento tipo) => switch (tipo) {
      TipoEvento.bloqueioAtivado => (cor: _vermelho, icone: Icons.block),
      // A recusa e consequencia direta do bloqueio e e a prova de que a regra
      // vive no servidor, entao ela puxa a mesma cor em vez do cinza de
      // comando do operador.
      TipoEvento.comandoRecusado => (cor: _vermelho, icone: Icons.gpp_bad),
      TipoEvento.bloqueioLiberado => (cor: _azul, icone: Icons.lock_open),
      TipoEvento.irrigacaoIniciada => (cor: _azul, icone: Icons.water_drop),
      TipoEvento.irrigacaoEncerrada => (
          cor: _azul,
          icone: Icons.water_drop_outlined
        ),
      TipoEvento.alertaDesperdicio => (
          cor: _amarelo,
          icone: Icons.warning_amber
        ),
      TipoEvento.comandoAceito => (cor: _cinza, icone: Icons.touch_app),
      TipoEvento.velocidadeAlterada => (cor: _cinza, icone: Icons.fast_forward),
      TipoEvento.simulacaoReiniciada => (cor: _cinza, icone: Icons.restart_alt),
    };

String _hora(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}:'
    '${d.second.toString().padLeft(2, '0')}';

class TelaEventos extends StatelessWidget {
  const TelaEventos({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<EventosBloc>();

    return Scaffold(
      appBar: AppBar(title: const Text('Historico de decisoes')),
      body: BlocBuilder<EventosBloc, EstadoHistorico>(
        builder: (context, estado) {
          final visiveis = estado.visiveis;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                for (final (rotulo, origem) in const [
                  ('Tudo', null),
                  ('Sistema', Origem.sistema),
                  ('Operador', Origem.operador),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(rotulo),
                      selected: estado.filtro == origem,
                      onSelected: (_) => bloc.add(FiltroAlterado(origem)),
                    ),
                  ),
                const Spacer(),
                Text('${visiveis.length}',
                    style: const TextStyle(color: _cinza)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: visiveis.isEmpty
                  ? const Center(child: Text('Nenhuma decisao registrada ainda.'))
                  // Construcao sob demanda: a lista cresce durante a sessao.
                  : ListView.separated(
                      itemCount: visiveis.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, indice) => _Linha(visiveis[indice]),
                    ),
            ),
          ]);
        },
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha(this.evento);

  final Evento evento;

  @override
  Widget build(BuildContext context) {
    final aparencia = _aparencia(evento.tipo);
    final doSistema = evento.origem == Origem.sistema;

    return ListTile(
      // Barra na lateral separando o que o sistema decidiu do que o operador
      // mandou, visivel de longe durante a demonstracao.
      leading: SizedBox(
        width: 44,
        child: Row(children: [
          Container(
            width: 4,
            height: 36,
            color: doSistema ? aparencia.cor : Colors.transparent,
          ),
          const SizedBox(width: 8),
          Icon(aparencia.icone, color: aparencia.cor),
        ]),
      ),
      title: Text(evento.descricao,
          style: TextStyle(
              fontWeight: doSistema ? FontWeight.bold : FontWeight.normal)),
      subtitle: Text(evento.motivo, style: const TextStyle(fontSize: 12)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_hora(evento.hora), style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          // RN11: a origem e escrita, nao so sugerida pela cor (RNF04).
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: doSistema ? aparencia.cor : Colors.transparent,
              border: Border.all(color: doSistema ? aparencia.cor : _cinza),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              doSistema ? 'SISTEMA' : 'OPERADOR',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: doSistema ? Colors.white : _cinza),
            ),
          ),
        ],
      ),
    );
  }
}
