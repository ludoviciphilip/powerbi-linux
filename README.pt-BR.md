# powerbi-linux (Português)

**Rode o Microsoft Power BI Desktop no Linux, numa janela própria, com um comando.** · [English](README.md)

O Power BI Desktop só existe para Windows e não funciona no Wine. O `powerbi-linux` instala, em segundo plano, uma VM pequena com Windows 11. Ela usa KVM por meio do container [dockur/windows](https://github.com/dockur/windows). Depois instala o Power BI dentro dela sem você clicar em nada e cria o atalho **"Power BI Desktop"** no menu de aplicativos. Ao abrir o atalho, ele liga o Windows se precisar e mostra o Power BI numa janela que você redimensiona, encaixa lado a lado (tiling) ou maximiza como qualquer outro programa.

- **Instalação automática.** O Windows e o Power BI vêm direto da Microsoft. Antes de rodar o instalador do Power BI, o Windows confere a assinatura digital dele.
- **Parece um aplicativo comum.** O Power BI abre maximizado e a barra de tarefas do Windows fica escondida. A janela acompanha o tamanho que o gerenciador de janelas der para ela.
- **Liga e desliga sob demanda.** Ao fechar a janela, ele pergunta se deve desligar o Windows. Ao sair da sessão ou desligar o PC, o Windows é desligado do jeito certo, por um serviço de usuário do systemd.
- **Seus arquivos.** Sua pasta pessoal aparece no Windows como a unidade **Linux** (em *Este Computador*).
- **Só acesso local.** As portas ficam presas em `127.0.0.1` e a senha é gerada aleatoriamente.

> Projeto sem vínculo com a Microsoft. Para usar o Windows além do período de avaliação, é preciso uma licença válida. O Power BI Desktop é gratuito.

## Instalar

```bash
git clone https://github.com/ludoviciphilip/powerbi-linux.git
cd powerbi-linux
./install.sh          # ./install.sh --deps instala só os pacotes da sua distro
```

O processo leva de **20 a 60 minutos**, quase tudo é o download do Windows (~7 GB). Você pode acompanhar a tela da VM em <http://127.0.0.1:48006>.

**Dica para quem trabalha com números no padrão brasileiro:** use `--region pt-BR`. Ele é detectado automaticamente pelo `LC_NUMERIC`, e é o que faz o Power Query entender vírgula como separador decimal.

## Usar

```bash
powerbi-linux open        # liga o Windows se precisar e abre o Power BI
powerbi-linux stop        # desliga o Windows
powerbi-linux status      # estado da VM e versão do Power BI
powerbi-linux update      # baixa a versão mais nova (instala no próximo boot do Windows)
powerbi-linux uninstall   # remove (com --purge apaga também o disco do Windows)
```

Fechar a janela só **desconecta**: o Power BI continua aberto dentro do Windows. Antes de escolher "Shut down", salve o `.pbix`.

Os detalhes técnicos, a configuração e a solução de problemas estão no [README em inglês](README.md).
