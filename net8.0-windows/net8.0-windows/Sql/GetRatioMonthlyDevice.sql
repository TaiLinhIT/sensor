CREATE OR ALTER PROCEDURE GetRatioMonthlyDevice (@month INT, @year INT)
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Xác định ngày bắt đầu và ngày kết thúc của tháng đã nhập
    DECLARE @NgayBatDau DATE = DATEFROMPARTS(@year, @month, 1);
    DECLARE @NgayKetThuc DATE = EOMONTH(@NgayBatDau);

    -- 2. Tính Mức tiêu thụ tuyệt đối (Max - Min của Imp + Exp) cho mỗi device
    WITH DeviceConsumption AS (
        SELECT
            A.devid,
            -- Tính mức tăng Imp
            (MAX(CASE WHEN B.Name = 'Imp' THEN A.Value END) - 
             MIN(CASE WHEN B.Name = 'Imp' THEN A.Value END)) AS MucTangImp,
            -- Tính mức tăng Exp
            (MAX(CASE WHEN B.Name = 'Exp' THEN A.Value END) - 
             MIN(CASE WHEN B.Name = 'Exp' THEN A.Value END)) AS MucTangExp
        FROM
            SensorData AS A
        INNER JOIN
            ControlCode AS B ON A.CodeID = B.CodeID
        WHERE
            A.day >= @NgayBatDau 
            AND A.day <= @NgayKetThuc
            AND B.Name IN ('Imp', 'Exp')
        GROUP BY
            A.devid
    ),
    -- 3. Tính Tổng mức tiêu thụ toàn bộ và Mức tiêu thụ cuối cùng của từng device
    FinalCalculation AS (
        SELECT
            devid,
            (MucTangImp + MucTangExp) AS TotalConsumption,
            SUM(MucTangImp + MucTangExp) OVER () AS TongTieuThuTatCa
        FROM
            DeviceConsumption
        WHERE
            (MucTangImp + MucTangExp) IS NOT NULL
            AND (MucTangImp + MucTangExp) > 0 
    )
    -- 4. JOIN với bảng devices để lấy tên và tính tỷ lệ phần trăm
    SELECT
        FC.devid,
        D.name AS DeviceName, -- <--- LẤY TÊN THIẾT BỊ
        FC.TotalConsumption,
        -- Tính tỷ lệ phần trăm
        ROUND((FC.TotalConsumption * 100.0) / FC.TongTieuThuTatCa, 2) AS Percentage
    FROM
        FinalCalculation AS FC
    INNER JOIN 
        devices AS D ON FC.devid = D.devid -- <--- THỰC HIỆN JOIN Ở ĐÂY
    ORDER BY
        Percentage DESC;
END;
