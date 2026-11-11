# dev-cycle

Um kit inicial para **desenvolvimento agêntico**: um comando leva um ticket do planejamento até a revisão final, com um agente especializado por fase e registro escrito de cada decisão.

Funciona com **Claude Code**, **Kiro** e **Codex**. Sem build, sem instalador — copie uma pasta e defina uma variável de ambiente.

[Leia em inglês](README.md)

---

## Por quê

Deixar um agente escrever código é fácil. Confiar no que sai é que não é. Este kit divide o trabalho em fases com entrega clara entre elas, para que cada passo produza algo verificável:

- O plano define critérios de aceite **verificáveis** antes de existir qualquer código.
- Os testes são escritos **antes** da implementação, e não ajustados depois para passar.
- Um script determinístico compara os erros com uma **linha de base**, então "já estava quebrado" vira fato, não opinião.
- O veredito tem **três** estados, então "não consegui verificar" deixa de ser arquivado silenciosamente como sucesso.
- Todo ciclo deixa uma nota, inclusive os que falharam.

O agente faz o trabalho mecânico. Você continua sendo o revisor.

## O ciclo

```
Baseline → Plan → Test → Implement → Checks → Review → Verify → Estimate → Record → Revisão final
                            ▲           │        │        │
                            └──── reprovou (até 3 tentativas) ────┘
```

| Fase | O que acontece | Agente |
|---|---|---|
| **Baseline** | Roda type-check, lint, testes e build **antes** de qualquer mudança e registra os erros que já existiam. | `dc-checks` |
| **Plan** | Lê o ticket, escreve requisitos e critérios de aceite verificáveis, define a abordagem, quebra em tarefas, sinaliza dúvidas bloqueantes e estima o tamanho. | `dc-plan` |
| **Test** | Escreve os testes primeiro e confirma que falham pelo motivo certo. Pulada em tickets triviais. | `dc-test` |
| **Implement** | Escreve o código de produção. Sem commits. | `dc-implement` |
| **Checks** | Roda as mesmas checagens e compara **erro a erro** com a linha de base. Erro que já existia não conta; erro novo reprova a tentativa. | `dc-checks` |
| **Review** | Revisão estática do diff contra o plano e as regras do repositório, com régua fixa de severidade. Só um achado **Crítico** reprova. | `dc-review` |
| **Verify** | Confere cada critério de aceite e cada tarefa, com evidência. | `dc-verify` |
| **Estimate** | Pontua o que foi de fato entregue, como métrica de esforço x entrega. | `dc-estimate` |
| **Record** | Escreve a nota do ticket, as pendências e os padrões. Roda em **qualquer** desfecho. | `dc-record` |
| **Improve** | Sob demanda, sobre vários ciclos: padrões recorrentes e propostas de mudança no processo. | `dc-improve` |

### Desfechos

| Desfecho | Significado |
|---|---|
| **Aprovado** | Todos os critérios verificados com evidência, todas as checagens limpas, todas as tarefas feitas. |
| **Aprovado com ressalvas** | Nada falhou, mas algo **não foi confirmado** — um critério que precisa de teste manual, uma checagem pulada pelo perfil, uma tarefa não feita. Leia as ressalvas antes do merge. |
| **Reprovado** | Três tentativas e ainda há erro novo, achado Crítico ou critério não atendido. |
| **Bloqueado no plano** | Você decidiu não seguir depois das dúvidas ou da estimativa de tamanho. |
| **Interrompido** | O ciclo foi parado no meio. Rode de novo para retomar. |

### Quando ele para e espera você

O ciclo roda sozinho e só para nestes pontos:

| Pausa | Por quê |
|---|---|
| Árvore do git suja | A comparação precisa partir de um estado limpo. |
| Ticket inacessível | Sem integração com o issue tracker, ou a chamada falhou. Cole a descrição. |
| Dúvida bloqueante | Respostas diferentes mudariam o escopo ou a abordagem. |
| Tarefa grande | A estimativa chegou ao limite do perfil (padrão: 8 pontos). |
| Revisão final | Sempre. |

Dúvidas pequenas não param o ciclo: ele adota uma suposição, registra, e deixa como pendência para você confirmar.

---

## Instalação

### 1. Copie os arquivos

**Claude Code**
```bash
mkdir -p ~/.claude/agents ~/.claude/commands ~/.dev-cycle
cp agents/*.md ~/.claude/agents/
cp commands/*.md ~/.claude/commands/
cp scripts/check-diff.sh ~/.dev-cycle/ && chmod +x ~/.dev-cycle/check-diff.sh
```

**Kiro**
```bash
mkdir -p ~/.kiro/agents ~/.dev-cycle
cp agents/*.md commands/*.md ~/.kiro/agents/
cp scripts/check-diff.sh ~/.dev-cycle/ && chmod +x ~/.dev-cycle/check-diff.sh
```

**Codex** — skills ficam um nível abaixo, então cada arquivo vira a sua própria pasta:
```bash
mkdir -p ~/.agents/skills ~/.dev-cycle
for f in agents/*.md commands/*.md; do
  n=$(basename "$f" .md)
  mkdir -p ~/.agents/skills/"$n" && cp "$f" ~/.agents/skills/"$n"/SKILL.md
done
cp scripts/check-diff.sh ~/.dev-cycle/ && chmod +x ~/.dev-cycle/check-diff.sh
```

### 2. Defina onde ficam as notas

Adicione ao seu `~/.zshrc` ou `~/.bashrc`:
```bash
export DEV_CYCLE_HOME="$HOME/dev-cycle"
```

Qualquer diretório serve. Se você usa Obsidian, aponte para uma pasta dentro do vault e as notas viram uma base de conhecimento navegável (veja [Notas](#notas)). Sem a variável, o ciclo usa `~/dev-cycle`.

### 3. Reinicie seu agente

Abra um terminal novo (para carregar a variável) e reinicie a ferramenta. No Claude Code e no Kiro, digite `/` e veja se `dev-cycle` aparece. No Codex, digite `$` e procure por `dev-cycle`.

> **Só no Claude Code:** se `DEV_CYCLE_HOME` apontar para fora do projeto, adicione o caminho em `permissions.additionalDirectories` no `~/.claude/settings.json`, senão o ciclo não consegue escrever lá.

---

## Uso

```bash
/dev-cycle PROJ-123     # roda um ticket
/dev-cycle PROJ-123     # rodar de novo retoma um ciclo que parou no meio
/dev-cycle-improve      # periódico: analisa os ciclos acumulados
```

Se não houver integração com o issue tracker, ou o ticket não puder ser lido, o ciclo pede que você cole a descrição e os critérios de aceite e segue a partir daí.

No Codex, invoque como `$dev-cycle PROJ-123`.

Comece com a árvore do git limpa. O ciclo compara o estado do repositório antes e depois; mudanças suas não commitadas contaminam essa comparação.

### Primeira execução em um repositório

Não há nada para configurar. Na primeira execução em um repositório, o ciclo lê o manifesto do projeto, descobre os comandos de type-check, lint, teste e build, grava em `$DEV_CYCLE_HOME/Projects/<nome-do-repo>.md` e segue. Ele avisa o que encontrou em uma linha:

```
Profile: typecheck=npx tsc --noEmit | lint=npm run lint | test=npx jest --ci | build=npm run build
```

Edite esse arquivo quando a detecção errar, quando um comando precisar de uma flag para sobreviver à sua máquina, ou quando uma checagem não deve rodar:

- `prep:` roda antes de cada checagem — carregar uma versão de runtime, por exemplo. Pode ficar vazio.
- `SKIP — motivo` desliga uma checagem. Ela não some: vira ressalva no veredito, então checagem faltando nunca é silenciosa.

Há um ponto de partida comentado em [`templates/project-profile.md`](templates/project-profile.md).

### A revisão final

```
Outcome: approved with caveats
Track: full | Attempts: 2 | Story points: 3
Caveats: 1
  CV1: o checkbox desabilitado no modo edição precisa de teste manual (abrir um registro existente)
Open review warnings: 2
Checks not run: build
Cycle files: ~/dev-cycle/Cycles/PROJ-123
Notes: written to ~/dev-cycle/Tickets/PROJ-123.md
Secrets: scan clean
```

A partir daí é com você. O ciclo **pergunta** antes de cada uma destas ações e não faz nenhuma sozinho: commit, abrir PR, mover o ticket, gravar a pontuação na issue ou corrigir os avisos em aberto.

### Trilha leve e completa

Não há nada para escolher aqui — quem decide é o plano, e a única diferença é se a fase Test roda. Quando o plano estima o ticket em 1 ponto e ele não cria regra de negócio (configuração, texto, remoção de dependência), o ciclo é marcado como **leve** e os testes são pulados, porque a comparação com a linha de base já pega regressão nesse tipo de mudança. Todo o resto roda a trilha **completa**. Baseline, Checks, Review, Verify, Estimate e Record acontecem nos dois casos. A trilha aparece no resumo final, para você ver qual rodou.

---

## Notas

```
$DEV_CYCLE_HOME/
  _Dashboard.md           visão geral
  Projects/<repo>.md      perfil: comandos, restrições, aprendizados operacionais
  Tickets/<TICKET>.md     uma nota por ticket: desfecho, decisões, tentativas, pendências
  Patterns/<nome>.md      uma nota por problema recorrente
  Cycles/<TICKET>/        relatório de cada fase e a linha do tempo do ciclo
  Improve/                relatórios do dev-cycle-improve
```

Nada disso vai para o repositório do projeto — lá entram só código e testes.

As **pendências** são a parte que vale acompanhar. Cada aviso da revisão, tarefa não feita, teste manual e suposição não confirmada vira um item `- [ ]` na nota do ticket.

As notas são Markdown puro e legíveis em qualquer editor. No **Obsidian**, o `_Dashboard.md` gerado usa o plugin [Dataview](https://github.com/blacksmithgu/obsidian-dataview) para listar tickets recentes, pendências abertas de todos os tickets e os padrões mais frequentes. As notas de padrão são ligadas por wikilinks, então os backlinks do Obsidian mostram quantas vezes cada problema apareceu, sem ferramenta nenhuma.

---

## Como funciona a comparação com a linha de base

Esta é a única peça que **não** é modelo de linguagem. O [`scripts/check-diff.sh`](scripts/check-diff.sh) roda cada comando, reduz a saída a assinaturas de erro (arquivo mais código do erro, sem número de linha) e compara os conjuntos:

```
== typecheck: rc 1 -> 1 | new errors: 1 | resolved: 0
+1  src/c.html - error NG8002: Can't bind to 'label'
RESULT: REGRESSION
```

Erro que já existia e só mudou de linha não conta. Erro novo reprova, mesmo que o total já fosse alto. Os logs brutos ficam em `/tmp/dev-cycle/` e nunca entram no contexto do modelo.

Ele entende a saída do **tsc**, do **Angular**, do **ESLint** e do **Jest**. Para outras ferramentas ainda compara o código de saída, mas pode não enxergar um erro novo dentro de uma checagem que já falhava. Adicionar um formato é uma regra de `awk` — contribuições são bem-vindas.

---

## Adaptando

Cada agente é um arquivo Markdown com um frontmatter curto e um prompt. Para mudar o comportamento de uma fase, edite o arquivo e reinicie a ferramenta.

O frontmatter traz `name` e `description` (obrigatórios em todas as ferramentas), mais `tools` e `model`, que o Claude Code e o Kiro respeitam e o Codex ignora. A lista `tools` é proteção, não otimização: o `dc-review` não tem ferramenta de edição, então só consegue relatar problemas, e o `dc-plan` não edita código. Mantenha as descrições em uma linha — elas são carregadas em toda sessão, então descrição longa custa contexto em trabalho que nada tem a ver com este ciclo.

- **Sua régua de severidade:** edite `agents/dc-review.md`.
- **A rubrica de estimativa do seu time:** instale como skill e o `agents/dc-estimate.md` passa a usá-la; sem isso, ele usa a escala Fibonacci definida no arquivo.
- **Suas regras de código:** coloque no arquivo de instruções do próprio repositório (`CLAUDE.md`, `AGENTS.md`, `.kiro/steering/`). O agente de review lê e dá prioridade a elas sobre o próprio checklist.
- **Menos fases:** apague o agente e remova o passo dele em `commands/dev-cycle.md`.

## Custo

As fases não são iguais, e o kit não as trata como se fossem:

- Trabalho mecânico (rodar checagens, escrever a nota) roda em modelo mais barato; trabalho de julgamento (planejar, implementar, revisar) roda em modelo mais forte. Quem define isso é o campo `model` de cada agente, e ferramentas que não suportam simplesmente ignoram.
- A comparação de erros é feita pelo script — logs não chegam a nenhum modelo.
- O Verify não roda a suíte de novo; lê o resultado do Checks da mesma tentativa.
- A trilha leve corta uma fase inteira das tarefas triviais.
- O Improve roda sob demanda e lê só as notas mais novas que a última análise.

O que realmente encarece é o retrabalho. Ticket bem descrito, com critérios de aceite claros, é ticket mais barato.

## Segurança

- Todo agente é instruído a nunca gravar tokens, senhas, chaves de API ou conteúdo de `.env` nos relatórios — os valores viram `[REDACTED]`.
- Antes do gate final, o ciclo varre os arquivos que escreveu procurando padrões comuns de segredo e informa o resultado.
- A varredura é heurística. Dê uma olhada nas notas antes de compartilhá-las.

## Limitações

- A fase de checks só reconhece os quatro formatos de saída citados acima.
- Uma checagem com `SKIP` não protege nada naquele ponto — por isso ela vira ressalva.
- O Verify lê código e resultados; comportamento visual e fluxos que dependem de backend ficam como teste manual.
- O limite de 3 tentativas evita laço infinito, não garante sucesso. Ticket grande ou ambíguo tende a reprovar: divida.
- O suporte a subagentes varia entre as ferramentas. Onde a ferramenta não consegue criar um, o orquestrador segue cada arquivo de agente em sequência — mesmas fases, um contexto só.

## Contribuindo

Issues e pull requests são bem-vindos, principalmente: novos formatos de saída para o `check-diff.sh`, adaptadores para outras ferramentas de agente e melhorias nos prompts das fases. Aqui os prompts são o produto, então um PR que mude um deles deve dizer qual comportamento está corrigindo.

## Licença

[MIT](LICENSE).
