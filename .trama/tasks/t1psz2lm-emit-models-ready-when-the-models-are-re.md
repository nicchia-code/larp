---
column: done
technical: false
refs:
  - models.READY
  - models/Ready
drift: null
proposal: null
agent: false
created: 2026-10-13T16:03:11.836Z
finished: 2026-10-13T17:37:30.422Z
---
# Emit models.READY when the models are ready

Quando i modelli diventano pronti, sia perché già presenti all'avvio sia perché appena scaricati, il sistema deve emettere l'evento models.READY, così che la schermata della call passi da attesa dei modelli a pronta e Avvia si abilita. Oggi nel codice la transizione verso Ready non emette alcun evento: il metodo che riceve models.READY esiste ma nessun codice dei modelli lo chiama.
