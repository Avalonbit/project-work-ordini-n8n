# Richiesta ordine fornitore – n8n + Supabase + AI Agent

Project Work finale – corso AI Automation (Epicode)

🎥 **Video di presentazione:** https://drive.google.com/drive/folders/18gDEPAyc_74wGgs9KadyZd_LMk3gwG9c

## Problema e perimetro
- **Utente:** ufficio acquisti di un'azienda che vende su Amazon e ordina merce a molti fornitori.
- **Attività attuale:** l'ordine si prepara a mano: controllo delle confezioni, email al fornitore, lista per il magazzino.
- **Errori tipici:** confezioni incomplete, codici sbagliati, ordini inviati due volte.
- **Risultato atteso:** si carica il riepilogo ordine in PDF; il sistema lo valida, lo salva, prepara il messaggio per il fornitore, la nota per il magazzino e due PDF (magazzino e ufficio).
- **Indicatore di utilità:** tempo di preparazione di un ordine (da circa 20 minuti a pochi secondi), zero ordini duplicati, nessuna confezione incompleta non segnalata.

## Architettura
| Strumento | Ruolo |
| --- | --- |
| n8n | Orchestrazione dei workflow |
| Supabase (Postgres) | Dati: fornitori, prodotti, richieste, righe |
| Claude (AI Agent n8n) | Testi per fornitore e magazzino, avvisi, priorità (output strutturato) |

### Workflow
1. **ESAME – Modulo carica ordine PDF**: modulo web → estrazione testo dal PDF → conversione in JSON → chiamata al webhook → creazione dei PDF "Nota magazzino" e "Riepilogo ufficio" (solo per ordini nuovi e validi).
2. **ESAME – Richiesta ordine fornitore**: Webhook → Validazione → IF valido → Lettura stato su Supabase → Switch (duplicato / fornitore sconosciuto / nuova) → Inserimento richiesta e righe → Lettura dati → AI Agent → IF pagamento anticipato/dilazionato → Aggiornamento (una sola volta) → Risposta.
3. **ESAME – Tester**: invia richieste di prova al webhook.

### Database (4 tabelle collegate)
- `esame_fornitori` (PK id, nome UNIQUE, pagamento)
- `esame_prodotti` (PK id, FK fornitore_id, UNIQUE fornitore_id+codice)
- `esame_richieste` (PK id, **richiesta_id UNIQUE**, FK fornitore_id, stato, esito jsonb)
- `esame_righe` (PK id, FK richiesta_fk ON DELETE CASCADE, UNIQUE richiesta_fk+codice)

Row Level Security attiva senza policy pubbliche: solo n8n, con la connessione di servizio, legge e scrive.

**Perché non il vector store:** i dati sono strutturati e si cercano per chiave esatta (codice, ID richiesta). Servono SQL, vincoli e chiavi esterne. Il vector store sarebbe utile per la ricerca semantica su testi liberi (es. listini PDF dei fornitori): sviluppo futuro.

## Avvio
1. Supabase → SQL Editor: eseguire `1_tabelle_supabase.sql`.
2. n8n: importare i workflow JSON.
3. Collegare le credenziali Postgres e Anthropic (non incluse nei file).
4. Pubblicare i workflow e aprire l'URL del modulo.

## Test
| Prova | Input | Esito |
| --- | --- | --- |
| Caso valido (anticipato) | PDF ORD-2026-010 Fornitore Alfa | stato `in_attesa_pagamento`, avviso confezione incompleta, 2 PDF creati |
| Caso valido (dilazionato) | PDF ORD-2026-011 Fornitore Beta | stato `confermato` |
| Input incompleto | PDF ORD-2026-012 | errore 400 con campi mancanti, nessuna scrittura nel database |
| Invio duplicato | di nuovo ORD-2026-010 | esito già registrato, nessuna nuova azione, un solo record |

## Scelte progettuali
- I numeri (confezioni, pezzi mancanti, importi) li calcola il database; l'AI scrive i testi e segnala anomalie: l'AI non può sbagliare i conti.
- Idempotenza: vincolo UNIQUE su `richiesta_id`, `ON CONFLICT DO NOTHING` e aggiornamento solo se lo stato è ancora `ricevuta`.

## Prompt di sistema dell'AI Agent
> Sei l'assistente acquisti di Qwertycom, un'azienda che vende su Amazon. Ricevi le righe di un ordine a un fornitore, lette dal database. I numeri (confezioni, pezzi mancanti, importi) sono già calcolati: NON ricalcolarli e non inventare dati. Compiti: 1. messaggio_fornitore … 2. nota_magazzino … 3. avvisi … 4. priorita … Rispondi solo nel formato richiesto.

## Limiti del prototipo
- Webhook senza autenticazione (in produzione: Header Auth).
- Dati di prova; nessun invio reale di email.
- La lettura del PDF funziona con questo formato di documento.
- Se l'AI si interrompe a metà, la richiesta resta `ricevuta` e va sbloccata a mano.
