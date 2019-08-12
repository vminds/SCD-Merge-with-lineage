select * from dbo.CustomerStaging -- check the data in the customer staging table - this has been loaded via the PostDeployment script.
select * from dbo.vw_CustomerStaging -- slightly different results from the view - which is the SOURCE input for merge statements.
select * from dbo.DimCustomer -- first time, no records should exist here.

-- now run the DimCustomer_SCD1.dtsx package via the integration services project.
-- this will load the data from dbo.CustomerStaging into dbo.DimCustomer.
-- note you can run the stored procedures directly but then you will not have the SSISexecutionID into the lineage tables.
select * from dbo.Lineage
select * from dbo.LineageHistory
select * from dbo.LineageDetail
select * from dbo.LineageDetailHistory

-- update some record in staging, run _SCD1 package again and check the data and lineage tables.
update dbo.CustomerStaging set CustomerName='John Doe' where CustomerID=1 -- overwrites value in first record
select * from dbo.DimCustomer where BK=1 -- one updated record

-- now try the same for the _SCD2 package, if required you can truncate the dbo.DimCustomer upfront.
update dbo.CustomerStaging set CustomerName='Jane Doe' where CustomerID=1 -- marks customerID 1 as inactive and creates a new record
select * from dbo.DimCustomer where BK=1 -- one obsolete record, and one new.

