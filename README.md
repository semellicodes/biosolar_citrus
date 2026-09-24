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
