-- =============================================================
--   NASHVILLE HOUSING — TABLE SCHEMA
--   Run this script first to create the table, then import
--   NashvilleHousing.csv, then run the cleaning pipeline.
-- =============================================================

-- Drop and recreate cleanly if the table already exists
IF OBJECT_ID('dbo.NashvilleHousing', 'U') IS NOT NULL
    DROP TABLE dbo.NashvilleHousing;

CREATE TABLE dbo.NashvilleHousing (
    -- Primary identifier
    UniqueID          INT              NOT NULL,
    ParcelID          VARCHAR(50)      NULL,

    -- Property details
    LandUse           VARCHAR(100)     NULL,
    PropertyAddress   VARCHAR(255)     NULL,
    Acreage           DECIMAL(10, 2)   NULL,
    TaxDistrict       VARCHAR(100)     NULL,
    LandValue         INT              NULL,
    BuildingValue     INT              NULL,
    TotalValue        INT              NULL,

    -- Sale details
    SaleDate          DATETIME         NULL,
    SalePrice         INT              NULL,
    LegalReference    VARCHAR(100)     NULL,
    SoldAsVacant      VARCHAR(5)       NULL,   -- raw: 'Y','N','Yes','No'

    -- Owner details
    OwnerName         VARCHAR(255)     NULL,
    OwnerAddress      VARCHAR(255)     NULL,

    -- Building characteristics
    YearBuilt         INT              NULL,
    Bedrooms          INT              NULL,
    FullBath          INT              NULL,
    HalfBath          INT              NULL,

    CONSTRAINT PK_NashvilleHousing PRIMARY KEY (UniqueID)
);

-- =============================================================
-- After running the cleaning pipeline, the table will also have
-- these additional columns (added by the script):
--
--   SaleDateConverted   DATE           — stripped time component
--   PropertySplitAddress VARCHAR(255)  — street part of PropertyAddress
--   PropertySplitCity    VARCHAR(100)  — city  part of PropertyAddress
--   OwnerSplitAddress    VARCHAR(255)  — street part of OwnerAddress
--   OwnerSplitCity       VARCHAR(100)  — city  part of OwnerAddress
--   OwnerSplitState      VARCHAR(10)   — state part of OwnerAddress
--
-- And these columns will be dropped by the cleaning script:
--
--   PropertyAddress   — replaced by PropertySplitAddress + PropertySplitCity
--   OwnerAddress      — replaced by OwnerSplitAddress / City / State
--   SaleDate          — replaced by SaleDateConverted
--   TaxDistrict       — not used in analysis
-- =============================================================
