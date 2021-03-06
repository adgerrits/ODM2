-------------------------------------------------------------------------------
-- Created by:  Jeff Horsburgh
-- This script copies an ODM 1.1.1 Database to a blank ODM2 database
--
-- Requirements:
-- 1.  The ODM2 Database must already exist and it must have all of the ODM2 
--     objects in it
-- 2.  The ODM2 controlled vocabularies should be loaded into the ODM2 
--     database prior to running this script.
-- 2.  The ODM2 database must not contain any data prior to running this script
-- 3.  Right now it is hard-coded to an ODM 1.1.1 database called 
--     "LittleBearRiverODM" and an ODM2 database called "ODM2" - these names 
--     will need to be changed for running on other database names
-- 4.  No other processes adding data to the ODM2 database while this is being 
--     run
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
--Populate the ODM2 SamplingFeatures, SpatialReferences, and Sites tables
--NOTES:
--1.  Uses the SiteIDs from the ODM 1.1.1 database to populate 
--    SamplingFeatureID  
--2.  Currently uses the LatLongDatumID as SpatialReferenceID
-------------------------------------------------------------------------------

--Populate the ODM2.SpatialReferences table with the SpatialReferences that 
--were used in the ODM 1.1.1 database
--TODO:  If we eventually provide a list of spatial references for ODM2, this
--part of the code will have to be fixed to match spatial references by name
SET IDENTITY_INSERT ODM2.ODM2.SpatialReferences ON;
INSERT INTO ODM2.ODM2.SpatialReferences (SpatialReferenceID, SRSCode, SRSName, 
	SRSDescription, SRSLink)
SELECT SpatialReferenceID, 'CUAHSI:' + CAST(SRSID AS VARCHAR(50)) AS SRSCode, 
	SRSName, CAST(Notes AS VARCHAR(500)) AS SRSDescription, 
	'http://his.cuahsi.org/mastercvreg/edit_cv11.aspx?tbl=SpatialReferences' 
	AS SRSLink
FROM LittleBearRiverODM.dbo.SpatialReferences
ORDER BY SpatialReferenceID;
SET IDENTITY_INSERT ODM2.ODM2.SpatialReferences OFF;

--Add records to the ODM2.SpatialReferences table for the OffsetTypes used in 
--the ODM 1.1.1 database
INSERT INTO ODM2.ODM2.SpatialReferences (SRSName)
SELECT OffsetDescription
FROM LittleBearRiverODM.dbo.OffsetTypes;

--Add the Site SamplingFeatures to the ODM2 SamplingFeatures table 
--NOTES:
--1.  Set the default value of the SamplingFeatureUUID attribute to 
--    NEWSQUENTIALID() so the GUID is automatically generated. I did this by
--    adding a default value constraint to the SamplingFeatureUUID field set 
--    to generate a NEWSEQUENTIALID()when new records are entered into the 
--    SamplingFeatures table
ALTER TABLE ODM2.ODM2.SamplingFeatures ADD CONSTRAINT DF_SamplingFeatureUUID 
	DEFAULT NEWSEQUENTIALID() FOR SamplingFeatureUUID;
SET IDENTITY_INSERT ODM2.ODM2.SamplingFeatures ON; 
INSERT INTO ODM2.ODM2.SamplingFeatures (SamplingFeatureID, SamplingFeatureTypeCV, 
	SamplingFeatureCode, SamplingFeatureName, SamplingFeatureDescription, 
	SamplingFeatureGeoTypeCV, FeatureGeometry, Elevation_m, ElevationDatumCV)
SELECT s.SiteID AS SamplingFeatureID, 'Site' AS SamplingFeatureTypeCV, 
	s.SiteCode AS SamplingFeatureCode, s.SiteName AS SamplingFeatureName, 
	s.Comments AS SamplingFeatureDescription, 'Point' AS SamplingFeatureGeoTypeCV, 
	geometry::Point(s.Longitude, s.Latitude, sr.SRSID) AS FeatureGeometry, 
	s.Elevation_m, VerticalDatum AS ElevationDatumCV
FROM LittleBearRiverODM.dbo.Sites s, LittleBearRiverODM.dbo.SpatialReferences sr
WHERE s.LatLongDatumID = sr.SpatialReferenceID
ORDER BY SamplingFeatureID;
SET IDENTITY_INSERT ODM2.ODM2.SamplingFeatures OFF;

--Populate the ODM2.Sites table with Sites from the ODM 1.1.1 Sites table
INSERT INTO ODM2.ODM2.Sites (SamplingFeatureID, SiteTypeCV, Latitude, Longitude, 
	SpatialReferenceID)
SELECT SiteID AS SamplingFeatureID, SiteType AS SiteTypeCV, Latitude, Longitude, 
	LatLongDatumID
FROM LittleBearRiverODM.dbo.Sites 
ORDER BY SiteID;

-------------------------------------------------------------------------------
--Populate the ODM2.Units table
--TODO:  We are considering pre-populating the ODM2 schema with a list of Units. 
--If we do this, this part of the code will go away.
--
--NOTES:  
--1.  Before running this part of the script, need to verify that the 
--    'UnitsType' values used in the ODM 1.1.1 database contain valid values
--    from the ODM2 UnitsTypeCV.
--2.  The script only moves Units from the ODM 1.1.1 database that are actually 
--    used, so only need to check those and not the whole list of Units in the 
--    ODM 1.1.1 database.
-------------------------------------------------------------------------------

--TODO: Verify that UnitsTypeCV terms get loaded to the ODM2 database correctly
--Got stuck here on updating my script because the Python script that loads the 
--CVs fails to load the UnitsTypeCV. I had to download and import the 
--UnitsTypeCV terms manually.

--Load the Units from ODM 1.1.  Use the same IDs, but only copy the Units that 
--are currently in use
--TODO:  This code will go away when the Units table is pre-populated in ODM2
SET IDENTITY_INSERT ODM2.ODM2.Units ON; 
INSERT INTO ODM2.ODM2.Units (UnitsID, UnitsTypeCV, UnitsAbbreviation, UnitsName, 
	UnitsLink)
SELECT UnitsID, UnitsType AS UnitsTypeCV, UnitsAbbreviation, UnitsName, 
	'http://his.cuahsi.org/mastercvreg/edit_cv11.aspx?tbl=Units' AS UnitsLink
FROM LittleBearRiverODM.dbo.Units
WHERE UnitsID IN (
	SELECT VariableUnitsID AS UnitsID FROM LittleBearRiverODM.dbo.Variables
	UNION
	SELECT TimeUnitsID AS UnitsID FROM LittleBearRiverODM.dbo.Variables
	UNION 
	SELECT OffsetUnitsID AS UnitsID FROM LittleBearRiverODM.dbo.OffsetTypes)
ORDER BY UnitsID;
SET IDENTITY_INSERT ODM2.ODM2.Units OFF;

--Create a temporary table for Units that does the following:
--1.  Get the distinct UnitsIDs and UnitsNames actually used in the ODM 1.1.1 
--    database
--2.  Match the names of the Units from ODM 1.1.1 with those pre-populated into
--    the ODM2 database
SELECT LBRUnits.UnitsID AS ODM1UnitsID, LBRUnits.UnitsName AS ODM1UnitsName, 
	ODM2Units.UnitsID AS ODM2UnitsID, ODM2Units.UnitsName AS ODM2UnitsName
INTO #tempUnitsInfo
FROM LittleBearRiverODM.dbo.Units LBRUnits, ODM2.ODM2.Units ODM2Units
WHERE LBRUnits.UnitsName = ODM2Units.UnitsName;

-------------------------------------------------------------------------------
--Populate the ODM2.ProcessingLevels table from the ODM 1.1.1 
--QualityControlLevels table
--NOTE:
--1.  Keeps the existing QualityControlLevelIDs as ProcessingLevelIDs
-------------------------------------------------------------------------------
SET IDENTITY_INSERT ODM2.ODM2.ProcessingLevels ON; 
INSERT INTO ODM2.ODM2.ProcessingLevels (ProcessingLevelID, ProcessingLevelCode, 
	Definition, Explanation)
SELECT QualityControlLevelID AS ProcessingLevelID, 
	QualityControlLevelCode AS ProcessingLevelCode, Definition, Explanation 
FROM LittleBearRiverODM.dbo.QualityControlLevels 
ORDER BY ProcessingLevelID;
SET IDENTITY_INSERT ODM2.ODM2.ProcessingLevels OFF;

-------------------------------------------------------------------------------
--Populate the ODM2.Variables table
--NOTES:  
--1.  Uses the VariableIDs from the ODM 1.1.1 database for Variables in the 
--    ODM2 database
--2.  Set ODM2.Variables.VariableTypeCV = ODM1.1.1.Variables.GeneralCategory.  
--    So, need to verify that any terms used in the ODM 1.1.1 GeneralCategory 
--    field are valid terms from the ODM2 VariableTypeCV before running this
--    code.
--3.  Set ODM2.Variables.VariableDefinition = NULL because it doesn't exist in 
--    ODM 1.1.1
-------------------------------------------------------------------------------
SET IDENTITY_INSERT ODM2.ODM2.Variables ON; 
INSERT INTO ODM2.ODM2.Variables (VariableID, VariableTypeCV, VariableCode, 
	VariableNameCV, VariableDefinition, SpeciationCV, NoDataValue)
SELECT VariableID, GeneralCategory AS VariableTypeCV, VariableCode, 
	VariableName AS VariableNameCV, NULL AS VariableDefinition, 
	Speciation AS SpeciationCV, NoDataValue 
FROM LittleBearRiverODM.dbo.Variables 
ORDER BY VariableID;
SET IDENTITY_INSERT ODM2.ODM2.Variables OFF;

-------------------------------------------------------------------------------
--Populate the ODM2.Methods table
--NOTES:  
--1.  Uses the MethodIDs from the ODM 1.1.1 database as the MethodIDs in the 
--    ODM2 database.
--2.  Set ODM2.Methods.MethodTypeCV = NULL because it doesn't exist in
--    ODM 1.1.1
--3.  Set ODM2.Methods.MethodCode = ODM11.1.1.Methods.MethodID because there 
--    is no MethodCode in ODM 1.1.1.
--4.  Set ODM2.Methods.OrganizationID = NULL because Methods weren't associated
--    with Organizations in ODM 1.1.1
-------------------------------------------------------------------------------
SET IDENTITY_INSERT ODM2.ODM2.Methods ON; 
INSERT INTO ODM2.ODM2.Methods (MethodID, MethodTypeCV, MethodCode, MethodName, 
	MethodDescription, MethodLink, OrganizationID)
SELECT MethodID, 'Unknown' AS MethodTypeCV, MethodID AS MethodCode, 
	MethodDescription AS MethodName, MethodDescription, MethodLink, 
	NULL AS OrganizationID  
FROM LittleBearRiverODM.dbo.Methods 
ORDER BY MethodID;
SET IDENTITY_INSERT ODM2.ODM2.Methods OFF;

-------------------------------------------------------------------------------
--Populate the ODM2.Organizations table
--NOTES:
--1.  Uses the SourceIDs from the ODM 1.1.1 database as the ODM2 OrganizationID
--2.  Uses the SourceIDs from the ODM 1.1.1 database as the ODM2 
--    OrganizationCode because they don't exist in ODM 1.1.1.  Would need to be
--    adjusted afterward.
--3.  This uses "Research institute" as the OrganizationTypeCV for now - this 
--    won't be true for all organizations stored in an ODM 1.1.1 database and
--    so should be adjusted as needed afterward.
--4.  There are no parent organizations in ODM 1.1.1, so ParentOrganizationID 
--    is set to NULL
-------------------------------------------------------------------------------
SET IDENTITY_INSERT ODM2.ODM2.Organizations ON; 
INSERT INTO ODM2.ODM2.Organizations (OrganizationID, OrganizationTypeCV, 
	OrganizationCode, OrganizationName, OrganizationDescription, 
	OrganizationLink, ParentOrganizationID)
SELECT SourceID AS OrganizationID, 'Research institute' AS OrganizationTypeCV, 
	SourceID AS OrganizationCode, Organization AS OrganizationName, 
	CAST(SourceDescription AS VARCHAR(500)) AS OrganizationDescription,  
	SourceLink AS OrganizationLink, NULL AS ParentOrganizationID 
FROM LittleBearRiverODM.dbo.Sources 
ORDER BY OrganizationID;
SET IDENTITY_INSERT ODM2.ODM2.Organizations OFF;

-------------------------------------------------------------------------------
--Populate the ODM2.People table
--NOTES: 
--1.  Uses the ContactName from the ODM 1.1.1 Sources table.
--2.  This function may not work for all names in the ODM 1.1.1 Sources table, 
--    especially those with middle names or initials
-------------------------------------------------------------------------------
INSERT INTO ODM2.ODM2.People (PersonFirstName, PersonLastName)
SELECT DISTINCT
  CAST(SUBSTRING(ContactName, 1, CHARINDEX(' ', ContactName) - 1) 
	AS VARCHAR(255)) AS PersonFirstName,
  CAST(SUBSTRING(ContactName, CHARINDEX(' ', ContactName) + 1, 8000) 
	AS VARCHAR(255)) AS PersonLastName
FROM LittleBearRiverODM.dbo.Sources  
ORDER BY PersonLastName;

-------------------------------------------------------------------------------
--Populate the ODM2.Affiliations table
-------------------------------------------------------------------------------
INSERT INTO ODM2.ODM2.Affiliations (PersonID, OrganizationID, 
	IsPrimaryOrganizationContact, AffiliationStartDate, AffiliationEndDate, 
	PrimaryPhone, PrimaryEmail, PrimaryAddress, PersonLink)
SELECT p.PersonID, s.SourceID AS OrganizationID, 1 AS IsPrimaryOrganizationContact, 
	GETDATE() AS AffiliationStartDate, NULL AS AffiliationEndDate, 
	s.Phone AS PrimaryPhone, s.Email AS PrimaryEmail, 
	s.[Address] + ', ' + s.[City] + ', ' + s.[State] + ', ' + s.[ZipCode] 
	AS PrimaryAddress, NULL AS PersonLink
FROM LittleBearRiverODM.dbo.Sources s, ODM2.ODM2.People p 
WHERE p.PersonFirstName + ' ' + p.PersonLastName = s.ContactName
ORDER BY OrganizationID, PersonID;

-------------------------------------------------------------------------------
--Add the LabMethods from ODM 1.1 to the ODM2.Methods table
--NOTES:
--1.  Can't use the IDs from ODM 1.1 because they were not in the same table 
--    as methods
--2.  Sets the ODM2 OrganizationTypeCV = 'Analytical laboratory' for 
--    Organizations associated with laboratory methods.
--3.  Sets the ODM2 MethodTypeCV = 'Specimen analysis' for Methods imported 
--    from the ODM 1.1.1 LabMethods table.
-------------------------------------------------------------------------------
--Get the last MethodID and that was created in the ODM2 Methods table
DECLARE @MaxMethodID AS int;
SELECT @MaxMethodID = MAX(MethodID) FROM ODM2.ODM2.Methods;
--Get the last OrgnanizationID that was created
DECLARE @MaxOrganizationID AS int;
SELECT @MaxOrganizationID = MAX(OrganizationID) FROM ODM2.ODM2.Organizations;
--Add the analytical labs to the ODM2 Organizations table 
INSERT INTO ODM2.ODM2.Organizations (OrganizationTypeCV, OrganizationCode, 
	OrganizationName, OrganizationDescription, OrganizationLink, 
	ParentOrganizationID)
SELECT DISTINCT 'Analytical laboratory' AS OrganizationTypeCV, 
	LabName AS OrganizationCode, LabName AS OrganizationName, 
	LabOrganization AS OrganizationDescription, NULL AS OrganizationLink, 
	NULL AS ParentOrganizationID 
FROM LittleBearRiverODM.dbo.LabMethods;

--Create a temporary table that will make this easier
SELECT DISTINCT lm.LabMethodID AS ODM1LabMethodID, 
	lm.LabMethodID + @MaxMethodID + 1 AS MethodID, 
	'Specimen analysis' AS MethodTypeCV, 
	lm.LabMethodID + @MaxMethodID + 1 AS MethodCode, 
	lm.LabMethodName AS MethodName, lm.LabMethodDescription AS MethodDescription,
	lm.LabMethodLink AS MethodLink, org.OrganizationID		
INTO #tempLabMethodInfo
FROM LittleBearRiverODM.dbo.LabMethods lm, ODM2.ODM2.Organizations org
WHERE lm.LabName = org.OrganizationName AND 
	org.OrganizationID > @MaxOrganizationID;

--Add the LabMethods from ODM 1.1.1 to the ODM2 Methods table
SET IDENTITY_INSERT ODM2.ODM2.Methods ON; 
INSERT INTO ODM2.ODM2.Methods (MethodID, MethodTypeCV, MethodCode, MethodName,
	MethodDescription, MethodLink, OrganizationID)
SELECT MethodID, MethodTypeCV, MethodCode, MethodName, MethodDescription, 
	MethodLink, OrganizationID  
FROM #tempLabMethodInfo 
ORDER BY MethodID;
SET IDENTITY_INSERT ODM2.ODM2.Methods OFF;


--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
--Populate the ODM2.Actions, ODM2.ActionBy, ODM2.FeatureActions, ODM2.Results, 
--ODM2TimeSeriesResults, and ODM2.TimeSeriesResultValues tables for 
--sensor-based time series data
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-------------------------------------------------------------------------------
--Add records to the ODM2.Actions table for "Observation" Actions associated 
--with sensor-based time series data
--NOTES:  
--1.  This uses the SeriesIDs from the ODM 1.1.1 SeriesCatalog table as the 
--    ActionID
--2.  All Actions are given the ActionTypeCV of "Observation" because this 
--    concept does not exist in ODM 1.1.1 and nothing more is known about
--    them.
--3.  Assumes that any DataValue in the ODM 1.1.1 database that does not have
--    a SampleID associated with it is the result of a sensor measurement.
-------------------------------------------------------------------------------
SET IDENTITY_INSERT ODM2.ODM2.Actions ON; 
INSERT INTO ODM2.ODM2.Actions (ActionID, ActionTypeCV, MethodID, BeginDateTime, 
	BeginDateTimeUTCOffset, EndDateTime, EndDateTimeUTCOffset, ActionDescription,
	ActionFileLink)
SELECT DISTINCT sc.SeriesID AS ActionID, 'Observation' AS ActionTypeCV, 
	sc.MethodID, sc.BeginDateTime, CONVERT(integer, 24.0*CONVERT(decimal(10,5), 
	sc.BeginDateTime - sc.BeginDateTimeUTC)) AS BeginDateTimeUTCOffset,	
	sc.EndDateTime, CONVERT(integer, 24.0*CONVERT(decimal(10,5), sc.EndDateTime 
	- sc.EndDateTimeUTC)) AS EndDateTimeUTCOffset, 'Sensor deployment and 
	observation. This is a generic Observation Action created for a Time Series 
	Result loaded into ODM2	from an ODM 1.1.1 database.' AS ActionDescription, 
	NULL AS ActionFileLink
FROM LittleBearRiverODM.dbo.SeriesCatalog sc, 
	LittleBearRiverODM.dbo.DataValues dv
WHERE sc.SiteID = dv.SiteID AND sc.VariableID = dv.VariableID AND 
	sc.MethodID = dv.MethodID AND sc.SourceID = dv.SourceID 
	AND sc.QualityControlLevelID = dv.QualityControlLevelID AND dv.SampleID IS NULL
ORDER BY ActionID;
SET IDENTITY_INSERT ODM2.ODM2.Actions OFF;

-------------------------------------------------------------------------------
--Populate the ODM2.ActionBy table to caputure the "Observer" for sensor-based 
--time series data
--NOTES:
--1.  This uses the contact person from the Sources table in ODM 1.1.1 
--    associated with the time series
--2.  It is assumed that the contact person from the ODM 1.1.1 Sources table is
--    the ActionLead and Observer.
--    If this is not the case, this would need to be adjusted after this script
--    has been executed.
--3.  Uses the SeriesID from the ODM 1.1.1 database as the ActionID so I can 
--    easily associate the Actions with the right person.
-------------------------------------------------------------------------------
INSERT INTO ODM2.ODM2.ActionBy (ActionID, AffiliationID, IsActionLead, 
	RoleDescription)
SELECT act.ActionID, aff.AffiliationID, 1 AS IsActionLead, 
	'Observer' AS RoleDescription
FROM ODM2.ODM2.Actions act, LittleBearRiverODM.dbo.SeriesCatalog sc, 
	ODM2.ODM2.Affiliations aff
WHERE act.ActionID = sc.SeriesID AND sc.SourceID = aff.OrganizationID

-------------------------------------------------------------------------------
--Populate the ODM2.FeatureActions table
--NOTES:
--1.  Uses the SiteID from ODM 1.1.1 as the FeatureID
--2.  Uses the SeriesID from the ODM 1.1.1 database as the ActionID
--3.  Gets information from the ODM 1.1.1 SeriesCatalog table because it 
--    contains the association between the SeriesID and the SiteID
-------------------------------------------------------------------------------
INSERT INTO ODM2.ODM2.FeatureActions (SamplingFeatureID, ActionID)
SELECT DISTINCT sc.SiteID AS SamplingFeatureID, sc.SeriesID AS ActionID
FROM LittleBearRiverODM.dbo.SeriesCatalog sc, 
	LittleBearRiverODM.dbo.DataValues dv
WHERE sc.SiteID = dv.SiteID AND sc.VariableID = dv.VariableID 
	AND sc.MethodID = dv.MethodID AND sc.SourceID = dv.SourceID 
	AND sc.QualityControlLevelID = dv.QualityControlLevelID	AND dv.SampleID IS NULL 
ORDER BY SamplingFeatureID, ActionID;

-------------------------------------------------------------------------------
--Populate the ODM2.Results table for sensor-based time series data
--NOTES:  
--1.  Uses the SeriesIDs from the ODM 1.1.1 SeriesCatalog table as the ResultID
--    in the ODM2 Results table
--2.  Sets TaxonomicClassifierID = NULL - this doesn't exist in ODM 1.1.1
--3.  The ResultDateTime is set to the current system date (e.g., the time that
--    the result was added to the database)
--4.  ValidDateTime is set to NULL as it is most likely not relevant for any of
--    the results (also doesn't exist in ODM 1.1.1)
--5.  Status is set to 'Unknown' - this may not be correct for all time series,
--    but isn't present in ODM 1.1.1
--6.  Before running this, need to verify that the terms that have been used
--    in the ODM 1.1.1 database for SampleMediumCV match terms in the ODM2
--    MediumCV.
-------------------------------------------------------------------------------
--Set the default value of the ResultUUID attribute to NEWSQUENTIALID() so the 
--UUID for each Result is automatically generated when new records are inserted
ALTER TABLE ODM2.ODM2.Results ADD CONSTRAINT DF_ResultUUID 
	DEFAULT NEWSEQUENTIALID() FOR ResultUUID;
	
--Now add the records to the Result table for each time series Result
SET IDENTITY_INSERT ODM2.ODM2.Results ON; 
INSERT INTO ODM2.ODM2.Results (ResultID, FeatureActionID, ResultTypeCV, 
	VariableID, UnitsID, TaxonomicClassifierID, ProcessingLevelID, ResultDateTime, 
	ResultDateTimeUTCOffset, ValidDateTime, ValidDateTimeUTCOffset, StatusCV, 
	SampledMediumCV, ValueCount)
SELECT DISTINCT sc.SeriesID AS ResultID, fa.FeatureActionID, 'Time series coverage' 
	AS ResultTypeCV, sc.VariableID, ui.ODM2UnitsID AS UnitsID, 
	NULL AS TaxonomicClassifierID, sc.QualityControlLevelID AS ProcessingLevelID, 
	GETDATE() AS ResultDateTime, CONVERT(integer, 24.0*CONVERT(decimal(10,5),
	GETDATE() - GETUTCDATE())) AS ResultDateTimeUTCOffset, 
	NULL AS ValidDateTime, NULL AS ValidDateTimeUTCOffset, 'Unknown' AS StatusCV, 
	sc.SampleMedium AS SampledMediumCV, sc.ValueCount
FROM LittleBearRiverODM.dbo.SeriesCatalog sc, 
	LittleBearRiverODM.dbo.DataValues dv, ODM2.ODM2.FeatureActions fa,
	#tempUnitsInfo ui
WHERE sc.SiteID = dv.SiteID AND sc.VariableID = dv.VariableID 
	AND sc.MethodID = dv.MethodID AND sc.SourceID = dv.SourceID 
	AND sc.QualityControlLevelID = dv.QualityControlLevelID 
	AND fa.SamplingFeatureID = sc.SiteID AND fa.ActionID = sc.SeriesID 
	AND ui.ODM1UnitsID = sc.VariableUnitsID AND dv.SampleID IS NULL
ORDER BY ResultID;
SET IDENTITY_INSERT ODM2.ODM2.Results OFF;

-------------------------------------------------------------------------------
--Populate the ODM2.TimeSeriesResults table for sensor-based time series data
--NOTES:  
--1.  This uses the SeriesIDs from the ODM 1.1 SeriesCatalog as the ResultID
--2.  This adds everything from the ODM database into the TimeSeriesResults 
--    table except those DataValues that have SampleIDs
--3.  This assumes that values in the ODM database only have Z offsets, which 
--    could be wrong for many series.  If this is the case, the coordinates
--    in the TimeSeriesResults table may need to be adjusted after running
--    this query.
--4.  IntendedTimeSpacing and associated Units are set to NULL - these don't 
--    exist in ODM 1.1.1 and so aren't known.
--5.  Before running this code, need to make sure that the DataTypes used in 
--    the ODM 1.1.1 database match terms from the ODM2 AggregationStatisticCV
-------------------------------------------------------------------------------
INSERT INTO ODM2.ODM2.TimeSeriesResults (ResultID, XLocation, XLocationUnitsID, 
	YLocation, YLocationUnitsID, ZLocation, ZLocationUnitsID, SpatialReferenceID, 
	IntendedTimeSpacing, IntendedTimeSpacingUnitsID, AggregationStatisticCV)
SELECT sq.SeriesID AS ResultID, NULL AS XLocation, NULL AS XLocationUnitsID, 
	NULL AS YLocation, NULL AS YLocationUnitsID, sq.OffsetValue AS ZLocation, 
	ui.ODM2UnitsID AS ZLocationUnitsID, 
	sr.SpatialReferenceID AS SpatialReferenceID, NULL AS IntendedTimeSpacing, 
	NULL AS IntendedTimeSpacingUnitsID,	sq.DataType AS AggregationStatisticCV 
FROM (SELECT DISTINCT sc.SeriesID, sc.DataType, dv.OffsetValue, dv.OffsetTypeID
		FROM LittleBearRiverODM.dbo.SeriesCatalog sc, 
			LittleBearRiverODM.dbo.DataValues dv
		WHERE sc.SiteID = dv.SiteID AND sc.VariableID = dv.VariableID 
			AND sc.MethodID = dv.MethodID AND sc.SourceID = dv.SourceID 
			AND sc.QualityControlLevelID = dv.QualityControlLevelID 
			AND dv.SampleID IS NULL) AS sq
LEFT JOIN LittleBearRiverODM.dbo.OffsetTypes ot 
	ON sq.OffsetTypeID = ot.OffsetTypeID
LEFT JOIN #tempUnitsInfo ui
	ON ui.ODM1UnitsID = ot.OffsetUnitsID
LEFT JOIN ODM2.ODM2.SpatialReferences sr 
	ON ot.OffsetDescription = sr.SRSName
ORDER BY ResultID;		

-------------------------------------------------------------------------------
--Populate the ODM2.TimeSeriesResultValues table for sensor-based time series
--data
--NOTES:  
--1.  This uses the SeriesIDs from the ODM 1.1.1 SeriesCatalog as the ResultID
--2.  This adds everything from the ODM database into the TimeSeriesValues 
--    table except those DataValues that have SampleIDs associated with them
--3.  I am preserving ValueIDs from the ODM 1.1 database so I can go back later
--    and add annotations for Qualifiers
--4.  Sets QualityCodeCV = 'Unknown' because it doesn't exist in ODM 1.1.1
--5.  Although ODM2 supports different TimeAggregationIntervals for each 
--    DataValue, this script applies the TimeSupport from the ODM 1.1.1 
--    SeriesCatalog table to every data value within a time series.
--6.  Before running this code, need to make sure that the CensorCodes used
--    in the ODM 1.1.1 database match valid terms in the ODM2 CensorCodeCV
-------------------------------------------------------------------------------
SET IDENTITY_INSERT ODM2.ODM2.TimeSeriesResultValues ON;
INSERT INTO ODM2.ODM2.TimeSeriesResultValues (ValueID, ResultID, DataValue, 
	ValueDateTime, ValueDateTimeUTCOffset, CensorCodeCV, 
	QualityCodeCV, TimeAggregationInterval, TimeAggregationIntervalUnitsID)
SELECT dv.ValueID, sc.SeriesID AS ResultID, dv.DataValue, 
	dv.LocalDateTime AS ValueDateTime, dv.UTCOffset AS ValueDateTimeUTCOffset, 
	dv.CensorCode AS CensorCodeCV, 'Unknown' AS QualityCodeCV, 
	sc.TimeSupport AS TimeAggregationInterval, 
	ui.ODM2UnitsID AS TimeAggregationIntervalUnitsID
FROM LittleBearRiverODM.dbo.SeriesCatalog sc, LittleBearRiverODM.dbo.DataValues dv,
	#tempUnitsInfo ui
WHERE sc.SiteID = dv.SiteID AND sc.VariableID = dv.VariableID 
	AND sc.MethodID = dv.MethodID AND sc.SourceID = dv.SourceID 
	AND sc.QualityControlLevelID = dv.QualityControlLevelID 
	AND sc.TimeUnitsID = ui.ODM1UnitsID AND dv.SampleID IS NULL
ORDER BY ResultID, ValueDateTime;
SET IDENTITY_INSERT ODM2.ODM2.TimeSeriesResultValues OFF;

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
--Populate the ODM2.SamplingFeatures, ODM2.Specimens, ODM2.RelatedFeatures, 
--ODM2.Actions, ODM2.ActionBy, ODM2.FeatureActions, ODM2.RelatedActions, 
--ODM2.Results, ODM2.MeasurementResults, and ODM2.MeasurementResultValues 
--tables for specimen-based Results
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-------------------------------------------------------------------------------
--Load the specimens from the ODM 1.1.1 Samples table into the ODM2 
--SamplingFeatures table and return a temp table that contains the 
--SamplingFeatureIDs linked with the SamplingFeatureCodes
-------------------------------------------------------------------------------
CREATE TABLE #tempInsertedSpecimens
(
	SamplingFeatureID INT,
	SamplingFeatureCode VARCHAR(200) NOT NULL
);
INSERT INTO ODM2.ODM2.SamplingFeatures (SamplingFeatureTypeCV, 
	SamplingFeatureCode, SamplingFeatureName, SamplingFeatureDescription,
	SamplingFeatureGeoTypeCV, FeatureGeometry, Elevation_m, ElevationDatumCV)
OUTPUT INSERTED.SamplingFeatureID, INSERTED.SamplingFeatureCode 
INTO #tempInsertedSpecimens
SELECT DISTINCT 'Specimen' AS SamplingFeatureTypeCV, 
	LabSampleCode AS SamplingFeatureCode, NULL AS SamplingFeatureName, 
	'Specimen loaded from an ODM 1.1.1 database.' AS SamplingFeatureDescription,
	'Not applicable' AS SamplingFeatureGeoTypeCV, NULL AS FeatureGeometry, 
	NULL AS Elevation_m, NULL AS ElevationDatumCV
FROM LittleBearRiverODM.dbo.Samples;

-------------------------------------------------------------------------------
--Load the specimens from the ODM 1.1.1 Samples table into the ODM2
--Specimens table
--NOTES:
--1.  Before running this code, need to make sure that the SampleType terms in
--    the Samples table of the ODM 1.1.1 database match valid ODM2 
--    SpecimenTypeCV terms.
--2.  Before running this code, need to make sure that the SampleMedium terms
--    used in the ODM 1.1.1 Variables table match valid ODM2 MediumCV terms.
-------------------------------------------------------------------------------
INSERT INTO ODM2.ODM2.Specimens (SamplingFeatureID, SpecimenTypeCV, 
	SpecimenMediumCV, IsFieldSpecimen)
SELECT DISTINCT sp.SamplingFeatureID, smp.SampleType AS SpecimenTypeCV, 
	vr.SampleMedium AS SpecimenMediumCV, 1 AS IsFieldSpecimen
FROM #tempInsertedSpecimens sp, LittleBearRiverODM.dbo.Samples smp,
	LittleBearRiverODM.dbo.DataValues dv, LittleBearRiverODM.dbo.Variables vr
WHERE smp.SampleID = dv.SampleID AND dv.VariableID = vr.VariableID
	AND sp.SamplingFeatureCode = smp.LabSampleCode;

-------------------------------------------------------------------------------
--Populate the ODM2.RelatedFeatures table to associate the Specimen 
--SamplingFeatures with the Site at which they were collected
--NOTES:
--1.  The following code works because I used the SiteIDs from the ODM 1.1.1
--    Sites table as the SamplingFeatureIDs for those Sites in ODM2.
-------------------------------------------------------------------------------
INSERT INTO ODM2.ODM2.RelatedFeatures (SamplingFeatureID, RelationshipTypeCV, 
	RelatedFeatureID, SpatialOffsetID)
SELECT DISTINCT sp.SamplingFeatureID, 'Was collected at' AS RelationshipTypeCV, 
	s.SiteID AS RelatedFeatureID, NULL AS SpatialOffsetID
FROM #tempInsertedSpecimens sp, LittleBearRiverODM.dbo.Samples smp, 
	LittleBearRiverODM.dbo.DataValues dv, LittleBearRiverODM.dbo.Sites s
WHERE sp.SamplingFeatureCode = smp.LabSampleCode AND smp.SampleID = dv.SampleID
	AND dv.SiteID = s.SiteID
ORDER BY SamplingFeatureID, RelatedFeatureID;	

-------------------------------------------------------------------------------
--Add "Specimen analysis" Actions to the ODM2.Actions table for the samples in
--the ODM 1.1.1 database.
--NOTE:  
--1.  Only adds Actions for Samples that actually appear in the ODM 1.1.1
--    DataValues table
--2.  Uses the "LabMethod" associated with the Sample in the ODM 1.1.1 
--    database.
--3.  Assumes that each DataValue in the ODM 1.1.1 database that has a SampleID
--    associated with it is the result of a separate analysis on that sample.
-------------------------------------------------------------------------------
--Create a temporary table with the information I need to populate the ODM2
--Actions, ActionBy, and FeatureActions tables
DECLARE @MaxActionID AS int;
SELECT @MaxActionID = MAX(ActionID) FROM ODM2.ODM2.Actions;
DECLARE @MaxResultID AS int;
SELECT @MaxResultID = MAX(ResultID) FROM ODM2.ODM2.Results;
SELECT DISTINCT dv.ValueID, dv.ValueID + @MaxResultID AS ResultID,
	tempsp.SamplingFeatureID, dv.SampleID, 
	@MaxActionID + ROW_NUMBER() OVER (ORDER BY SamplingFeatureID) AS ActionID, 
	'Specimen analysis' AS ActionTypeCV, met.MethodID, 
	dv.LocalDateTime AS BeginDateTime, dv.UTCOffset AS BeginDateTimeUTCOffset, 
	dv.LocalDateTime AS EndDateTime, dv.UTCOffset AS EndDateTimeUTCOffset, 
	'Specimen laboratory analysis.' AS ActionDescription, NULL AS ActionFileLink
INTO #tempActionInfo
FROM LittleBearRiverODM.dbo.DataValues dv, ODM2.ODM2.Methods met,
	LittleBearRiverODM.dbo.LabMethods lmet, #tempInsertedSpecimens tempsp, 
	LittleBearRiverODM.dbo.Samples smp
WHERE tempsp.SamplingFeatureCode = smp.LabSampleCode 
	AND smp.SampleID = dv.SampleID
	AND smp.LabMethodID = lmet.LabMethodID 
	AND lmet.LabMethodName = met.MethodName
ORDER BY SamplingFeatureID ASC;

--Now insert the "Specimen analysis" Actions into the ODM2.Actions table
SET IDENTITY_INSERT ODM2.ODM2.Actions ON;
INSERT INTO ODM2.ODM2.Actions (ActionID, ActionTypeCV, MethodID, BeginDateTime,
	BeginDateTimeUTCOffset, EndDateTime, EndDateTimeUTCOffset, 
	ActionDescription, ActionFileLink)
SELECT ActionID, ActionTypeCV, MethodID, BeginDateTime, BeginDateTimeUTCOffset, 
	EndDateTime, EndDateTimeUTCOffset, 
	'Specimen laboratory analysis.' AS ActionDescription, NULL AS ActionFileLink
FROM #tempActionInfo 
SET IDENTITY_INSERT ODM2.ODM2.Actions OFF;

-------------------------------------------------------------------------------
--Populate the ODM2.ActionBy table for the "Specimen analysis" actions
--NOTES:
--1.  This uses the contact person from the Sources table in ODM 1.1 as the 
--    "Laboratory analyst"
-------------------------------------------------------------------------------
INSERT INTO ODM2.ODM2.ActionBy (ActionID, AffiliationID, IsActionLead,
	RoleDescription)
SELECT DISTINCT tempai.ActionID, aff.AffiliationID, 1 AS IsActionLead, 
	'Laboratory analyst' AS RoleDescription
FROM #tempActionInfo tempai, ODM2.ODM2.Affiliations aff, 
	LittleBearRiverODM.dbo.DataValues dv  
WHERE tempai.SampleID = dv.SampleID AND dv.SourceID = aff.OrganizationID
ORDER BY ActionID, AffiliationID;

-------------------------------------------------------------------------------
--Populate the ODM2.FeatureActions table for the "Specimen analysis" actions
-------------------------------------------------------------------------------
CREATE TABLE #tempInsertedFeatureActions
(
	FeatureActionID INT,
	SamplingFeatureID INT,
	ActionID INT
);	
INSERT INTO ODM2.ODM2.FeatureActions (SamplingFeatureID, ActionID)
OUTPUT INSERTED.FeatureActionID, INSERTED.SamplingFeatureID, 
	INSERTED.ActionID 
INTO #tempInsertedFeatureActions
SELECT SamplingFeatureID, ActionID
FROM #tempActionInfo;

-------------------------------------------------------------------------------
--Add records to the ODM2.Results table for measurements resulting from 
--laboratory analysis of Specimens  
--NOTES:
--1.  The ResultType will be "Measurement" and there will be at least one 
--    Result for every sample
--2.  The ResultDateTime will be set to the LocalDateTime in the ODM 1.1.1
--    DataValues table.
--3.  Set Status = "Complete" for now 
--4.  Need to make sure that all of the terms in the SampleMedium field in the 
--    ODM 1.1.1 Variables table match valid terms from the ODM2 MediumCV
-------------------------------------------------------------------------------
SET IDENTITY_INSERT ODM2.ODM2.Results ON;
INSERT INTO ODM2.ODM2.Results (ResultID, FeatureActionID, ResultTypeCV, 
	VariableID, UnitsID, TaxonomicClassifierID, ProcessingLevelID, ResultDateTime,
	ResultDateTimeUTCOffset, ValidDateTime, ValidDateTimeUTCOffset, StatusCV, 
	SampledMediumCV, ValueCount)
SELECT tempai.ResultID, tempfas.FeatureActionID, 'Measurement' AS ResultTypeCV, 
	dv.VariableID, vbl.VariableUnitsID AS UnitsID, NULL AS TaxonomicClassifierID,
	dv.QualityControlLevelID AS ProcessingLevelID, 
	dv.LocalDateTime AS ResultDateTime, dv.UTCOffset AS ResultDateTimeUTCOffset,
	NULL AS ValidDateTime, NULL AS ValidDateTimeUTCOffset, 'Complete' AS StatusCV,
	vbl.SampleMedium AS SampledMediumCV, 1 AS ValueCount
FROM LittleBearRiverODM.dbo.DataValues dv, LittleBearRiverODM.dbo.Variables vbl, 
	#tempActionInfo AS tempai, #tempInsertedFeatureActions AS tempfas
WHERE dv.ValueID = tempai.ValueID AND dv.VariableID = vbl.VariableID 
	AND tempai.SamplingFeatureID = tempfas.SamplingFeatureID 
	AND tempai.ActionID = tempfas.ActionID
ORDER BY ResultID ASC;
SET IDENTITY_INSERT ODM2.ODM2.Results OFF;

-------------------------------------------------------------------------------
--Populate the ODM2.ODM2.MeasurementResults table for specimen-based data
--NOTES:  
--1.  Results are created only for DataValues in the ODM 1.1.1 database if they 
--    have an associated SampleID
--2.  This assumes that values in the ODM database only have Z offsets, which
--    could be wrong for many data values. May need to be adjusted after the
--    script is run to correct the coordinates for any offsets.
--3.  I am preserving ValueIDs from the ODM 1.1 database so I can go back later
--    and add annotations for Qualifiers
-------------------------------------------------------------------------------
INSERT INTO ODM2.ODM2.MeasurementResults (ResultID, XLocation, 
	XLocationUnitsID, YLocation, YLocationUnitsID, ZLocation, ZLocationUnitsID, 
	SpatialReferenceID, CensorCodeCV, QualityCodeCV, AggregationStatisticCV,
	TimeAggregationInterval, TimeAggregationIntervalUnitsID)
SELECT tempai.ResultID, NULL AS XLocation, NULL AS XLocationUnitsID, 
	NULL AS YLocation, NULL AS YLocationUnitsID, sq.OffsetValue AS ZLocation, 
	tempui.ODM1UnitsID AS ZLocationUnitsID, sr.SpatialReferenceID, 
	sq.CensorCode AS CensorCodeCV, 'Unknown' AS QualityCodeCV, 
	sq.AggregationStatisticCV, sq.TimeAggregationInterval, 
	sq.TimeAggregationIntervalUnitsID
FROM (SELECT dv.ValueID, dv.OffsetValue, dv.OffsetTypeID, dv.CensorCode, 
			vbl.DataType AS AggregationStatisticCV, 
			vbl.TimeSupport AS TimeAggregationInterval, 
			tempui.ODM2UnitsID AS TimeAggregationIntervalUnitsID
		FROM LittleBearRiverODM.dbo.DataValues dv, 
			LittleBearRiverODM.dbo.Variables vbl, #tempUnitsInfo tempui
		WHERE dv.VariableID = vbl.VariableID
			AND tempui.ODM1UnitsID = vbl.TimeUnitsID
			AND dv.SampleID IS NOT NULL) AS sq
INNER JOIN #tempActionInfo tempai 
	ON sq.ValueID = tempai.ValueID
LEFT JOIN LittleBearRiverODM.dbo.OffsetTypes ot 
	ON sq.OffsetTypeID = ot.OffsetTypeID
LEFT JOIN #tempUnitsInfo tempui
	ON ot.OffsetUnitsID = tempui.ODM1UnitsID
LEFT JOIN ODM2.ODM2.SpatialReferences sr 
	ON ot.OffsetDescription = sr.SRSName
ORDER BY ResultID;

-------------------------------------------------------------------------------
--Populate the ODM2.MeasurementResultValues table for Specimen-based data
--NOTES:  
--1.  This adds DataValues to the ODM2.MeasurementResultValues table only
--    if they have an associated SampleID
--2.  I am preserving ValueIDs from the ODM 1.1.1 database so I can go back
--    later and add ODM2 Annotations for ODM 1.1.1 Qualifiers
-------------------------------------------------------------------------------
SET IDENTITY_INSERT ODM2.ODM2.MeasurementResultValues ON;
INSERT INTO ODM2.ODM2.MeasurementResultValues (ValueID, ResultID, DataValue, 
	ValueDateTime, ValueDateTimeUTCOffset)
SELECT dv.ValueID, tempai.ResultID, dv.DataValue, 
	dv.LocalDateTime AS ValueDateTime, dv.UTCOffset AS ValueDateTimeUTCOffset
FROM LittleBearRiverODM.dbo.DataValues dv, #tempActionInfo tempai
WHERE dv.ValueID = tempai.ValueID  
ORDER BY ResultID;
SET IDENTITY_INSERT ODM2.ODM2.MeasurementResultValues OFF;

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
--Add the qualifiers from ODM 1.1.1 to the ODM2.ODM2.Annotations and 
--related tables
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
--Add the Measurement Result Value Annotations from ODM 1.1.1 to the 
--ODM2.Annotations table
SET IDENTITY_INSERT ODM2.ODM2.Annotations ON;
INSERT INTO ODM2.ODM2.Annotations (AnnotationID, AnnotationTypeCV, 
	AnnotationCode, AnnotationText, AnnotationDateTime,
	AnnotationUTCOffset, AnnotationLink, AnnotatorID, CitationID)
SELECT dv.QualifierID AS AnnotationID, 
	'Measurement result value annotation' AS AnnotationTypeCV,
	q.QualifierCode AS AnnotationCode, 
	CAST(q.QualifierDescription AS NVARCHAR(500)) AS AnnotationText, 
	NULL AS AnnotationDateTime, NULL AS AnnotationUTCOffset,
	NULL AS AnnotationLink, NULL AS AnnotatorID, NULL AS CitationID
FROM LittleBearRiverODM.dbo.DataValues dv, LittleBearRiverODM.dbo.Qualifiers q
WHERE dv.QualifierID = q.QualifierID AND dv.SampleID IS NOT NULL
ORDER BY AnnotationID;
SET IDENTITY_INSERT ODM2.ODM2.Annotations OFF;

--Add the Time Series Result Value Annotations from ODM 1.1.1 to the 
--ODM2.Annotations table
SET IDENTITY_INSERT ODM2.ODM2.Annotations ON;
INSERT INTO ODM2.ODM2.Annotations (AnnotationID, AnnotationTypeCV, 
	AnnotationCode, AnnotationText, AnnotationDateTime,
	AnnotationUTCOffset, AnnotationLink, AnnotatorID, CitationID)
SELECT dv.QualifierID AS AnnotationID, 
	'Time series result value annotation' AS AnnotationTypeCV,
	q.QualifierCode AS AnnotationCode, 
	CAST(q.QualifierDescription AS NVARCHAR(500)) AS AnnotationText, 
	NULL AS AnnotationDateTime, NULL AS AnnotationUTCOffset,
	NULL AS AnnotationLink, NULL AS AnnotatorID, NULL AS CitationID
FROM LittleBearRiverODM.dbo.DataValues dv, LittleBearRiverODM.dbo.Qualifiers q
WHERE dv.QualifierID = q.QualifierID AND dv.SampleID IS NULL
ORDER BY AnnotationID;
SET IDENTITY_INSERT ODM2.ODM2.Annotations OFF;

--Add the records to the ODM2.MeasurementResultValueAnnotations table
INSERT INTO ODM2.ODM2.MeasurementResultValueAnnotations (ValueID, AnnotationID)
SELECT ValueID, QualifierID AS AnnotationID
FROM LittleBearRiverODM.dbo.DataValues
WHERE QualifierID IS NOT NULL AND SampleID IS NOT NULL
ORDER BY ValueID;

--Add the records to the ODM2.TimeSeriesResultValueAnnotations table
INSERT INTO ODM2.ODM2.TimeSeriesResultValueAnnotations (ValueID, AnnotationID)
SELECT ValueID, QualifierID AS AnnotationID
FROM LittleBearRiverODM.dbo.DataValues
WHERE QualifierID IS NOT NULL AND SampleID IS NULL
ORDER BY ValueID;

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
--Clean up by dropping the temporary tables that are no longer needed
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
DROP TABLE #tempUnitsInfo;
DROP TABLE #tempLabMethodInfo;
DROP TABLE #tempInsertedSpecimens;
DROP TABLE #tempActionInfo;
DROP TABLE #tempInsertedFeatureActions;