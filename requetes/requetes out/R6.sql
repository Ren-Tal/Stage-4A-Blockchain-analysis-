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