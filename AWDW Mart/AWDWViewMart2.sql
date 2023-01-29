Use AWDWpt2;
GO
/*
	The Business requirement is as follows:
	-Total sales by order
	-Total Sales at order level
	-line item count
	-by country 
	-by channel
	-by date, by month, by year 
*/

Create or ALTER PROCEDURE spSalesByOrder
as
SELECT f.SalesOrderID
	  ,ca.[Year]
	  ,ca.Qtr
	  ,ca.[Quarter]
	  ,ca.[Date] 
	  ,ca.[Month] 
	  ,ca.[MonthName]
	  ,ter.SalesCountry 
	  ,ch.Channel 
	  ,Max(f.lineitem) as 'LineItemCnt'
	  ,Sum(f.LineTotal) as 'TotalSales'
FROM Vw.fSales f
	Inner Join vw.dCalendar ca
	on f.bkDateKey = ca.bkDateKey
	Inner Join vw.dChannel ch
	on f.OnlineOrderFlag = ch.OnlineOrderFlag
	Inner Join vw.dSalesTerritory ter
	on f.TerritoryID = ter.TerritoryID
Group by   f.SalesOrderID
		  ,ca.[Year]
		  ,ca.[Quarter]
		  ,ca.Qtr
		  ,ca.[Date] 
		  ,ca.[Month] 
		  ,ca.[MonthName]
		  ,ter.SalesCountry 
		  ,ch.Channel 
Order by f.SalesOrderID
;
--31,465
GO


--EXEC spSalesByOrder;

GO
/*
	Summary Fact Table for sale- agg to the order grain 
*/

CREATE or Alter View vw.fSalesSummary
AS
SELECT SalesOrderID
	  ,bkDateKey
	  ,OnlineOrderFlag
	  ,CustomerID
	  ,SalesPersonID
	  ,TerritoryID
	  ,ShipMethodID
	  ,max(Lineitem) as 'LineItemCnt'
	  ,Sum(SubTotal) as 'TotalAmount'
FROM vw.fSales
GROUP BY   SalesOrderID
		  ,bkDateKey
		  ,OnlineOrderFlag
		  ,CustomerID
		  ,SalesPersonID
		  ,TerritoryID
		  ,ShipMethodID
;
Go