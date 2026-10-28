# Configurador único: baixe SÓ este arquivo num PC novo e execute.
#   powershell -ExecutionPolicy Bypass -File Configurar.ps1
# Fora do repositório central, ele instala as ferramentas, autentica as contas, clona o repositório
# central e continua a partir da cópia clonada. Dentro dele, mostra o menu.
param([ValidateSet('Menu', 'Ferramentas', 'Contas', 'Regras', 'Instalar', 'Projetos', 'Atualizar', 'Catalogo')][string]$Acao = 'Menu')

$NOME_PROGRAMA = 'Ambiente do Pedro'
$VERSAO = '1.0'
$TITULO_PROGRAMA = "$NOME_PROGRAMA v$VERSAO"
# Sem 'Stop' global: no PowerShell 5.1 o stderr de programas nativos (gh devolve 404 quando não há release) viraria exceção.
$ErrorActionPreference = 'Continue'
$ContasPadrao = @('pedrohsml31', 'contadescartavel26')
$RepoCentral = 'pedrohsml31/pedro-ambiente'

function Atualizar-PathSessao {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}
function Achar-Gh {
    $c = Get-Command gh -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    $f = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages') -Recurse -Filter gh.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($f) { return $f.FullName }
    throw 'gh não encontrado; rode a etapa de ferramentas.'
}

function Instalar-Ferramentas {
    # --scope user: não precisa de administrador (importante em notebook corporativo).
    $pacotes = @(@{ Id = 'Git.Git'; Cmd = 'git' }, @{ Id = 'GitHub.cli'; Cmd = 'gh' }, @{ Id = 'twpayne.chezmoi'; Cmd = 'chezmoi' })
    foreach ($p in $pacotes) {
        Atualizar-PathSessao
        if (Get-Command $p.Cmd -ErrorAction SilentlyContinue) { Write-Host "$($p.Cmd): já instalado."; continue }
        Write-Host "Instalando $($p.Id)..."
        winget install --id $p.Id -e --scope user --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { Write-Warning "winget terminou com código $LASTEXITCODE para $($p.Id)." }
    }
    Atualizar-PathSessao
}

function Autenticar-Contas {
    param([string[]]$Contas)
    $gh = Achar-Gh
    foreach ($c in $Contas) {
        & $gh auth token --user $c *>$null
        if ($LASTEXITCODE -eq 0) { Write-Host "${c}: já autenticada."; continue }
        Write-Host "`nAutentique a conta '$c': responda 'n' se perguntar sobre configurar o Git, abra o navegador, e ENTRE NA CONTA $c."
        & $gh auth login --hostname github.com --git-protocol https --web --skip-ssh-key
        & $gh auth token --user $c *>$null
        if ($LASTEXITCODE -ne 0) { Write-Warning "A conta '$c' ainda não consta no gh (login em outra conta?)." }
    }
}

$raizRepo = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not (Test-Path -LiteralPath (Join-Path $raizRepo 'scripts\lib.ps1'))) {
    # Modo bootstrap: este arquivo está sozinho (PC recém-formatado).
    Write-Host "$TITULO_PROGRAMA - preparando este computador"
    Instalar-Ferramentas
    Autenticar-Contas $ContasPadrao
    $dev = Join-Path $env:USERPROFILE 'Dev'
    $destino = Join-Path $dev 'pedro-ambiente'
    if (-not (Test-Path -LiteralPath $destino)) {
        New-Item -ItemType Directory -Force $dev | Out-Null
        $env:GH_TOKEN = (& (Achar-Gh) auth token --user ($RepoCentral -split '/')[0] 2>$null) -join ''
        try { & (Achar-Gh) repo clone $RepoCentral $destino } finally { Remove-Item Env:GH_TOKEN -ErrorAction SilentlyContinue }
        if ($LASTEXITCODE -ne 0) { throw 'Não consegui clonar o repositório central.' }
    }
    & (Join-Path $destino 'Configurar.ps1') -Acao $Acao
    return
}

. (Join-Path $raizRepo 'scripts\lib.ps1')
$cfg = Obter-Config
$host.UI.RawUI.WindowTitle = $TITULO_PROGRAMA

function Aplicar-Regras {
    # Backup do que já existe, diferença visível e confirmação antes de sobrescrever. Só instruções compartilháveis.
    $fonte = Join-Path $raizRepo 'chezmoi'
    git -C $raizRepo pull --ff-only --quiet 2>$null   # só avança em linha reta; se divergir, não faz nada
    chezmoi diff --source $fonte --destination $HOME
    if ((Read-Host 'Aplicar estas regras? Cópias .bak-<data> serão guardadas (s/N)') -notmatch '^[sS]') { return }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmm'
    foreach ($alvo in chezmoi managed --include=files --path-style=absolute --source $fonte --destination $HOME) {
        if (Test-Path -LiteralPath $alvo) { Copy-Item -LiteralPath $alvo -Destination "$alvo.bak-$stamp" }
    }
    chezmoi apply --source $fonte --destination $HOME --force
    Write-Host 'Regras aplicadas.'
}

function Mostrar-Catalogo {
    $cat = Obter-Catalogo
    $cat | Sort-Object Tipo, Conta, Repo | Format-Table Conta, Repo, Tipo, Versao, Privado -AutoSize
    return $cat
}

function Menu-Principal {
    do {
        Write-Host "`n=== $TITULO_PROGRAMA ==="
        Write-Host '1 Instalar ferramentas (git, gh, chezmoi)   5 Preparar projetos para desenvolvimento'
        Write-Host '2 Autenticar contas GitHub                  6 Atualizar programas instalados'
        Write-Host '3 Regras do Codex e Claude (chezmoi)        7 Ligar/desligar atualização automática'
        Write-Host '4 Instalar programas                        8 Ver catálogo completo      0 Sair'
        $opcao = Read-Host 'Opção'
        switch ($opcao) {
            '1' { Instalar-Ferramentas }
            '2' { Autenticar-Contas $cfg.contas }
            '3' { Aplicar-Regras }
            '4' { Executar-Instalar }
            '5' { Executar-Projetos }
            '6' { Atualizar-Instalados }
            '7' { if ((Read-Host 'Ligar? (s = ligar, n = desligar)') -match '^[sS]') { Ativar-AtualizacaoAutomatica } else { Desativar-AtualizacaoAutomatica } }
            '8' { [void](Mostrar-Catalogo) }
        }
    } while ($opcao -ne '0')
}

function Executar-Instalar {
    $cat = Obter-Catalogo
    $prontos = @($cat | Where-Object { $_.Tipo -eq 'instalavel' })
    if ($prontos.Count -eq 0) { Write-Host 'Nenhum programa com release aprovada (.exe) ainda. Use scripts\Publicar-Release.ps1 depois de testar o build.' }
    foreach ($i in Selecionar-Itens $prontos 'Programas prontos para instalar' { param($x) "$($x.Nome) v$($x.Versao)  [$($x.Conta)]" }) { Instalar-Programa $i }
    $outros = @($cat | Where-Object { $_.Tipo -ne 'instalavel' -and $_.Tipo -ne 'projeto' })
    if ($outros.Count) { Write-Host "`nNão instaláveis por aqui (web/extensão/em preparo): $(($outros | ForEach-Object { $_.Repo + ':' + $_.Tipo }) -join ', ')" }
}

function Executar-Projetos {
    $cat = Obter-Catalogo
    foreach ($i in Selecionar-Itens $cat 'Projetos para preparar em Dev (clone; nunca pull/merge)' { param($x) "$($x.Repo)  [$($x.Tipo)]  $($x.Conta)" }) { Preparar-Projeto $i }
}

switch ($Acao) {
    'Ferramentas' { Instalar-Ferramentas }
    'Contas' { Autenticar-Contas $cfg.contas }
    'Regras' { Aplicar-Regras }
    'Instalar' { Executar-Instalar }
    'Projetos' { Executar-Projetos }
    'Atualizar' { Atualizar-Instalados }
    'Catalogo' { [void](Mostrar-Catalogo) }
    default { Menu-Principal }
}

