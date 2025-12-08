CREATE OR ALTER PROCEDURE GetLatestSensorByDevice
    @devid INT
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH LatestData AS
    (
        SELECT 
            devid,
            codeid,
            value,
            day,
            logid,
            ROW_NUMBER() OVER (
                PARTITION BY devid, codeid 
                ORDER BY logid DESC
            ) AS rn
        FROM SensorData
        WHERE devid = @devid
    )
    SELECT 
        devid,
        codeid,
        value,
        day,
        logid -- Đã bổ sung
    FROM LatestData
    WHERE rn = 1
    ORDER BY codeid;
END
