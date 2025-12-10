    CREATE OR ALTER PROCEDURE GetLatestSensorByDeviceYear
    @year INT
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH LatestData AS (
        SELECT 
            sd.devid,
            sd.codeid,
            sd.value,
            sd.day,
            ROW_NUMBER() OVER(
                PARTITION BY sd.devid, sd.codeid
                ORDER BY sd.day DESC
            ) AS rn
        FROM SensorData sd
        WHERE YEAR(sd.day) = @year
    )
    SELECT 
        ld.devid,
        d.name AS device_name,
        ROUND(
            SUM(CASE WHEN c.name = 'Imp' THEN ld.value ELSE 0 END) +
            SUM(CASE WHEN c.name = 'Exp' THEN ld.value ELSE 0 END)
        , 2) AS TotalValue
    FROM LatestData ld
    JOIN controlcode c 
        ON ld.codeid = c.codeid
    JOIN devices d
        ON ld.devid = d.devid
    WHERE ld.rn = 1
      AND c.name IN ('Imp','Exp')
    GROUP BY ld.devid, d.name
    ORDER BY ld.devid;

END
