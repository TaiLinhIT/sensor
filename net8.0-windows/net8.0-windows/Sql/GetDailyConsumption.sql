CREATE OR ALTER PROCEDURE GetDailyConsumption (@devid INT)
AS
BEGIN
    -- 1. Xác định ngày bắt đầu và ngày kết thúc
    -- Ngày kết thúc là ngày hôm nay
    DECLARE @NgayKetThuc DATE = CAST(GETDATE() AS DATE); 
    -- Ngày bắt đầu là 30 ngày (tính cả hôm nay) trước ngày kết thúc
    DECLARE @NgayBatDau DATE = DATEADD(day, -29, @NgayKetThuc); 

    -- 2. Tạo chuỗi 30 ngày hoàn chỉnh (Recursive CTE)
    -- Đảm bảo có đủ 30 ngày liên tục trong kết quả
    WITH DateSeries AS (
        SELECT @NgayBatDau AS dayData
        UNION ALL
        SELECT DATEADD(day, 1, dayData)
        FROM DateSeries
        WHERE DATEADD(day, 1, dayData) <= @NgayKetThuc -- Bao gồm ngày hôm nay
    ),
    
    -- 3. Tính toán mức tiêu thụ thực tế (Consumption) cho mỗi ngày
    DailyConsumption AS (
        SELECT
            CAST(A.day AS DATE) AS NgayThucTe,
            
            -- Tính mức tăng Imp trong ngày: MAX(hiện tại) - MIN(đầu ngày)
            (MAX(CASE WHEN B.Name = 'Imp' THEN A.Value END) - 
             MIN(CASE WHEN B.Name = 'Imp' THEN A.Value END)) AS MucTangImp,
             
            -- Tính mức tăng Exp trong ngày: MAX(hiện tại) - MIN(đầu ngày)
            (MAX(CASE WHEN B.Name = 'Exp' THEN A.Value END) - 
             MIN(CASE WHEN B.Name = 'Exp' THEN A.Value END)) AS MucTangExp
             
        FROM
            SensorData AS A
        INNER JOIN
            ControlCode AS B ON A.CodeID = B.CodeID
        WHERE
            A.devid = @devid
            -- Chỉ lấy dữ liệu nằm trong 30 ngày cần xét
            AND A.day >= @NgayBatDau 
            AND A.day < DATEADD(day, 1, @NgayKetThuc) -- Bao gồm toàn bộ ngày hôm nay
            AND B.Name IN ('Imp', 'Exp')
        GROUP BY
            CAST(A.day AS DATE) -- Nhóm theo từng ngày
    )
    
    -- 4. LEFT JOIN chuỗi 30 ngày với dữ liệu tính toán và tổng hợp
    SELECT
        S.dayData,
        -- Tổng hợp mức tăng của Imp và Exp, gán 0 cho các ngày không có dữ liệu
        COALESCE(C.MucTangImp, 0) + COALESCE(C.MucTangExp, 0) AS TotalDailyConsumption
    FROM
        DateSeries AS S
    LEFT JOIN
        DailyConsumption AS C ON S.dayData = C.NgayThucTe
    ORDER BY
        S.dayData
    OPTION (MAXRECURSION 31); -- Đảm bảo đủ 30 ngày
END;
