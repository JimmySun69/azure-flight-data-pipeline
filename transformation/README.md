## 🏗️ Phase 2: Silver Layer Transformation (T-SQL & Spatial)

Once the raw OpenSky JSON is landed in the `bronze` staging table, a custom T-SQL Stored Procedure (`silver.sp_ProcessFlightData`) is triggered by Azure Data Factory to transform the data into a structured, queryable format.

*(Insert your ADF pipeline success screenshot here)*
![ADF Pipeline Success](link-to-your-adf-screenshot.png)

### 🧠 Transformation Logic
The transformation process was engineered to handle three specific technical challenges:

1. **JSON Flattening:** Utilized `OPENJSON` with explicit path expressions to "shred" the complex nested array-of-arrays format typical of the OpenSky REST API.
2. **Schema & Type Enforcement:** Implemented `TRY_CAST` and `TRIM` functions to ensure telemetry data (Altitude, Velocity, TrueTrack) is stored as numeric types, preventing pipeline failures from unexpected "null" strings or empty fields.
3. **Temporal Normalization:** Converted the API's Unix Epoch timestamps (seconds since 1970) into standard SQL `DATETIME` formats using the `DATEADD` function for human-readable reporting.

### 🌍 Spatial Data Engineering
To enable advanced GIS analysis, this project implements native spatial objects:
* **Geography Constructor:** Converts raw Latitude and Longitude into a native `GEOGRAPHY` point object using the **SRID 4326** (WGS 84) standard.
* **Resiliency Logic:** Developed a `CASE` statement to validate coordinates (Lat: -90 to 90, Long: -180 to 180) before processing. This prevents "Parameter Null" errors common in live telemetry streams when an aircraft loses GPS lock.
* **Business Value:** This allows for high-performance spatial queries, such as calculating "distance to nearest airport" or identifying flights within specific "no-fly" zones.

### 🛠️ Stored Procedure Snippet (Spatial Logic)
```sql
-- Robust Point Creation Logic
CASE 
    WHEN Latitude IS NOT NULL AND Longitude IS NOT NULL 
    THEN geography::Point(Latitude, Longitude, 4326)
    ELSE NULL 
END AS SpatialLocation
