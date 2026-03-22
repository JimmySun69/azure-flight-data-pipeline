-- 1. Create the Medallion Schemas for organization
CREATE SCHEMA bronze;
GO
CREATE SCHEMA silver;
GO

-- 2. Create a Staging Table (Where ADF will dump the raw JSON)
CREATE TABLE bronze.Staging_OpenSky (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    RawJsonData NVARCHAR(MAX),
    IngestionTimestamp DATETIME DEFAULT GETUTCDATE()
);
GO

-- 3. Create the Structured Silver Table (With Spatial Geometry!)
CREATE TABLE silver.FlightTracking (
    FlightId INT IDENTITY(1,1) PRIMARY KEY,
    Icao24 NVARCHAR(50),
    Callsign NVARCHAR(50),
    OriginCountry NVARCHAR(100),
    Longitude FLOAT,
    Latitude FLOAT,
    Altitude FLOAT,
    Velocity FLOAT,
    TrueTrack FLOAT,
    SpatialLocation GEOGRAPHY, -- This is the Azure SQL version of PostGIS geometry
    LastContactTimestamp DATETIME,
    ProcessedTimestamp DATETIME DEFAULT GETUTCDATE()
);
GO

-- 4. Create the Stored Procedure to Flatten and Transform the Data
CREATE PROCEDURE silver.sp_ProcessFlightData
AS
BEGIN
    SET NOCOUNT ON;

    -- Extract the latest JSON payload from the staging table
    DECLARE @json NVARCHAR(MAX);
    SELECT TOP 1 @json = RawJsonData 
    FROM bronze.Staging_OpenSky 
    ORDER BY IngestionTimestamp DESC;

    -- Parse the nested JSON arrays and insert into the Silver table
    INSERT INTO silver.FlightTracking (
        Icao24, Callsign, OriginCountry, Longitude, Latitude, 
        Altitude, Velocity, TrueTrack, SpatialLocation, LastContactTimestamp
    )
    SELECT 
        JSON_VALUE(Value, '$[0]') AS Icao24,
        TRIM(JSON_VALUE(Value, '$[1]')) AS Callsign,
        JSON_VALUE(Value, '$[2]') AS OriginCountry,
        CAST(JSON_VALUE(Value, '$[5]') AS FLOAT) AS Longitude,
        CAST(JSON_VALUE(Value, '$[6]') AS FLOAT) AS Latitude,
        CAST(JSON_VALUE(Value, '$[7]') AS FLOAT) AS Altitude,
        CAST(JSON_VALUE(Value, '$[9]') AS FLOAT) AS Velocity,
        CAST(JSON_VALUE(Value, '$[10]') AS FLOAT) AS TrueTrack,
        
        -- Build the Spatial Point (Longitude, Latitude, SRID 4326)
        CASE 
            WHEN JSON_VALUE(Value, '$[5]') IS NOT NULL AND JSON_VALUE(Value, '$[6]') IS NOT NULL 
            THEN geography::Point(
                    CAST(JSON_VALUE(Value, '$[6]') AS FLOAT), 
                    CAST(JSON_VALUE(Value, '$[5]') AS FLOAT), 
                    4326)
            ELSE NULL 
        END AS SpatialLocation,

        -- Convert Unix Epoch time to standard SQL DateTime
        DATEADD(second, CAST(JSON_VALUE(Value, '$[4]') AS INT), '1970-01-01') AS LastContactTimestamp

    -- The OpenSky data array is located under the "states" key
    FROM OPENJSON(@json, '$.states');

    -- Optional: Clean up staging table to save free-tier space
    TRUNCATE TABLE bronze.Staging_OpenSky;
END;
GO
