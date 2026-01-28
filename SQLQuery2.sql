SELECT * FROM (
    SELECT
        OrderDate,
        ProductKey,
        UnitPrice,
        ROW_NUMBER() OVER (
            PARTITION BY OrderDate
            ORDER BY UnitPrice DESC
        ) AS rn
    FROM AdventureWorksDW2019.dbo.FactInternetSales
    ) t
where rn <= 3