# pedro-configurador

Ponto de partida para preparar um PC Windows novo. Contém **apenas** o `Configurar.ps1`, sem segredos.

```powershell
irm https://raw.githubusercontent.com/pedrohsml31/pedro-configurador/main/Configurar.ps1 -OutFile Configurar.ps1
powershell -ExecutionPolicy Bypass -File .\Configurar.ps1
```

O script instala git, GitHub CLI e chezmoi (sem administrador), pede o login das contas no navegador, clona o
repositório privado de configuração e abre o menu para escolher programas e projetos. Sem login nas contas do
dono, nada além disso é acessível.
