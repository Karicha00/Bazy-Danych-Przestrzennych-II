-- Oracle:


SELECT column_name,
       data_type,
       data_length,
       nullable
FROM user_tab_columns
WHERE table_name = 'FACTINTERNETSALES';

-- PostgreSQL:

SELECT column_name,
       data_type,
       is_nullable
FROM information_schema.columns
WHERE table_name = 'factinternetsales';

--MySQL:

SELECT column_name,
       data_type,
       character_maximum_length,
       is_nullable
FROM information_schema.columns
WHERE table_schema = 'dbo'
  AND table_name = 'FactInternetSales';