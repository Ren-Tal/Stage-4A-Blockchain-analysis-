SELECT
  `hash`,
  block_timestamp,
  input_count,
  output_count
FROM `bigquery-public-data.crypto_bitcoin.transactions`
WHERE block_timestamp_month = '2026-09-01'
  AND output_count = 601
ORDER BY block_timestamp