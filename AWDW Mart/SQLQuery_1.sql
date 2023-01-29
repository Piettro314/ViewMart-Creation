Use w3schools
Go

Select prd.ProductID as 'kProd'
	  ,cat.CategoryID as 'kCat'
	  ,cat.CategoryName
	  ,cat.[Description] as 'CategoryDesc'
	  ,prd.*
From w3.Products prd
	left join [w3].[Categories] cat
	on prd.ProductID = cat.CategoryID