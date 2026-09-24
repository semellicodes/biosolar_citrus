# BioSolar Citrus

Sistema de automação hidro-energética para pomares de citros. Um servidor Dart
simula a fazenda em tempo real (umidade dos talhões, nível do reservatório,
estado das bombas) e toma **todas** as decisões de irrigação: liga o aspersor
sozinho quando o solo seca (RN04) e executa bloqueio de emergência desligando
tudo quando o reservatório chega ao nível crítico (RN06), com precedência
absoluta do bloqueio sobre a irrigação (RN07). O aplicativo Flutter apenas
exibe a telemetria e envia comandos manuais — nenhuma regra de automação mora
no app.

HackUFRA, V JTI — Caderno de Desafio, Opção 03. Autora: Paula — UFRA, Campus
Capitão Poço.

## Rodando

```bash
dart pub get -C servidor
dart run servidor/bin/servidor.dart          # ciclo de 2s
dart run servidor/bin/servidor.dart --demo   # modo demonstracao, ciclo de 300ms
```

| Rota | Para que serve |
| --- | --- |
| `GET /telemetria` | Estado completo da fazenda |
| `POST /bombas/acionar` | `{"bombaId":"b1","ligar":true}`. Responde **409** durante o bloqueio |
| `GET /eventos?limite=&deslocamento=` | Historico de decisoes |
| `POST /simulacao/velocidade` | `{"acelerada":true}` liga o modo demonstracao |
| `POST /simulacao/reset` | Devolve a simulacao ao estado inicial |

## Regras

Todas as decisoes vivem em [`servidor/lib/dominio/regras/regras.dart`](servidor/lib/dominio/regras/regras.dart),
como funcoes puras, e sao provadas pelos testes T01 a T10 em
[`servidor/test/regras_test.dart`](servidor/test/regras_test.dart) (`dart test servidor`).

| | Regra | Limiar |
| --- | --- | --- |
| RN04 | Irrigacao critica automatica | umidade < 25% |
| RN05 | Encerramento da irrigacao | umidade >= 45% (histerese) |
| RN06 | Bloqueio de emergencia | reservatorio < 15% |
| RN07 | Bloqueio tem precedencia sobre a irrigacao | garantido pela ordem do ciclo e por guarda na regra |
| RN08 | Comando manual recusado no bloqueio | HTTP 409 com o motivo |
| RN09 | Liberacao do bloqueio | reservatorio >= 25% |
