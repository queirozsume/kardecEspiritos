# O Livro dos Espíritos

Aplicativo Android para leitura e busca em *O Livro dos Espíritos*, de Allan Kardec: partes, capítulos, temas, palavras-chave (índice remissivo) e cada uma das 1019 perguntas e respostas.

## Baixar o APK

[**Última versão (releases/latest)**](https://github.com/queirozsume/kardecEspiritos/releases/latest) ou o arquivo [apk/livro-dos-espiritos.apk](apk/livro-dos-espiritos.apk), que sempre contém apenas a versão atual.

O APK é compilado e assinado pelo GitHub Actions a partir deste repositório. Para conferir a autenticidade:

- Certificado de assinatura (SHA-256): `97dbaa35 4f5c6792 96ebf0bb 2893bcdf 4f829505 8b333207 61277da9 eefa3be9`
- Procedência do build: `gh attestation verify livro-dos-espiritos-v1.0.0.apk --repo queirozsume/kardecEspiritos`

No Android, pode ser necessário permitir a instalação de apps de fontes desconhecidas.

## Recursos

- Navegação por partes, capítulos e temas.
- Busca por palavra ou número da pergunta, em perguntas, capítulos/temas e índice remissivo.
- Modo noite e ajuste do tamanho da fonte.

## Desenvolvimento

- `build_data.py` extrai o texto do PDF e gera o `data.json` (copiado para `app/assets/`).
- `app/` é o projeto Flutter. Um push na `main` gera o APK como artefato; uma tag `v*` publica a release.

Desenvolvido por Joel Queiroz. Retrato de Kardec: Bibliothèque nationale de France, domínio público.
