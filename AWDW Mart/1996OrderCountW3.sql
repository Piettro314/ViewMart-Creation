SELECT MONTH(OrderDate) as 'OrderMnth'
      ,Count(*) as 'OrderCnt'
FROM [w3].[Orders]
WHERE YEAR(OrderDate) = 1996
GROUP BY MONTH(OrderDate)