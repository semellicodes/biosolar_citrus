# BioSolar Citrus

Sistema de automação hidro energética para pomares de laranja e limão. Um
servidor em Dart simula a fazenda em tempo real, acompanhando a umidade de cada
talhão e o nível do reservatório, e toma sozinho todas as decisões de irrigação:
liga o aspersor quando o solo seca e executa o bloqueio de emergência
desligando todas as bombas quando a água chega ao nível crítico, recusando
inclusive os comandos manuais enquanto durar o bloqueio. O aplicativo Flutter
apenas exibe o que está acontecendo e envia comandos do operador. **Nenhuma
regra de automação mora no aplicativo.** Se o aplicativo for apagado, a fazenda
continua sendo irrigada corretamente.

HackUFRA, V JTI, Caderno de Desafio Opção 03. Autora: Paula. Universidade
Federal Rural da Amazônia, Campus Capitão Poço.

## Como rodar

Precisa do Flutter, que já traz o Dart. Desenvolvido e testado no Flutter
3.44.9 com Dart 3.12. Dois terminais:

```bash
# terminal 1, o servidor
dart pub get -C servidor && dart run servidor/bin/servidor.dart
```

```bash
# terminal 2, o aplicativo
cd app && flutter pub get && flutter run
```

Se não houver dispositivo conectado, `flutter run -d chrome` abre a versão web,
que é a mesma base de código e serve de plano de contingência.

O servidor sobe na porta 8080 e imprime o estado da fazenda a cada ciclo, então
dá para ver a simulação funcionando antes mesmo de abrir o aplicativo. Para
acelerar a simulação desde o início, use `dart run servidor/bin/servidor.dart
--demo`.

O aplicativo aponta para `http://localhost:8080` por padrão, o que serve para
web, desktop e simulador iOS. No emulador Android troque por `10.0.2.2`, e em
celular físico pelo IP da máquina na rede local:

```bash
flutter run --dart-define=SERVIDOR=http://192.168.0.10:8080
```

## Telas

Painel em operação normal. As faixas de alerta aparecem por cor e por texto, o
gráfico mostra a produção solar prevista ao longo do dia simulado com a hora
atual destacada, e o ponto ao lado do título diz se a telemetria está chegando
pelo canal em tempo real ou pela consulta de reserva:

![Painel em operação normal](docs/painel-normal.png)

Bloqueio de emergência ativo. A tela inteira muda de temperatura com o estado do
reservatório, os interruptores ficam travados e o botão "Tentar mesmo assim"
existe para provar, na frente da banca, que a recusa vem do servidor e não da
interface:

![Painel com bloqueio de emergência](docs/painel-bloqueio.png)

Histórico de decisões. O bloqueio em vermelho aparece no meio da parede azul
das irrigações automáticas, e cada linha diz se a ação partiu do sistema ou do
operador:

![Histórico de decisões](docs/historico.png)

O painel se ajusta à largura disponível. Os talhões são uma lista única com
divisórias, e cada linha muda de arranjo conforme o espaço: em tela larga ficam
três blocos lado a lado, identificação, medida e controle; em coluna estreita
eles empilham. Acima de 1100 pixels o conteúdo para de crescer e se centraliza,
com o fundo cobrindo a janela inteira.

## Regras de negócio

Todas as decisões vivem em [`servidor/lib/dominio/regras/regras.dart`](servidor/lib/dominio/regras/regras.dart),
como funções puras que recebem o estado e devolvem o estado seguinte. Cada
função leva no topo o código da regra que implementa.

A coluna de origem separa o que o caderno exige do que foi projetado aqui. Onde
o caderno define o comportamento mas não o número, a linha aparece como caderno
com calibragem própria, porque o valor foi escolhido para que a demonstração
funcione e não está no enunciado.

| Código | Regra | Limiar ou detalhe | Origem |
| --- | --- | --- | --- |
| RN01 | Queda natural da umidade | 1,2 ponto por ciclo em talhão sem irrigação | Caderno, taxa calibrada aqui |
| RN02 | Recuperação por irrigação | 3,0 pontos por ciclo com aspersor ligado | Caderno, taxa calibrada aqui |
| RN03 | Consumo do reservatório | 0,8 por bomba ligada por ciclo | Caderno, taxa calibrada aqui |
| RN04 | Irrigação crítica automática | umidade abaixo de 25% aciona o aspersor | Caderno |
| RN05 | Encerramento da irrigação automática | umidade de volta a 45%, acima do gatilho para criar histerese | Caderno, patamar e histerese decididos aqui |
| RN06 | Bloqueio de emergência | reservatório abaixo de 15% desliga todas as bombas | Caderno |
| RN07 | Precedência | o bloqueio tem prioridade absoluta sobre a irrigação crítica | Decisão de projeto |
| RN08 | Recusa de comando manual | durante o bloqueio o servidor responde 409 com o motivo | Decisão de projeto |
| RN09 | Liberação do bloqueio | reservatório de volta a 25% | Decisão de projeto |
| RN10 | Faixas de alerta | verde, amarelo e vermelho, com rótulo escrito junto da cor | Caderno, fronteiras decididas aqui |
| RN11 | Origem do evento | todo evento identifica se foi operador ou sistema | Decisão de projeto |
| RN12 | Captação solar | vazão que acompanha a curva do sol, nula à noite, no pico valendo um quinto do consumo com as quatro bombas ligadas | Decisão de projeto |

O caderno define os dois limiares que importam, 25% de umidade e 15% de
reservatório. Todo o resto, as taxas de queda e recuperação, o consumo por
bomba, o patamar de histerese e as fronteiras de cor, é calibragem feita para
que os cenários aconteçam em tempo de demonstração.

### RN12, por que existe captação solar se o caderno não pediu

O caderno define o consumo do reservatório, mas não diz o que o reabastece. Sem
reposição, depois do primeiro bloqueio o nível ficaria parado para sempre e a
RN09 nunca aconteceria fora dos testes. A captação solar resolve isso e faz o
nome do projeto significar alguma coisa: ela segue a curva do sol, é nula à
noite, e no pico do dia vale um quinto do consumo com as quatro bombas ligadas.
Ou seja, **ela nunca compensa a irrigação plena**, então o reservatório continua
caindo até o bloqueio como o caderno espera. Com as bombas paradas ela repõe
água devagar, e é isso que faz a liberação acontecer ao vivo na demonstração. O
valor de calibragem é `Limiares.recargaSolarPico`.

### Contrato da API

| Rota | Para que serve |
| --- | --- |
| `GET /telemetria` | Estado completo da fazenda |
| `POST /bombas/acionar` | `{"bombaId":"b1","ligar":true}`. Responde **409** durante o bloqueio, com o motivo |
| `GET /eventos?limite=&deslocamento=` | Histórico de decisões, paginado |
| `POST /simulacao/velocidade` | `{"acelerada":true}` liga o modo demonstração |
| `POST /simulacao/reset` | Devolve a simulação ao estado inicial |
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
   |   RN01 ate RN12          |
   +------------+-------------+
                |
   +------------v-------------+
   |   ESTADO EM MEMORIA      |
   |   talhoes, reservatorio, |
   |   bombas e eventos       |
   +--------------------------+
```

**Nenhuma decisão acontece no aplicativo.** Ele desenha o que recebe e envia o
que o operador pede, e até a cor de cada indicador vem calculada do servidor. A
prova operacional disso é o botão "Tentar mesmo assim" do painel bloqueado: ele
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
|   +-- lib/nucleo/                  injecao de dependencias, tema e falhas
|   +-- lib/funcionalidades/         monitoramento e eventos, cada um com
|   |                                dominio, dados e apresentacao
|   +-- test/                        testes de bloc
|
+-- compartilhado/
    +-- lib/modelos.dart             contratos usados pelos dois lados
```

A pasta `servidor/lib/dominio/regras/` é a mais importante do repositório. Ela
contém apenas decisões, sem rede e sem interface, e é a primeira coisa a abrir
quando a pergunta for onde está determinada exigência do caderno.

O aplicativo segue a mesma separação por camadas dentro de cada funcionalidade.
Dois detalhes que valem apontar:

- **Leitura e comando são contratos separados.** `LeitorTelemetria`,
  `LeitorEventos` e `EmissorComando` são interfaces distintas, então uma tela
  que só observa não depende de métodos de escrita. O painel não sabe ler
  histórico e a tela de histórico não sabe ler telemetria.
- **A origem do dado fica escondida da tela.** `CanalFazenda` entrega leituras
  vindas do WebSocket ou da consulta REST de reserva, e quem consome não sabe
  nem precisa saber por qual caminho elas chegaram. Foi isso que permitiu trocar
  polling por tempo real sem mudar uma linha de tela.

## Testes

Dezesseis testes no total, executados a cada envio pela rotina de integração
contínua em [`.github/workflows/ci.yaml`](.github/workflows/ci.yaml). As regras
são funções puras, então os testes mais importantes do projeto são também os
mais simples de escrever, sem nenhum objeto falso e sem subir servidor.

Cada linha em um subshell, para poder colar as duas de uma vez a partir da raiz
do repositório:

```bash
(cd servidor && dart test)
```

```bash
(cd app && flutter test)
```

| Teste | O que verifica | Regra |
| --- | --- | --- |
| T01 | A umidade cai a cada ciclo em talhão sem irrigação | RN01 |
| T02 | A umidade sobe a cada ciclo com o aspersor ligado | RN02 |
| T03 | Consumo proporcional às bombas, contra a captação solar | RN03 |
| T04 | A irrigação aciona sozinha ao cruzar o limite crítico | RN04 |
| T05 | A irrigação automática só encerra no patamar de segurança | RN05 |
| T06 | O bloqueio desliga todas as bombas ao cruzar o limite | RN06 |
| T07 | **Reservatório crítico e talhão seco ao mesmo tempo, nenhuma bomba liga** | RN07 |
| T08 | O comando manual é recusado no bloqueio e devolve o motivo | RN08 |
| T09 | O bloqueio só é liberado no patamar de segurança | RN09 |
| T10 | Todo evento identifica corretamente a origem | RN11 |
| T11 | A captação solar segue a curva do sol e nunca compensa a irrigação plena | RN12 |
| T12 | A irrigação manual acima do patamar alerta sem desligar, e alerta uma vez só | RN05 |

O **T07 é o mais valioso da suíte**, porque documenta a precedência entre as duas
regras críticas do desafio, que é o ponto onde a maioria das implementações
falha. O T12 roda duzentos ciclos até o solo saturar em 100%, porque é ali que
um teste de cruzamento ingênuo vira condição permanente e o alerta viraria spam.

Os quatro testes de bloc cobrem o que a interface promete: telemetria recebida
vira estado carregado, a perda de contato não apaga a última leitura conhecida,
a leitura seguinte reconecta a tela sozinha, e a recusa do servidor chega à
interface com a mensagem original.

## Balanço hídrico e regime de escassez

O reservatório opera em déficit, e isso não é acidente de calibragem: é o
cenário que o caderno descreve. Durante a estiagem, a demanda de irrigação de um
pomar supera com folga o que a captação solar consegue repor, e a medição abaixo
quantifica exatamente isso.

### Os números, medidos

Cada talhão precisa de bomba durante 28,6% do tempo para se manter na faixa
segura, porque a umidade sobe 3,0 por ciclo irrigando e cai 1,2 por ciclo sem
irrigação, então `1,2 / (3,0 + 1,2)`. Com quatro talhões, isso dá 1,14 bombas
ligadas em média, de forma contínua.

| | Cálculo | Pontos percentuais por dia |
| --- | --- | --- |
| Captação solar | `0,64 x média do seno x 48 ciclos de sol` | **19,6** |
| Consumo da irrigação | `1,14 bombas x 0,8 x 96 ciclos` | **87,8** |
| Saldo | | **-68,2** |

**O consumo é cerca de 4,5 vezes a captação.** O único momento em que o nível
sobe é durante o bloqueio, com todas as bombas desligadas, e por isso o sistema
se estabiliza oscilando entre 13% e 25%: é o único equilíbrio possível com esta
fazenda.

Observado em execução, com a simulação acelerada:

| Hora simulada | Nível | Bloqueio | Bombas |
| --- | --- | --- | --- |
| 12h | 24,7% | ativo | 0 |
| 13h | 17,7% | liberado | 4 |
| 14h | 13,6% | ativo | 0 |
| 18h às 6h | 18,2% | ativo | 0 |
| 8h | 19,7% | ativo | 0 |

O bloqueio é liberado quando a captação leva o nível aos 25%, as quatro bombas
ligam de uma vez nos talhões secos e derrubam onze pontos em uma hora simulada,
e o bloqueio volta. À noite o nível fica parado, porque a captação é solar.

### O que isso quer dizer

**A fazenda é subdimensionada para irrigação plena.** Dimensionar reservatório e
captação para a demanda do pomar é decisão de projeto agronômico, não de
software: envolve área irrigada, cultura, evapotranspiração local e orçamento de
painel solar. O papel do sistema de automação diante de uma fazenda assim é
exatamente o que ele faz, que é **impedir que o reservatório zere**, irrigando
enquanto há água e travando tudo quando não há.

Uma calibragem alternativa, se o objetivo fosse um cenário que se recupera em
vez de oscilar, seria mexer no estado inicial em vez das taxas: partir de
talhões bem secos para o bloqueio acontecer logo no começo, e reduzir o consumo
por bomba para que a fazenda se sustente depois disso. Os números atuais foram
escolhidos para que o bloqueio aconteça de forma confiável na demonstração.

### Irrigação sem priorização

O sistema trata todos os talhões com igualdade, então quando o bloqueio é
liberado todos os que estiverem abaixo do gatilho são irrigados ao mesmo tempo.
Uma regra de priorização por criticidade, irrigando apenas o talhão mais seco
abaixo de um patamar de conforto, suavizaria a queda e entraria como mais uma
função no mesmo módulo de regras, sem tocar em transporte nem em interface.

Vale a ressalva de que ela **não elimina o déficit**: como a manutenção dos
quatro talhões exige 1,14 bombas em média, uma bomba de cada vez não dá conta do
pomar inteiro. O problema é de dimensionamento, e a priorização trata do
sintoma.

### Pausa noturna da captação

À noite a captação solar é zero e o reservatório fica parado até o amanhecer
simulado. Não é defeito, é o comportamento esperado de um sistema movido a sol,
e o painel diz isso com todas as letras. Se a demonstração cair num horário
simulado ruim, o botão de reiniciar cenário devolve a fazenda para a manhã.

### Sem persistência

O estado vive na memória do servidor e o histórico tem teto de 500 eventos,
descartando os mais antigos. Reiniciar o servidor zera a simulação. É uma
decisão alinhada ao caderno, que proíbe persistência local e não exige banco de
dados.

## Evolução futura

Em uma versão com pomar real, a camada de simulação daria lugar à leitura de
sensores de umidade de solo e boia de nível, e as bombas passariam a ser
acionadas por relé, sem que o motor de regras precisasse mudar, porque ele já
recebe estado e devolve decisão sem saber de onde o estado veio. Junto com isso
entrariam a priorização por criticidade descrita acima, o balanço energético
solar completo, indicando as janelas em que irrigar sai mais barato, e um
histórico persistente para análise de safra, que hoje não existe apenas porque
a restrição de persistência do desafio não permite.
