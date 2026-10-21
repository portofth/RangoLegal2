# Rango Legal - Aplicativo Flutter

Este diretório contém a aplicação principal em Flutter do projeto Rango Legal. A aplicação foi desenvolvida para gerenciar receitas, criar perfis nutricionais e sugerir novas receitas com apoio de inteligência artificial.

## Objetivo do app

O Rango Legal ajuda o usuário a:

- organizar receitas pessoais;
- categorizar pratos por tipo;
- manter um perfil nutricional com restrições e objetivos;
- receber recomendações mais adequadas;
- gerar receitas novas com base no perfil do usuário.

## Como o código está organizado

A estrutura principal está em `lib/`:

```
lib/
├── main.dart
├── database_helper.dart
├── recipe_form.dart
├── recomendacao_screen.dart
├── servico_ia_receita.dart
├── servico_recomendacao.dart
├── perfil_screen.dart
├── perfil_list_screen.dart
├── configuracoes_screen.dart
├── category_management_screen.dart
├── image_service.dart
├── notification_service.dart
├── models/
│   ├── category.dart
│   ├── profile.dart
│   ├── recipe.dart
│   └── user.dart
├── theme_provider.dart
├── dados_receitas.dart
└── splash_screen.dart
```

## Fluxo da aplicação

1. `main.dart` inicia a aplicação e carrega as configurações iniciais.
2. `DatabaseHelper` prepara o banco local e alimenta os dados iniciais.
3. A navegação principal fica no `HomePage`, com abas para receitas, recomendações, perfis e configurações.
4. A criação/edição de receitas é feita pela tela `RecipeForm`.
5. O perfil nutricional é armazenado e usado para personalizar as recomendações.
6. O botão de geração de receitas dispara `ServicoIAReceita`.
7. A IA gera uma receita em JSON e a mesma é salva em `SharedPreferences` pela classe `ServicoRecomendacao`.

## Implementação da IA

O serviço de IA está em `servico_ia_receita.dart`.

Ele monta um prompt com as informações do usuário, incluindo:

- objetivo nutricional;
- restrições alimentares;
- idade;
- nível de atividade;
- regra de não repetir receitas já existentes.

Depois ele envia a requisição para o Gemini usando `http.post` e valida se a resposta tem o formato esperado. Se tudo estiver correto, a receita é salva na lista de recomendações.

## Configuração de ambiente

Antes de executar o app, crie um arquivo `.env` na raiz do projeto com a chave da API do Gemini:

```env
GEMINI_API_KEY=sua_chave_aqui
```

O projeto já contém o arquivo `env-example` como referência.

## Como rodar no Flutter

No terminal:

```bash
flutter pub get
flutter run
```

Se o projeto não estiver configurado, pode ser necessário abrir o diretório em um editor com suporte ao Flutter e selecionar um emulador ou dispositivo.

## Observações

- O app trabalha com dados locais e com a API externa do Gemini.
- A geração de receita depende de uma chave válida do Gemini.
- A parte de IA é aplicada como apoio para criação de sugestões personalizadas, não como substituição do processo manual do usuário.

## Tecnologias principais

- Flutter
- Dart
- SQLite / Hive
- Shared Preferences
- HTTP
- Flutter DotEnv
- Gemini API
