# Próximas Faturas

Aplicativo de página única para acompanhar contas a vencer.

## Uso
Abra `index.html` no navegador (duplo clique). Não precisa de servidor nem instalação.

- **Status:** vermelho = vencida/vence hoje · âmbar = vence em até 7 dias · azul = mais adiante · verde = paga
- **Recorrente:** ao clicar em *Paguei*, a próxima ocorrência é criada no mês seguinte (dia 31 vira o último dia do mês quando necessário).
- **Backup:** os dados ficam no `localStorage` do navegador. Use *Exportar backup* periodicamente — limpar dados do navegador apaga as faturas.
