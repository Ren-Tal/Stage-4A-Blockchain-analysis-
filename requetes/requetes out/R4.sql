SELECT
  output.value / 1e8 AS value_btc,
  COUNT(*) AS nb_outputs_with_this_value
FROM `bigquery-public-data.crypto_bitcoin.transactions`,
  UNNEST(outputs) AS output
WHERE block_timestamp_month = '2026-09-01'
  AND `hash` = 'eaa1bc4a2eb26ec8adbd88bf6865c7d4e4ab67c753087369afb1a46875f362a8'
GROUP BY value_btc
ORDER BY nb_outputs_with_this_value DESC