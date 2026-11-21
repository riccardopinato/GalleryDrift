# Requisiti condivisi — Art Drift / Gallery Drift
Data: 2026-11-21
Stato: note di prodotto da valutare e implementare; nessuna funzione nuova certificata da questo documento.

## Provenienza
Trascrizioni fornite dall'utente di due messaggi vocali WhatsApp del 21/11/2026 e schizzo manoscritto inviato nella stessa conversazione. Il documento preserva le idee espresse ma non costituisce trascrizione audio parola-per-parola verificata. Nessun audio o fotografia personale viene caricato qui.

## R-01 — Inserzioni integrate nel canvas (proposta)
- Idee utente: inserire saltuariamente riquadri pubblicitari al posto di alcune tessere/immagini durante la navigazione continua, sia in Art Drift sia in Gallery Drift.
- Mantenere, se approvato, un banner inferiore distinto; offrire una versione Pro che rimuove la pubblicità.
- Verifica tecnica e policy PRIMA dello sviluppo: NON trattare un normale BannerAd come tessera del canvas. Google sconsiglia banner vicini a immagini interattive e banner che si muovono durante lo scroll: https://support.google.com/admob/answer/6275345
- Valutare esclusivamente Native Ads con identificazione esplicita 'Annuncio', AdChoices, separazione dai contenuti e test clic accidentali: https://admob.google.com/home/resources/native-ads-playbook/
- Nel canvas bidimensionale, gestire viewport, pinch/zoom, riuso risorse, limiti alle pubblicità visibili, assenza di fill e validazione impression. Non mostrare inserzioni in contesti di cancellazione o gesti di gestione file.
- Decisione: PROPOSTA / non autorizza attivazione produzione di AdMob, account pubblicitari o abbonamento.

## R-02 — Sviluppo con motore condiviso (priorità alta)
- Obiettivo: ogni miglioramento di canvas, gesture, fluidità, layout, ricerca/shell, preferiti, animazioni e UI comuni si sviluppa una sola volta e si propaga a entrambe le app.
- Il '95% identico' citato nella trascrizione è un'ipotesi, non una misura verificata sul codice.
- Architettura proposta: package Flutter condiviso drift_canvas_core; due app autonome dipendono da una versione taggata del package.
- Core: coordinate del mondo, layout deterministico, tile virtualization, camera e zoom, componenti comuni, contratti MediaSource/MediaItem, shell e accessibilità, posizioni annuncio (astratte).
- Art Drift: cataloghi opere, musei, artisti, asset e link esterni, ricerca artistica.
- Gallery Drift: MediaStore/Photo Library, scelta cartelle, EXIF/metadati, eliminazione sicura, foto/video locali e gestione accessi.
- CI: rilascio core -> bot apre PR di aggiornamento in entrambi i repository -> test/build -> merge solo con gate approvati. Nessun auto-copia-incolla bidirezionale o aggiornamento automatico non verificato.
- Audit: confrontare le versioni core, funzionalità divergenti intenzionali e PR aperte di entrambe le app.

## R-03 — Ricerca visiva, ispirata a Lens (schizzo)
- Richiesta manoscritta: 'Ricerca visiva tipo Lens per oggetti da riconoscere'.
- Gallery Drift: possibile analisi on-device di immagini (classificazione oggetti/etichette, OCR); distinguere riconoscimento categoria da identificazione esatta dell'oggetto.
- Art Drift: possibile ricerca per similarità visiva tra opere e metadati del catalogo; identificazione certa richiede catalogo/servizio adeguato.
- Preferire elaborazione locale quando possibile. Qualsiasi invio di foto personali a servizi cloud richiede scelta esplicita e privacy disclosure.
- API utili da valutare: ML Kit Image Labeling, Object Detection; nessuna integrazione non ufficiale con Google Lens assunta come disponibile.

## R-04 — Preferiti nell'header (schizzo)
- Cuore dei preferiti ben visibile nella barra in alto, a destra del campo/controllo ricerca, per entrare nella raccolta.
- Nello schizzo compaiono: nome app a sinistra, cerca, cuore, ulteriore icona a destra (funzione da definire).
- La barra deve restare discreta per preservare il canvas immersivo.
- Preferiti supportati da entrambe le app con persistenza e fonti dati proprie.

## Stato operativo
Requisiti documentati come input; non sono state introdotte modifiche a UI, dipendenze, manifest, monetizzazione o repository condiviso.
Repository coinvolti:
- https://github.com/riccardopinato/ArtDrift-Infinite-Art-Gallery
- https://github.com/riccardopinato/GalleryDrift
