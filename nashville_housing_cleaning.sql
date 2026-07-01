-- =============================================================
--   NASHVILLE HOUSING DATA CLEANING PROJECT
--   Dataset: ~56,000 property sales records
--   Skills: Standardization, NULL handling, Deduplication,
--           Column splitting, Data transformation
-- =============================================================


-- =============================================================
-- STEP 0: INSPECT THE RAW DATA
-- =============================================================

-- Get a feel for the data
SELECT TOP 10 *
FROM NashvilleHousing;

-- Row count
SELECT COUNT(*) AS total_records
FROM NashvilleHousing;

-- Check column-level nulls
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN UniqueID       IS NULL THEN 1 ELSE 0 END) AS null_unique_id,
    SUM(CASE WHEN ParcelID       IS NULL THEN 1 ELSE 0 END) AS null_parcel_id,
    SUM(CASE WHEN SaleDate       IS NULL THEN 1 ELSE 0 END) AS null_sale_date,
    SUM(CASE WHEN SalePrice      IS NULL THEN 1 ELSE 0 END) AS null_sale_price,
    SUM(CASE WHEN PropertyAddress IS NULL THEN 1 ELSE 0 END) AS null_property_address,
    SUM(CASE WHEN OwnerAddress   IS NULL THEN 1 ELSE 0 END) AS null_owner_address,
    SUM(CASE WHEN LandUse        IS NULL THEN 1 ELSE 0 END) AS null_land_use,
    SUM(CASE WHEN SoldAsVacant   IS NULL THEN 1 ELSE 0 END) AS null_sold_as_vacant,
    SUM(CASE WHEN Bedrooms       IS NULL THEN 1 ELSE 0 END) AS null_bedrooms,
    SUM(CASE WHEN Acreage        IS NULL THEN 1 ELSE 0 END) AS null_acreage
FROM NashvilleHousing;


-- =============================================================
-- STEP 1: STANDARDIZE DATE FORMAT
-- SaleDate comes in as a DATETIME — strip the time component
-- =============================================================

-- Preview the problem
SELECT
    SaleDate,
    CONVERT(DATE, SaleDate) AS SaleDateConverted
FROM NashvilleHousing;

-- Add a clean date column (guarded so re-running the script doesn't
-- error if this column already exists from a prior run)
IF COL_LENGTH('NashvilleHousing', 'SaleDateConverted') IS NULL
BEGIN
    ALTER TABLE NashvilleHousing
    ADD SaleDateConverted DATE;
END;

-- Populate it
UPDATE NashvilleHousing
SET SaleDateConverted = CONVERT(DATE, SaleDate);

-- Verify
SELECT TOP 10 SaleDate, SaleDateConverted
FROM NashvilleHousing;


-- =============================================================
-- STEP 2: POPULATE MISSING PROPERTY ADDRESSES
-- Logic: Same ParcelID → same address. Join the table to itself
-- to find rows where address is NULL and another row with the
-- same ParcelID has an address we can borrow.
-- =============================================================

-- First, see the scale of the problem
SELECT COUNT(*) AS missing_addresses
FROM NashvilleHousing
WHERE PropertyAddress IS NULL;

-- Find matches: where a.address IS NULL but b (same parcel) has one
SELECT
    a.ParcelID,
    a.PropertyAddress    AS address_missing,
    b.ParcelID,
    b.PropertyAddress    AS address_to_use
FROM NashvilleHousing a
JOIN NashvilleHousing b
    ON  a.ParcelID   = b.ParcelID
    AND a.UniqueID  <> b.UniqueID          -- different rows
WHERE a.PropertyAddress IS NULL;

-- Fill in the blanks. A correlated subquery (rather than a bare
-- self-join UPDATE) guarantees a deterministic pick if a ParcelID
-- ever has more than one other non-null address on file.
UPDATE a
SET a.PropertyAddress = (
    SELECT TOP 1 b.PropertyAddress
    FROM NashvilleHousing b
    WHERE b.ParcelID = a.ParcelID
      AND b.UniqueID <> a.UniqueID
      AND b.PropertyAddress IS NOT NULL
    ORDER BY b.UniqueID
)
FROM NashvilleHousing a
WHERE a.PropertyAddress IS NULL;

-- Confirm 0 nulls remain
SELECT COUNT(*) AS still_missing
FROM NashvilleHousing
WHERE PropertyAddress IS NULL;


-- =============================================================
-- STEP 3: SPLIT PropertyAddress INTO SEPARATE COLUMNS
-- Format is: "1234 MAIN ST, NASHVILLE"
-- We need: Address | City
-- =============================================================

-- Preview the split logic
-- Guard against PropertyAddress with no comma at all — CHARINDEX
-- returns 0 in that case, and SUBSTRING(..., 1, -1) throws an error.
SELECT
    PropertyAddress,
    CASE WHEN CHARINDEX(',', PropertyAddress) > 0
         THEN LTRIM(RTRIM(SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) - 1)))
         ELSE LTRIM(RTRIM(PropertyAddress))
    END AS prop_street,
    CASE WHEN CHARINDEX(',', PropertyAddress) > 0
         THEN LTRIM(RTRIM(SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) + 1, LEN(PropertyAddress))))
         ELSE NULL
    END AS prop_city
FROM NashvilleHousing;

-- Add two new columns (guarded for re-runs)
IF COL_LENGTH('NashvilleHousing', 'PropertySplitAddress') IS NULL
BEGIN
    ALTER TABLE NashvilleHousing
    ADD PropertySplitAddress VARCHAR(255),
        PropertySplitCity    VARCHAR(100);
END;

-- Populate them
UPDATE NashvilleHousing
SET
    PropertySplitAddress = CASE WHEN CHARINDEX(',', PropertyAddress) > 0
        THEN LTRIM(RTRIM(SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) - 1)))
        ELSE LTRIM(RTRIM(PropertyAddress))
    END,
    PropertySplitCity = CASE WHEN CHARINDEX(',', PropertyAddress) > 0
        THEN LTRIM(RTRIM(SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) + 1, LEN(PropertyAddress))))
        ELSE NULL
    END;

-- Verify
SELECT TOP 10 PropertyAddress, PropertySplitAddress, PropertySplitCity
FROM NashvilleHousing;


-- =============================================================
-- STEP 4: SPLIT OwnerAddress INTO THREE COLUMNS
-- Format is: "1234 MAIN ST, NASHVILLE, TN"
-- We need: Address | City | State
-- Using PARSENAME trick (replaces commas with dots, then parses)
-- =============================================================

-- Preview PARSENAME trick
-- Caveat: PARSENAME silently returns NULL for any part over 128
-- characters, and only handles up to 4 dot-separated parts — an
-- OwnerAddress with an embedded comma (e.g. a unit number) would
-- silently misparse rather than error. Works here because Nashville
-- addresses fit the 3-part pattern, but isn't fully general.
SELECT
    OwnerAddress,
    LTRIM(RTRIM(PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3))) AS owner_street,
    LTRIM(RTRIM(PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2))) AS owner_city,
    LTRIM(RTRIM(PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1))) AS owner_state
FROM NashvilleHousing;

-- Add three new columns (guarded for re-runs)
IF COL_LENGTH('NashvilleHousing', 'OwnerSplitAddress') IS NULL
BEGIN
    ALTER TABLE NashvilleHousing
    ADD OwnerSplitAddress VARCHAR(255),
        OwnerSplitCity    VARCHAR(100),
        OwnerSplitState   VARCHAR(10);
END;

-- Populate them
UPDATE NashvilleHousing
SET
    OwnerSplitAddress = LTRIM(RTRIM(PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3))),
    OwnerSplitCity    = LTRIM(RTRIM(PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2))),
    OwnerSplitState   = LTRIM(RTRIM(PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1)));

-- Verify
SELECT TOP 10 OwnerAddress, OwnerSplitAddress, OwnerSplitCity, OwnerSplitState
FROM NashvilleHousing;


-- =============================================================
-- STEP 5: STANDARDIZE "SoldAsVacant" FIELD
-- Has 4 values: 'Y', 'N', 'Yes', 'No' — normalize to Yes/No
-- =============================================================

-- See the mess
SELECT
    SoldAsVacant,
    COUNT(*) AS occurrences
FROM NashvilleHousing
GROUP BY SoldAsVacant
ORDER BY occurrences DESC;

-- Fix with CASE
UPDATE NashvilleHousing
SET SoldAsVacant =
    CASE
        WHEN SoldAsVacant = 'Y' THEN 'Yes'
        WHEN SoldAsVacant = 'N' THEN 'No'
        ELSE SoldAsVacant           -- already 'Yes' or 'No'
    END;

-- Confirm only two values remain
SELECT SoldAsVacant, COUNT(*) AS count
FROM NashvilleHousing
GROUP BY SoldAsVacant;


-- =============================================================
-- STEP 5.5: BACKUP BEFORE DESTRUCTIVE CHANGES
-- Steps 6 and 7 permanently delete rows and drop columns.
-- Snapshot the table first so the raw data can be recovered.
-- =============================================================

-- Drop any prior backup so this step is safe to re-run
IF OBJECT_ID('dbo.NashvilleHousing_Backup', 'U') IS NOT NULL
    DROP TABLE NashvilleHousing_Backup;

SELECT *
INTO NashvilleHousing_Backup
FROM NashvilleHousing;


-- =============================================================
-- STEP 6: REMOVE DUPLICATES
-- A "duplicate" = same ParcelID, SaleDate, SalePrice,
--   LegalReference, PropertyAddress
-- Keep one row per combination using ROW_NUMBER()
-- =============================================================

-- Identify duplicates — any row_num > 1 is a dupe
WITH RowNumCTE AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY
                ParcelID,
                PropertyAddress,
                SalePrice,
                SaleDate,
                LegalReference
            ORDER BY UniqueID
        ) AS row_num
    FROM NashvilleHousing
)
SELECT *
FROM RowNumCTE
WHERE row_num > 1
ORDER BY PropertyAddress;

-- Count dupes before deletion
WITH RowNumCTE AS (
    SELECT
        UniqueID,
        ROW_NUMBER() OVER (
            PARTITION BY
                ParcelID,
                PropertyAddress,
                SalePrice,
                SaleDate,
                LegalReference
            ORDER BY UniqueID
        ) AS row_num
    FROM NashvilleHousing
)
SELECT COUNT(*) AS duplicate_rows_to_delete
FROM RowNumCTE
WHERE row_num > 1;

-- Delete duplicates — deleting directly against the CTE avoids the
-- redundant re-query-by-UniqueID-IN(...) pattern.
WITH RowNumCTE AS (
    SELECT
        UniqueID,
        ROW_NUMBER() OVER (
            PARTITION BY
                ParcelID,
                PropertyAddress,
                SalePrice,
                SaleDate,
                LegalReference
            ORDER BY UniqueID
        ) AS row_num
    FROM NashvilleHousing
)
DELETE FROM RowNumCTE
WHERE row_num > 1;

-- Confirm row count dropped
SELECT COUNT(*) AS records_after_dedup
FROM NashvilleHousing;


-- =============================================================
-- STEP 7: DROP UNUSED COLUMNS
-- Original raw columns replaced by cleaner versions
-- =============================================================

-- Guarded so re-running the script after columns are already
-- dropped doesn't error
IF COL_LENGTH('NashvilleHousing', 'PropertyAddress') IS NOT NULL
BEGIN
    ALTER TABLE NashvilleHousing
    DROP COLUMN
        PropertyAddress,   -- replaced by PropertySplitAddress + PropertySplitCity
        OwnerAddress,      -- replaced by OwnerSplitAddress/City/State
        SaleDate,          -- replaced by SaleDateConverted
        TaxDistrict;       -- not needed for analysis
END;


-- =============================================================
-- STEP 8: FINAL VALIDATION — CLEANED DATASET
-- =============================================================

-- Row count after full cleaning
SELECT COUNT(*) AS final_row_count
FROM NashvilleHousing;

-- Quick column-level null check on final table
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN SaleDateConverted  IS NULL THEN 1 ELSE 0 END) AS null_sale_date,
    SUM(CASE WHEN SalePrice          IS NULL THEN 1 ELSE 0 END) AS null_sale_price,
    SUM(CASE WHEN PropertySplitAddress IS NULL THEN 1 ELSE 0 END) AS null_prop_address,
    SUM(CASE WHEN PropertySplitCity  IS NULL THEN 1 ELSE 0 END) AS null_prop_city,
    SUM(CASE WHEN OwnerSplitAddress  IS NULL THEN 1 ELSE 0 END) AS null_owner_address,
    SUM(CASE WHEN OwnerSplitCity     IS NULL THEN 1 ELSE 0 END) AS null_owner_city,
    SUM(CASE WHEN OwnerSplitState    IS NULL THEN 1 ELSE 0 END) AS null_owner_state,
    SUM(CASE WHEN SoldAsVacant       IS NULL THEN 1 ELSE 0 END) AS null_sold_vacant
FROM NashvilleHousing;

-- Preview final clean table
SELECT TOP 20 *
FROM NashvilleHousing
ORDER BY SaleDateConverted DESC;


-- =============================================================
-- BONUS: ANALYTICAL QUERIES ON CLEANED DATA
-- (Resume talking point: "extracted insights post-cleaning")
-- =============================================================

-- 1. Sales volume and average price by year
SELECT
    YEAR(SaleDateConverted)    AS sale_year,
    COUNT(*)                   AS total_sales,
    AVG(SalePrice)             AS avg_sale_price,
    MIN(SalePrice)             AS min_price,
    MAX(SalePrice)             AS max_price
FROM NashvilleHousing
GROUP BY YEAR(SaleDateConverted)
ORDER BY sale_year;

-- 2. Top 10 cities by number of property sales
SELECT TOP 10
    PropertySplitCity,
    COUNT(*)        AS total_sales,
    AVG(SalePrice)  AS avg_price
FROM NashvilleHousing
GROUP BY PropertySplitCity
ORDER BY total_sales DESC;

-- 3. Vacant vs non-vacant: avg price comparison
SELECT
    SoldAsVacant,
    COUNT(*)        AS total_sales,
    AVG(SalePrice)  AS avg_price,
    MIN(SalePrice)  AS min_price,
    MAX(SalePrice)  AS max_price
FROM NashvilleHousing
GROUP BY SoldAsVacant;

-- 4. Land use breakdown — what types of properties sell most
SELECT
    LandUse,
    COUNT(*)        AS total_sales,
    AVG(SalePrice)  AS avg_price
FROM NashvilleHousing
GROUP BY LandUse
ORDER BY total_sales DESC;

-- 5. Price distribution buckets
SELECT
    CASE
        WHEN SalePrice <  100000               THEN 'Under 100K'
        WHEN SalePrice BETWEEN 100000 AND 249999 THEN '100K - 250K'
        WHEN SalePrice BETWEEN 250000 AND 499999 THEN '250K - 500K'
        WHEN SalePrice BETWEEN 500000 AND 999999 THEN '500K - 1M'
        ELSE 'Over 1M'
    END AS price_range,
    COUNT(*) AS total_sales
FROM NashvilleHousing
GROUP BY
    CASE
        WHEN SalePrice <  100000               THEN 'Under 100K'
        WHEN SalePrice BETWEEN 100000 AND 249999 THEN '100K - 250K'
        WHEN SalePrice BETWEEN 250000 AND 499999 THEN '250K - 500K'
        WHEN SalePrice BETWEEN 500000 AND 999999 THEN '500K - 1M'
        ELSE 'Over 1M'
    END
ORDER BY total_sales DESC;
