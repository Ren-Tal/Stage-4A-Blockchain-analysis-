# Analyse de blockchain (Bitcoin) — Introduction : acquisition et exploration de données

Ce dépôt documente une première étape de recherche sur l'analyse de blockchain : comment acquérir des données Bitcoin, avec quels outils, et ce que ces données permettent déjà de montrer. Ce document est écrit pour qu'un lecteur qui ne connaît pas notre travail dispose du même niveau de connaissance que nous : ce qui a été lu, fait, mesuré, conclu, et ce qui reste incertain.

## Sommaire

1. Contexte et consigne
2. État d'avancement
3. Méthode de travail et transparence
4. Phase 0 — Fondations (UTXO, adresses, transactions)
5. Phase 1 — Block explorers et méthodes d'acquisition
6. Phase 3 — Google BigQuery, datasets publics crypto (réalisée avant la Phase 2)
7. Phase 2 — Elliptic Data Set
8. Phase 4 — Telegram / OSINT
9. Synthèse : établi, hypothèses, limites
10. Ce qui n'a pas été fait
11. Glossaire
12. Reproduire le travail
13. Références complètes

---

## 1. Contexte et consigne

### Sujet donné par le professeur de recherche

**Blockchain Analysis**

- Cryptocurrency research :
  - Bitcoin : mining, PoW, PoS, transactions, addresses, UTXO
  - Ecosystem : exchanges, money laundering, gambling, dark markets, mixers
  - Introduction to analysis : data acquisition, block explorers, dumps, Elliptic Data Set et Google BigQuery (Crypto Public Datasets)
  - Some statistics and metrics : Gini et Benford ; topologie : Degree Centrality, PageRank, Clustering Coefficient
  - H1 Clustering et Change Address Clustering
  - ML : k-means, DBSCAN, random forest, SVM, decision trees ; Feature Engineering : Temporal Features, Value Features, Network Features

### Consigne exacte

Le professeur a demandé de commencer par : *Introduction to analysis : data acquisition, block explorers, dumps, Elliptic Data Set et Google BigQuery (Crypto Public Datasets)*, ainsi que *Telegram/Telemetry*.

La consigne était littéralement « look into data acquisition first ». Aucun livrable, format de rendu, jeu de données imposé ou échéance n'a été défini à ce stade. Le travail ci-dessous est donc une exploration structurée, pas la réponse à un énoncé précis.

### Point non résolu sur la consigne

Le terme « Telemetry » est ambigu. Nous l'avons traité comme « Telegram utilisé comme source de renseignement (OSINT) pour relier des adresses on-chain à des acteurs ». La télémétrie au sens large (données de nœuds, métriques réseau) n'a pas été étudiée. À confirmer auprès du professeur.

---

## 2. État d'avancement

Le plan initial comptait cinq phases. L'ordre chronologique réel a été : 0, 1, 3, 2, 4.

| Phase | Contenu | État |
|---|---|---|
| 0 | Fondations : UTXO, adresses, transactions, traçage manuel | Terminée |
| 1 | Block explorers, limites des API, dumps et nœuds complets | Terminée |
| 2 | Elliptic Data Set : exploration + Random Forest | Terminée (voir §10 pour les pistes non explorées) |
| 3 | BigQuery : requêtes SQL sur les données Bitcoin | Terminée à un niveau exploratoire |
| 4 | Telegram / OSINT | Terminée (lecture, sans manipulation technique) |

---

## 3. Méthode de travail et transparence

L'exploration a été guidée pas à pas par un assistant IA (Claude, Anthropic) : proposition de ressources, de requêtes SQL et de code Python, puis discussion des résultats que nous avons exécutés nous-mêmes et collés dans la conversation. Toutes les valeurs numériques de ce document proviennent de sorties réellement obtenues (BigQuery, pandas, scikit-learn), pas d'estimations.

Pour distinguer le solide du fragile, les affirmations sont étiquetées :

- **[Mesuré]** : résultat direct d'une requête ou d'un calcul que nous avons exécuté.
- **[Documenté]** : information provenant d'une source citée en §13.
- **[Hypothèse]** : interprétation plausible, non démontrée par nos données.
- **[À vérifier]** : information donnée de mémoire ou non confirmée, à contrôler dans la source avant tout usage dans un rapport.

---

## 4. Phase 0 — Fondations

### 4.1 Lectures

- *Mastering Bitcoin* (Andreas Antonopoulos), disponible gratuitement sous licence Creative Commons : dépôt `github.com/bitcoinbook/bitcoinbook`. Chapitre 2 (« How Bitcoin Works ») lu intégralement, lecture poursuivie jusqu'à la section sur le minage.
- Une vidéo pédagogique sur le modèle UTXO a été suggérée (recherche YouTube « Bitcoin UTXO model explained », chaînes Whiteboard Crypto ou Ivan on Tech) mais n'a pas été utilisée : la lecture du livre a suffi.
- Chainalysis Academy (cours gratuits « Crypto Essentials » et « Blockchain Basics ») a été identifié puis écarté : le lien direct du cours renvoyait une erreur 404 (compte requis) et nous avons décidé de ne pas l'utiliser.

### 4.2 Concepts (définitions retenues après correction)

- **Transaction** : contient un ou plusieurs *inputs* (UTXO dépensés) et un ou plusieurs *outputs* (nouveaux UTXO créés). Elle a un identifiant (txid) et est signée par le détenteur des clés des inputs.
- **UTXO** (Unspent Transaction Output) : *n'importe quel* output de transaction pas encore dépensé, c'est-à-dire pas encore utilisé comme input d'une nouvelle transaction. Le « change » (monnaie rendue à soi-même) n'est qu'une des sources possibles d'UTXO, pas sa définition. Une pièce reçue et non dépensée est aussi un UTXO.
- **Adresse** : destination publique permettant de *recevoir* des fonds. Elle ne permet pas de dépenser : dépenser exige la **clé privée** correspondante (qui produit la signature). Le contrôle vient de la clé privée, pas de l'adresse.
- **Atomicité d'un UTXO** : un UTXO se dépense toujours en entier. Pour n'en dépenser qu'une partie, la transaction crée deux outputs : le paiement au destinataire et un output de *change* vers soi-même. C'est le mécanisme qui explique l'existence du change.
- **Frais (fee)** : pas un champ explicite de la transaction, mais la différence implicite `somme(inputs) − somme(outputs)`. Le protocole ne fixe pas leur montant : c'est un marché entre utilisateurs et mineurs (plus on paie, plus la transaction est minée vite).

### 4.3 Traçage manuel d'une transaction (mempool.space)

Une transaction confirmée du dernier bloc a été examinée à la main :

| Élément | Valeur |
|---|---|
| Inputs | 1, de 0,07505574 BTC (type V0_P2WPKH, nSequence `0xfffffffd`) |
| Output 0 | 0,01262598 BTC vers `bc1q09x9l4r82z6mmmqmm7eyyre5tl335cpyzg2uxf` (V0_P2WPKH) |
| Output 1 | 0,06214776 BTC vers `bc1qn3mh5y5kcmckctv9pty0a4fgdn3x7077c0ynxr` (V0_P2WPKH) |
| Somme des outputs | 0,07477374 BTC |
| Fee | 0,00028200 BTC (28 200 satoshis) |

**Constat [Mesuré]** : impossible de dire avec certitude lequel des deux outputs est le change. Aucun montant n'est « rond », et input et outputs sont du même type de script, donc l'indice de type ne tranche pas non plus. Le `nSequence` `0xfffffffd` est inférieur à `0xfffffffe`, ce qui signale l'option de remplacement par frais (RBF, BIP 125) [Documenté, spécification Bitcoin ; non approfondi].

### 4.4 Pourquoi chercher à distinguer paiement et change

Le protocole est conçu pour que les deux soient indiscernables, et c'est une bonne pratique de confidentialité. Mais en pratique, des failles existent :

- certains wallets placent systématiquement le change à une position donnée (biais de position) ;
- le change reste souvent dans le type d'adresse habituel du wallet de l'émetteur, alors que le paiement va vers le format d'adresse du destinataire ;
- un paiement a souvent un montant « logique » (rond, ou équivalent d'un prix), le change est un reliquat quelconque ;
- la réutilisation d'adresses.

Identifier le change permet de relier l'adresse de change à l'entité qui a fourni les inputs, donc de suivre les fonds d'une même personne d'une transaction à l'autre malgré le changement d'adresse. C'est l'objet des modules « H1 Clustering » et « Change Address Clustering » du syllabus : des heuristiques statistiques, jamais des certitudes.

### 4.5 Confidentialité lors de la consultation d'un explorateur

Le livre avertit que l'exploitant d'un explorateur voit l'IP et les recherches, et peut en déduire les intérêts de l'utilisateur ; regarder ses propres transactions peut révéler son solde et son historique. Précisions retenues :

- consulter une transaction quelconque pour étudier sa structure n'expose rien de sensible et ne touche pas à la blockchain (lecture seule d'une base publique) ;
- ce n'est pas l'adresse qui « sait » qu'on la consulte, mais l'exploitant de l'explorateur qui peut journaliser les requêtes ;
- le risque réel concerne les recherches sur ses propres adresses (mitigations : Tor, explorateur sur nœud local).

### 4.6 Auto-évaluation de fin de phase

Réponses initiales puis corrections :

1. *Pourquoi un UTXO ne peut-il pas être dépensé partiellement ?* Réponse initiale à côté (redéfinition de l'UTXO). Correct : unité atomique du protocole, dépensée en entier, d'où le change.
2. *Pourquoi le fee n'est-il pas un champ explicite ?* Réponse initiale : il dépend du mineur. Correct : il est implicite, égal à inputs moins outputs, sans règle de consensus sur son montant.
3. *En quoi savoir qu'un output est du change aide-t-il ?* Réponse correcte : relier l'adresse de change à celle des inputs pour tracer les transactions d'une même personne.

---

## 5. Phase 1 — Block explorers et méthodes d'acquisition

Objectif : comprendre les trois façons d'obtenir des données blockchain et leurs compromis.

### 5.1 Explorateur et son API (mempool.space)

Documentation consultée : `https://mempool.space/docs/api/rest`. Deux endpoints comparés :

- endpoint des transactions d'une adresse (`GET /api/address/:address/txs`) : limité à un nombre restreint de transactions par requête (nous avons relevé environ 50 « dernières » transactions ; la documentation décrit aussi une pagination pour l'historique confirmé) **[À vérifier : chiffres exacts et pagination dans la documentation actuelle]** ;
- endpoint d'une transaction (`GET /api/tx/:txid`) : une seule transaction par requête.

Conséquence [Documenté par la structure de l'API] : reconstruire l'historique complet d'adresses très actives (exchanges, mixers) ou un graphe de milliers d'adresses exige des milliers de requêtes : lent, soumis à des limites de débit, fragile.

### 5.2 Deux raisons de ne pas s'appuyer sur un explorateur public pour de la recherche

1. **Passage à l'échelle** : limites de débit et pagination.
2. **Sécurité opérationnelle (OPSEC)** : l'exploitant voit précisément ce qu'on investigue (IP et requêtes). Pour une enquête réelle, cela peut fuiter l'objet de l'investigation.

### 5.3 Nœud complet et dumps

Faire tourner son propre nœud élimine la fuite vers un tiers et les limites de débit, mais pose trois obstacles :

1. **Stockage** : plusieurs centaines de Go (chiffre cité en séance : 600 Go et plus, non revérifié).
2. **Temps de synchronisation** : de plusieurs heures à plusieurs jours selon le matériel.
3. **Absence de couche de requête** : les données brutes sont des fichiers de blocs, sans SQL ni index. Répondre à « toutes les transactions de plus de 10 BTC le mois dernier » demande d'écrire soi-même un parseur.

### 5.4 Datasets curatés et hébergés

BigQuery (Google a déjà synchronisé et structuré les données, on écrit du SQL) et Elliptic (jeu étiqueté prêt pour le ML) résolvent ces trois obstacles. BigQuery reste un tiers qui voit les requêtes, ce qui est sans importance pour un travail académique mais compterait pour une enquête sensible.

---

## 6. Phase 3 — BigQuery : datasets publics crypto

### 6.1 Accès

- Lab guidé Google Cloud Skills Boost (`https://www.skills.google/focuses/8486?parent=catalog`) : identifié mais **non utilisé**. Les labs de cette plateforme peuvent consommer des crédits, ce qui n'est pas garanti gratuit.
- Voie retenue : le **BigQuery Sandbox** via `https://console.cloud.google.com/bigquery`, avec un compte Google ordinaire. Le sandbox n'exige pas de carte bancaire (bandeau « Bac à sable » observé dans la console). Un niveau gratuit permanent de 1 To de requêtes par mois s'applique.
- Documentation d'appui : `cloud.google.com/bigquery/docs/quickstarts/query-public-dataset-console`.
- Ajout du dataset : « Ajouter des données » → « Ensembles de données publics » → filtre Type « Données », recherche « bitcoin » → carte **Bitcoin Cryptocurrency** (« Bitcoin blockchain transactions and blocks »). Autres datasets vus dans le catalogue : Bitcoin Cash, Litecoin, Zcash, Dogecoin, Dash, Zilliqa, Ethereum (deux versions), Sui, Avalanche, Tron, Cronos, Fantom, Polygon, Optimism, Arbitrum One, Ethereum Goerli.
- Observation : le raccourci du dataset a disparu de l'Explorateur en revenant dans BigQuery Studio. Ce n'est pas une perte de données (le dataset appartient à Google) ; on peut interroger avec le nom complet `bigquery-public-data.crypto_bitcoin.…`.

### 6.2 Schéma et conventions utiles

- Table principale : `bigquery-public-data.crypto_bitcoin.transactions` (autres tables : blocks, inputs, outputs).
- Colonnes utilisées : `hash`, `block_timestamp`, `block_timestamp_month` (colonne de **partitionnement mensuel**), `input_count`, `output_count`, `fee`, et le tableau imbriqué `outputs` (chaque élément a notamment `index`, `value`, `type`, `addresses`).
- `value` est exprimé en **satoshis** (1 BTC = 1e8 satoshis).
- Le nom de la colonne de type de script dans `outputs` est **`type`** (et non `script_type`, erreur initiale corrigée).

### 6.3 Coût des requêtes

- `SELECT * … LIMIT 10` sur toute la table : **2,35 To** estimés, soit plus de deux fois le quota mensuel gratuit. `LIMIT` ne réduit pas les données lues.
- Filtre sur `block_timestamp_month` + cinq colonnes seulement : **153,19 Go** estimés pour un mois (janvier 2024). Toujours vérifier l'estimation affichée avant d'exécuter.
- Le volume estimé des requêtes sur septembre 2026 n'a pas été consigné.
- Un compteur cumulé du quota n'est pas clairement visible en mode sandbox ; la pratique retenue est de vérifier l'estimation avant chaque exécution.

### 6.4 Requêtes réalisées et résultats

Toutes les requêtes portent sur **septembre 2026** (`block_timestamp_month = '2026-09-01'`). Le mois était en cours au moment de l'analyse, donc les données sont partielles (le dernier jour observé est le 19 septembre 2026 pour la première requête). Le format de date doit être `'YYYY-MM-DD'` (une saisie `'26-09-01'` était incorrecte).

#### 6.4.1 Repérer des transactions à outputs de valeurs très répétées

Idée : beaucoup d'outputs de même valeur dans une transaction est un motif associé aux mixers/CoinJoin. Première version en `HAVING` rejetée (« HAVING requires GROUP BY or aggregation ») ; version corrigée par sous-requête :

```sql
SELECT *
FROM (
  SELECT
    `hash`,
    block_timestamp,
    output_count,
    (SELECT COUNT(DISTINCT value) FROM UNNEST(outputs)) AS distinct_output_values
  FROM `bigquery-public-data.crypto_bitcoin.transactions`
  WHERE block_timestamp_month = '2026-09-01'
    AND output_count > 5
)
WHERE distinct_output_values < output_count / 2
ORDER BY output_count DESC
LIMIT 20
```

Résultat [Mesuré] (top 20 par nombre d'outputs) :

| hash | block_timestamp (UTC) | output_count | valeurs distinctes |
|---|---|---|---|
| `6ed610d9de8c7baf63c973596048bf04dd2abca941862234ad28dba0df456cc4` | 2026-09-19 12:23:34 | 1151 | 423 |
| `a1fdaf0c3da2c6286cf02c5666bda42c36f42dd9bb0d31f3d07960351b09e89d` | 2026-09-01 04:34:23 | 971 | 21 |
| `3fe53d71e11fba3cce1a0a7e07014a4a4be3a1336d495e3b171ccf10bc02504e` | 2026-09-15 23:17:02 | 918 | 3 |
| `9adc69e4430928f0d1f3e25a27e198477a83814041c6bc6f2ebd09c904107bb8` | 2026-09-15 23:17:02 | 917 | 3 |
| `df652b09935c414f0f2d99b97db97607359e7ecf650738094bf9fb5e15e27a65` | 2026-09-15 22:53:42 | 912 | 3 |
| `38645affe595e2c6a13ab9e37c1e9722b7f40d0164c7e21cbd0399dece1fa701` | 2026-09-19 07:41:13 | 890 | 72 |
| `f2e248dd5a6f92c7bdb52079a1299923e9f83e476f8a32f1115c713435f998bc` | 2026-09-01 06:56:36 | 832 | 10 |
| `93276775439b19f65dec6ba47aa03b21d9262deee91268cca49d5c1abfba1395` | 2026-09-12 21:07:58 | 803 | 4 |
| `a18d060b935fb0e4a7a887f71fb3e046826e28c615587abc1eabb6dd361f4ab8` | 2026-09-16 00:31:07 | 772 | 3 |
| `a35e26bd400a37785c41cf83d44b1f06f5a753b38c1cf78a29b4eae7d6538094` | 2026-09-02 08:57:36 | 601 | 5 |
| `026e57d7bf7a7ea48262caf5df86b0d8438d7313d90187abfc24ed3e882103fd` | 2026-09-02 10:45:01 | 601 | 5 |
| `70e02dd0d0faa86b03461be56405d6787d2c80f3969ec0e881a593863e3e10d8` | 2026-09-02 10:06:10 | 601 | 5 |
| `161b07b05830739e1fc1f16538cd5b081620131dd07f4103ad0dd02cd521298b` | 2026-09-02 10:06:10 | 601 | 7 |
| `bf758e9fbe512a3c27cf026c6ec36dc3305af39a4aa54c638780f82b29f7b404` | 2026-09-02 08:57:36 | 601 | 3 |
| `b5e1543aa9b8c15269c501a45ad107ae36993c4e7d880a48f85bfc5cc083d15f` | 2026-09-02 12:00:50 | 601 | 6 |
| `3ba8850d34a2775f60aa8e8dad689f42dcc74b1c57b58cf9912f54fb4a83c770` | 2026-09-02 08:15:13 | 601 | 5 |
| `3bfa6c12e39ed8a25368c97c1f5b6baeb7f3b645edd475c1c8c2940ac0f2e02b` | 2026-09-02 10:06:10 | 601 | 4 |
| `b1d618c2baf85fade59e6f1cf12ff188f09c9e9e3e327f9fb11e87dd37e88e18` | 2026-09-02 08:57:36 | 601 | 5 |
| `58441ba600958a99113d461fa5d182e605f62984c30f581c920c9175b8a7ef8a` | 2026-09-02 08:57:36 | 601 | 5 |
| `860c0064a43d58916b273ca7f963b5e76e61ed6067c4d1ac6af2cfcf094f0f37` | 2026-09-02 08:57:36 | 601 | 7 |

Le groupe de transactions à exactement 601 outputs est apparu de façon répétée le 2 septembre 2026.

#### 6.4.2 Nombre d'inputs des transactions à 601 outputs

Une transaction de 601 inputs et 601 outputs n'est pas un paiement groupé d'exchange classique (qui a peu d'inputs). Requête :

```sql
SELECT `hash`, block_timestamp, input_count, output_count
FROM `bigquery-public-data.crypto_bitcoin.transactions`
WHERE block_timestamp_month = '2026-09-01'
  AND output_count = 601
ORDER BY block_timestamp
```

Résultat [Mesuré] : **23 transactions**, toutes du 2 septembre 2026, avec 601 outputs et entre **601 et 604 inputs** :

| hash | heure (UTC) | input_count |
|---|---|---|
| `eaa1bc4a2eb26ec8adbd88bf6865c7d4e4ab67c753087369afb1a46875f362a8` | 06:34:02 | 601 |
| `3ba8850d34a2775f60aa8e8dad689f42dcc74b1c57b58cf9912f54fb4a83c770` | 08:15:13 | 601 |
| `143129a549a6599e9ee3cab6d2153d6aa8e2694c1175d9f1673e6503c73c5953` | 08:57:36 | 603 |
| `8c54be421427e55e97efe18dace71a809e22d3b9c8c61771cf7e5ed9bfc63fb5` | 08:57:36 | 604 |
| `cfd385e748bc949097bae5fd5aaabfeab3a0227be415daea978a09009ed53c97` | 08:57:36 | 604 |
| `58441ba600958a99113d461fa5d182e605f62984c30f581c920c9175b8a7ef8a` | 08:57:36 | 604 |
| `a35e26bd400a37785c41cf83d44b1f06f5a753b38c1cf78a29b4eae7d6538094` | 08:57:36 | 604 |
| `860c0064a43d58916b273ca7f963b5e76e61ed6067c4d1ac6af2cfcf094f0f37` | 08:57:36 | 601 |
| `b1d618c2baf85fade59e6f1cf12ff188f09c9e9e3e327f9fb11e87dd37e88e18` | 08:57:36 | 604 |
| `bf758e9fbe512a3c27cf026c6ec36dc3305af39a4aa54c638780f82b29f7b404` | 08:57:36 | 604 |
| `b7dfb9335232cd99a940f730c1ca0fba2b3a8ba80150e6d1ed98c71127efbac5` | 10:05:51 | 604 |
| `0d9db8787f602a02eb79d97b3069a927084413d076d067a8d98ff12347599b2a` | 10:06:10 | 604 |
| `d6e63840de2d4e776cf57251123a3b30bcd4367fcb6b1e64b30c340f45bd0162` | 10:06:10 | 604 |
| `3bfa6c12e39ed8a25368c97c1f5b6baeb7f3b645edd475c1c8c2940ac0f2e02b` | 10:06:10 | 604 |
| `70e02dd0d0faa86b03461be56405d6787d2c80f3969ec0e881a593863e3e10d8` | 10:06:10 | 604 |
| `161b07b05830739e1fc1f16538cd5b081620131dd07f4103ad0dd02cd521298b` | 10:06:10 | 604 |
| `6fa0eb5e0b937864fc4feaf898d967cf11f6fc277bc8dbf8c2288ed33dca6a27` | 10:06:10 | 604 |
| `026e57d7bf7a7ea48262caf5df86b0d8438d7313d90187abfc24ed3e882103fd` | 10:45:01 | 604 |
| `b0c706ed4ce2d5eca02af4afe0b684a54e9be867b2969fbb9187ab6e7eb34ca3` | 10:51:07 | 604 |
| `2a28f8be20c67a8f619a52d513e0d9083b886e75ade83d3217a27c187000b236` | 10:59:40 | 604 |
| `157e5b19e739f0b01d6bdc9cb3efb3b2da17a98bb2a98fe9b44782af7b677e4a` | 12:00:50 | 604 |
| `b5e1543aa9b8c15269c501a45ad107ae36993c4e7d880a48f85bfc5cc083d15f` | 12:00:50 | 604 |
| `098c5870ac162ff68d6f94277a330048a66eecdcfc179e82a3b2d162e665fe7a` | 12:00:50 | 604 |

Plusieurs transactions partagent le même horodatage de bloc, donc le même bloc : 8 à 08:57:36, 6 à 10:06:10, 3 à 12:00:50.

#### 6.4.3 Distribution des valeurs d'output d'une de ces transactions

```sql
SELECT
  output.value / 1e8 AS value_btc,
  COUNT(*) AS nb_outputs_with_this_value
FROM `bigquery-public-data.crypto_bitcoin.transactions`,
  UNNEST(outputs) AS output
WHERE block_timestamp_month = '2026-09-01'
  AND `hash` = 'eaa1bc4a2eb26ec8adbd88bf6865c7d4e4ab67c753087369afb1a46875f362a8'
GROUP BY value_btc
ORDER BY nb_outputs_with_this_value DESC
```

Résultat [Mesuré] :

| value_btc | nombre d'outputs |
|---|---|
| 0,00000546 | 591 |
| 0,000021 | 3 |
| 0,000005 | 3 |
| 0,00074053 | 1 |
| 0,0000055 | 1 |
| 0,00000333 | 1 |
| 0,00001 | 1 |

591 des 601 outputs valent **546 satoshis**. Cette valeur correspond au seuil de « poussière » (dust) couramment cité pour les outputs de type P2PKH aux paramètres de relais par défaut ; le seuil diffère selon le type de script (plus bas pour les scripts segwit) **[À vérifier : valeur exacte du seuil selon le type de script]**. Ce n'est donc ni un CoinJoin (qui vise des outputs de dénomination « ronde » entre participants) ni un paiement en masse ordinaire.

#### 6.4.4 Nombre d'adresses distinctes visées

```sql
SELECT
  `hash`,
  block_timestamp,
  COUNT(DISTINCT output.addresses[SAFE_OFFSET(0)]) AS distinct_addresses_targeted,
  COUNTIF(output.value = 546) AS nb_dust_outputs
FROM `bigquery-public-data.crypto_bitcoin.transactions`,
  UNNEST(outputs) AS output
WHERE block_timestamp_month = '2026-09-01'
  AND `hash` IN ( /* 10 hash de la liste précédente */ )
GROUP BY `hash`, block_timestamp
ORDER BY block_timestamp
```

Résultat [Mesuré], sur 10 transactions du groupe (préfixes de hash) :

| hash | heure (UTC) | adresses distinctes | outputs à 546 sats |
|---|---|---|---|
| `eaa1bc4a…` | 06:34:02 | 2 | 591 |
| `3ba8850d…` | 08:15:13 | 2 | 593 |
| `b1d618c2…` | 08:57:36 | 2 | 590 |
| `860c0064…` | 08:57:36 | 2 | 592 |
| `cfd385e7…` | 08:57:36 | 2 | 589 |
| `143129a5…` | 08:57:36 | 2 | 593 |
| `a35e26bd…` | 08:57:36 | 2 | 594 |
| `8c54be42…` | 08:57:36 | 2 | 593 |
| `58441ba6…` | 08:57:36 | 2 | 596 |
| `bf758e9f…` | 08:57:36 | 2 | 593 |

Les ~590 outputs de poussière de chaque transaction pointent vers seulement **2 adresses distinctes**. Les 13 autres transactions du groupe n'ont pas été soumises à cette requête.

**Interprétation**

- **[Hypothèse]** : création massive de petits UTXO concentrée sur peu d'adresses (« UTXO flooding »), avec inputs ≈ outputs (le même acteur consolide et refragmente). Ce n'est pas une attaque de dust de désanonymisation à large échelle, qui viserait des centaines d'adresses différentes.
- **Explications alternatives non écartées** : fractionnement d'UTXO par un service ou un protocole de jetons, test technique, ou autre usage automatisé. Nos données ne permettent pas de trancher, et les adresses d'inputs n'ont pas été analysées.
- Leçon méthodologique : le seul nombre d'outputs suggérait d'abord un CoinJoin ; les valeurs (546 sats) puis les adresses distinctes (2) ont renversé et affiné la conclusion. Un indicateur isolé ne suffit pas, il faut croiser plusieurs features, ce qui préfigure le module Feature Engineering.
- Cette piste s'est éloignée de l'objectif initial (le change clustering) ; elle a été menée par curiosité puis refermée.

#### 6.4.5 Heuristique de type de script pour le change

Question : pour les transactions simples (1 input, 2 outputs), quelle part a deux outputs de types de script différents ?

```sql
SELECT
  CASE
    WHEN (SELECT type FROM UNNEST(outputs) LIMIT 1 OFFSET 0)
       = (SELECT type FROM UNNEST(outputs) LIMIT 1 OFFSET 1)
    THEN 'same_type'
    ELSE 'different_type'
  END AS script_comparison,
  COUNT(*) AS nb_transactions
FROM `bigquery-public-data.crypto_bitcoin.transactions`
WHERE block_timestamp_month = '2026-09-01'
  AND output_count = 2
  AND input_count = 1
GROUP BY script_comparison
```

Résultat [Mesuré] :

| Comparaison | Transactions | Part |
|---|---|---|
| Types différents | 9 082 528 | environ 86,6 % |
| Même type | 1 403 198 | environ 13,4 % |
| Total | 10 485 726 | 100 % |

**Lecture** : dans environ 87 % des transactions simples, les deux outputs ont des types de script différents, donc l'heuristique « l'output du même type que l'input est probablement le change » *s'applique* à la grande majorité des cas. **Réserve importante** : nous avons mesuré son *applicabilité*, pas sa *précision*. Il n'y a pas de vérité terrain, et le type de l'input n'a pas été comparé à celui des outputs dans cette requête.

### 6.5 Requêtes proposées mais dont les résultats n'ont pas été consignés

Transactions triées par fee, par valeur totale sortante, volume total transféré par jour, et recherche d'inputs/outputs simultanément nombreux (`input_count > 10 AND output_count > 10`). Elles n'ont pas été rapportées et ne figurent donc pas dans les conclusions.

### 6.6 Journal des erreurs rencontrées

- `HAVING` sans `GROUP BY` : remplacé par une sous-requête.
- `script_type` inconnu : le champ s'appelle `type`.
- Format de date `'26-09-01'` invalide : utiliser `'2026-09-01'`.
- Dataset disparu de l'Explorateur : sans conséquence, requêtes possibles par nom complet.

---

## 7. Phase 2 — Elliptic Data Set

### 7.1 Obtention

Téléchargé depuis Kaggle (compte gratuit requis, connexion Google possible), recherche « Elliptic Data Set ». Trois fichiers CSV, environ 190 à 200 Mo au total dézippés :

- `elliptic_txs_features.csv` : sans en-tête ; colonne 0 = identifiant de transaction, colonne 1 = time step (1 à 49), colonnes 2 à 166 = features numériques normalisées.
- `elliptic_txs_classes.csv` : colonnes `txId`, `class`.
- `elliptic_txs_edgelist.csv` : colonnes `txId1`, `txId2`, une ligne par flux d'une transaction vers une autre (graphe orienté).

Le dataset est publié par Elliptic à des fins de recherche ; il est très utilisé dans la littérature sur la détection de transactions illicites.

### 7.2 Chargement et dimensions

```python
import pandas as pd

features = pd.read_csv("elliptic_txs_features.csv", header=None)
classes = pd.read_csv("elliptic_txs_classes.csv")
edgelist = pd.read_csv("elliptic_txs_edgelist.csv")
print(features.shape, classes.shape, edgelist.shape)
```

Résultat [Mesuré] : `(203769, 167)`, `(203769, 2)`, `(234355, 2)`.

Les features sont déjà standardisées (centrées autour de zéro). Leur signification n'est pas publiée. D'après la documentation, les colonnes 1 à 94 sont des features *locales* (dont le time step) et les colonnes 95 à 166 des features *agrégées* sur les transactions voisines **[À vérifier dans le papier Weber et al.]**. Chaque time step représente environ deux semaines ; les dates réelles ne sont pas publiées [Documenté].

### 7.3 Répartition des classes

Le sens des codes vient de la documentation : `1` = illicite, `2` = licite, `unknown` = non labellisé [Documenté : papier Weber et al. 2019 et page Kaggle ; rien dans les données brutes ne l'indique, il faut le vérifier à la source].

| Classe | Effectif | Part du total |
|---|---|---|
| unknown | 157 205 | environ 77 % |
| 2 (licite) | 42 019 | environ 21 % |
| 1 (illicite) | 4 545 | environ 2 % |

Parmi les **46 564** transactions labellisées, l'illicite représente environ **9,8 %**. Conséquences : classes très déséquilibrées ; l'accuracy seule est trompeuse (un modèle « toujours licite » aurait environ 90 % sur les labellisées) ; seules les transactions labellisées servent à l'entraînement supervisé.

### 7.4 Évolution temporelle de la proportion d'illicite

```python
features_ts = features[[0, 1]].rename(columns={0: 'txId', 1: 'time_step'})
merged = features_ts.merge(classes, on='txId')
labeled = merged[merged['class'] != 'unknown'].copy()
labeled['is_illicit'] = (labeled['class'] == '1').astype(int)
illicit_ratio_per_step = labeled.groupby('time_step')['is_illicit'].mean() * 100
```

Résultat [Mesuré] (% d'illicite parmi les transactions labellisées de chaque time step) :

```
 1: 0.79    2: 1.61    3: 0.86    4: 2.08    5: 0.43    6: 1.03
 7: 8.48    8: 5.75    9: 31.88  10: 1.85   11: 18.82  12: 3.16
13: 35.97  14: 10.31  15: 23.79  16: 24.15  17: 12.21  18: 13.37
19: 10.74  20: 28.89  21: 15.60  22: 8.96   23: 4.47   24: 12.17
25: 19.87  26: 18.57  27: 11.65  28: 29.93  29: 28.02  30: 15.84
31: 14.93  32: 25.85  33: 5.22   34: 7.18   35: 13.57  36: 1.93
37: 8.03   38: 14.68  39: 6.85   40: 9.25   41: 10.25  42: 11.10
43: 1.75   44: 1.51   45: 0.41   46: 0.28   47: 2.60   48: 7.64
49: 11.76
```

Observations : niveau très bas aux steps 1 à 6 (moins de 2,1 %) ; pics aux steps **9 (31,88 %)** et **13 (35,97 %)** ; plateau élevé et irrégulier ensuite ; creux aux steps 43 à 46. Ces proportions varient donc fortement, d'où le choix d'un split temporel plutôt qu'aléatoire.

**Cause des pics (9 et 13) : non établie.** Les dates ne sont pas publiées. Une hypothèse d'événement réel (par exemple la fermeture d'un marché noir) a été formulée mais n'est appuyée par aucune source fiable pour ces steps. Un dépôt GitHub communautaire consulté (non officiel, URL non conservée) évoquait un événement autour du **step 43**, qui ne correspond pas à ces pics **[À vérifier]** ; il devient toutefois pertinent au §7.8.

### 7.5 Features discriminantes

Comparaison de la moyenne de chaque colonne entre illicite et licite (colonnes d'ID exclues après une erreur initiale : les colonnes `0` et `txId` sortaient en tête avec environ 3,04e7, sans sens) :

```python
full_merged = features.merge(classes, left_on=0, right_on='txId')
labeled_full = full_merged[full_merged['class'] != 'unknown'].copy()
means_by_class = labeled_full.groupby('class').mean(numeric_only=True)
diff = (means_by_class.loc['1'] - means_by_class.loc['2']).abs()
print(diff.drop(index=[0, 'txId'], errors='ignore').sort_values(ascending=False).head(10))
```

Résultat [Mesuré] (écart absolu de moyenne, features standardisées) :

| Colonne | Écart |
|---|---|
| 54 | 1,262973 |
| 56 | 1,082785 |
| 91 | 1,023468 |
| 90 | 1,000078 |
| 55 | 0,902200 |
| 53 | 0,853648 |
| 92 | 0,813541 |
| 60 | 0,753366 |
| 66 | 0,753319 |
| 61 | 0,707137 |

À titre de comparaison, la colonne 2 (choisie au hasard) : moyenne −0,165745 (illicite) contre −0,040412 (licite), soit un écart d'environ 0,125.

**Histogramme de la colonne 54** [Mesuré] : les illicites sont très concentrés autour de −0,5, avec un second pic net vers 1,0 et presque rien au-delà ; les licites sont étalés jusqu'à environ 3,5–4, avec un petit pic vers 3,7 ; les deux classes se chevauchent autour de −0,5.

**Réserves.** L'écart de moyennes est une mesure grossière (il ignore la forme des distributions et la dérive temporelle). L'idée que l'illicite serait « plus automatisé et répétitif » est une **[Hypothèse]** sans preuve. Le sens des colonnes est inconnu : on sait que la colonne 54 est discriminante, pas ce qu'elle représente.

### 7.6 Structure du graphe

```python
edges_with_class = edgelist.merge(classes, left_on='txId1', right_on='txId', suffixes=('', '_1'))
edges_with_class = edges_with_class.merge(classes, left_on='txId2', right_on='txId', suffixes=('_1', '_2'))
edges_labeled = edges_with_class[
    (edges_with_class['class_1'] != 'unknown') &
    (edges_with_class['class_2'] != 'unknown')
]
print(edges_labeled.groupby(['class_1', 'class_2']).size())
```

Résultat [Mesuré] (arêtes dont les deux extrémités sont labellisées : 36 624 sur 234 355) :

| Source → cible | Arêtes | Part parmi les arêtes issues de cette classe |
|---|---|---|
| illicite → illicite | 998 | environ 52,2 % |
| illicite → licite | 915 | environ 47,8 % |
| licite → illicite | 781 | environ 2,2 % |
| licite → licite | 33 930 | environ 97,8 % |

**Lecture** : une transaction illicite mène vers une autre illicite dans environ 52 % des cas, contre environ 2 % pour une licite ; l'illicite n'est pas réparti au hasard mais forme des chaînes ou grappes, cohérent avec l'idée d'un circuit de blanchiment. Comparé au taux de base d'environ 10 % d'illicite parmi les labellisées, 52 % est élevé et 2,2 % est bas. **Réserves** : seules les arêtes entre nœuds labellisés sont comptées (les voisins `unknown`, majoritaires, sont ignorés) et aucune comparaison à un modèle aléatoire n'a été faite.

Ce résultat justifie l'intérêt de modèles exploitant le graphe (par exemple des réseaux de neurones sur graphes, GCN, cités dans la littérature sur ce dataset) **[À vérifier]**.

### 7.7 Modèle : Random Forest

**Découpage temporel** (comme dans la littérature sur ce dataset) : time steps 1 à 34 pour l'entraînement, 35 à 49 pour le test, afin de simuler la prédiction sur des données futures. Seules les transactions labellisées sont utilisées.

```python
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report

features_all = features.rename(columns={0: 'txId', 1: 'time_step'})
data = features_all.merge(classes, on='txId')
data = data[data['class'] != 'unknown'].copy()
data['label'] = (data['class'] == '1').astype(int)   # 1 = illicite

train = data[data['time_step'] <= 34]
test = data[data['time_step'] > 34]
feature_cols = [c for c in features.columns if c not in [0, 1]]
X_train, y_train = train[feature_cols], train['label']
X_test, y_test = test[feature_cols], test['label']
print(X_train.shape, X_test.shape)
```

Dimensions [Mesuré] : train `(29894, 165)`, test `(16670, 165)` (somme : 46 564, cohérente avec le nombre de transactions labellisées). Dans le test, 1 083 transactions illicites (6,5 %) contre 15 587 licites ; dans l'entraînement, 3 462 illicites (environ 11,6 %). Un modèle « toujours licite » aurait donc environ 93,5 % d'accuracy sur le test.

**Modèle 1 (de base)**

```python
rf = RandomForestClassifier(n_estimators=100, random_state=42, n_jobs=-1)
rf.fit(X_train, y_train)
print(classification_report(y_test, rf.predict(X_test), target_names=['licite', 'illicite']))
```

| | precision | recall | f1 | support |
|---|---|---|---|---|
| licite | 0,98 | 1,00 | 0,99 | 15 587 |
| illicite | 0,97 | 0,72 | 0,83 | 1 083 |

Accuracy 0,98 (macro avg : 0,98 / 0,86 / 0,91 ; weighted avg : 0,98 / 0,98 / 0,98). Sur la classe illicite : quand le modèle dit « illicite » il a raison dans 97 % des cas, mais il ne retrouve que 72 % des vrais cas (environ 302 sur 1 083 ratés). En lutte anti-blanchiment, rater un cas coûte généralement plus cher qu'une fausse alerte.

**Modèle 2 (`class_weight='balanced'`, mêmes paramètres et même split)**

| | precision | recall | f1 | support |
|---|---|---|---|---|
| licite | 0,98 | 0,99 | 0,99 | 15 587 |
| illicite | 0,91 | 0,72 | 0,81 | 1 083 |

Accuracy 0,98. L'hypothèse initiale (la pondération ferait monter le recall) est **infirmée** : le recall reste à 0,72, la precision baisse (0,97 vers 0,91) et le F1 recule légèrement. Explication probable **[Hypothèse]** : les arbres profonds ont des feuilles quasi pures, donc la pondération change peu la décision finale ; le problème n'est pas le déséquilibre.

**Comparaison avec la littérature : non faite.** Les chiffres du papier de Weber et al. n'ont pas été vérifiés ; ne pas citer de comparaison sans les avoir lus dans la source.

### 7.8 Diagnostic : le recall s'effondre après le step 42

Recall illicite du modèle 1, par time step du test :

```python
test_eval = test.copy()
test_eval['pred'] = rf.predict(X_test)
recall_per_step = (
    test_eval[test_eval['label'] == 1]
    .groupby('time_step')
    .apply(lambda g: (g['pred'] == 1).mean())
)
```

Résultat [Mesuré] :

| Step | Cas illicites | Détectés | Recall |
|---|---|---|---|
| 35 | 182 | 176 | 0,97 |
| 36 | 33 | 32 | 0,97 |
| 37 | 40 | 26 | 0,65 |
| 38 | 111 | 100 | 0,90 |
| 39 | 81 | 75 | 0,93 |
| 40 | 112 | 71 | 0,63 |
| 41 | 116 | 108 | 0,93 |
| 42 | 239 | 190 | 0,79 |
| 43 | 24 | 0 | 0,00 |
| 44 | 24 | 1 | 0,04 |
| 45 | 5 | 0 | 0,00 |
| 46 | 2 | 1 | 0,50 |
| 47 | 22 | 0 | 0,00 |
| 48 | 36 | 0 | 0,00 |
| 49 | 56 | 1 | 0,02 |

Agrégé [Mesuré] :

- steps 35 à 42 : 914 cas, 778 détectés, recall **0,85** ;
- steps 43 à 49 : 169 cas, 3 détectés, recall **0,02** ;
- sur les 302 cas ratés au total, environ 166 (55 %) tombent dans les steps 43 à 49 et environ 136 (45 %) dans les steps 35 à 42.

**Interprétation.**

- Établi : le modèle entraîné sur les steps 1 à 34 fonctionne correctement jusqu'au step 42 puis ne détecte presque plus rien à partir du step 43. Le recall global de 0,72 est une moyenne trompeuse entre un modèle correct et un modèle aveugle. L'effondrement n'explique qu'un peu plus de la moitié des erreurs.
- **[Hypothèse]** : changement de comportement des acteurs illicites (*concept drift*), possiblement lié à un événement réel autour du step 43. Le papier original de Weber et al. semble décrire une dégradation du même type après la fermeture d'un marché noir **[À vérifier dans le papier avant de l'écrire]**. Nos données montrent *où* le modèle casse, pas *pourquoi*.
- Prudence sur les steps isolés en fin de série : le recall de 0,50 au step 46 repose sur 2 cas et celui du step 45 sur 5. Il faut raisonner sur le bloc 43–49 (169 cas).
- Test non réalisé pour départager les explications : réentraîner sur les steps 1 à 42 et évaluer sur 43 à 49.

### 7.9 Articulation avec la Phase 3

Elliptic ne contient **pas d'adresses**, seulement des identifiants de transactions anonymisés ; le *change address clustering* est donc structurellement impossible avec ce dataset (il se pratique sur BigQuery, où les adresses existent). Elliptic sert le volet classification et ML du syllabus, BigQuery le volet clustering.

---

## 8. Phase 4 — Telegram / OSINT

Phase de lecture, sans manipulation technique. Elle éclaire comment une adresse on-chain est reliée à un acteur réel, ce qui alimente l'analyse blockchain.

### 8.1 Pourquoi Telegram

Telegram est un lieu majeur de fraude financière, de blanchiment, de carding et d'arnaques d'investissement. Beaucoup de canaux et groupes sont **publics** et donc analysables sans intrusion.

### 8.2 Outils

- **Maltego** : analyse de liens (link analysis) ; des *Transforms* (scripts externes, souvent en Python) prennent une entité en entrée (canal, pseudo, adresse), interrogent une API ou une source et renvoient de nouvelles entités liées, affichées comme nœuds ; on « pivote » en relançant un autre Transform sur un résultat, ce qui construit le graphe d'enquête.
- **Gephi** : alternative gratuite pour de gros graphes (milliers de nœuds), import de relations en CSV ; l'algorithme de mise en page **ForceAtlas2** fait s'attirer les nœuds connectés et se repousser les autres, ce qui révèle des grappes et des nœuds « ponts » entre groupes (souvent des acteurs stratégiques comme un blanchisseur).
- **Google Dorks** : requêtes Google avancées ciblées (par exemple sur `t.me`).
- **Spiderfoot** : collecte automatisée depuis plusieurs sources.

### 8.3 Types de nœuds cartographiés

Canaux, noms d'utilisateur, numéros de téléphone, **adresses de wallet**, adresses IP (quand un renseignement technique le permet). Les adresses de wallet font le pont entre l'OSINT et l'analyse blockchain.

### 8.4 Cas d'usage documenté

Dans les arnaques d'usurpation ou de « giveaway » (« envoyez 0,1 BTC, recevez 0,5 BTC »), les criminels publient une adresse : c'est le moment où le lien identité-adresse devient public. Un chercheur peut alors suivre les fonds sur la blockchain (requêtes de type BigQuery, heuristique de change) jusqu'à d'éventuels points de sortie (exchange, mixer). L'OSINT ne remplace pas l'analyse blockchain, il l'alimente en points de départ.

### 8.5 Désanonymisation par pack de stickers

Selon les sources consultées, le pack de stickers d'un utilisateur Telegram expose un identifiant numérique unique (UID) de son créateur ; extrait des métadonnées du pack puis résolu en nom d'utilisateur (via des bots dédiés, un bot précis a été cité en séance), il peut révéler le gérant d'un canal anonyme qui a publié un pack **[À vérifier : mécanisme exact et nom du bot dans le dépôt `maltego-telegram`]**.

---

## 9. Synthèse : établi, hypothèses, limites

### Établi par nos mesures

- Septembre 2026 (partiel), BigQuery : 23 transactions à 601 outputs et 601 à 604 inputs le 2 septembre, dont environ 590 outputs de 546 sats vers 2 adresses distinctes (sur 10 transactions testées).
- Environ 87 % des transactions simples à 1 input et 2 outputs ont des types de script différents entre leurs outputs (10 485 726 transactions).
- Elliptic : 203 769 transactions, 46 564 labellisées, environ 9,8 % illicites parmi elles ; proportion d'illicite très variable dans le temps (pics aux steps 9 et 13).
- Graphe : illicite vers illicite 52 % contre licite vers illicite 2,2 % (arêtes entre nœuds labellisés).
- Random Forest : precision 0,97, recall 0,72, F1 0,83 sur l'illicite ; `class_weight='balanced'` n'améliore pas ; recall 0,85 sur les steps 35–42 contre 0,02 sur les steps 43–49.

### Hypothèses non démontrées

- Nature du comportement à 601 outputs (flooding, test technique, protocole de jetons).
- Cause des pics aux steps 9 et 13.
- Cause de l'effondrement après le step 43 (concept drift).
- Explication de l'inefficacité de la pondération de classes.
- Caractère « automatisé » des transactions illicites sur la colonne 54.

### Limites générales

Un seul mois de données BigQuery (partiel) ; heuristique de change évaluée en applicabilité seulement ; un seul entraînement de Random Forest sans réglage d'hyperparamètres, au seuil de décision par défaut ; signification des features Elliptic inconnue ; dates réelles des time steps inconnues.

---

## 10. Ce qui n'a pas été fait

- Suivi d'une chaîne de transactions sur plusieurs sauts (change clustering complet) et validation de la précision de l'heuristique.
- Analyse des adresses d'inputs du groupe à 601 outputs, et des 13 transactions non testées.
- Réentraînement sur les steps 1 à 42 pour tester la dérive ; ajustement du seuil de décision (`predict_proba`) ; autres modèles (SVM, k-means, DBSCAN, arbre de décision).
- Visualisation du graphe (par exemple avec `networkx`).
- Notebooks du dépôt `git-disl/EllipticPlusPlus` (référencé, non exécuté) ; tutoriel Medium sur le coefficient de Gini avec BigQuery (référencé, non réalisé) ; cours Chainalysis Academy.
- Modules ultérieurs du syllabus : Gini et Benford, centralités (degré, PageRank), coefficient de clustering, H1 Clustering, feature engineering formalisé.
- Lecture du papier original de Weber et al. pour vérifier les points marqués **[À vérifier]**.
- Éclaircir avec le professeur le sens de « Telemetry » et le livrable attendu.

---

## 11. Glossaire

- **UTXO** : output de transaction non dépensé.
- **Change** : output qui rend à l'émetteur le reliquat d'un UTXO dépensé en entier.
- **Fee** : somme des inputs moins somme des outputs, gagnée par le mineur.
- **Satoshi** : 1e-8 BTC.
- **Dust (poussière)** : output de valeur minuscule, proche du seuil minimal de relais.
- **CoinJoin / mixer** : transaction collective visant à brouiller la correspondance entre inputs et outputs (outputs de valeurs identiques).
- **UTXO flooding** : création de très nombreux petits UTXO vers peu d'adresses.
- **H1 / change heuristics** : règles statistiques pour regrouper des adresses ou repérer le change.
- **Time step (Elliptic)** : fenêtre d'environ deux semaines, de 1 à 49.
- **Precision / recall / F1** : part de vrais positifs parmi les alertes / part des vrais cas retrouvés / moyenne harmonique des deux.
- **Concept drift** : changement de la distribution des données entre entraînement et test.
- **OSINT** : renseignement de sources ouvertes.

---

## 12. Reproduire le travail

Environnement : VS Code, notebook Jupyter (`.ipynb`), Python.

```bash
pip install pandas matplotlib scikit-learn
```

Placer les trois CSV Elliptic dans le dossier du notebook. Après l'installation de scikit-learn, redémarrer le noyau du notebook. Un avertissement de PATH sur `fonttools` à l'installation est sans conséquence. Les requêtes SQL du §6 s'exécutent dans la console BigQuery (Sandbox) sans carte bancaire ; vérifier l'estimation de volume avant chaque exécution.

Graphique de la proportion d'illicite par time step :

```python
import matplotlib.pyplot as plt
illicit_ratio_per_step.plot(kind='line', marker='o', figsize=(12, 5))
plt.xlabel('Time step'); plt.ylabel('% de transactions illicites')
plt.title('Proportion de transactions illicites par time step (Elliptic Dataset)')
plt.grid(True); plt.show()
```

---

## 13. Références complètes

**Fondations et explorateurs**
- *Mastering Bitcoin*, A. Antonopoulos : `https://github.com/bitcoinbook/bitcoinbook` (chapitre 2)
- Explorateur : `https://mempool.space` ; documentation de l'API : `https://mempool.space/docs/api/rest`
- Chainalysis Academy (identifié, non utilisé) : `https://academy.chainalysis.com/`

**BigQuery**
- Console : `https://console.cloud.google.com/bigquery`
- Lab Google Cloud Skills Boost (identifié, non utilisé) : `https://www.skills.google/focuses/8486?parent=catalog`
- Quickstart officiel : `cloud.google.com/bigquery/docs/quickstarts/query-public-dataset-console`
- Tutoriel Medium (Gini sur Litecoin/Dash ; référencé, non réalisé) : `https://medium.com/@vivbellavita/explore-cryptocurrency-public-datasets-with-bigquery-1d9562691580`

**Elliptic**
- Kaggle : « Elliptic Data Set » (`kaggle.com`)
- Annonce Elliptic : `https://medium.com/elliptic/the-elliptic-data-set-opening-up-machine-learning-on-the-blockchain-e0a343d99a14`
- Extension avec notebooks (référencée, non exécutée) : `https://github.com/git-disl/EllipticPlusPlus`
- Papier : M. Weber et al., « Anti-Money Laundering in Bitcoin: Experimenting with Graph Convolutional Networks for Financial Forensics » (2019) : non relu pour ce travail, à consulter
- Dépôt GitHub communautaire évoquant un événement au step 43 : URL non conservée, source non officielle

**Telegram / OSINT**
- Flare, « Telegram and OSINT Investigations » : `https://flare.io/learn/resources/blog/telegram-investigation`
- DaVinci Forensics, guide d'investigation Telegram sur la criminalité financière : `https://davinciforensics.co.za/cybersecurity/financial-crime-telegram-investigation/`
- Article de recherche, « A Proposed High-Level Methodology on How OSINT is applied in Blockchain Investigations » : `https://www.researchgate.net/publication/379221566_A_Proposed_High-Level_Methodology_on_How_OSINT_is_applied_in_Blockchain_Investigations`
- Transforms Maltego pour Telegram : `https://github.com/vognik/maltego-telegram`
- Répertoire d'outils OSINT Telegram : `https://github.com/The-Osint-Toolbox/Telegram-OSINT`