/*
	Target it AWDW - Source is Adventureworks 2019
	AWDW required the following schemas:
		Go
		Create schema stg
		GO
		Create schema vw
		GO
		Create schema dim
		GO
*/

Use AWDW;
GO

--Drop ALL Views that have schema binding prior to Staging loads
Drop VIEW if exists Vw.dproduct;

GO

/*
	Staging table for the production
*/

DROP TABLE if exists stg.product;

GO

Select *
Into stg.Product
From AdventureWorks2019.Production.Product
;--504

GO

DROP TABLE if exists stg.ProductSubCategory

GO
Select *
Into stg.ProductSubCategory
From AdventureWorks2019.Production.ProductSubcategory
;--37

GO 

DROP TABLE if exists stg.ProductCategory

GO
Select *
Into stg.ProductCategory
From AdventureWorks2019.Production.ProductCategory
;--4
Go

/*
	Creating Product Dim *View*
*/
Create or ALTER view Vw.dProduct
	WITH SCHEMABINDING
AS
Select prod.ProductID as 'bkProductID'
	  ,cat.ProductCategoryID
	  ,cat.[Name] as 'ProductCategory'
	  ,sc.ProductSubcategoryID
	  ,sc.[Name] as 'ProductSubCategory'
	  ,prod.ProductID 
	  ,prod.[Name] as 'ProductName'
	  ,prod.ProductNumber as 'ProductNumber'
-- All below are attributes --
	  ,IIF(prod.ProductSubcategoryID is null, 'Y', 'N')as 'OrphanProducts'
From stg.Product prod
	INNER JOIN stg.ProductSubCategory sc
		ON prod.ProductSubcategoryID = sc.ProductSubcategoryID
	INNER JOIN	stg.ProductCategory cat
		ON sc.ProductCategoryID = cat.ProductCategoryID
GO

CREATE UNIQUE CLUSTERED INDEX IDX_Product
	on Vw.dProduct(bkProductID)
GO

/*
Create Indexed View
CREATE UNIQUE CLUSTERED INDEX IDX_EXAMPLE_V1
   ON schema.ExampleView (kfield);
FROM schema.ExampleView as vw WITH (NOEXPAND) 
*/
;--504 --295 intersected

Drop table if exists dim.Calendar;

Go

DECLARE @StartDate  date;
Set @StartDate = '20110101';

DECLARE @CutoffDate date; 
Set @CutoffDate = DATEADD(DAY, -1, DATEADD(YEAR, 4, @StartDate));

--Change nothing below this line --
;WITH seq(n) AS 
(
  SELECT 0 UNION ALL SELECT n + 1 FROM seq
  WHERE n < DATEDIFF(DAY, @StartDate, @CutoffDate)
),
d(d) AS 
(
  SELECT DATEADD(DAY, n, @StartDate) FROM seq
),
src AS
(
  SELECT
  	bkDateKey	 = CAST(REPLACE(CONVERT(varchar(10), d),'-','') as INT),
    Date         = CONVERT(date, d),
    DayofMonth   = DATEPART(DAY,       d),
    DayName      = DATENAME(WEEKDAY,   d),
    WeekOfYear   = DATEPART(WEEK,      d),
    ISOWeek      = DATEPART(ISO_WEEK,  d),
    DayOfWeek    = DATEPART(WEEKDAY,   d),
    Month        = DATEPART(MONTH,     d),
    MonthName    = DATENAME(MONTH,     d),
	MonthAbbrev  = LEFT(DATENAME(MONTH, d),3),
    Quarter      = DATEPART(Quarter,   d),
	Qtr          =(Case
						When DATEPART(QUARTER,    d) = 1 THEN 'Q1'
						When DATEPART(QUARTER,    d) = 2 THEN 'Q2'
						When DATEPART(QUARTER,    d) = 3 THEN 'Q3'
						When DATEPART(QUARTER,    d) = 4 THEN 'Q4'
					  ELSE 'Err'
				    End),

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

Create or ALTER view Vw.dCalendar
as
SELECT [bkDateKey]
      ,[Date]
      ,[DayofMonth]
      ,[DayName]
      ,[WeekOfYear]
      ,[ISOWeek]
      ,[DayOfWeek]
      ,[Month]
      ,[MonthName]
      ,[MonthAbbrev]
      ,[Quarter]
      ,[Qtr]
      ,[Year]
      ,[FirstOfMonth]
      ,[LastOfYear]
      ,[DayOfYear]
  FROM dim.Calendar
  
GO

/************ Fact Table Build ************/
/*
	Import Tables to create fSales
*/
Drop Table if exists stg.SalesOrderDetail

GO
Select *
Into stg.SalesOrderDetail
From AdventureWorks2019.Sales.SalesOrderDetail
;--121,317


Go
Drop Table if exists stg.SalesOrderHeader
Go

Select *
Into stg.SalesOrderHeader
From AdventureWorks2019.Sales.SalesOrderHeader
; -- 31465


Go

Drop Table if exists stg.SpecialOffer

Go

Select *
INTO stg.SpecialOffer
From AdventureWorks2019.Sales.SpecialOffer
; --16

Go
/* 
	Create fSales View using the necesssary joins of the imported fact tables above
*/
Create or ALter view Vw.fSales
as
Select sod.SalesOrderID
	  ,ROW_NUMBER() Over
				(Partition by sod.SalesOrderID Order by sod.SalesOrderID) as 'LineItem'
	  ,cal.bkDateKey
	  ,soh.OnlineOrderFlag as 'OnlineOrderFlag'
	  ,soh.CustomerID as 'CustomerID'
	  ,ISNULL(soh.SalesPersonID, -99) as 'SalesPersonID'
	  ,soh.TerritoryID
	  ,soh.ShipMethodID
	  ,sod.ProductID
	  ,sod.SpecialOfferID
	  ,DATEDIFF(DAY,soh.OrderDate, soh.ShipDate) as 'DaysToShip'
	  ,sod.OrderQty
	  ,Cast(sod.UnitPrice as money) as 'UnitPrice'
	  ,sod.UnitPriceDiscount
	  ,Cast(((sod.UnitPrice*OrderQty)*(1+sod.UnitPriceDiscount)) as money) as 'Subtotal'
	  ,Cast(sod.LineTotal as money) as 'Linetotal'
From stg.SalesOrderDetail sod
	Inner Join stg.SalesOrderHeader soh 
	on sod.SalesOrderID = soh.SalesOrderID
	Inner Join dim.Calendar cal
	on cal.[Date] = soh.OrderDate
--Where soh.SalesPersonID is null
;--121317
Go 

/*

	Create Look up Dimension for Comparsion Online vs Retail Sales 

*/

Create or Alter view Vw.dChannel
as
Select soh.OnlineOrderFlag
      ,IIF(soh.OnlineOrderFlag=0, 'Retail', 'Online') as 'SalesChannel' 
From stg.SalesOrderHeader soh
Group by soh.OnlineOrderFlag
;--

Go
/*

	Import tables to create customer view

*/

Drop Table if exists stg.Customer

Go

Select *
Into stg.Customer
From AdventureWorks2019.Sales.Customer
;
--19820

Go

Drop table if exists stg.Person

Go

Select BusinessEntityID
	, PersonType
	, NameStyle 
	, Title 
	, FirstName 
	, MiddleName 
	, LastName 
	, Suffix 
	, EmailPromotion
Into stg.Person
From AdventureWorks2019.Person.Person
;
--19972

Go

Drop Table if exists stg.Store

Go

Select BusinessEntityID 
      ,[Name] 
	  ,SalesPersonID 
Into stg.Store
From AdventureWorks2019.Sales.Store
;
--701
Go

Drop table if exists stg.SalesTerritory

Go

Select *
Into stg.SalesTerritory
From AdventureWorks2019.Sales.SalesTerritory
;-- 10
Go

Create or Alter View Vw.dSalesTerritory
as
Select TerritoryID as 'bkTerritoryID'
	  ,[Name] as 'SalesTerritory'
	  ,CountryRegionCode as 'CountryCode'
	  ,(Case
			When CountryRegionCode = 'US' Then 'United States'
			When CountryRegionCode = 'CA' Then 'Canada'
			When CountryRegionCode = 'FR' Then 'France'
			When CountryRegionCode = 'DE' Then 'Germany'
			When CountryRegionCode = 'AU' Then 'Australia'
			When CountryRegionCode = 'GB' Then 'United Kindom'
		End) as 'SalesCountry'
	  ,[Group] as 'SalesGroup'
From stg.SalesTerritory

GO

/*

	Create Customer View

*/

Create or Alter View Vw.dCustomer
as
Select c.CustomerID as 'bkCustomerID'
--	  ,c.PersonID
--	  ,CONCAT_WS(' ', FirstName, LastName) as 'CustomerName'
	  ,IsNull(p.PersonType, 'NA') as 'PersonType'
--	  ,c.StoreID
--	  ,s.[Name] as 'Store'
	  ,(Case
			When s.[Name] is not null Then c.StoreID
			Else c.PersonID
		End) as 'SoldToID'
	  ,(Case
			When s.[Name] is not null Then s.[Name]
			Else CONCAT_WS(' ', FirstName, LastName)
		End)as 'SoldToCust'
	  , IIF (s.Name is not null, 1, 0) as 'StoreFlag'
From stg.Customer c
	Left outer join stg.Person p
	on c.PersonID = p.BusinessEntityID
	Left outer join stg.Store s
	on c.StoreID = s.BusinessEntityID
;
--19820
Go

Drop table if exists stg.SalesPerson

Go

Select sp.BusinessEntityID as 'SalesPersonID'
	  ,p.FirstName + ' ' + p.LastName as 'SalesPerson'
	  ,p.PersonType
Into stg.SalesPerson
From AdventureWorks2019.Sales.SalesPerson sp
	Inner Join AdventureWorks2019.Person.Person p
	On sp.BusinessentityID = p.BusinessEntityID
;
--17

Go

/*

	Create SalePerson view

*/

Create or Alter View Vw.dSalesPerson
as
SELECT *
FROM stg.SalesPerson
;
  -- 17
 GO

INSERT INTO Vw.dSalesPerson 
	VALUES (-99, 'No SalesPerson', 'NS')

 GO

/* 
	Create Special Offer View

*/

Create or Alter View Vw.dSpecialOffer
as
Select so.SpecialOfferID as 'bkSpecialOfferID'
	,so.[Description] as 'SpecialOfferDesc'
	,so.DiscountPct
	,so.[Type] as 'SpecialOfferType'
	,so.Category as 'SpecialOfferCategory'
	,Cast(so.StartDate as date) as 'StartDate'
	,Cast(so.EndDate as date) as 'EndDate'
	,so.MinQty
	,so.MaxQty
From stg.SpecialOffer so

; --16

GO
/*
	Import table for ShipMethod
*/
Drop table if exists stg.ShipMethod 

Go

Select *
Into stg.ShipMethod
From AdventureWorks2019.Purchasing.ShipMethod

Go 

Create or alter view Vw.dShipMethod
as

Select ShipMethodID
	  , [Name] as 'Method'
From stg.ShipMethod

Go