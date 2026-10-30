# Venom dataset: statistics (step 3) and blockchain transaction graph (step 4)

This document records, step by step, how we analysed the dataset released with the Venom paper and how we followed a selection of its Bitcoin address sets onto the blockchain. It says what was done, how, with which tools, what each result was, and what the results do and do not show. A reader who follows it should reach the same numbers and the same caveats we did.

## Contents

1. Scope and the professor's task
2. Results at a glance
3. Tools, data sources and environment
4. How to read this document (evidence labels, unit of analysis)
5. Step 3: dataset statistics
6. Step 4: blockchain data and transaction graph
7. What the data supports and what it does not
8. Limitations
9. Problems met along the way
10. Not done / open items
11. Ethics and safety
12. References

---

## 1. Scope and the professor's task

The paper is: L. O. Ingemarsson, K. D. Karlsson and N. Carlsson, *Using Venom to Flip the Coin and Peel the Onion: Measurement Tool and Dataset for Studying the Bitcoin - Dark Web Synergy*, ACM CODASPY 2025. Venom is a crawler that visits Tor onion sites, extracts Bitcoin addresses from the pages with a regular expression, asks a blockchain API how much each address received and sent, and writes a per-site CSV. The paper's snapshot was collected on 24 April 2024.

The professor asked for four things:

1. Read the paper and its main references.
2. Search for papers that cite the Venom paper.
3. Compute basic statistics using the dataset.
4. Get blockchain data for some items, compute statistics and build a transaction graph.

**This document covers tasks 3 and 4.** Tasks 1 and 2 are not written up here (section 10 gives their status).

## 2. Results at a glance

| Topic | Result |
|---|---|
| Dataset reproduction | The summary CSV reproduces the paper's headline numbers: 196,591 sites attempted, 177,127 reached, 13,154 showing at least one Bitcoin address, 2,463 with at least one transaction, 86.1% of address-bearing sites with a single address, maximum 2,028 addresses on one site. |
| Addresses | 4,382 unique addresses in the file (25,070 occurrences), equal to the paper's count of valid addresses. |
| Mirroring | The 13,154 address-bearing sites collapse into 686 distinct address sets; the 2,463 transaction-active sites into 292. The largest set appears on 1,648 sites. |
| Concentration | The top 4 sites hold 95.7% of all transactions; the top 4 address sets hold 97.5%. The paper's concentration claim survives removing mirrors. |
| Topics | Topic labels are multi-label (they sum to 123.4%). "stolen_funds" is first by sites (109,169) but sixth by distinct titles (891). |
| Paper's distribution anomalies | The steps at 7 transactions and 10.77 BTC come from one mirrored set of 1,648 sites with 3 addresses. |
| Items followed on the blockchain | 8 address sets (11 addresses), 6,047 transactions listed, 6,045 unique. |
| Dataset validation | For all 8 sets, transactions up to the snapshot date and BTC received match the dataset exactly. 882 of the 6,045 transactions (about 15%) are newer than the snapshot. |
| Graph | Bipartite address/transaction graph: 64,600 nodes (58,555 addresses, 6,045 transactions), 109,746 edges, 2 connected components. |
| Links between sets | One component contains all 8 sets. They are joined by 2 direct transactions that pay two sets at once and by 44 "bridge" addresses. The strongest pair is sets 43 and 149 (15 shared bridges). |
| Common-input clustering (H1) | Adds 6,821 addresses to the 11 seeds, but merges no two sets. |
| PageRank | Correlates 0.978 with in-degree and adds little beyond it, except at addresses that end huge sweep transactions. |

## 3. Tools, data sources and environment

**Data**
- Venom summary CSV: `https://www.ida.liu.se/~nikca89/papers/venom-dataset-summary.csv`. It is linked from the paper's page, `https://www.ida.liu.se/~nikca89/papers/venom.html`, whose address is given in the paper's conclusion.
- Venom tool (not run by us): `https://github.com/LukasIngemarsson/venom`.
- Blockchain data: the Esplora HTTP API run by Blockstream, `https://blockstream.info/api/`. Documentation: `https://github.com/Blockstream/esplora/blob/master/API.md`.

**Software**
- Python 3 in VS Code Jupyter notebooks (Windows). Package versions were not recorded.
- `pandas`, `numpy`, `matplotlib` for tables and figures.
- `requests` for the API.
- `networkx` for the graph (installed with `%pip install networkx`), with `scipy` for PageRank.
- Gephi (optional) for viewing the exported graph.
- Standard library: `ast`, `json`, `glob`, `os`, `time`, `itertools`, `collections`.

**Notebooks and files** (the `data/` folder is git-ignored because it holds addresses)

| File | Content |
|---|---|
| Notebook 1 (Venom statistics) | Step 3 and the selection of address sets |
| `2_fetch_blockchain.ipynb` | Download, parsing, graph and graph analysis |
| `venom-dataset-summary.csv` | The downloaded dataset (git-ignored) |
| `data/selected_clusters.pkl` | The 8 selected sets, written by notebook 1 and read by notebook 2 |
| `data/raw/c{set}_a{index}.json` | One file per address: its confirmed transactions as returned by the API |
| `data/graph_full.gexf`, `data/bridges_subgraph.gexf` | Anonymised graph exports |
| `sets_graph.png`, `sets_matrix.png` | Figures safe to publish |

Dates: the blockchain data was downloaded in mid-October 2026 (the latest transactions in the per-set summary in 6.12 are from early October 2026). The exact CSV download date was not recorded; note it in your own copy.

## 4. How to read this document

**Evidence labels**
- **[Measured]**: a result of a computation we ran.
- **[Hypothesis]**: a plausible reading the data does not prove.
- **[To verify]**: information taken from outside our own computations and not yet checked at its source.

**Unit of analysis.** Many sites in the file are copies of each other. Counting per site therefore counts the same service many times. We call an **address set** (also "cluster" or "set") the exact list of Bitcoin addresses shown by a site. All sites with the same list belong to the same address set. Statistics are given per site and per address set when the difference matters. An address set is a convenience for counting, not proof of a single owner.

**Privacy rule used throughout.** Results are described with counts, set numbers (`cluster_id`) and topic labels only. No Bitcoin address, onion address or site title appears in this document, and the code prints none.

---

## 5. Step 3: dataset statistics

### 5.1 The file

- Separator `;`, decimal comma (so `1,3212817` means 1.3212817).
- Columns: `onion_addr`, `title`, `topic`, `btc_addrs`, `btc_addrs_count`, `total_sent`, `total_received`, `n_tx`, `comment`.
- `btc_addrs` is text that looks like a Python list (`['…']`, or `[]`).
- `topic` can hold several labels separated by `, `. The labels come from keywords in the page title, so they are noisy.
- A failed visit has empty `title` and `topic`; `comment` holds the reason (for example a connection error).
- `total_sent`, `total_received` and `n_tx` are sums over **all addresses of the site** and date from the crawl (April 2024).

### 5.2 Load and first check

```python
import pandas as pd
df = pd.read_csv("venom-dataset-summary.csv", sep=";", decimal=",")
print(df.shape)                      # (196591, 9)
print(df["comment"].notna().sum())   # 19464 failed visits
```

[Measured] 196,591 rows and 19,464 failed visits, so 177,127 sites were reached. This matches the paper.

### 5.3 Reproducing the paper's headline numbers

```python
ok = df[df["comment"].isna()]
print(len(ok))                                       # 177,127
with_addr = ok[ok["btc_addrs_count"] > 0]
print(len(with_addr))                                # 13,154 (7.4 %)
print((with_addr["n_tx"] > 0).sum())                 # 2,463
print((with_addr["btc_addrs_count"] == 1).sum())     # 11,328 (86.1 %)
print(with_addr["btc_addrs_count"].max())            # 2,028
```

[Measured] All five values matched the paper. This confirms we had the right file and read its columns correctly.

### 5.4 Addresses: parsing and unique counts

```python
import ast
ok = ok.copy()
ok["addr_list"] = ok["btc_addrs"].fillna("[]").apply(ast.literal_eval)
all_addrs = ok["addr_list"].explode().dropna()
print(len(all_addrs), all_addrs.nunique())       # 25070, 4382
print(all_addrs.value_counts().head(5).tolist()) # [1648, 1648, 1648, 127, 125]
```

[Measured]
- 25,070 address occurrences and 4,382 unique addresses.
- The paper reports 42,696 extracted strings, 10,210 unique and 4,382 valid, so the file contains only the addresses the API accepted.
- On average an address appears on about 5.7 sites. Three addresses each appear on 1,648 sites (about 20% of all occurrences together).

### 5.5 Mirror clusters (address sets)

```python
has_addr = ok[ok["addr_list"].str.len() > 0].copy()
has_addr["addr_key"] = has_addr["addr_list"].apply(lambda l: tuple(sorted(l)))
clusters = has_addr.groupby("addr_key").agg(
    n_sites=("onion_addr", "size"), n_tx=("n_tx", "first"),
    n_tx_values=("n_tx", "nunique"))
print(len(has_addr), len(clusters))                  # 13154, 686
print((clusters["n_tx_values"] > 1).sum())           # 0
print(clusters["n_sites"].nlargest(10).tolist())     # [1648, 127, 125, 119, 113, 109, 109, 109, 107, 106]
print((clusters["n_sites"] == 1).sum())              # 318
```

[Measured]
- 13,154 sites collapse into **686** address sets.
- 318 sets (46%) consist of a single site, but they hold only 2.4% of the sites.
- The largest set covers 1,648 sites (12.5% of address-bearing sites); the ten largest cover 2,672 (about 20%).
- Sites sharing the same addresses always report identical `n_tx`, so per-site transaction counts count the same transactions many times.

Grouping by exact address list is a first approximation: two sites with overlapping but different lists stay in different sets. 686 is therefore an upper bound on the number of distinct operators.

### 5.6 Concentration, per site and per set

```python
print((has_addr["n_tx"] > 0).sum(), (clusters["n_tx"] > 0).sum())     # 2463, 292
site_tx = has_addr["n_tx"].fillna(0).sort_values(ascending=False)
print(site_tx.head(4).sum() / site_tx.sum())                           # 0.9571
cluster_tx = clusters["n_tx"].fillna(0).sort_values(ascending=False)
print(cluster_tx.head(4).sum() / cluster_tx.sum())                     # 0.9752
top_key = clusters["n_sites"].idxmax()
sub = has_addr[has_addr["addr_key"] == top_key]
print(len(sub), sub["n_tx"].iloc[0], sub["total_received"].iloc[0], len(top_key))  # 1648 7.0 10.77 3
```

[Measured]
- The 2,463 transaction-active sites collapse into only **292** address sets.
- The top 4 sites hold 95.7% of all transactions (the paper says more than 95%); the top 4 sets hold 97.5%. The concentration is not an artefact of copied sites.
- The largest set has 1,648 sites, 7 transactions, 10.77 BTC received and 3 addresses. The paper attributes two peaks in its distributions (7 transactions and 10.77 BTC) to mirrored content, and this single set accounts for both.
- [To verify] The paper names a market mirrored on 1,648 domains. The number is the same, but we did not confirm that this set is that market.
- Not checked: the paper's second concentration claim, about the share of received BTC.

### 5.7 Topics: by site and by distinct title

```python
t = ok[["topic", "title"]].dropna(subset=["topic"]).copy()
t["topic"] = t["topic"].str.split(", ")
t = t.explode("topic")
summary = t.groupby("topic").agg(n_sites=("title", "size"),
                                 n_distinct_titles=("title", "nunique"))
summary["pct_of_reached_sites"] = (summary["n_sites"] / len(ok) * 100).round(1)
print(summary.sort_values("n_sites", ascending=False))
```

[Measured]

| Topic label | Sites | Distinct titles | % of reached sites | Sites per title |
|---|---|---|---|---|
| stolen_funds | 109,169 | 891 | 61.6 | about 122 |
| abusive_content | 30,955 | 1,991 | 17.5 | about 16 |
| market | 27,921 | 921 | 15.8 | about 30 |
| pornography | 27,254 | 2,002 | 15.4 | about 14 |
| website_list | 8,460 | 1,205 | 4.8 | about 7 |
| other | 6,751 | 2,977 | 3.8 | about 2 |
| hacking | 4,215 | 389 | 2.4 | about 11 |
| stolen_bitcoin | 3,412 | 111 | 1.9 | about 31 |
| bitcoin_generator | 257 | 61 | 0.1 | about 4 |
| bitcoin_mixer | 200 | 61 | 0.1 | about 3 |

- The first four rows match the paper's counts.
- The percentages add up to 123.4% (218,594 label assignments over 177,127 sites): topics are multi-label.
- By number of sites, stolen_funds is first; by number of distinct titles it is sixth. About 109,000 sites share 891 titles, so most of that category is copies of few stores.
- Identical titles do not prove one owner, and the labels come from title keywords, not from checked content. Treat the labels as noisy.

### 5.8 Distributions (CCDF)

The complementary cumulative distribution function (CCDF) gives, for each value x, the share of items with a value of at least x. On log-log axes a roughly straight line suggests a heavy tail. We plot each variable per site and per address set.

```python
import numpy as np, matplotlib.pyplot as plt

clusters = has_addr.groupby("addr_key").agg(
    n_sites=("onion_addr", "size"), n_addr=("btc_addrs_count", "first"),
    n_tx=("n_tx", "first"), total_received=("total_received", "first"))

def ccdf(values):
    v = np.sort(np.asarray(values))
    return v, 1.0 - np.arange(len(v)) / len(v)

panels = [
    ("Addresses", has_addr["btc_addrs_count"], clusters["n_addr"]),
    ("Transactions (>0)", has_addr.loc[has_addr["n_tx"] > 0, "n_tx"],
                          clusters.loc[clusters["n_tx"] > 0, "n_tx"]),
    ("BTC received (>0)", has_addr.loc[has_addr["total_received"] > 0, "total_received"],
                          clusters.loc[clusters["total_received"] > 0, "total_received"]),
]
fig, axes = plt.subplots(1, 3, figsize=(15, 4))
for ax, (title, site_vals, set_vals) in zip(axes, panels):
    for vals, label in [(site_vals, "per site"), (set_vals, "per address set")]:
        x, p = ccdf(vals.dropna())
        ax.loglog(x, p, label=label)
    ax.set_title(title); ax.set_xlabel("value"); ax.set_ylabel("P(X >= x)"); ax.legend()
plt.tight_layout(); plt.show()
```

Using `first` for `total_received` is valid because a check showed it is identical inside every set (`has_addr.groupby("addr_key")["total_received"].nunique().max()` printed 1).

[Measured] What the figure shows:
- **Addresses:** about 14% of sites have two or more addresses; the per-site curve then falls from about 14% to about 1% at 3 addresses. That 12-point step is the 1,648-site set (1,648 / 13,154 = 12.5%). The per-set curve has no step there.
- **Transactions:** the per-site curve stays near 1 up to 7 transactions and then falls to about 0.25, again the mirrored set. The per-set curve is smooth.
- **BTC received:** the same pattern at 10.77 BTC.
- The BTC axis reaches about 10^8 BTC, far above the 21 million cap. These totals add up flows through the same addresses, so they are volumes, not distinct money [Hypothesis, consistent with the paper's own remark about its top site].
- A straight line on a log-log CCDF does not prove a power law. We describe the tails as heavy, nothing more.

### 5.9 Step 3 conclusions

1. The summary CSV is the paper's April 2024 snapshot and reproduces its headline numbers.
2. The file holds 4,382 valid unique addresses; each appears on about 5.7 sites on average.
3. Mirroring is extreme: 13,154 sites map to 686 address sets, and 2,463 transaction-active sites to 292.
4. Activity is concentrated in a few services, also after removing mirrors.
5. Topic percentages by site overstate how many distinct services exist in a category.

---

## 6. Step 4: blockchain data and transaction graph

### 6.1 Choosing the items (address sets)

We followed address sets rather than sites so that no service counts twice. To keep the number of API requests small and avoid sensitive content, we applied these rules (the numeric limits are our own choices):

- Exclude sets whose sites carry the labels `abusive_content` or `pornography`. The paper says the first category includes child sexual abuse material, and the labels are noisy anyway. This removed 95 of the 686 sets, leaving 591.
- Keep sets with 20 to 5,000 transactions in the dataset and at most 10 addresses: 83 sets.
- From those, take the busiest set for each topic label except `other`, and add every set labelled `bitcoin_mixer`.

```python
MIN_TX, MAX_TX, MAX_ADDR = 20, 5000, 10
print(has_addr.groupby("addr_key")["total_received"].nunique().max())   # 1

topics_per_cluster = (
    has_addr.assign(topic_list=has_addr["topic"].fillna("").str.split(", "))
    .groupby("addr_key")["topic_list"]
    .apply(lambda s: sorted({t for lst in s for t in lst if t})))
cand = clusters.join(topics_per_cluster.rename("topics")).reset_index()
cand["cluster_id"] = cand.index        # id = position in the sorted grouping, reproducible for the same CSV

bad = cand["topics"].apply(lambda t: "abusive_content" in t or "pornography" in t)
cand = cand[~bad]
pool = cand[(cand["n_tx"] >= MIN_TX) & (cand["n_tx"] <= MAX_TX) & (cand["n_addr"] <= MAX_ADDR)]
print(len(cand), len(pool))            # 591 83

by_topic = pool.explode("topics").sort_values("n_tx", ascending=False)
by_topic = by_topic[by_topic["topics"].notna() & (by_topic["topics"] != "other")]
top_ids = by_topic.drop_duplicates("topics")["cluster_id"].unique()
selected = pool[pool["cluster_id"].isin(top_ids)
                | pool["topics"].apply(lambda t: "bitcoin_mixer" in t)].copy()

import os
os.makedirs("data", exist_ok=True)
selected.to_pickle("data/selected_clusters.pkl")
```

[Measured] Topic labels in the 83-set pool (multi-label): bitcoin_generator 27, stolen_funds 26, other 22, market 20, stolen_bitcoin 18, hacking 11, website_list 10, bitcoin_mixer 3. The selection is **8 sets**, numbered by `cluster_id`: 25, 43, 45, 104, 149, 157, 209 and 667 (11 addresses in total).

- Sets 45, 104 and 667 carry the `bitcoin_mixer` label, which comes from title keywords and is not a confirmed mixer.
- Picking the busiest set per topic is not a random sample. The graph describes busy services, not typical ones.
- Excluding two label groups also biases the sample; the 95 excluded sets are 14% of the sets.

### 6.2 The API and how we used it

From the Esplora documentation:
- `GET /address/:address` returns `chain_stats` with `tx_count`, `funded_txo_count`, `funded_txo_sum`, `spent_txo_count`, `spent_txo_sum`.
- `GET /address/:address/txs/chain[/:last_seen_txid]` returns the confirmed transactions, newest first, **25 per page**. To get the next page, pass the last transaction id seen.
- A transaction lists `vin` (each input carries the output it spends, in `prevout`) and `vout`, plus `fee` and `status` (`block_time`). Amounts are in satoshis.
- The documentation states no rate limit. We paused one second between requests and retried with longer waits on HTTP 429 and 5xx errors.

```python
import requests, json, time, os
BASE = "https://blockstream.info/api"
os.makedirs("data/raw", exist_ok=True)

def get_json(url, tries=5):
    for k in range(tries):
        r = requests.get(url, timeout=30)
        if r.status_code == 200:
            return r.json()
        if r.status_code == 429 or r.status_code >= 500:
            time.sleep(10 * (k + 1)); continue
        r.raise_for_status()
    raise RuntimeError("too many retries")

def fetch_all_txs(addr, cache_name):
    path = f"data/raw/{cache_name}.json"
    if os.path.exists(path):                       # never download twice
        with open(path) as f: return json.load(f)
    txs, last = [], None
    while True:
        url = f"{BASE}/address/{addr}/txs/chain" + (f"/{last}" if last else "")
        page = get_json(url)
        txs.extend(page)
        if len(page) < 25: break                   # a short page is the last page
        last = page[-1]["txid"]; time.sleep(1)
    with open(path, "w") as f: json.dump(txs, f)
    return txs
```

Cache files are named by set number and address index, so no address appears in a file name.

### 6.3 A first test, and why the counts differ

Before the full download we tested set 45 (2 addresses, 37 transactions in the dataset). Querying only its first address returned 11 transactions, not 37. The reason was our test design: the dataset's `n_tx` is summed over all addresses of the set.

[Measured] For set 45:
- The two addresses have 11 and 38 transactions (49 in total); their funded/spent output counts are 6/6 and 22/22.
- 12 of the 49 transactions are dated after the snapshot, so 37 precede it, which equals the dataset value.
- BTC received before the snapshot: 0.02902714, equal to the dataset's `total_received`.
- All 49 transactions are distinct.

The snapshot cutoff used everywhere is 25 April 2024 00:00 UTC (`snap`), since the paper dates the crawl to 24 April 2024.

### 6.4 Dry run and full download

A dry run (one request per address) counted today's transactions: 11 addresses, 6,047 transactions, 249 requests needed (25 transactions per page, plus one request when a count is an exact multiple of 25). Then the whole history of every address was downloaded and compared with the dataset.

```python
snap = pd.Timestamp("2024-04-25", tz="UTC").timestamp()
report = []
for _, c in selected.iterrows():
    before = recv_before = n_total = 0
    for i, a in enumerate(c["addr_key"]):
        txs_a = fetch_all_txs(a, f"c{c['cluster_id']}_a{i}")
        n_total += len(txs_a)
        for t in txs_a:
            if (t["status"].get("block_time") or 0) <= snap:
                before += 1
                recv_before += sum(o["value"] for o in t["vout"]
                                   if o.get("scriptpubkey_address") == a)
    report.append({"cluster_id": c["cluster_id"], "n_tx_dataset": c["n_tx"],
                   "n_before": before, "n_total": n_total,
                   "recv_dataset": c["total_received"], "recv_before": recv_before / 1e8})
rep = pd.DataFrame(report)
```

[Measured]

| Set | Dataset n_tx | Before snapshot | Today | New since snapshot | BTC received, dataset | BTC received before snapshot |
|---|---|---|---|---|---|---|
| 25 | 2,118 | 2,118 | 2,315 | +197 (9%) | 428.570773 | 428.570773 |
| 43 | 89 | 89 | 103 | +14 (16%) | 0.121478 | 0.121478 |
| 45 | 37 | 37 | 49 | +12 (32%) | 0.029027 | 0.029027 |
| 104 | 253 | 253 | 268 | +15 (6%) | 37.648299 | 37.648299 |
| 149 | 262 | 262 | 293 | +31 (12%) | 0.357399 | 0.357399 |
| 157 | 304 | 304 | 304 | 0 | 1.339006 | 1.339006 |
| 209 | 1,645 | 1,645 | 1,955 | +310 (19%) | 15.845226 | 15.845226 |
| 667 | 456 | 456 | 760 | +304 (67%) | 0.822595 | 0.822595 |

- The dataset's transaction counts and received totals are reproduced for **all 8 sets**, so its per-set numbers are reliable and snapshot-dated.
- 883 transactions were added after the snapshot by the per-set count (882 unique, because one is shared by two sets, see 6.5).
- Every analysis below uses today's data. The flag `after_snap` lets one restrict to the snapshot period.

### 6.5 Parsing into tables

The raw files hold one nested object per transaction. We flattened them into a transaction table (`txs`) and a flow table (`flows`, one row per input or output), keeping each transaction once.

```python
import glob
seed_to_cluster = {a: c["cluster_id"] for _, c in selected.iterrows() for a in c["addr_key"]}
tx_rows, flow_rows, seen = [], [], set()
for path in sorted(glob.glob("data/raw/c*_a*.json")):
    with open(path) as f:
        for t in json.load(f):
            if t["txid"] in seen: continue
            seen.add(t["txid"])
            tx_rows.append({"txid": t["txid"], "block_time": t["status"].get("block_time"),
                            "fee": t["fee"], "n_in": len(t["vin"]), "n_out": len(t["vout"])})
            for v in t["vin"]:
                p = v.get("prevout") or {}
                flow_rows.append({"txid": t["txid"], "side": "in",
                                  "addr": p.get("scriptpubkey_address"), "value": p.get("value")})
            for o in t["vout"]:
                flow_rows.append({"txid": t["txid"], "side": "out",
                                  "addr": o.get("scriptpubkey_address"), "value": o.get("value")})
txs = pd.DataFrame(tx_rows); flows = pd.DataFrame(flow_rows)
flows["cluster_id"] = flows["addr"].map(seed_to_cluster)   # filled only for seed addresses
txs["after_snap"] = txs["block_time"] > snap
touch = flows.dropna(subset=["cluster_id"]).groupby("txid")["cluster_id"].nunique()
```

[Measured]
- 6,045 unique transactions (6,047 downloaded: two appear in two sets' files).
- 141,427 flow rows, 3 of them without an address (outputs that pay no address).
- 882 transactions are newer than the snapshot.
- 58,555 distinct addresses (11 seeds plus their counterparties).
- Exactly **2 transactions touch seeds of two different sets**, and in neither case does a seed appear among the inputs:
  - 1 input and 19 outputs, paying sets 104 and 667 (fee 10,200 sat, 3 June 2024);
  - 1 input and 9 outputs, paying sets 43 and 149 (fee 5,170 sat, 31 January 2023).
- No transaction is shared inside a set: the unique transactions per set equal the per-set totals above.

Because a transaction was downloaded only if it touches a seed, **this is a one-hop view**: for any other address we only see its transactions with our seeds.

### 6.6 Transaction sizes

[Measured] Inputs plus outputs per transaction: median 5, mean 23.4, 25th percentile 3, 75th percentile 9, maximum 1,185. The ten largest are 1,185, 650, 645, 637, 609, 559, 541, 532, 520 and 502. The largest 1% of transactions (60) account for 16.5% of all rows. That is below the 30% level at which we would have capped them, so all transactions were kept.

### 6.7 Choosing the graph representation

Two designs were possible:
- **Address-to-address projection:** a transaction with n inputs and m outputs becomes n x m edges.
- **Bipartite graph:** address nodes and transaction nodes; an input is an edge from address to transaction, an output an edge from transaction to address.

[Measured] The projection would have 3,399,535 edges (the sum of n_in x n_out over the transactions), about 24 times the 141,424 rows of the bipartite graph. The five largest transactions contribute 39,576, 21,186, 21,120, 21,006 and 20,900 edges (3.6% of the total), so the explosion is spread over many transactions and capping a few would not help. We built the **bipartite directed graph**.

Its limit: the usual clustering coefficient (based on triangles) is always 0 on a bipartite graph, so it needs a projection restricted to a small subset. We did not compute it (section 10).

### 6.8 Building the graph

Repeated address-transaction pairs are merged into one edge whose `value` is the summed satoshis. Node names are anonymised (`A0`, `T0`, …).

```python
import networkx as nx
fl = flows.dropna(subset=["addr", "value"]).copy()
agg = fl.groupby(["txid", "side", "addr"], as_index=False)["value"].sum()
addr_id = {a: f"A{i}" for i, a in enumerate(agg["addr"].unique())}
tx_id = {t: f"T{i}" for i, t in enumerate(txs["txid"])}

G = nx.DiGraph()
for t, r in txs.set_index("txid").iterrows():
    G.add_node(tx_id[t], kind="tx", after_snap=bool(r["after_snap"]))
for a, nid in addr_id.items():
    G.add_node(nid, kind="addr", cluster=int(seed_to_cluster.get(a, -1)))   # -1 = not a seed
for r in agg.itertuples():
    if r.side == "in": G.add_edge(addr_id[r.addr], tx_id[r.txid], value=int(r.value))
    else:              G.add_edge(tx_id[r.txid], addr_id[r.addr], value=int(r.value))
```

[Measured]
- **64,600 nodes** (58,555 addresses, 6,045 transactions) and **109,746 edges**.
- The 141,424 usable rows became 109,746 edges: 7,485 edges (6.8%) merge several rows, together holding 39,163 rows (about 28%). The largest merge is 469 rows into one edge, followed by four of 201.
- [Hypothesis] The large merges come from sweeps and from flooding-style transactions with many outputs to few addresses, as we saw in an earlier BigQuery analysis. We did not inspect the transactions behind them.
- Merging loses the number of original inputs or outputs behind an edge. It is not stored as an edge attribute.

### 6.9 Components and degrees

```python
comps = sorted(nx.weakly_connected_components(G), key=len, reverse=True)
for c in comps:
    seeds = sorted({G.nodes[n]["cluster"] for n in c
                    if G.nodes[n]["kind"] == "addr" and G.nodes[n]["cluster"] >= 0})
    print(len(c), seeds)

addr_nodes = [n for n, d in G.nodes(data=True) if d["kind"] == "addr"]
deg = pd.Series({n: G.degree(n) for n in addr_nodes})
```

[Measured]
- **2 weakly connected components**: one with 64,571 nodes containing all 8 sets, and one with 29 nodes containing only set 25.
- Every downloaded transaction touches a seed, so each component has at least one seed. The 8 sets being in one component means they are connected through shared counterparties.
- Address degree: mean 1.87, median 1, maximum 2,001; **89.7% of addresses have degree 1**.
- The three highest degrees belong to seeds: set 25 (2,001), set 209 (1,955) and set 667 (760); for 209 and 667 this equals their transaction count. The next seven addresses are non-seeds with 373 to 500 edges.
- For non-seed addresses, degree is a lower bound (we only see their transactions with seeds). Degree-based measures are meaningful for the 11 seeds and weaker for the rest.

### 6.10 Bridge addresses

A **bridge address** is a non-seed address whose transactions reach seeds of two or more different sets. Transactions that already touch two sets (the 2 direct links above) are skipped, so their co-recipients do not count as bridges.

```python
tx_nodes = [n for n, d in G.nodes(data=True) if d["kind"] == "tx"]
tx_sets = {}
for t in tx_nodes:
    nb = set(G.predecessors(t)) | set(G.successors(t))
    tx_sets[t] = {G.nodes[a]["cluster"] for a in nb if G.nodes[a]["cluster"] >= 0}

bridge = {}
for a in addr_nodes:
    if G.nodes[a]["cluster"] >= 0: continue
    reach = set()
    for t in set(G.predecessors(a)) | set(G.successors(a)):
        if len(tx_sets[t]) == 1: reach |= tx_sets[t]
    if len(reach) >= 2: bridge[a] = reach
```

[Measured]
- **44 bridge addresses** (0.075% of all addresses): 40 reach 2 sets, 3 reach 3 sets, 1 reaches 4.
- Together with the 2 direct transactions, these 46 items are all that joins the 8 sets at the one-hop level.
- The top bridge has 80 edges and reaches sets 43, 45, 149 and 667. The next ones reach [43, 149] (55 edges), [25, 43] (41), [43, 149] (20), [149, 157] (19)…
- Bridges are a lower bound on connectivity: two sets could also be linked beyond the one hop we collected.

Shared bridges per pair of sets (a bridge reaching three sets counts once in each of its three pairs; the 44 bridges give 55 pair counts):

| | 25 | 43 | 45 | 104 | 149 | 157 | 209 | 667 |
|---|---|---|---|---|---|---|---|---|
| **25** | 0 | 1 | 0 | 0 | 1 | 1 | 7 | 0 |
| **43** | 1 | 0 | 1 | 2 | 15 | 1 | 0 | 2 |
| **45** | 0 | 1 | 0 | 0 | 2 | 0 | 0 | 1 |
| **104** | 0 | 2 | 0 | 0 | 2 | 2 | 1 | 0 |
| **149** | 1 | 15 | 2 | 2 | 0 | 8 | 1 | 5 |
| **157** | 1 | 1 | 0 | 2 | 8 | 0 | 1 | 0 |
| **209** | 7 | 0 | 0 | 1 | 1 | 1 | 0 | 1 |
| **667** | 0 | 2 | 1 | 0 | 5 | 0 | 1 | 0 |

[Measured]
- 19 of the 28 possible pairs share at least one bridge, but most share only 1 or 2. The four strongest pairs (43-149 with 15, 149-157 with 8, 25-209 with 7, 149-667 with 5) hold 35 of the 55 pair counts (64%).
- Set 149 shares at least one bridge with each of the other seven sets (row total 34); set 43 comes next (22).
- Sets 25 and 209 are the largest by transactions yet link mostly to each other (7 bridges) and only weakly to the rest.
- Sets 104 and 667 share no bridge; their only link is the 19-output transaction. The pair 43-149 has both bridges and a direct transaction.
- 8 pairs have neither a bridge nor a direct transaction (25-45, 25-104, 25-667, 43-209, 45-104, 45-157, 45-209, 157-667).
- We did not compare these counts with a random baseline. Larger sets have more counterparties, so some overlap arises by chance. Read the pattern as an impression, not a tested effect.

### 6.11 What role do the bridges play?

For each bridge, each transaction it takes part in was classified by who else is in it:
- **funds_seed:** the bridge is an input and a seed is among the outputs;
- **paid_by_seed:** the bridge is an output and a seed is among the inputs;
- **co_input:** the bridge is an input together with a seed;
- **co_output:** the bridge is an output together with a seed.

```python
seed_nodes = {n for n in addr_nodes if G.nodes[n]["cluster"] >= 0}
has_seed = lambda nodes: any(n in seed_nodes for n in nodes)
roles = {}
for a in bridge:
    r = dict(funds_seed=0, co_input=0, paid_by_seed=0, co_output=0)
    for t in G.successors(a):                 # a is an input of t
        r["funds_seed"] += has_seed(G.successors(t));  r["co_input"] += has_seed(G.predecessors(t))
    for t in G.predecessors(a):               # a is an output of t
        r["paid_by_seed"] += has_seed(G.predecessors(t)); r["co_output"] += has_seed(G.successors(t))
    roles[a] = r
roles_df = pd.DataFrame(roles).T
print(roles_df.sum()); print((roles_df > 0).sum())
```

[Measured]

| Role | Bridges (of 44) | Transactions |
|---|---|---|
| co_output (paid in the same transaction as a seed) | 36 | 117 |
| funds_seed | 15 | 119 |
| paid_by_seed | 6 | 94 |
| co_input (spent together with a seed) | 3 | 31 |

A bridge can play several roles, so the rows overlap.

- **Co-input bridges (3).** Two are spent only with seeds of set 157 and one only with seeds of set 25, in transactions with 3 to 27, 5 to 18 and 16 inputs and 1 to 2 outputs. None is spent together with seeds of two different sets, so the common-input heuristic ties these bridges to one set each and links no two sets.
- **Destination bridges (6).** All six are paid only by seeds of sets 43 and 149, receiving 94 payments in total (20, 55, 3, 8, 6 and 2); two addresses hold 75 of them (80%).
- **Co-output** is by far the commonest role: one sender paying both a seed and the bridge, which is weak evidence of any link.

### 6.12 Summary per set

```python
rows = []
for cid in sorted(int(x) for x in selected["cluster_id"]):
    mine = fl[fl["cluster_id"] == cid]
    tids = set(mine["txid"]); sub = txs[txs["txid"].isin(tids)]
    others = fl[fl["txid"].isin(tids) & fl["cluster_id"].isna()]
    rows.append({"set": cid, "n_tx": len(tids),
        "first": pd.to_datetime(sub["block_time"].min(), unit="s", utc=True).date(),
        "last": pd.to_datetime(sub["block_time"].max(), unit="s", utc=True).date(),
        "recv_btc": round(mine.loc[mine["side"] == "out", "value"].sum() / 1e8, 4),
        "sent_btc": round(mine.loc[mine["side"] == "in", "value"].sum() / 1e8, 4),
        "median_fee": int(sub["fee"].median()),
        "counterparties": others["addr"].nunique()})
summary = pd.DataFrame(rows).set_index("set")
```

[Measured] (BTC totals cover all dates, so they exceed the dataset's snapshot-dated totals by what arrived later)

| Set | Transactions | First | Last | Received (BTC) | Sent (BTC) | Median fee (sat) | Counterparties |
|---|---|---|---|---|---|---|---|
| 25 | 2,315 | 2018-01-08 | 2026-01-14 | 429.6823 | 429.6823 | 110,000 | 34,813 |
| 43 | 103 | 2021-02-07 | 2026-02-04 | 0.1335 | 0.1335 | 4,388 | 1,663 |
| 45 | 49 | 2021-11-27 | 2025-04-05 | 0.0309 | 0.0309 | 2,530 | 827 |
| 104 | 268 | 2016-06-09 | 2026-09-02 | 37.6535 | 37.6535 | 5,470 | 6,202 |
| 149 | 293 | 2020-09-30 | 2026-06-26 | 0.3673 | 0.3649 | 5,275 | 5,972 |
| 157 | 304 | 2018-07-21 | 2022-03-04 | 1.3390 | 1.3390 | 12,600 | 2,259 |
| 209 | 1,955 | 2020-07-07 | 2026-10-06 | 15.9038 | 15.7739 | 4,000 | 2,820 |
| 667 | 760 | 2023-02-16 | 2026-08-02 | 1.4798 | 1.4798 | 4,230 | 4,062 |

- Six sets have sent out everything they received (equal totals at four decimals). Set 149 holds about 0.0024 BTC and set 209 about 0.1299 BTC (our subtraction; unconfirmed transactions ignored).
- Set 157's last transaction is from 4 March 2022, more than two years before the crawl, although a site still showed its address in April 2024. [Hypothesis] The address may be abandoned.
- Set 25 accounts for 34,813 of the 58,555 addresses (about 59%), so it shapes most graph statistics.
- Set 25's median fee is 9 to 57 times that of the other sets even per input/output row (median 18,333 sat per row against 322 to 2,126). Transaction size does not explain it, and we did not separate fee-setting behaviour from the timing of its activity (fees vary over time).

### 6.13 PageRank

PageRank scores a node higher when it receives edges from high-ranked nodes. We computed it on the directed bipartite graph.

```python
pr = nx.pagerank(G)
pr_a = pd.Series({n: pr[n] for n in addr_nodes})
cmp_df = pd.DataFrame({"pagerank": pr_a, "degree": deg})
print(cmp_df["pagerank"].rank().corr(cmp_df["degree"].rank()))   # -0.0009
cmp_df["in_degree"] = pd.Series({n: G.in_degree(n) for n in addr_nodes})
print(cmp_df["pagerank"].rank().corr(cmp_df["in_degree"].rank())) # 0.978
```

[Measured]
- Spearman correlation with total degree: **-0.0009**; with in-degree: **0.978**. Because edges point from inputs to outputs, PageRank mainly ranks addresses by how many transactions pay them.
- The highest-scoring address is a non-seed with 131 edges and about 5% of all PageRank. Only two seeds (sets 25 and 209) are in the top ten.
- Several top non-seed addresses have degree 1 or 2 and sit at the end of a single huge transaction (342 to 518 inputs, 1 to 2 outputs), a pattern that looks like consolidation of many small amounts [Hypothesis].
- None of the top ten non-seed addresses is a bridge: five touch only set 25 and three only set 104. They are collection-style addresses of one set each, not meeting points between sets.

### 6.14 Common-input (H1) clustering

The common-input heuristic assumes that the party who signs a transaction controls all of its inputs, so addresses spent together belong together. We added, for each set, every address spent in the same transaction as one of its seeds (one hop only). It can fail for CoinJoin-style transactions, which are usually recognisable by many outputs, so we also counted the co-inputs found in transactions with at most 2 outputs.

```python
from itertools import combinations
ins = fl[fl["side"] == "in"]
rows, cos = [], {}
for cid in sorted(int(x) for x in selected["cluster_id"]):
    mine = {a for a, c in seed_to_cluster.items() if c == cid}
    tx_in = set(ins.loc[ins["addr"].isin(mine), "txid"])
    co = set(ins.loc[ins["txid"].isin(tx_in), "addr"]) - mine
    small = set(txs.loc[txs["n_out"] <= 2, "txid"]) & tx_in
    co_small = set(ins.loc[ins["txid"].isin(small), "addr"]) - mine
    cos[cid] = co
    rows.append({"set": cid, "txs_spending_seed": len(tx_in), "co_inputs": len(co),
                 "co_inputs_n_out_le_2": len(co_small),
                 "max_inputs_in_one_tx": int(txs.loc[txs["txid"].isin(tx_in), "n_in"].max()) if tx_in else 0})
overlap = sum(len(cos[x] & cos[y]) for x, y in combinations(cos, 2))
```

[Measured]

| Set | Transactions spending a seed | Co-input addresses | of which in tx with at most 2 outputs | Max inputs in one tx |
|---|---|---|---|---|
| 25 | 319 | 2,966 | 2,629 | 548 |
| 43 | 46 | 20 | 20 | 40 |
| 45 | 21 | 53 | 53 | 28 |
| 104 | 20 | 3,423 | 3,423 | 643 |
| 149 | 79 | 38 | 38 | 27 |
| 157 | 145 | 225 | 225 | 87 |
| 209 | 7 | 0 | 0 | 201 |
| 667 | 245 | 96 | 96 | 38 |

- The overlap between the clusters of any two sets is **0**: H1 merges none of the 8 sets.
- H1 adds 6,821 addresses (about 11.6% of the 58,555), mostly to sets 104 (3,423) and 25 (2,966). Thousands of addresses spent together in few transactions look like a service gathering deposits into a central wallet [Hypothesis].
- Set 209's seed is spent only with its own outputs: its 201-input transaction consolidates its own small payments.
- These clusters are lower bounds (one hop) and describe wallets, not identities.

### 6.15 Figures and exports

- **`sets_graph.png`** shows the 8 sets as nodes (label: set number and transaction count). Edge width falls in four classes (1, 2-4, 5-9 and 10+ shared bridges, with a legend) and dashed red edges mark the two direct shared-sender transactions. Node positions on the circle carry no meaning.
- **`sets_matrix.png`** is a heat map with the exact bridge count in each cell and the two directly linked pairs outlined. It is the precise version of the same information.
- **`data/graph_full.gexf`** is the full 64,600-node graph and **`data/bridges_subgraph.gexf`** a 324-node, 632-edge subgraph made of the bridges, the transactions next to them and the seeds in those transactions. In the subgraph some transactions show fewer neighbours than in the full graph. Colour by the `cluster` attribute (the bridges have -1) in Gephi.

```python
keep = set(bridge)
for a in bridge:
    for t in set(G.predecessors(a)) | set(G.successors(a)):
        keep.add(t)
        keep |= {x for x in set(G.predecessors(t)) | set(G.successors(t)) if x in seed_nodes}
sub = G.subgraph(keep).copy()
nx.write_gexf(G, "data/graph_full.gexf")
nx.write_gexf(sub, "data/bridges_subgraph.gexf")
```

The node names are anonymised, but the structure, amounts and `after_snap` flag could in principle be matched back to the public blockchain. Keep the GEXF files out of git and publish only the PNG figures and aggregate tables.

---

## 7. What the data supports and what it does not

**Supported by our measurements**
- The 8 sets are connected: one component contains them all, joined by 2 shared-sender transactions and 44 bridge addresses.
- Sets 43 and 149 are the most tightly linked pair: 15 shared bridges, one shared-sender transaction, and the same six destination addresses paid by both.
- Set 149 touches every other set; sets 25 and 209 form a separate strong pair.
- H1 clustering enlarges individual sets but never merges two.

**Not supported**
- **Common ownership.** A shared bridge, a shared payer or a shared destination can equally be an exchange or payment-service deposit address, a common funding source, or ordinary customers. For the six destinations shared by 43 and 149, we cannot tell a single operator from a shared deposit service without their own histories (the second hop).
- **What the services are.** The topic labels come from keywords in page titles. "bitcoin_mixer", "stolen_funds" or "market" are not verdicts, and none of the sets was confirmed as a scam, mixer or market.
- **Causes of activity patterns** (dormancy of set 157, growth of set 667, the high fees of set 25) are untested hypotheses.
- **Representativeness.** The sets are busy services chosen by topic, not a random sample of the dark web.

## 8. Limitations

- The dataset is a single crawl from April 2024; blockchain data was collected in October 2026 and differs from the paper's totals by what arrived later.
- Only one hop was downloaded; non-seed addresses are partly observed, so their degree and PageRank are lower bounds.
- Exact-list grouping of sites is conservative (it can only over-count distinct operators).
- The per-pair bridge counts were not compared with a random baseline.
- Several readings (flooding behind the large merged edges, consolidation, fee behaviour) were not checked at transaction level.
- Counts of 6,045 transactions and a few hundred thousand rows are small enough for our tools; larger samples would need a database.

## 9. Problems met along the way

| Problem | Cause and fix |
|---|---|
| Parsing numbers as text | The CSV uses decimal commas: pass `decimal=","`. |
| `ModuleNotFoundError: networkx` | Install with `%pip install networkx`, then rerun the cell. |
| `selected` not defined in notebook 2 | It lives in notebook 1: load it with `pd.read_pickle("data/selected_clusters.pkl")`. |
| API count (11) differed from the dataset (37) | The test queried one address; the dataset sums all addresses of the set. |
| 6,047 downloaded but 6,045 unique | Two transactions touch two sets; they are the two direct links. |
| Edge count lower than row count | Repeated address-transaction pairs are merged; see 6.8. |
| Unused `import re` in a cell | Harmless leftover; removed. |
| Wrong guesses corrected by data | The top PageRank addresses were not bridges; set 104 was not isolated in the bridge matrix; the largest transactions did not dominate the projection. |

## 10. Not done / open items

- **Task 1 (read the paper and main references):** the main references to read first are Lee et al. (NDSS 2019, the closest predecessor) and Rosenquist et al. (PAM 2024, same research group).
- **Task 2 (citing papers):** OpenAlex and Semantic Scholar each list one citing paper, *Bitcoin Flows from Sanctioned Sources* (IEEE LCN 2025, DOI 10.1109/LCN65610.2025.11146304). It has not been read, and Google Scholar and DBLP have not been searched.
- Second hop for the six destination addresses shared by sets 43 and 149.
- Weighting the links between sets by transactions or BTC passing through the bridges instead of by the number of bridge addresses.
- A random baseline for the bridge counts.
- Clustering coefficient on a restricted projection, and per-year fee analysis for set 25.
- Run **Restart and Run All** on both notebooks to confirm they reproduce from a clean start.

## 11. Ethics and safety

- We worked from the summary CSV and public blockchain data. The crawler was not run and no onion site was visited.
- Sets with `abusive_content` or `pornography` labels were excluded from the blockchain analysis because the paper states that category includes child sexual abuse material. Do not open the titles of those rows.
- An address on a web page does not prove who owns it (it can be copied, mistaken or belong to a service). We therefore avoid naming or accusing anyone, and publish no addresses.
- `data/` (raw responses, pickles and GEXF files) stays out of version control.

## 12. References

- L. O. Ingemarsson, K. D. Karlsson, N. Carlsson. *Using Venom to Flip the Coin and Peel the Onion: Measurement Tool and Dataset for Studying the Bitcoin - Dark Web Synergy.* Proc. ACM CODASPY 2025, pages 299-304. DOI 10.1145/3714393.3726488. Page with tool and dataset: `https://www.ida.liu.se/~nikca89/papers/venom.html`; PDF: `https://www.ida.liu.se/~nikca89/papers/codaspy25.pdf`.
- Venom summary CSV: `https://www.ida.liu.se/~nikca89/papers/venom-dataset-summary.csv`. Tool: `https://github.com/LukasIngemarsson/venom`.
- Esplora HTTP API (Blockstream): `https://github.com/Blockstream/esplora/blob/master/API.md`.
- Citation records: OpenAlex `https://api.openalex.org/works/doi:10.1145/3714393.3726488` and Semantic Scholar `https://api.semanticscholar.org/graph/v1/paper/DOI:10.1145/3714393.3726488/citations`.
- Related work seen only through search excerpts, not read in full: *The Devil Behind the Mirror: Tracking the Campaigns of Cryptocurrency Abuses on the Dark Web* (arXiv 2401.04662); *Dizzy* (arXiv 2209.07202).
