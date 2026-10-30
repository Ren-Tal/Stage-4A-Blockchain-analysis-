SELECT
  `hash`,
  block_timestamp,
  COUNT(DISTINCT output.addresses[SAFE_OFFSET(0)]) AS distinct_addresses_targeted,
  COUNTIF(output.value = 546) AS nb_dust_outputs
FROM `bigquery-public-data.crypto_bitcoin.transactions`,
  UNNEST(outputs) AS output
WHERE block_timestamp_month = '2026-09-01'
  AND `hash` IN (
    'eaa1bc4a2eb26ec8adbd88bf6865c7d4e4ab67c753087369afb1a46875f362a8',
    '3ba8850d34a2775f60aa8e8dad689f42dcc74b1c57b58cf9912f54fb4a83c770',
    '143129a549a6599e9ee3cab6d2153d6aa8e2694c1175d9f1673e6503c73c5953',
    '8c54be421427e55e97efe18dace71a809e22d3b9c8c61771cf7e5ed9bfc63fb5',
    'cfd385e748bc949097bae5fd5aaabfeab3a0227be415daea978a09009ed53c97',
    '58441ba600958a99113d461fa5d182e605f62984c30f581c920c9175b8a7ef8a',
    'a35e26bd400a37785c41cf83d44b1f06f5a753b38c1cf78a29b4eae7d6538094',
    '860c0064a43d58916b273ca7f963b5e76e61ed6067c4d1ac6af2cfcf094f0f37',
    'b1d618c2baf85fade59e6f1cf12ff188f09c9e9e3e327f9fb11e87dd37e88e18',
    'bf758e9fbe512a3c27cf026c6ec36dc3305af39a4aa54c638780f82b29f7b404'
  )
GROUP BY `hash`, block_timestamp
ORDER BY block_timestamp