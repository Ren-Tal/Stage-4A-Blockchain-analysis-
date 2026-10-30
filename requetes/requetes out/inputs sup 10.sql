SELECT
  `hash`,
  block_timestamp,
  input_count,
  output_count,
  fee
FROM `bigquery-public-data.crypto_bitcoin.transactions`
WHERE block_timestamp_month = '2026-09-01'
  AND input_count > 10
  AND output_count > 10
ORDER BY output_count DESC
LIMIT 20