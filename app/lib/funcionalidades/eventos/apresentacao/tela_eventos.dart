/// Histórico de decisões.
///
/// A lista é o print que prova a autonomia: no modo demonstração ela enche de
/// eventos do sistema sem ninguém tocar em nada.
library;

import 'package:compartilhado/modelos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../nucleo/tema.dart';
import 'eventos_bloc.dart';

const _vermelho = Cores.vermelho;
const _azul = Color(0xFF1B5FA8);
const _amarelo = Cores.ambar;
const _cinza = Cores.textoSecundario;

/// Cor e ícone por tipo, para achar o bloqueio no meio da lista sem ler.
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
      TipoEvento.chuvaIniciada => (cor: _azul, icone: Icons.water),
      TipoEvento.chuvaEncerrada => (cor: _cinza, icone: Icons.water_outlined),
    };

String _hora(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}:'
    '${d.second.toString().padLeft(2, '0')}';

class TelaEventos extends StatelessWidget {
  const TelaEventos({super.key});

  static const String rota = '/eventos';

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<EventosBloc>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Histórico de decisões',
            style: Fontes.titulo(Cores.texto, tamanho: 18)),
        iconTheme: const IconThemeData(color: Cores.textoSecundario),
      ),
      body: BlocBuilder<EventosBloc, EstadoHistorico>(
        builder: (context, estado) {
          final visiveis = estado.visiveis;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Espaco.m, vertical: Espaco.p),
              child: Row(children: [
                Segmentado(
                  opcoes: const ['Tudo', 'Sistema', 'Operador'],
                  selecionado: switch (estado.filtro) {
                    null => 0,
                    Origem.sistema => 1,
                    Origem.operador => 2,
                  },
                  aoSelecionar: (indice) => bloc.add(FiltroAlterado(
                      switch (indice) {
                        1 => Origem.sistema,
                        2 => Origem.operador,
                        _ => null,
                      })),
                ),
                const Spacer(),
                Text('${visiveis.length} eventos',
                    style: Fontes.corpo(Cores.textoTerciario, tamanho: 12)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: visiveis.isEmpty
                  ? Center(
                      child: Text('Nenhuma decisão registrada ainda.',
                          style: Fontes.corpo(_cinza)))
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
          style: doSistema
              ? Fontes.titulo(Cores.texto, tamanho: 15)
              : Fontes.corpo(Cores.texto, tamanho: 15)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: Espaco.xs),
        child: Text(evento.motivo, style: Fontes.corpo(_cinza, tamanho: 12)),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_hora(evento.hora), style: Fontes.corpo(_cinza, tamanho: 12)),
          const SizedBox(height: Espaco.xs),
          // RN11: a origem e escrita, nao so sugerida pela cor (RNF04).
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: doSistema ? aparencia.cor : Colors.transparent,
              border: Border.all(color: doSistema ? aparencia.cor : Cores.borda),
              borderRadius: BorderRadius.circular(Raio.interno - 2),
            ),
            child: Text(
              doSistema ? 'Sistema' : 'Operador',
              style: Fontes.corpo(doSistema ? Colors.white : _cinza,
                  tamanho: 11),
            ),
          ),
        ],
      ),
    );
  }
}
