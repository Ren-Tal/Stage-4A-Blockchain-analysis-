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