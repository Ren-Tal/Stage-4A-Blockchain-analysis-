# Deep learning for Bitcoin transaction and address classification

Can deep learning classify Bitcoin transactions and addresses better than tree models? Two weeks of experiments on Elliptic, BABD-13 and a transaction graph built from raw BABD data say no: what helps is information from the transaction graph, and tree models use it as well as graph neural networks once it is given to them as features.

## Context

This is the deep-learning part of an internship project on Bitcoin blockchain analysis. The professor's directive (26 October 2026) was to try deep learning to classify transactions and addresses, choosing the approaches and datasets ourselves, and to relate the results to the dark-web work done earlier on the Venom dataset.

Research questions:

1. Do neural networks (MLP, GCN, GraphSAGE) beat tree models (Random Forest, XGBoost) on standard Bitcoin classification benchmarks?
2. Does the transaction graph add information beyond each transaction's or address's own features?
3. How much do the usual evaluation protocols (random splits, the published test sets) overstate the scores?
4. Can labelled data be used to say something about the Bitcoin addresses found on dark-web sites (Venom)?

## Data

| Data | Source | Size used | Content | Labels |
|---|---|---|---|---|
| Elliptic | [Kaggle](https://www.kaggle.com/datasets/ellipticco/elliptic-data-set), Weber et al. 2019 | 203,769 transactions, 234,355 edges, 166 features, 49 time steps | anonymized transaction graph | 4,545 illicit, 42,019 licit, rest unknown |
| BABD-13 | [Kaggle](https://www.kaggle.com/datasets/lemonx/babd13), Xiang et al. 2022 | 544,462 addresses, 148 features (`BABD-13.csv`, 785 MB) | address behaviour statistics | 13 classes |
| BABD transaction window | same Kaggle archive (`BABD.zip`, 5.3 GB, 22.4 GB uncompressed) | 264,841 JSON files, 13,093,228 transactions | raw explorer API pages (BTC.com format) for blocks 600,000 to 605,999 | none (joined to BABD-13) |
| Venom | [authors' page](https://www.ida.liu.se/~nikca89/papers/venom.html), Ingemarsson et al. 2025 | 4,382 addresses; full histories of 8 address sets (Blockstream Esplora API) | Bitcoin addresses found on onion sites | none |

Notes on the data:

- **BABD-13 label table.** The `label` column holds the 13 classes as numbers 0 to 12. Their names follow the paper's Table I; the mapping was inferred from the class counts, which match the paper one to one. The `SW` column (strong or weak label) is metadata about the label's origin and was never used as a feature.
- **The BABD archive does not contain ready-made graphs.** Besides `BABD-13.csv`, it holds one folder per block and one file per page of 50 transactions. File names are offset from page numbers (`39_1.json` holds page 10), but a check on block 600,000 found all 39 pages and all 1,925 transactions.
- **Real-CATS was set aside.** The Kaggle copy downloaded (`archive.zip`, 12 GB, 77.6 GB uncompressed) holds only Ethereum transaction records (`ETHdata`, `Sup-CATS-Txs`) and no Bitcoin address profiles. Whether the Ethereum part is of interest is an open question to the professor.

## Methodology

### Common evaluation protocol

- Every neural model is compared with a tree-based baseline trained on the same split and the same features.
- Class imbalance is handled with class weights in every model.
- Models are judged on the rare classes, not on accuracy: precision, recall and F1 on the illicit class and PR AUC for Elliptic; accuracy, macro F1 and weighted F1 for BABD.
- Neural results are single runs with seed 42 unless three seeds are stated.

### Week 1, step 1: Elliptic, MLP against Random Forest

- **Split:** temporal, as in Weber et al.: time steps 1 to 34 for training (29,894 labelled transactions, 11.6% illicit), 35 to 49 for testing (16,670, 6.5% illicit). A random split would mix the same weeks into training and test.
- **Scaling:** `StandardScaler` fitted on the training period only, so no statistics from the test period leak into training.
- **Models:** Random Forest (200 trees) and an MLP (165-64-32-1, ReLU, `BCEWithLogitsLoss` with `pos_weight` about 7.6, Adam, 300 full-batch epochs).
- **Regularized MLP:** steps 30 to 34 held out for validation, early stopping on validation PR AUC, dropout 0.2, weight decay, threshold chosen on validation.

### Week 1, step 2: Elliptic, graph neural networks

- **Graph:** all 203,769 transactions (labelled or not) with the 234,355 payment flows in both directions. Loss on training nodes only, evaluation on test nodes only.
- **Leakage check:** no edge crosses time steps (0 of 234,355), so message passing never brings test-period information into training nodes.
- **Models:** GCN and GraphSAGE, two layers of 64 units, dropout 0.2, same class weighting and threshold as the plain MLP, 300 epochs.

### Week 1, step 3: BABD-13 from the address features

- **Split:** stratified random 80/20 (435,569 / 108,893 addresses), as in the paper; the file has no time column.
- **Models:** XGBoost (300 trees, depth 8) and an MLP (148-256-128-13, dropout 0.2) with a sign-log transform `sign(x)·log(1+|x|)`, standardization, mini-batches of 1,024, square-root balanced class weights, and the best of 30 epochs on a 10% validation set.
- **Metrics:** macro F1 is also reported over the 10 classes that remain after removing government blacklist, money laundering and Ponzi (5, 3 and 3 test addresses).

### Week 2, step 4: building the BABD transaction graph

- **Sample check:** 100 blocks (one in 60) contained 7,120 BABD-labelled addresses, enough to justify a full scan.
- **Full scan:** one pass over the 264,841 files (10.6 minutes) read 13,093,228 transactions and kept the 358,784 that touch a labelled address. 94,966 labelled addresses appear in the window.
- **Graph:** nodes are the labelled addresses with their 148 features. Two addresses are linked when one pays the other in a transaction (payment link) or both are spent as inputs of the same transaction (co-spend link, the H1 common-input heuristic). Consolidations with many labelled inputs are linked as a star on the first input, to avoid millions of pairs.

### Week 2, step 5: label quality checks

- **Duplicates:** 1,706 addresses appear more than once in `BABD-13.csv`, and 1,414 of them carry contradictory labels. These were removed, leaving 540,954 addresses with a single label.
- **Labels follow H1 clusters:** co-spend clusters were computed as connected components of the co-spend links, and the share of clusters carrying a single label was measured.

### Week 2, step 6: entity split against random split

- Because labels follow co-spend clusters, a random split lets a graph model copy a test address's label from its co-spend neighbours in training.
- **Entity split:** whole co-spend clusters go to training or test (`StratifiedGroupKFold`, 5 folds, first fold whose test part does not contain the giant cluster). 82,269 training and 12,578 test addresses, 0 clusters shared.
- **Random split:** stratified, same test size, for comparison.
- **Classes:** the 10 classes with at least 20 addresses in the window (94,847 addresses).

### Week 2, step 7: models on the graph

- XGBoost on the 148 features.
- XGBoost on the 148 features plus the mean of each address's neighbours' (sign-log) features and its degree (297 features).
- MLP and GraphSAGE, two layers of 128 units, dropout 0.2, square-root class weights, 300 full-batch epochs; three seeds (0, 1, 2) on the entity split.

### Week 2, step 8: Venom application

- Lookup of the 4,382 Venom addresses in the BABD-13 label table.
- Lookup of the 58,544 counterparties of the 8 Venom address sets (from their full Esplora histories), and the role of each exchange-labelled counterparty in each transaction: payee, payer, co-spent input or co-recipient.
- A model-based application was not done: a BABD-trained model needs the 148 BABD features, which cannot be reproduced for Venom addresses without reimplementing the BABD feature code.

## Results

### Elliptic: transactions (test steps 35 to 49, 1,083 illicit)

| Model | Precision | Recall | F1 | PR AUC | False alarms |
|---|---|---|---|---|---|
| Random Forest | 0.963 | 0.723 | **0.826** | **0.793** | 30 |
| GraphSAGE | 0.806 | 0.584 | 0.678 | 0.640 | 152 |
| GCN | 0.788 | 0.528 | 0.632 | 0.649 | 154 |
| MLP | 0.599 | 0.536 | 0.565 | 0.528 | 389 |
| MLP + validation, early stopping, dropout | 0.421 | 0.513 | 0.463 | 0.291 | 764 |

- The GCN reproduces Weber et al. (F1 0.632 against 0.628 in the paper).
- The graph networks beat the MLP mainly through precision: false alarms drop from 389 to about 150.
- The regularized MLP reached validation PR AUC 0.864 but test PR AUC 0.291: the recent past did not represent the later test period.
- **Drift after the dark-market shutdown (step 43).** Recall on steps 35 to 42 against 43 to 49:

| Model | Recall, steps 35–42 | Recall, steps 43–49 |
|---|---|---|
| Random Forest | 0.853 | 0.018 |
| GraphSAGE | 0.690 | 0.012 |
| MLP | 0.633 | 0.006 |
| GCN | 0.625 | 0.006 |

### BABD-13: addresses from their features (random 80/20 split)

| Model | Accuracy | Macro F1 (13 classes) | Macro F1 (10 classes) | Weighted F1 |
|---|---|---|---|---|
| XGBoost | **0.970** | **0.662** | **0.832** | **0.969** |
| MLP | 0.921 | 0.604 | 0.732 | 0.922 |

XGBoost reproduces the paper's best model (accuracy 0.967, weighted F1 0.966 in Xiang et al.). The weakest classes for both models are individual wallet (XGBoost F1 0.07) and blackmail (0.59).

### BABD transaction graph

| Property | Value |
|---|---|
| Labelled addresses (nodes) | 94,851 |
| Undirected edges | 287,596 (267,942 co-spend links, 25,473 payment links) |
| Isolated addresses | 23,446 (24.7%) |
| Largest connected component | 68,991 addresses (73%) |
| Edges joining two addresses of the same class | 98.0% (co-spend 98.5%, payment 93.5%) |
| Co-spend clusters with 2+ addresses carrying a single label | 99.3% of 764 |
| Largest co-spend cluster | 37,178 addresses (39.2%), all but 6 labelled exchange |

The 99.3% purity is strong evidence that BABD-13's labels were assigned per co-spend cluster; the paper takes most labels from WalletExplorer, which labels whole clusters.

### BABD-13 on unseen entities

| Model | Accuracy, entity | Macro F1, entity | Accuracy, random | Macro F1, random |
|---|---|---|---|---|
| XGBoost + neighbour features | **0.945** | **0.821** | **0.992** | **0.857** |
| GraphSAGE (3 seeds) | 0.936 ± 0.004 | 0.691 ± 0.046 | 0.982 (1 seed) | 0.804 (1 seed) |
| XGBoost | 0.915 | 0.747 | 0.985 | 0.817 |
| MLP (3 seeds) | 0.843 ± 0.003 | 0.593 ± 0.014 | 0.950 (1 seed) | 0.699 (1 seed) |

- **Neighbour information is what helps:** it lifts XGBoost by 3 accuracy points and the neural model by 9 (MLP against GraphSAGE). With neighbour features, XGBoost is best on every metric.
- **The random split adds 4 to 11 accuracy points** to every model, because addresses of one entity end up on both sides.
- GraphSAGE beats plain XGBoost on the large classes (cyber-security service F1 0.917 against 0.829, gambling 0.959 against 0.920) and loses on the small ones (tumbler 0.357 against 0.688, with 47 test addresses).
- Darknet-market addresses generalize well to unseen markets for every model (F1 0.91 to 0.97).

### Venom application

| Check | Result |
|---|---|
| Venom addresses labelled in BABD-13 | 2 of 4,382 (one blackmail, one cyber-security service), none in the 8 sets |
| Counterparties of the 8 sets labelled in BABD-13 | 91 of 58,544: 85 exchanges, 4 blackmail, 2 cyber-security |
| Sets with no labelled counterparty | 3 of 8 |
| `cluster_25`: transactions including an exchange-labelled address | 358 of 2,315 |
| `cluster_25`: co-spent with exchange addresses | 119 transactions (about 37% of the 319 that spend its address) |
| `cluster_25`: pays an exchange / paid by an exchange | 3 / 0 |

Under the common-input heuristic, the address shown on the onion sites of `cluster_25` is most likely inside an exchange's wallet (for example a deposit address that the exchange sweeps with others). This is a hypothesis: the exchange labels date from 2019–2021, while the set is active from 2018 to 2026.

## Repository structure

```
ML and DL/
├── 3_deep_learning.ipynb      # TODO: confirm which notebook holds the week-2 cells
├── README.md
└── data/                      # git-ignored
    └── babd/
        ├── BABD-13.csv
        ├── window_activity.pkl    # per-address activity in the 6,000 blocks (scan output)
        └── window_edges.pkl       # links between labelled addresses (scan output)
../elliptic/                   # Elliptic CSV files (git-ignored)
../Venom/                      # Venom notebooks, data/selected_clusters.pkl, data/raw/ (git-ignored)
```

The BABD and Real-CATS zip archives are kept outside the repository.

## How to reproduce

**Environment**

- Python 3.14, PyTorch 2.15 with CUDA 13.2, PyTorch Geometric 2.8.1, scikit-learn, XGBoost, pandas, numpy, scipy, networkx. TODO: add a `requirements.txt` with exact versions.
- GPU optional: every model runs on a CPU, more slowly. The experiments used an NVIDIA RTX 3050 laptop GPU with 6 GB of memory, enough for full-batch training on both graphs.
- PyTorch with CUDA: install the build matching your driver from the selector on pytorch.org, for example:

```bash
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu132
pip install torch_geometric xgboost scikit-learn pandas numpy scipy networkx
```

On Windows, uninstall a CPU build first (`pip uninstall torch torchvision`), because pip otherwise keeps it.

**Data**

1. Elliptic: download from Kaggle and place the three CSV files in `../elliptic/`.
2. BABD: download the BABD archive from Kaggle, then extract only `BABD-13.csv` into `data/babd/`. The week-2 scan reads the JSON files directly from the zip, so the 22.4 GB archive never needs to be extracted.
3. Venom: the summary CSV and the 8 sets' raw histories come from the Venom part of the repository.

**Order**

1. Elliptic cells (data, MLP and Random Forest, regularized MLP, GNNs).
2. BABD-13 feature cells (XGBoost, MLP).
3. BABD window scan (about 11 minutes; saves `window_activity.pkl` and `window_edges.pkl`).
4. Label cleaning, graph, co-spend clusters, splits.
5. XGBoost with and without neighbour features, MLP and GraphSAGE, seeds.
6. Venom overlap and counterparty analysis.

## Limitations and next steps

**Limitations**

- The BABD graph covers one window of 6,000 blocks (late 2019) and 17% of BABD's labelled addresses; links through unlabelled addresses are not in the graph.
- The neural models were barely tuned (one architecture each, fixed learning rate), and only the BABD entity split has three seeds.
- The entity split approximates entities by co-spend clusters; the giant exchange cluster is always in training, and four classes have 4 to 47 test addresses, so macro F1 is noisy.
- The week-1 BABD-13 split may contain the 528 exact duplicate rows on both sides.
- The Venom analysis rests on 91 labelled counterparties, labels from 2019–2021, and the common-input heuristic.

**Next steps**

- Repeat the Elliptic neural runs with several seeds.
- Extend the BABD graph to more blocks, and include unlabelled intermediate addresses.
- Decide with the professor whether the Ethereum part of Real-CATS is worth using.

## References

- M. Weber et al., *Anti-Money Laundering in Bitcoin: Experimenting with Graph Convolutional Networks for Financial Forensics*, KDD Workshop on Anomaly Detection in Finance, 2019. [arXiv:1908.02591](https://arxiv.org/abs/1908.02591)
- Y. Xiang et al., *BABD: A Bitcoin Address Behavior Dataset for Pattern Analysis*, IEEE TIFS, 2023. [arXiv:2204.05746](https://arxiv.org/abs/2204.05746)
- Z. Huang et al., *Demystifying Bitcoin Address Behavior via Graph Neural Networks*, 2022. [arXiv:2211.14582](https://arxiv.org/abs/2211.14582)
- L. Ingemarsson, K. Duckert Karlsson, N. Carlsson, *Using Venom to Flip the Coin and Peel the Onion: Measurement Tool and Dataset for Studying the Bitcoin – Dark Web Synergy*, ACM CODASPY, 2025. [DOI 10.1145/3714393.3726488](https://dl.acm.org/doi/abs/10.1145/3714393.3726488)
- S. Lee et al., *Cybercriminal Minds: An Investigative Study of Cryptocurrency Abuses in the Dark Web*, NDSS, 2019. [NDSS page](https://ndss-symposium.org/ndss-paper/cybercriminal-minds-an-investigative-study-of-cryptocurrency-abuses-in-the-dark-web)
- J. Shi et al., *Real-CATS: A Practical Training Ground for Emerging Research on Cryptocurrency Cybercrime Detection*, 2025. [arXiv:2501.15553](https://arxiv.org/abs/2501.15553)
