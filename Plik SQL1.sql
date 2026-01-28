CREATE OR ALTER PROCEDURE procedura_s401001
    @YearsAgo INT
AS
BEGIN
    SELECT *     FROM dbo.DimCurrency AS dc
    INNER JOIN dbo.FactCurrencyRate AS fcr 
    ON dc.CurrencyKey = fcr.CurrencyKey
    WHERE dc.CurrencyAlternateKey IN ('EUR', 'GBP')
    AND fcr.Date <= DATEADD(YEAR, -@YearsAgo, GETDATE());
END;
GO


EXEC procedura_s401001 @YearsAgo = 14;


