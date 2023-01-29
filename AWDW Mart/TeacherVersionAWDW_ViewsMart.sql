/* -- Pat's STARTER Script
 Target is AWDW - source is AdventureWorks 2019
 AWDW requires the following schemas:
    --  CREATE DATABASE AWDWpt2
	GO
	CREATE SCHEMA stg
	GO
	CREATE SCHEMA vw
	GO
	CREATE SCHEMA dim
	GO
*/
USE AWDWpt2;
GO

-- Drop ALL views that have schema binding prior to staging loads 
DROP VIEW if exists vw.dProduct;
GO 
/* 
	Staging tables for the production dimension
*/
DROP TABLE if exists stg.Product;

GO
SELECT *
INTO stg.Product
FROM AdventureWorks2019.Production.Product
; -- 504

GO

DROP TABLE if exists stg.ProductSubCategory;

GO
SELECT *
INTO stg.ProductSubCategory
FROM AdventureWorks2019.Production.ProductSubcategory
; -- 37

GO

DROP TABLE if exists stg.ProductCategory;

GO
SELECT *
INTO stg.ProductCategory
FROM AdventureWorks2019.Production.ProductCategory
; -- 4

GO

DROP TABLE if exists stg.Store;

GO -- XML fields ommited
SELECT BusinessEntityID
     , [Name]
	 , [SalesPersonID]
INTO stg.Store
FROM AdventureWorks2019.Sales.Store
GO

DROP TABLE if exists stg.SalesPerson;

SELECT sp.BusinessEntityID as 'SalesPersonID'
      ,p.FirstName + ' ' + p.LastName as 'SalesPerson'
	  ,p.PersonType
INTO stg.SalesPerson
FROM AdventureWorks2019.Sales.SalesPerson sp 
		INNER JOIN AdventureWorks2019.Person.Person p
		ON sp.BusinessEntityID = p.BusinessEntityID
; -- 17 rows
GO                                                                                                          

INSERT INTO stg.SalesPerson 
   VALUES(-99, 'No SalesPerson', 'NS')

GO

DROP TABLE if exists stg.Channel;
GO
SELECT OnlineOrderFlag
	 ,IIF(OnlineOrderFlag = 0, 'Retail', 'Online') as 'Channel'
INTO stg.Channel
FROM AdventureWorks2019.Sales.SalesOrderHeader
GROUP BY OnlineOrderFlag
;

GO
DROP TABLE if exists stg.Store;

GO -- XML fields ommited
SELECT BusinessEntityID
     , [Name]
	 , [SalesPersonID]
INTO stg.Store
FROM AdventureWorks2019.Sales.Store

GO

DROP TABLE if exists stg.Customer;

SELECT CustomerID
	  ,PersonID
	  ,StoreID
	  ,TerritoryID
INTO stg.Customer
FROM AdventureWorks2019.Sales.Customer
;

GO

DROP TABLE if exists stg.SalesTerritory;

SELECT TerritoryID	
	  ,[Name] as 'SalesTerritory'
	  ,CountryRegionCode as 'CountryCode'
	  ,CASE
			WHEN CountryRegionCode = 'US' THEN 'United States'
			WHEN CountryRegionCode = 'CA' THEN 'Canada'
			WHEN CountryRegionCode = 'FR' THEN 'France'
			WHEN CountryRegionCode = 'DE' THEN 'Germany'
			WHEN CountryRegionCode = 'AU' THEN 'Australia'
			WHEN CountryRegionCode = 'GB' THEN 'Great Britain'
		ELSE 'Error'
	   END as 'SalesCountry'
	  ,[Group] as 'SalesGroup'
INTO stg.SalesTerritory
FROM AdventureWorks2019.Sales.SalesTerritory
;
GO

DROP TABLE if EXISTS stg.ShipMethod;
GO
SELECT ShipMethodID
	  ,[Name] as 'ShipMethod'
INTO stg.ShipMethod
FROM AdventureWorks2019.Purchasing.ShipMethod
;
GO

DROP TABLE if exists stg.SpecialOffer;
GO
SELECT SpecialOfferID as 'bkSpecOfferID'
      ,Description as 'SpecialOfferDesc'
      ,DiscountPct
      ,Type as 'SpecialOfferType'
      ,Category as 'SpecialOfferCategory'
      ,cast(StartDate as date) as 'StartDate'
      ,cast(EndDate as date) as 'EndDate'
      ,MinQty
      ,MaxQty
INTO stg.SpecialOffer
FROM AdventureWorks2019.Sales.SpecialOffer




GO

/* 
	Create the Calender table dim.Calendar 
	-- then create vw.dCalendar
*/

DROP TABLE if exists dim.Calendar;
GO

DECLARE @StartDate  date;
SET @StartDate = '20110101';

DECLARE @CutoffDate date;
SET @CutoffDate = DATEADD(DAY, -1, DATEADD(YEAR, 7, @StartDate));

-- CHANGE NOTHING BELOW THIS LINE -- 
;WITH seq(n) AS 
(
  SELECT 0 UNION ALL SELECT n + 1 
  FROM seq
  WHERE n < DATEDIFF(DAY, @StartDate, @CutoffDate)
),
d(d) AS 
(
  SELECT DATEADD(DAY, n, @StartDate) 
  FROM seq
),
src AS
(
  SELECT
    bkDateKey    = CAST(REPLACE(CONVERT(varchar(10), d),'-','') as INT),
	Date         = CONVERT(date, d),
    DayOfMonth   = DATEPART(DAY,       d),
    DayName      = DATENAME(WEEKDAY,   d),
    WeekOfYear   = DATEPART(WEEK,      d),
    ISOWeek      = DATEPART(ISO_WEEK,  d),
    DayOfWeek    = DATEPART(WEEKDAY,   d),
    Month        = DATEPART(MONTH,     d),
    MonthName    = DATENAME(MONTH,     d),
	MonthAbbrev  = LEFT(DATENAME(MONTH, d),3),
    Quarter      = DATEPART(Quarter,   d),
	Qtr          = (CASE 
					   WHEN DATEPART(Quarter,   d) = 1 THEN 'Q1'
					   WHEN DATEPART(Quarter,   d) = 2 THEN 'Q2'
					   WHEN DATEPART(Quarter,   d) = 3 THEN 'Q3'
					   WHEN DATEPART(Quarter,   d) = 4 THEN 'Q4'
					 ELSE 'Err'
				   END),
    Year         = DATEPART(YEAR,      d),
    FirstOfMonth = DATEFROMPARTS(YEAR(d), MONTH(d), 1),
    LastOfYear   = DATEFROMPARTS(YEAR(d), 12, 31),
    DayOfYear    = DATEPART(DAYOFYEAR, d)
  FROM d
)
SELECT * 
INTO dim.Calendar
FROM src
  ORDER BY Date
  OPTION (MAXRECURSION 0);
GO
/*
	Creating the Calendar Dim *View*
*/
CREATE or ALTER VIEW vw.dCalendar
as
SELECT *
FROM dim.Calendar;

GO

GO
/*
	Creating the Product Dim *View*
*/
CREATE or ALTER VIEW vw.dProduct
   WITH SCHEMABINDING
AS
SELECT prod.ProductID as 'bkProductID'
	  ,cat.ProductCategoryID
	  ,cat.[Name] as 'ProductCategory'
	  ,sc.ProductSubcategoryID 
	  ,sc.[Name] as 'ProductSubCategory'
	  ,prod.ProductID
	  ,prod.[Name] as 'ProductName'
	  ,prod.ProductNumber as 'ProductNumber'
-- All below are attributes --
	 , IIF(prod.ProductSubcategoryID is NULL, 'Y', 'N')as 'OrphanProducts'
FROM stg.Product prod
     INNER JOIN stg.ProductSubCategory sc
	  ON prod.ProductSubcategoryID = sc.ProductSubcategoryID
	 INNER JOIN stg.ProductCategory cat
	   ON sc.ProductCategoryID = cat.ProductCategoryID
; -- 504  -- 295 intersected
GO

CREATE UNIQUE CLUSTERED INDEX IDX_PRODUCT
  ON vw.dProduct(bkProductID)



/*
	Creating the SpecialOffer Dim *View*
*/
GO
CREATE or ALTER VIEW vw.dSpecialOffer
AS
SELECT *
FROM stg.SpecialOffer

GO
CREATE or ALTER VIEW vw.dSalesPerson
AS 
SELECT * 
FROM stg.SalesPerson;
GO



CREATE or ALTER VIEW vw.dChannel
AS
SELECT *
FROM stg.Channel;
GO

DROP TABLE if exists stg.Person;
GO
SELECT BusinessEntityID
      ,PersonType
	  ,FirstName + ' ' + LastName as 'Customer'
INTO stg.Person
FROM [AdventureWorks2019].PERSON.[Person]
;
GO

CREATE or ALTER VIEW vw.dShipMethod
AS
SELECT *
FROM stg.ShipMethod
;
GO

CREATE or ALTER VIEW vw.dCustomer
AS
SELECT cus.CustomerID
--    ,cus.PersonID
--	  ,per.Customer
	  ,ISNULL(per.PersonType, 'NA') as 'PersonType'
 --   ,cus.StoreID
--	  ,st.[Name] as 'Store'
	  ,(CASE
		  WHEN st.[Name] is NOT NULL THEN cus.StoreID
	      ELSE cus.PersonID
	   END) as 'SoldToID'
	  ,(CASE
		  WHEN st.[Name] is NOT NULL THEN st.[Name]
	      ELSE per.Customer
	   END) as 'SoldToCust'
	   ,IIF(st.[Name] is NOT NULL, 1, 0) as 'StoreFlag'
FROM stg.Customer cus
	LEFT OUTER JOIN stg.Person per
	ON cus.PersonID = per.BusinessEntityID
	LEFT OUTER JOIN stg.Store st
	ON cus.StoreID = st.BusinessEntityID
-- WHERE per.PersonType is null

;
; -- 19820
GO

CREATE or ALTER VIEW vw.dSalesTerritory
AS
SELECT *
FROM stg.SalesTerritory 
;
GO


/**********		FACT Tables Build	 **********/
/*
	Import tables to create fSales 
*/

DROP TABLE if EXISTS stg.SalesOrderDetail;

GO
SELECT *
INTO stg.SalesOrderDetail
FROM AdventureWorks2019.Sales.SalesOrderDetail
; -- 121,317

GO
DROP TABLE if EXISTS stg.SalesOrderHeader;

GO
SELECT *
INTO stg.SalesOrderHeader
FROM AdventureWorks2019.Sales.SalesOrderHeader
; -- 31,465

/*
	Create and / or update vw.fSales 
*/
GO
CREATE or ALTER VIEW vw.fSales
AS
SELECT h.SalesOrderID
	  ,row_number() OVER 
	      (PARTITION by h.SalesOrderID ORDER by h.SalesOrderID) as 'LineItem'
	  ,c.bkDateKey
	  ,h.OnlineOrderFlag 
	  ,h.CustomerID
	  ,isnull(h.SalesPersonID, -99) as 'SalesPersonID'
--	  ,h.SalesPersonID
	  ,h.TerritoryID
	  ,h.ShipMethodID
	  ,d.ProductID
	  ,d.SpecialOfferID
	  ,DATEDIFF(DAY, h.OrderDate, h.ShipDate) as 'DaysToShip'
	  ,d.OrderQty
	  ,d.UnitPrice
	  ,d.UnitPriceDiscount
	  ,(CASE 
			WHEN d.UnitPriceDiscount = 0.00 
			THEN d.OrderQty * d.UnitPrice 
	    ELSE (d.OrderQty * d.UnitPrice) * (1 - d.UnitPriceDiscount)
		END) as 'SubTotal'
	  ,d.LineTotal
FROM stg.SalesOrderHeader h
	INNER JOIN stg.SalesOrderDetail d
	ON h.SalesOrderID = d.SalesOrderID
	INNER JOIN dim.Calendar c
	ON h.OrderDate = c.[Date]
;
GO

