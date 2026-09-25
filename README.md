# BioSolar Citrus

Sistema de automacao hidro energetica para pomares de laranja e limao. Um
servidor em Dart simula a fazenda em tempo real, acompanhando a umidade de cada
talhao e o nivel do reservatorio, e toma sozinho todas as decisoes de irrigacao:
liga o aspersor quando o solo seca e executa o bloqueio de emergencia
desligando todas as bombas quando a agua chega ao nivel critico, recusando
inclusive os comandos manuais enquanto durar o bloqueio. O aplicativo Flutter
apenas exibe o que esta acontecendo e envia comandos do operador. **Nenhuma
regra de automacao mora no aplicativo.** Se o aplicativo for apagado, a fazenda
continua sendo irrigada corretamente.

HackUFRA, V JTI, Caderno de Desafio Opcao 03. Autora: Paula. Universidade
Federal Rural da Amazonia, Campus Capitao Poco.

## Como rodar

Precisa do Flutter, que ja traz o Dart. Desenvolvido e testado no Flutter
3.44.9 com Dart 3.12. Dois terminais:

```bash
# terminal 1, o servidor
dart pub get -C servidor && dart run servidor/bin/servidor.dart
```

```bash
# terminal 2, o aplicativo
cd app && flutter pub get && flutter run
```

Se nao houver dispositivo conectado, `flutter run -d chrome` abre a versao web,
que e a mesma base de codigo e serve de plano de contingencia.

O servidor sobe na porta 8080 e imprime o estado da fazenda a cada ciclo, entao
da para ver a simulacao funcionando antes mesmo de abrir o aplicativo. Para
acelerar a simulacao desde o inicio, use `dart run servidor/bin/servidor.dart
--demo`.

O aplicativo aponta para `http://localhost:8080` por padrao, o que serve para
web, desktop e simulador iOS. No emulador Android troque por `10.0.2.2`, e em
celular fisico pelo IP da maquina na rede local:

```bash
flutter run --dart-define=SERVIDOR=http://192.168.0.10:8080
```

## Telas

Painel em operacao normal. As faixas de alerta aparecem por cor e por texto, o
arco mostra a posicao do sol no dia simulado e a captacao do momento, e o ponto
ao lado do titulo diz se a telemetria esta chegando pelo canal em tempo real ou
pela consulta de reserva:

![Painel em operacao normal](docs/painel-normal.png)

Bloqueio de emergencia ativo. A tela inteira muda de temperatura com o estado do
reservatorio, os interruptores ficam travados e o botao "Tentar mesmo assim"
existe para provar, na frente da banca, que a recusa vem do servidor e nao da
interface:

![Painel com bloqueio de emergencia](docs/painel-bloqueio.png)

Historico de decisoes. O bloqueio em vermelho aparece no meio da parede azul
das irrigacoes automaticas, e cada linha diz se a acao partiu do sistema ou do
operador:

![Historico de decisoes](docs/historico.png)

O painel se ajusta a largura disponivel. Os talhoes sao uma lista unica com
divisorias, e cada linha muda de arranjo conforme o espaco: em tela larga ficam
tres blocos lado a lado, identificacao, medida e controle; em coluna estreita
eles empilham. Acima de 1100 pixels o conteudo para de crescer e se centraliza,
com o fundo cobrindo a janela inteira.

## Regras de negocio

Todas as decisoes vivem em [`servidor/lib/dominio/regras/regras.dart`](servidor/lib/dominio/regras/regras.dart),
como funcoes puras que recebem o estado e devolvem o estado seguinte. Cada
funcao leva no topo o codigo da regra que implementa.

| Codigo | Regra | Limiar ou detalhe | Origem |
| --- | --- | --- | --- |
| RN01 | Queda natural da umidade | 1,2 ponto por ciclo em talhao sem irrigacao | Caderno |
| RN02 | Recuperacao por irrigacao | 3,0 pontos por ciclo com aspersor ligado | Caderno |
| RN03 | Consumo do reservatorio | 0,8 por bomba ligada por ciclo | Caderno |
| RN04 | Irrigacao critica automatica | umidade abaixo de 25% aciona o aspersor | Caderno |
| RN05 | Encerramento da irrigacao automatica | umidade de volta a 45%, acima do gatilho para criar histerese | Caderno |
| RN06 | Bloqueio de emergencia | reservatorio abaixo de 15% desliga todas as bombas | Caderno |
| RN07 | Precedencia | o bloqueio tem prioridade absoluta sobre a irrigacao critica | Decisao de projeto |
| RN08 | Recusa de comando manual | durante o bloqueio o servidor responde 409 com o motivo | Decisao de projeto |
| RN09 | Liberacao do bloqueio | reservatorio de volta a 25% | Decisao de projeto |
| RN10 | Faixas de alerta | verde, amarelo e vermelho, com rotulo escrito junto da cor | Caderno |
| RN11 | Origem do evento | todo evento identifica se foi operador ou sistema | Decisao de projeto |
| RN12 | Captacao solar | vazao que acompanha a curva do sol, nula a noite, no pico valendo um quinto do consumo com as quatro bombas ligadas | Decisao de projeto |

### RN12, por que existe captacao solar se o caderno nao pediu

O caderno define o consumo do reservatorio, mas nao diz o que o reabastece. Sem
reposicao, depois do primeiro bloqueio o nivel ficaria parado para sempre e a
RN09 nunca aconteceria fora dos testes. A captacao solar resolve isso e faz o
nome do projeto significar alguma coisa: ela segue a curva do sol, e nula a
noite, e no pico do dia vale um quinto do consumo com as quatro bombas ligadas.
Ou seja, **ela nunca compensa a irrigacao plena**, entao o reservatorio continua
caindo ate o bloqueio como o caderno espera. Com as bombas paradas ela repoe
agua devagar, e e isso que faz a liberacao acontecer ao vivo na demonstracao. O
valor de calibragem e `Limiares.recargaSolarPico`.

### Contrato da API

| Rota | Para que serve |
| --- | --- |
| `GET /telemetria` | Estado completo da fazenda |
| `POST /bombas/acionar` | `{"bombaId":"b1","ligar":true}`. Responde **409** durante o bloqueio, com o motivo |
| `GET /eventos?limite=&deslocamento=` | Historico de decisoes, paginado |
| `POST /simulacao/velocidade` | `{"acelerada":true}` liga o modo demonstracao |
| `POST /simulacao/reset` | Devolve a simulacao ao estado inicial |
| `WS /stream` | Empurra a telemetria a cada ciclo |

## Arquitetura

```
   +--------------------------+
   |   APLICATIVO FLUTTER     |
   |   telas e comandos       |
   +------------+-------------+
                |
         HTTP e WebSocket
                |
   +------------v-------------+
   |    SERVIDOR DART         |
   |  rotas e transporte      |
   +------------+-------------+
                |
   +------------v-------------+
   |   MOTOR DE SIMULACAO     |
   |   tick periodico         |
   +------------+-------------+
                |
   +------------v-------------+
   |   MOTOR DE REGRAS        |
   |   RN01 ate RN11          |
   +------------+-------------+
                |
   +------------v-------------+
   |   ESTADO EM MEMORIA      |
   |   talhoes, reservatorio, |
   |   bombas e eventos       |
   +--------------------------+
```

**Nenhuma decisao acontece no aplicativo.** Ele desenha o que recebe e envia o
que o operador pede, e ate a cor de cada indicador vem calculada do servidor. A
prova operacional disso e o botao "Tentar mesmo assim" do painel bloqueado: ele
passa por cima da trava da interface e o servidor recusa mesmo assim, com 409.

```
biosolar_citrus/
|
+-- servidor/
|   +-- bin/servidor.dart            ponto de entrada, simulacao e rotas
|   +-- lib/dominio/regras/          <-- TODAS as decisoes moram aqui
|   +-- lib/dominio/                 contrato do repositorio
|   +-- lib/aplicacao/               servico de simulacao, controla o tempo
|   +-- lib/infraestrutura/          rotas HTTP, WebSocket, estado em memoria
|   +-- test/                        T01 a T12
|
+-- app/
|   +-- lib/nucleo/                  injecao de dependencias e tipos de falha
|   +-- lib/funcionalidades/         monitoramento e eventos, cada um com
|   |                                dominio, dados e apresentacao
|   +-- test/                        testes de bloc
|
+-- compartilhado/
    +-- lib/modelos.dart             contratos usados pelos dois lados
```

A pasta `servidor/lib/dominio/regras/` e a mais importante do repositorio. Ela
contem apenas decisoes, sem rede e sem interface, e e a primeira coisa a abrir
quando a pergunta for onde esta determinada exigencia do caderno.

O aplicativo segue a mesma separacao por camadas dentro de cada funcionalidade.
Dois detalhes que valem apontar:

- **Leitura e comando sao contratos separados.** `LeitorTelemetria`,
  `LeitorEventos` e `EmissorComando` sao interfaces distintas, entao uma tela
  que so observa nao depende de metodos de escrita. O painel nao sabe ler
  historico e a tela de historico nao sabe ler telemetria.
- **A origem do dado fica escondida da tela.** `CanalFazenda` entrega leituras
  vindas do WebSocket ou da consulta REST de reserva, e quem consome nao sabe
  nem precisa saber por qual caminho elas chegaram. Foi isso que permitiu trocar
  polling por tempo real sem mudar uma linha de tela.

## Testes

Dezesseis testes no total. As regras sao funcoes puras, entao os testes mais
importantes do projeto sao tambem os mais simples de escrever, sem nenhum objeto
falso e sem subir servidor.

Cada linha em um subshell, para poder colar as duas de uma vez a partir da raiz
do repositorio:

```bash
(cd servidor && dart test)
```

```bash
(cd app && flutter test)
```

| Teste | O que verifica | Regra |
| --- | --- | --- |
| T01 | A umidade cai a cada ciclo em talhao sem irrigacao | RN01 |
| T02 | A umidade sobe a cada ciclo com o aspersor ligado | RN02 |
| T03 | Consumo proporcional as bombas, contra a captacao solar | RN03 |
| T04 | A irrigacao aciona sozinha ao cruzar o limite critico | RN04 |
| T05 | A irrigacao automatica so encerra no patamar de seguranca | RN05 |
| T06 | O bloqueio desliga todas as bombas ao cruzar o limite | RN06 |
| T07 | **Reservatorio critico e talhao seco ao mesmo tempo, nenhuma bomba liga** | RN07 |
| T08 | O comando manual e recusado no bloqueio e devolve o motivo | RN08 |
| T09 | O bloqueio so e liberado no patamar de seguranca | RN09 |
| T10 | Todo evento identifica corretamente a origem | RN11 |
| T11 | A captacao solar segue a curva do sol e nunca compensa a irrigacao plena | RN12 |
| T12 | A irrigacao manual acima do patamar alerta sem desligar, e alerta uma vez so | RN05 |

O **T07 e o mais valioso da suite**, porque documenta a precedencia entre as duas
regras criticas do desafio, que e o ponto onde a maioria das implementacoes
falha. O T12 roda duzentos ciclos ate o solo saturar em 100%, porque e ali que
um teste de cruzamento ingenuo vira condicao permanente e o alerta viraria spam.

Os quatro testes de bloc cobrem o que a interface promete: telemetria recebida
vira estado carregado, a perda de contato nao apaga a ultima leitura conhecida,
a leitura seguinte reconecta a tela sozinha, e a recusa do servidor chega a
interface com a mensagem original.

## Balanco hidrico e regime de escassez

O reservatorio opera em deficit, e isso nao e acidente de calibragem: e o
cenario que o caderno descreve. Durante a estiagem, a demanda de irrigacao de um
pomar supera com folga o que a captacao solar consegue repor, e a medicao abaixo
quantifica exatamente isso.

### Os numeros, medidos

Cada talhao precisa de bomba durante 28,6% do tempo para se manter na faixa
segura, porque a umidade sobe 3,0 por ciclo irrigando e cai 1,2 por ciclo sem
irrigacao, entao `1,2 / (3,0 + 1,2)`. Com quatro talhoes, isso da 1,14 bombas
ligadas em media, de forma continua.

| | Calculo | Pontos percentuais por dia |
| --- | --- | --- |
| Captacao solar | `0,64 x media do seno x 48 ciclos de sol` | **19,6** |
| Consumo da irrigacao | `1,14 bombas x 0,8 x 96 ciclos` | **87,8** |
| Saldo | | **-68,2** |

**O consumo e cerca de 4,5 vezes a captacao.** O unico momento em que o nivel
sobe e durante o bloqueio, com todas as bombas desligadas, e por isso o sistema
se estabiliza oscilando entre 13% e 25%: e o unico equilibrio possivel com esta
fazenda.

Observado em execucao, com a simulacao acelerada:

| Hora simulada | Nivel | Bloqueio | Bombas |
| --- | --- | --- | --- |
| 12h | 24,7% | ativo | 0 |
| 13h | 17,7% | liberado | 4 |
| 14h | 13,6% | ativo | 0 |
| 18h as 6h | 18,2% | ativo | 0 |
| 8h | 19,7% | ativo | 0 |

O bloqueio e liberado quando a captacao leva o nivel aos 25%, as quatro bombas
ligam de uma vez nos talhoes secos e derrubam onze pontos em uma hora simulada,
e o bloqueio volta. A noite o nivel fica parado, porque a captacao e solar.

### O que isso quer dizer

**A fazenda e subdimensionada para irrigacao plena.** Dimensionar reservatorio e
captacao para a demanda do pomar e decisao de projeto agronomico, nao de
software: envolve area irrigada, cultura, evapotranspiracao local e orcamento de
painel solar. O papel do sistema de automacao diante de uma fazenda assim e
exatamente o que ele faz, que e **impedir que o reservatorio zere**, irrigando
enquanto ha agua e travando tudo quando nao ha.

Uma calibragem alternativa, se o objetivo fosse um cenario que se recupera em
vez de oscilar, seria mexer no estado inicial em vez das taxas: partir de
talhoes bem secos para o bloqueio acontecer logo no comeco, e reduzir o consumo
por bomba para que a fazenda se sustente depois disso. Os numeros atuais foram
escolhidos para que o bloqueio aconteca de forma confiavel na demonstracao.

### Irrigacao sem priorizacao

O sistema trata todos os talhoes com igualdade, entao quando o bloqueio e
liberado todos os que estiverem abaixo do gatilho sao irrigados ao mesmo tempo.
Uma regra de priorizacao por criticidade, irrigando apenas o talhao mais seco
abaixo de um patamar de conforto, suavizaria a queda e entraria como mais uma
funcao no mesmo modulo de regras, sem tocar em transporte nem em interface.

Vale a ressalva de que ela **nao elimina o deficit**: como a manutencao dos
quatro talhoes exige 1,14 bombas em media, uma bomba de cada vez nao da conta do
pomar inteiro. O problema e de dimensionamento, e a priorizacao trata do
sintoma.

### Pausa noturna da captacao

A noite a captacao solar e zero e o reservatorio fica parado ate o amanhecer
simulado. Nao e defeito, e o comportamento esperado de um sistema movido a sol,
e o painel diz isso com todas as letras. Se a demonstracao cair num horario
simulado ruim, o botao de reiniciar cenario devolve a fazenda para a manha.

### Sem persistencia

O estado vive na memoria do servidor e o historico tem teto de 500 eventos,
descartando os mais antigos. Reiniciar o servidor zera a simulacao. E uma
decisao alinhada ao caderno, que proibe persistencia local e nao exige banco de
dados.

## Evolucao futura

Em uma versao com pomar real, a camada de simulacao daria lugar a leitura de
sensores de umidade de solo e boia de nivel, e as bombas passariam a ser
acionadas por rele, sem que o motor de regras precisasse mudar, porque ele ja
recebe estado e devolve decisao sem saber de onde o estado veio. Junto com isso
entrariam a priorizacao por criticidade descrita acima, o balanco energetico
solar completo, indicando as janelas em que irrigar sai mais barato, e um
historico persistente para analise de safra, que hoje nao existe apenas porque
a restricao de persistencia do desafio nao permite.
