SELECT 

OrderDate, 
COUNT(*) AS Orders_cnt
FROM AdventureWorksDW2019.dbo.FactInternetSales

GROUP BY OrderDate
HAVING COUNT(*) < 100
ORDER BY Orders_cnt DESC