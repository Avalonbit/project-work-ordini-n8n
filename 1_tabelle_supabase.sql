-- =========================================================
-- ESAME EPICODE – Richieste d'ordine ai fornitori (dati DEMO)
-- Incolla tutto in Supabase > SQL Editor > Run
-- Tabelle separate (prefisso esame_) dalle tabelle reali.
-- =========================================================

create table if not exists esame_fornitori (
  id         bigint generated always as identity primary key,
  nome       text not null unique,
  pagamento  text not null check (pagamento in ('anticipato','dilazionato'))
);

create table if not exists esame_prodotti (
  id                    bigint generated always as identity primary key,
  fornitore_id          bigint not null references esame_fornitori(id),
  codice                text not null,
  descrizione           text not null,
  pezzi_per_confezione  int  not null default 1 check (pezzi_per_confezione > 0),
  prezzo_confezione     numeric(10,2) not null check (prezzo_confezione >= 0),
  unique (fornitore_id, codice)
);

create table if not exists esame_richieste (
  id            bigint generated always as identity primary key,
  richiesta_id  text not null unique,              -- identifica la stessa richiesta tra invii ripetuti
  fornitore_id  bigint not null references esame_fornitori(id),
  stato         text not null default 'ricevuta'
                check (stato in ('ricevuta','in_attesa_pagamento','confermato')),
  esito         jsonb,                             -- output dell'AI Agent salvato
  creato_il     timestamptz not null default now(),
  aggiornato_il timestamptz
);

create table if not exists esame_righe (
  id              bigint generated always as identity primary key,
  richiesta_fk    bigint not null references esame_richieste(id) on delete cascade,
  codice          text not null,
  quantita_pezzi  int  not null check (quantita_pezzi > 0),
  confezioni      int,
  unique (richiesta_fk, codice)
);

-- Accessi: RLS attiva e nessuna policy => le chiavi pubbliche (anon) non leggono né scrivono.
-- Solo n8n, con la connessione Postgres di servizio, può operare sulle tabelle.
alter table esame_fornitori enable row level security;
alter table esame_prodotti  enable row level security;
alter table esame_richieste enable row level security;
alter table esame_righe     enable row level security;

-- Dati di prova (inventati)
insert into esame_fornitori (nome, pagamento) values
  ('Fornitore Alfa', 'anticipato'),
  ('Fornitore Beta', 'dilazionato')
on conflict (nome) do nothing;

insert into esame_prodotti (fornitore_id, codice, descrizione, pezzi_per_confezione, prezzo_confezione)
select f.id, x.codice, x.descrizione, x.pz, x.prezzo
from (values
  ('Fornitore Alfa', 'MENTA-ESP32', 'Espositore caramelle menta (32 pezzi)', 32, 56.00),
  ('Fornitore Alfa', 'MENTA-STR24', 'Strisce menta (24 pezzi)',              24, 30.00),
  ('Fornitore Beta', 'TAZZA-6',     'Set tazze ceramica (6 pezzi)',           6, 18.50),
  ('Fornitore Beta', 'PIATTO-1',    'Piatto da portata',                      1,  9.90)
) as x(forn, codice, descrizione, pz, prezzo)
join esame_fornitori f on f.nome = x.forn
on conflict (fornitore_id, codice) do nothing;

-- Query per mostrare nel video il collegamento tra i record
-- select q.richiesta_id, f.nome, q.stato, r.codice, r.quantita_pezzi, r.confezioni
-- from esame_richieste q
-- join esame_fornitori f on f.id = q.fornitore_id
-- join esame_righe r     on r.richiesta_fk = q.id
-- order by q.id, r.codice;
