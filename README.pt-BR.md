# Vocational Control Presets

**Idioma:** [English](README.md) · **Português (Brasil)**

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](CHANGELOG.md)
[![Game](https://img.shields.io/badge/game-Dragon's%20Dogma%202-red.svg)](#requisitos)
[![REFramework](https://img.shields.io/badge/tool-REFramework-orange.svg)](https://github.com/praydog/REFramework)
[![Nexus](https://img.shields.io/endpoint?url=https://raster.shields.io/nexus/mods/2667&label=Nexus&color=00a2ff&style=flat-square)](https://www.nexusmods.com/dragonsdogma2/mods/2667?tab=description)

![Capa do Vocational Control Presets](/cover.png)

## Resumo

Vocational Control Presets é um mod Lua para Dragon's Dogma 2 feito com REFramework. Ele salva uma configuração de botões do controle para cada vocação e aplica automaticamente a configuração correspondente quando o jogador troca de vocação.

## Recursos

- Salva uma configuração separada para o controle de cada vocação compatível.
- Aplica as configurações automaticamente depois que a vocação permanece estável por vários quadros.
- Restaura o layout padrão do jogo para uma vocação sem configuração própria.
- Faz o Warfarer acompanhar a vocação da arma em uso ou desativa esse comportamento.
- Permite editar todos os controles remapeáveis, incluindo o modificador Shift e as Habilidades de Arma 1–5.
- Exibe `[!]` quando controles alterados usam o mesmo botão que outro controle.
- Exibe controles analógicos e combinações de botões incompatíveis como somente leitura.
- Preenche uma configuração com o layout padrão do jogo.
- Aplica e salva as alterações imediatamente.
- Migra automaticamente as configurações do antigo nome de teste JobControlPresets.

## Vocações compatíveis

| Vocação |
|---|
| Fighter |
| Archer |
| Mage |
| Thief |
| Warrior |
| Sorcerer |
| Mystic Spearhand |
| Magick Archer |
| Trickster |
| Warfarer |

## Requisitos

- Dragon's Dogma 2 (PC)
- REFramework para Dragon's Dogma 2 (`dinput8.dll` na pasta do jogo)

## Instalação

### Fluffy Mod Manager

1. Baixe o arquivo de lançamento `VocationalControlPresets_<tag>.zip`.
2. Arraste o ZIP para o Fluffy Mod Manager com Dragon's Dogma 2 selecionado.
3. Ative o mod.

O ZIP mantém `VocationalControlPresets/` como diretório raiz da instalação.

### Instalação manual

Copie `reframework/autorun/VocationalControlPresets.lua` para:

```text
<pasta do jogo>/reframework/autorun/
```
