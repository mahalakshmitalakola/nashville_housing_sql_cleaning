# Nashville Housing — SQL Data Cleaning Project

A full data cleaning pipeline written in T-SQL (SQL Server) applied to a real-world Nashville property sales dataset of ~56,000 records. The project covers every major cleaning discipline: NULL imputation, column standardisation, address parsing, deduplication, and schema cleanup — followed by a set of analytical queries that extract business insights from the cleaned data.

---

## Dataset

| Property | Detail |
|---|---|
| Source | Nashville, Tennessee property sales records |
| Raw row count | ~56,000 |
| Format | Relational table (SQL Server) |
| Time period | Multiple years of residential and commercial sales |

The raw data contains mixed date formats, inconsistent boolean values, composite address fields, NULL property addresses, and duplicate rows — all common real-world data quality problems.

---

## Problems Identified & Solutions Applied

| # | Problem | Solution |
|---|---|---|
| 1 | `SaleDate` stored as `DATETIME` with redundant time component | Added `SaleDateConverted DATE` column via `CONVERT` |
| 2 | ~29 rows with `NULL` `PropertyAddress` | Self-referencing correlated subquery — borrow address from another row sharing the same `ParcelID` |
| 3 | `PropertyAddress` is a single composite string (`"STREET, CITY"`) | Split into `PropertySplitAddress` and `PropertySplitCity` using `CHARINDEX` + `SUBSTRING` with NULL-safe guards |
| 4 | `OwnerAddress` is a three-part composite string (`"STREET, CITY, STATE"`) | Split into three columns using `PARSENAME` + `REPLACE` trick, with `LTRIM`/`RTRIM` trimming |
| 5 | `SoldAsVacant` has four values: `Y`, `N`, `Yes`, `No` | Normalised to `Yes`/`No` only via `CASE` expression |
| 6 | ~104 duplicate rows (same parcel, price, date, legal reference, address) | Identified with `ROW_NUMBER() OVER (PARTITION BY ...)` and deleted directly via CTE |
| 7 | Raw columns made redundant by cleaned replacements | Dropped `PropertyAddress`, `OwnerAddress`, `SaleDate`, `TaxDistrict` |

---

## Repository Structure

```
nashville-housing-sql/
│
├── nashville_housing_cleaning.sql   # Full cleaning pipeline (Steps 0–8 + bonus queries)
├── schema.sql                       # CREATE TABLE statement to set up the database
├── NashvilleHousing.csv             # Raw dataset (import this before running the pipeline)
└── README.md
```

---

## How to Run

**1. Create the table**
```sql
-- Run schema.sql first
```

**2. Import the raw data**

Use SQL Server Management Studio (SSMS): right-click the database → Tasks → Import Flat File → select `NashvilleHousing.csv`.

Alternatively use `BULK INSERT`:
```sql
BULK INSERT NashvilleHousing
FROM 'C:\path\to\NashvilleHousing.csv'
WITH (FIELDTERMINATOR = ',', ROWTERMINATOR = '\n', FIRSTROW = 2);
```

**3. Run the cleaning pipeline**
```sql
-- Run nashville_housing_cleaning.sql step by step, or execute in full
```

The script is fully idempotent — it can be re-run against the same database without errors.

---

## Before vs After

| Metric | Before | After |
|---|---|---|
| Row count | ~56,000 | ~55,896 (dupes removed) |
| `PropertyAddress` NULLs | ~29 | 0 |
| `SoldAsVacant` distinct values | 4 (`Y`, `N`, `Yes`, `No`) | 2 (`Yes`, `No`) |
| Address columns | 2 composite | 5 split (`Street`, `City` × 2 + `State`) |
| Date column | `DATETIME` (with time noise) | `DATE` |
| Redundant columns | 4 | 0 (dropped) |

---

## Analytical Queries (Bonus)

After cleaning, five insight queries are included at the bottom of the script:

1. **Sales volume and average price by year** — trend over time
2. **Top 10 cities by sales count** — geographic distribution
3. **Vacant vs non-vacant price comparison** — segment analysis
4. **Land use breakdown** — which property types sell most
5. **Price distribution buckets** — Under 100K / 100K–250K / 250K–500K / 500K–1M / Over 1M

---

## Tools Used

- **SQL Server** (T-SQL dialect)
- **SQL Server Management Studio (SSMS)**

---

## Key SQL Concepts Demonstrated

- `ALTER TABLE` / `UPDATE` for schema evolution
- Self-referencing correlated subquery for NULL imputation
- `CHARINDEX` + `SUBSTRING` for string parsing with NULL-safe guards
- `PARSENAME` + `REPLACE` for multi-part address splitting
- `ROW_NUMBER() OVER (PARTITION BY ...)` for duplicate detection
- `DELETE` directly against a CTE
- `IF COL_LENGTH(...) IS NULL` / `IF OBJECT_ID(...) IS NOT NULL` idempotency guards
- Window functions, `GROUP BY`, `CASE` expressions, aggregate analytics
