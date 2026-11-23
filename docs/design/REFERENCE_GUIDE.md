# CompozyOS Mobile Design Reference Guide

Este guia é a diretriz canônica visual para o agente **designer** ao refatorar as interfaces do `compozy-app`. Todas as telas devem espelhar fielmente as capturas de tela oficiais do CompozyOS localizadas em `docs/design/reference-images/`.

---

## 1. Mapeamento das Imagens de Referência

| Arquivo | Superfície do CompozyOS | Uso no Aplicativo Mobile |
|---|---|---|
| `hero.jpg` | Tela principal de Sessão / Chat do agente | Layout do chat, cabeçalho de sessão, card "While you were away", barra de envio de prompt com botões pill e pills de status. |
| `board.jpg` | Board / Lista de Sessões ativas e recentes | Visual dos cards de sessão, avatares de agente, badges de estado ("Needs you", "Working", "Waiting", "Done"), timestamps relativos e tags. |
| `always-on.jpg` | Visão geral de Agentes e status | Avatares circulares com badges de status de atividade (dot verde pulsante para running, dot âmbar para waiting), tipografia de subtítulos e métricas. |
| `handoff.jpg` | Hierarquia de subagentes e transcrição | Renderização limpa de árvore de subtarefas, tool execution pills colapsáveis, cards compactos e hierarquia visual. |
| `loops.jpg` | Catálogo e editor de Loops | Cards de loops com bordas finas sutis, tags de categoria (`Engineering`, `Marketing`, etc.), ícones minimalistas e badges de execução. |
| `automations.jpg` | Execuções agendadas e histórico | Detalhes de automações, histórico de execuções passadas, status pill e cards de parâmetros. |
| `lockup-dark.png` | Identidade visual do CompozyOS | Tipografia, logo e proporção oficial do branding em modo escuro. |

---

## 2. Tokens de Design e Filosofia Visual

### Cores de Superfície (Chroma-Free Neutrals)
* **Canvas / Fundo Geral**: `#0A0A0A` (ultra escuro, sem tons azulados ou roxos).
* **Superfície Secundária / Desk**: `#101010` (para áreas de navegação e agrupamentos).
* **Cards & Containers**: `#161616` a `#1A1A1A` com borda extremamente sutil (`#262626`, 1px sólida).
* **Superfícies Elevadas / Hover**: `#232323`.

### Ação e Interatividade
* **Ação Primária (Primary Button)**: **Monocromático Invertido** (`#F5F5F5` com texto/ícone `#0A0A0A` em dark mode). **NUNCA usar laranja ou cores da marca para botões primários**.
* **Pills e Botões Secundários**: Superfície `#232323`, borda `#2B2B2B`, texto `#ECECEC`.

### Sinais Semânticos (Budget de Destaque)
* **Orange / Accent (`#E8572A`)**: Reservado exclusivamente para **atenção e urgência** (ex: badge ou dot de "Needs you", contadores não lidos). Nunca usado em bordas gerais ou botões primários.
* **Green / Mint (`#34D399`)**: Status "Working" / "Online" / Sucesso.
* **Amber / Warning (`#F5B14C`)**: Status "Waiting" / Alerta.
* **Red / Danger (`#F87171`)**: Erros e falhas.
* **Muted Foreground (`#989898`)**: Textos secundários, metadados, timestamps e categorias.

---

## 3. Diretrizes de Cada Tela

### A. Lista de Sessões (`sessions_list_screen.dart`)
* Espelha `board.jpg` e `hero.jpg`.
* Cada card de sessão possui:
  * Avatar com identificação do agente ou ícone sutil.
  * Título da sessão em destaque (`#FFFFFF`, peso 600, 15px).
  * Linha de status com dot colorido (Laranja para *Needs You*, Verde para *Working*, Cinza para *Done*).
  * Badge do agente (ex: `fixer`, `dispatcher`, `designer`) em pílula neutra compacta.
  * Timestamp relativo discreto (`#989898`).
* Top Bar: Logo do Compozy ou título limpo, acompanhado da pílula compacta de status de conexão com o daemon (`Online` verde / `Offline` vermelho).

### B. Tela de Chat & Interação (`session_chat_screen.dart`)
* Espelha `hero.jpg` e `handoff.jpg`.
* Mensagens:
  * Mensagens do usuário: alinhadas à direita, fundo discreto (`#232323`), borda sutil (`#2B2B2B`), cantos arredondados (16px, com canto inferior direito mais reto).
  * Mensagens do agente: alinhadas à esquerda, fundo flat/transparente sobre o canvas, avatar do agente à esquerda ou no topo, tipografia limpa com suporte a blocos de código com fundo `#161616`.
  * Tool calls / Subagentes: pills colapsáveis finas, formato pílula com chevron para expandir e ver detalhes (ex: `Run manage_task` ou `File ...`).
* Barra de Envio (Prompt Bar):
  * Fundo `#161616` com borda sutil `#262626`.
  * Botão de envio em formato de círculo ou pill arredondado `#FFFFFF` com ícone escuro `#0A0A0A`.

### C. Catálogo de Loops (`loops_catalog_screen.dart`)
* Espelha `loops.jpg` e `automations.jpg`.
* Cards de loop com cantos arredondados (12px), fundo `#161616`, borda `#262626`.
* Chips de categoria elegantes (All, Engineering, Marketing, etc.) com seleção monocromática de alto contraste.
* Bottom Sheet ou Modal de detalhes exibindo contrato, inputs e status de execuções anteriores.

### D. Navegação Mobile (`app_shell.dart`)
* Bottom Navigation Bar discreta, altura 64dp, fundo `#0A0A0A`, borda superior `#202020` de 1px.
* Ícones limpos com estilo geométrico; item selecionado com cor `#FFFFFF`, não selecionado `#707070`.
