CREATE OR ALTER  PROCEDURE Sensordata12monthbydevid (@devid INT)
AS
BEGIN
    -- Xác định ngày cuối tháng hiện tại
    DECLARE @NgayKetThuc DATE = EOMONTH(GETDATE()); 
    -- Xác định ngày bắt đầu (11 tháng trước ngày cuối tháng hiện tại)
    DECLARE @NgayBatDau DATE = DATEADD(month, -11, @NgayKetThuc);

    -- 1. Tạo chuỗi 12 tháng hoàn chỉnh (Recursive CTE)
    WITH MonthSeries AS (
        SELECT @NgayBatDau AS ThangDauTien
        UNION ALL
        SELECT DATEADD(month, 1, ThangDauTien)
        FROM MonthSeries
        WHERE DATEADD(month, 1, ThangDauTien) <= @NgayKetThuc
    ),
    -- 2. Tính toán mức tăng thực tế (Dữ liệu thực tế)
    ActualConsumption AS (
        SELECT
            EOMONTH(A.day) AS ThangKetThuc, -- Chuẩn hóa ngày về cuối tháng để JOIN
            (MAX(CASE WHEN B.Name = 'Imp' THEN A.Value END) - MIN(CASE WHEN B.Name = 'Imp' THEN A.Value END)) AS MucTangImp,
            (MAX(CASE WHEN B.Name = 'Exp' THEN A.Value END) - MIN(CASE WHEN B.Name = 'Exp' THEN A.Value END)) AS MucTangExp
        FROM
            SensorData AS A
        INNER JOIN
            ControlCode AS B ON A.CodeID = B.CodeID
        WHERE
            A.devid = @devid
            AND A.day >= DATEADD(month, -12, GETDATE()) -- Lọc dữ liệu thô
            AND B.Name IN ('Imp', 'Exp')
        GROUP BY
            EOMONTH(A.day)
    )
    -- 3. LEFT JOIN chuỗi 12 tháng với dữ liệu thực tế
    SELECT
        YEAR(S.ThangDauTien) AS Nam,
        MONTH(S.ThangDauTien) AS Thang,
        -- Sử dụng COALESCE để gán 0 nếu không có dữ liệu (NULL)
        COALESCE(C.MucTangImp, 0) AS DataImp,
        COALESCE(C.MucTangExp, 0) AS DataExp,
        -- Tổng hợp cuối cùng
        COALESCE(C.MucTangImp, 0) + COALESCE(C.MucTangExp, 0) AS TongMucTang
    FROM
        MonthSeries AS S
    LEFT JOIN
        ActualConsumption AS C ON EOMONTH(S.ThangDauTien) = C.ThangKetThuc
    ORDER BY
        S.ThangDauTien
    OPTION (MAXRECURSION 36); -- Tăng MAXRECURSION để đảm bảo đủ 12 tháng (và hơn nếu cần)
END;
