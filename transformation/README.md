## 🏗️ Phase 2: Silver Layer Transformation (T-SQL & Spatial)

Once the raw OpenSky JSON is landed in the `bronze` staging table, a custom T-SQL Stored Procedure (`silver.sp_ProcessFlightData`) is triggered by Azure Data Factory to transform the data into a structured, queryable format.

<p align="center">
  <img src="images/adf_pipeline_success.png" width="600" alt="ADF Pipeline Success">
</p>

### 🧠 1. Transformation Logic & Schema Mapping
The transformation process handles the "shredding" of nested JSON arrays into a relational format. By using a root-level mapping (`$`) in Data Factory, we ensure the entire API payload is preserved before SQL processing.

<p align="center">
  <img src="images/adf_json_mapping.png" width="600" alt="ADF JSON Mapping">
</p>

### 🌍 2. Spatial Data Engineering
To enable advanced GIS analysis, this project implements native SQL spatial objects. A critical challenge was handling "dirty data" from the live API (missing coordinates). I implemented a **Logic Gate** using a `CASE` statement to validate telemetry before creating geography points.

**Key Technical Features:**
* **Geography Constructor:** Converts coordinates into native `GEOGRAPHY` objects (SRID 4326).
* **Data Resiliency:** Uses `TRY_CAST` to prevent pipeline crashes from null telemetry.
* **Staging Management:** Implements `TRUNCATE` to maintain a high-performance "Transient" Bronze layer.

#### 🛠️ Stored Procedure Logic
```sql
CREATE PROCEDURE silver.sp_ProcessFlightData
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @json NVARCHAR(MAX);
    SELECT TOP 1 @json = RawJsonData FROM bronze.Staging_OpenSky ORDER BY IngestionTimestamp DESC;

    IF @json IS NOT NULL
    BEGIN
        INSERT INTO silver.FlightTracking (
            Icao24, Callsign, OriginCountry, Longitude, Latitude, 
            Altitude, Velocity, TrueTrack, SpatialLocation, LastContactTimestamp
        )
        SELECT 
            JSON_VALUE(Value, '$[0]'), 
            TRIM(JSON_VALUE(Value, '$[1]')), 
            JSON_VALUE(Value, '$[2]'), 
            TRY_CAST(JSON_VALUE(Value, '$[5]') AS FLOAT), 
            TRY_CAST(JSON_VALUE(Value, '$[6]') AS FLOAT), 
            TRY_CAST(JSON_VALUE(Value, '$[7]') AS FLOAT), 
            TRY_CAST(JSON_VALUE(Value, '$[9]') AS FLOAT), 
            TRY_CAST(JSON_VALUE(Value, '$[10]') AS FLOAT),
            
            -- SPATIAL LOGIC: Validates coordinates before Point creation
            CASE 
                WHEN JSON_VALUE(Value, '$[6]') IS NOT NULL 
                 AND JSON_VALUE(Value, '$[5]') IS NOT NULL 
                THEN geography::Point(
                        CAST(JSON_VALUE(Value, '$[6]') AS FLOAT), 
                        CAST(JSON_VALUE(Value, '$[5]') AS FLOAT), 
                        4326)
                ELSE NULL 
            END,

            DATEADD(second, TRY_CAST(JSON_VALUE(Value, '$[4]') AS INT), '1970-01-01')
        FROM OPENJSON(@json, '$.states');

        TRUNCATE TABLE bronze.Staging_OpenSky;
    END
END;
```

<p align="center">
  <img src="images/sql_stored_procedure.png" width="600" alt="T-SQL Logic">
</p>

### 📊 3. Verification & Results (Silver Layer)
The final output produces a cleaned, structured dataset ready for BI reporting or spatial indexing.

<p align="center">
  <img src="images/sql_silver_results.png" width="600" alt="Silver Layer Results">
</p>
