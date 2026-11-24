# pedro-configurador

Ponto de partida para preparar um PC Windows novo. Contém **apenas** arquivos públicos, sem segredos.

## Preparar este PC (recomendado)

Baixe sempre a última versão: [Preparar-PC.zip](https://github.com/pedrohsml31/pedro-configurador/releases/latest/download/Preparar-PC.zip)
(todas as versões em [Releases](https://github.com/pedrohsml31/pedro-configurador/releases)). Extraia o ZIP e abra
`Preparar este PC.cmd`. O ZIP não leva token nem dado pessoal; o login do GitHub é feito no próprio PC.

## Configurador manual

```powershell
irm https://raw.githubusercontent.com/pedrohsml31/pedro-configurador/main/Configurar.ps1 -OutFile Configurar.ps1
powershell -ExecutionPolicy Bypass -File .\Configurar.ps1
```

O script instala git, GitHub CLI e chezmoi (sem administrador), pede o login da conta no navegador, clona o
repositório privado de configuração e abre o menu para escolher programas e projetos. Sem login na conta do
dono, nada além disso é acessível.
