# Rango Legal

O Rango Legal é um aplicativo de receitas pensado para ajudar as pessoas a manterem uma alimentação mais organizada, saudável e alinhada ao seu perfil nutricional. A ideia central é unir gestão de receitas, perfil pessoal e inteligência artificial para sugerir pratos adequados ao objetivo do usuário.

Este projeto foi desenvolvido para a disciplina de Trabalho Interdisciplinar IV: Aplicações Móveis, como continuidade de um trabalho anterior da disciplina de Laboratório de Desenvolvimento para Dispositivos Móveis. A versão atual busca evoluir a proposta original com foco em melhoria da UI, da lógica de persistência e da implementação da IA.

O repositório original pode ser consultado em: https://github.com/portofth/RangoLegal

## Visão geral do projeto

A aplicação permite:

- cadastrar, editar e excluir receitas;
- organizar receitas por categoria;
- criar e gerenciar perfis nutricionais;
- receber recomendações com base em restrições e objetivos;
- gerar novas receitas com apoio de IA;
- salvar receitas criadas pela IA em uma lista de recomendações.

O projeto foi desenvolvido em Flutter e usa armazenamento local para manter os dados do usuário e das receitas, além de integração com a API do Gemini para geração inteligente de receitas.

## Como o aplicativo funciona

A lógica principal está em `main.dart`, que inicializa o app e coordena as telas principais:

1. O app inicia com `DatabaseHelper().initializeHive()`, preparando o armazenamento local.
2. O `HomePage` controla a navegação por abas: receitas, recomendações, perfis e configurações.
3. As receitas podem ser adicionadas e editadas em `RecipeForm`.
4. O perfil nutricional é criado e consultado em `perfil_screen.dart` e `perfil_list_screen.dart`.
5. Na aba de recomendações, o usuário pode solicitar a geração de uma receita personalizada.
6. A geração feita por IA usa o perfil do usuário para montar um prompt com objetivo, restrições, idade e nível de atividade.
7. A resposta da IA é validada e salva para uso posterior.

## Estrutura principal do código

A pasta `Codigo/lddm-main/lib` reúne a base do app:

- `main.dart`: ponto de entrada da aplicação e navegação principal;
- `database_helper.dart`: configura o armazenamento local e os dados iniciais;
- `recipe_form.dart`: formulário para cadastro e edição de receitas;
- `perfil_screen.dart`: criação/edição do perfil nutricional;
- `perfil_list_screen.dart`: lista de perfis cadastrados;
- `recomendacao_screen.dart`: tela de recomendações;
- `servico_ia_receita.dart`: integração com a IA para geração de receitas;
- `servico_recomendacao.dart`: armazenamento e organização das receitas sugeridas pela IA;
- `models/`: classes de domínio como `Recipe`, `Profile`, `User` e `Category`;
- `image_service.dart`: acesso à câmera e galeria;
- `notification_service.dart`: notificações internas da aplicação.

## Implementação da IA

A geração de receitas por inteligência artificial acontece no serviço `ServicoIAReceita`.

### Fluxo da IA

- o app verifica se existe um perfil nutricional válido;
- o usuário escolhe o perfil, se houver mais de um;
- o serviço monta um prompt detalhado com:
  - objetivo nutricional;
  - restrições alimentares;
  - idade;
  - nível de atividade;
  - regras de criação da receita;
- a aplicação envia essa informação para a API do Gemini;
- o modelo responde em JSON com:
  - nome da receita;
  - categoria;
  - ingredientes;
  - modo de preparo;
  - restrições atendidas;
- o retorno é validado e salvo na lista de recomendações.

O código da integração está em `Codigo/lddm-main/lib/servico_ia_receita.dart` e usa `http` com o endpoint do Gemini, lendo a chave da API do arquivo `.env`.

### Chave da API

O projeto espera um arquivo `.env` dentro de `Codigo/lddm-main` com, pelo menos:

```env
GEMINI_API_KEY=sua_chave_aqui
```

Existe também um arquivo `env-example` com esse padrão. A chave deve ser mantida privada e nunca enviada ao controle de versão.

## Dados e persistência

O aplicativo usa armazenamento local para manter as receitas e os perfis do usuário. O código em `database_helper.dart` também inicializa dados de exemplo para que a aplicação tenha receitas prontas ao abrir pela primeira vez.

## Como executar o projeto

1. Acesse a pasta do app:

```bash
cd Codigo/lddm-main
```

2. Crie o arquivo `.env` com a sua chave do Gemini:

```bash
cp env-example .env
```

3. Instale as dependências:

```bash
flutter pub get
```

4. Execute o aplicativo:

```bash
flutter run
```

## Integrantes da equipe

- Arthur Braga de Campos Tinoco
- Davi Wenzel Cury
- Diogo Patrick Cesário de Oliveira
- Fernando Theodoro Porto de Paula Dias
- Mateus Evangelista do Nascimento
- Rafael Nascimento Jardim

## Professores responsáveis

- Cristiano Neves Rodrigues
- Ilo Amy Saldanha Rivero
- Pedro Henrique Ramos Costa
- Rosilane Ribeiro da Mota
