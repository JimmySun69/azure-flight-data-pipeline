## 🏗️ Phase 2: Silver Layer Transformation (T-SQL & Spatial)

Once the raw OpenSky JSON is landed in the `bronze` staging table, a custom T-SQL Stored Procedure (`silver.sp_ProcessFlightData`) is triggered by Azure Data Factory to transform the data into a structured, queryable format.

*(📸 SCREENSHOT 1: Take a screenshot of your ADF pipeline canvas showing the three chained activities with the green checkmarks in the Output tab. This proves your orchestration works.)*
![ADF Pipeline Orchestration Success](images/adf_pipeline_success.png)

### 📥 1. The Raw Landing (Bronze Layer)
Before transformation, the API payload is preserved in its raw format using a Schema-on-Read approach. We map the entire JSON response root (`$`) directly into a single `NVARCHAR(MAX)` column.

*(📸 SCREENSHOT 2: Take a screenshot of the "Mapping" tab in your ADF 'Copy to SQL Staging' activity, showing the `$` mapped to `RawJsonData` with the 'Map complex values to string' box checked. This highlights your troubleshooting and mapping skills.)*
![ADF JSON Root Mapping](images/adf_json_mapping.png)

*(📸 SCREENSHOT 3: Take a screenshot of your Azure SQL Query Editor running `SELECT * FROM bronze.Staging_OpenSky;` showing the long string of raw JSON in the column. This shows the "Before" state of your data.)*
![Raw JSON in Staging Table](images/sql_bronze_raw_json.png)

### 🧠 2. Transformation Logic & Spatial Engineering
The transformation process was engineered to handle three specific technical challenges:

1. **JSON Flattening:** Utilized `OPENJSON` with explicit path expressions to "shred" the complex nested array-of-arrays format typical of the OpenSky REST API.
2. **Schema & Type Enforcement:** Implemented `TRY_CAST` and `TRIM` functions to ensure telemetry data is stored as numeric types, preventing pipeline failures from unexpected "null" strings.
3. **Temporal Normalization:** Converted the API's Unix Epoch timestamps into standard SQL `DATETIME` formats.

To enable advanced GIS analysis, this project implements native spatial objects:
* **Geography Constructor:** Converts raw Latitude and Longitude into a native `GEOGRAPHY` point object using the **SRID 4326** (WGS 84) standard.
* **Resiliency Logic:** Developed a `CASE` statement to validate coordinates (Lat: -90 to 90, Long: -180 to 180) before processing. This prevents "Parameter Null" errors common in live telemetry streams when an aircraft loses GPS lock.

*(📸 SCREENSHOT 4: Take a screenshot of your Azure SQL Query Editor showing the T-SQL Stored Procedure code, specifically highlighting the `TRY...CATCH` block and the `geography::Point` logic. This proves you write clean, robust SQL.)*
![T-SQL Stored Procedure Logic](images/sql_stored_procedure.png)

### 📊 3. Verification Query (Silver Layer)
To confirm the success of the transformation, the following query is executed to view the flattened data alongside the generated WKT (Well-Known Text) spatial coordinates:

```sql
SELECT TOP 20 
    Callsign, 
    OriginCountry, 
    Latitude,
    Longitude,
    SpatialLocation.STAsText() AS CoordinatePoint, 
    ProcessedTimestamp
FROM silver.FlightTracking
ORDER BY ProcessedTimestamp DESC;
