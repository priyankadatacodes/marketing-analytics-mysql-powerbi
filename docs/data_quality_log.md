# Data Quality Log

Each issue below was detected by a query in `sql/01b_raw_data_validation.sql` (or `05_data_quality.sql`), treated in `sql/02_data_cleaning.sql` / `04_populate_star_schema.sql`, and re-counted after loading.
Counts come from executing the scripts end-to-end; a few (marked ‡) come from the independent pandas check in `validation/verify_kpis.py` because the SQL does not output them.

**Net effect:** 185,219 raw rows → 184,309 staged rows (910 rows, 0.5%, removed); additional values were nulled or flagged rather than dropped.

| # | Issue | Detection | Treatment | Result |
|---|---|---|---|---|
| 1 | **Mixed date formats** in every date column — ISO `YYYY-MM-DD`, `DD-MM-YYYY`, `MM/DD/YYYY`, `DD Mon YYYY` (e.g. customers: 5,681 / 2,128 / 1,618 / 638, plus 435 blank) | Regex format census (`01b` §6) | `CASE` + `REGEXP` selects the pattern, `STR_TO_DATE` converts. Day/month order is inferred from the separator; in `transactions.csv` the second token of `xx/xx/yyyy` exceeds 12 in 5,320 of 8,731 values and the first never does, which supports month-first ‡ | All dates typed as `DATE` |
| 2 | **Missing or unparseable dates** | Unknown-date count (`05` §5) | Mapped to the `19000101` unknown member rather than dropped | Unknown-date rows: spend 1,063 (₹9.23M, 4.0%), revenue 2,397 (₹4.11M), activity 2,819, conversions 764. Included in headline totals, excluded from monthly trends |
| 3 | **Inconsistent channel labels** | Distinct-value listing (`01b` §5) | `CASE` on `LOWER(TRIM())` | 22 normalised variants (53 raw spellings in campaigns, 72 in customers) collapsed to 7 channels |
| 4 | **Inconsistent country labels** (`IN`, `INDIA`, `U.S.A`, `england`, padded values …) | Distinct-value listing | `CASE` mapping for 10 countries | Standardised names; unmapped values kept as trimmed text |
| 5 | **Padding / whitespace** in names, country, channel (1,000+ rows each) | `01b` §5 | `TRIM`, `NULLIF(…,'')` | Blanks become NULL |
| 6 | **Mixed currency symbols in numeric columns** — `₹` and `$` (spend: 3,116 rows; revenue: 3,665 rows) | Regex `[^0-9.-]` (`01b` §7) | `REGEXP_REPLACE` then `CAST AS DECIMAL`. **No exchange-rate conversion applied.** Median spend by symbol is similar (₹4,394 / $4,069 / unmarked 3,990 ‡), so the symbol appears cosmetic — an assumption to confirm | Numeric `spend` / `revenue` |
| 7 | **Duplicate customers** | Key duplicate count (`01b` §4) | `ROW_NUMBER() … PARTITION BY customer_id ORDER BY (email IS NULL)` keeps the row that has an email. Copies differ only in blank vs. populated email ‡ | 10,500 → 9,985 (15 blank ids + 500 duplicate rows removed) |
| 8 | **Duplicate campaigns** (5 ids) | `01b` §4 | `ROW_NUMBER` by id | 225 → 220. The duplicate pairs differ only by a "(v2)" suffix in `campaign_name`; the tie-break is arbitrary, so the surviving name can vary |
| 9 | **Duplicate transactions** | `01b` §4 | `ROW_NUMBER` by `transaction_id` | 300 exact-copy duplicates removed ‡ |
| 10 | **Fully blank transaction rows** | `01b` §3 | Filtered out | 10 rows |
| 11 | **Negative spend** | `01b` §8 | Set to NULL (cost cannot be negative) | 140 rows (−₹1.09M ‡, about 0.5% of spend) excluded from `SUM` |
| 12 | **Negative revenue** | `01b` §8 | Kept; `is_refund = TRUE` | 236 refunds, −₹387,685; revenue is reported net of refunds |
| 13 | **Clicks greater than impressions** | `01b` §9 | `clicks` set to NULL (impressions kept) | 259 rows. Because impressions are kept, CTR is slightly understated |
| 14 | **Blank impressions** | n/a (not profiled in `01b`) ‡ | Left NULL | 252 rows contribute no impressions |
| 15 | **Orphan foreign keys** | `01b` §10 | Rows without a parent campaign/customer removed by `INNER JOIN` | 20 performance rows, 60 conversion rows; 0 transactions/activity rows |
| 16 | **Blank categorical fields** | `01b` §2 | `'Unknown'` / `'unknown'` | 200 conversion stages, 150 activity types |
| 17 | **Transactions without a campaign** | `05` §3 | `LEFT JOIN`, `campaign_key` NULL | 5,740 transactions (9.9%), ₹10.22M — valid revenue that cannot be attributed to a channel |
| 18 | **Events dated before the customer's signup date** | Caveat query in `11_retention_analysis.sql` | Retention logic counts only post-signup events | 35,838 activity events and 28,879 transactions precede signup in SQL (this count includes unknown-date rows); about 50% of dated events ‡ — indicates `signup_date` is unreliable |
| 19 | **Missing signup dates** | `dim_customer` check | Excluded from cohort logic | 414 customers |

## Post-load checks (`05_data_quality.sql`)
No duplicate customer, campaign or transaction keys; no orphan keys in any fact table; no negative spend; no clicks above impressions; no leads above clicks. The "no negative spend" and "no clicks > impressions" checks pass by construction because the cleaning step already nulled those values — they validate the treatment, not the source data.

## Checks that are not in the repository
Raw-to-clean reconciliation of **sums** (only row counts are reported), a rejected-rows table with reason codes, and a guard that no date falls outside the `dim_date` range (2023-01-01 → 2026-12-31; no date was found outside it).
