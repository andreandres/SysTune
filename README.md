# SysTune CS2

Scripts em PowerShell e Batch para aplicar, em uma instalação limpa do Windows, configurações de sistema voltadas a energia, entrada, rede, recursos gráficos e Counter-Strike 2.

## Arquivos

- `INICIAR.bat` — iniciador com elevação administrativa automática e contorno da `ExecutionPolicy`.
- `otimizar_cs2.ps1` — fluxo principal de otimização, instalação de aplicações e criação do finalizador do CS2.
- `Finalizar_CS2.ps1.template` — modelo usado para localizar o CS2, criar o `autoexec.cfg` e configurar GPU e compatibilidade.

## Uso

1. Coloque todos os arquivos na mesma pasta.
2. Execute `INICIAR.bat` como usuário atual.
3. Autorize a solicitação do Controle de Conta de Usuário.
4. Aguarde as instalações e ajustes. O computador reiniciará após uma contagem de 15 segundos.
5. Após instalar o CS2 pela Steam, execute `Finalizar_CS2.bat` criado na Área de Trabalho.

Pressione `Ctrl+C` no console durante a contagem para cancelar o reinício automático.

## Relatórios

- Otimização principal: `%USERPROFILE%\Desktop\log_otimizacao.txt`
- Finalização do CS2: `%USERPROFILE%\Desktop\log_finalizar_cs2.txt`

## Requisitos

- Windows com suporte a PowerShell 5.1 ou superior.
- Conta com privilégios administrativos.
- Internet para o `winget` e downloads dos pacotes.
- Componentes visuais e scripts podem depender da versão instalada do Windows.

## Avisos importantes

- Revise o código antes da execução. O script altera o Registro, configurações de energia, rede, DNS, GPU, aplicativos provisionados e cria um Ponto de Restauração.
- O script pode remover aplicações nativas da Microsoft listadas no fluxo de debloat.
- O Ponto de Restauração é criado antes das alterações do Registro, mas não substitui um backup completo.
- Não execute em equipamentos ou ambientes corporativos sem autorização do administrador.
- O script configura o DNS para Cloudflare (`1.1.1.1` e `1.0.0.1`).
- Cores e prioridades de processo não garantem melhoria de FPS ou latência em todos os sistemas.

## Licença

MIT. Consulte `LICENSE`.
