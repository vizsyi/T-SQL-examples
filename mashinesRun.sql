USE [GrafanaSource]
GO

-- =============================================
-- Author:		<Vizsy I.>
-- Create date: <2020.04.04.>
-- Modified date: <2020.04.07.>
-- Description:	Runtime of machines at Grafana Monitor
-- =============================================

CREATE PROCEDURE dbo.mashinesRun @mchs VARCHAR(MAX), @sFrom BIGINT, @sTo BIGINT AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @fromDt DATETIME
	DECLARE @limDt DATETIME
	DECLARE @toDt DATETIME
	DECLARE @qLim VARCHAR(20)
	DECLARE @qTo VARCHAR(20)
	DECLARE @rangeSec INT
	DECLARE @sRun INT
	DECLARE @pRun INT
	DECLARE @mchCnt SMALLINT
	DECLARE @TZS SMALLINT

	DECLARE @mLog TABLE(
		ID INT NOT NULL,
		mch VARCHAR(8),
		stampT DATETIME NOT NULL,
		spindle BIT,
		program BIT
	)

	/*--For test
	DECLARE @mchs VARCHAR(MAX) = 'GG031,GG032,GG039'
	DECLARE @sFrom BIGINT = 1586263500000
	DECLARE @sTo BIGINT	= 1586349900000*/

	-- Datetime data
	SET @TZS = dbo.TZoneShift()
	SET @fromDt = DATEADD(HOUR, @TZS, dbo.StampToDt(@sFrom))
	SET @toDt = DATEADD(HOUR, @TZS, dbo.StampToDt(@sTo))
	SET @limDt = DATEADD(HOUR, -8, @fromDt)

	SET @qLim = dbo.DatetimeToCh(@limDt)
	SET @qTo = dbo.DatetimeToCh(@toDt)
	SET @rangeSec = (@sTo- @sFrom) / 1000

	--Machines
	SET @mchCnt = LEN(@mchs)
	SET @mchs = REPLACE(@mchs, ',', ''''',''''')
	SET @mchCnt = (LEN(@mchs) - @mchCnt) / 4 + 1

	-- Openquery of MCDB Machine Log
	INSERT INTO @mLog (ID, mch, stampT, spindle,	program)
	EXEC ('SELECT ID, mch, stampT, spindle,	program
		FROM OPENQUERY(MCDB,
			''SELECT ID, mach_ID mch, time_stamp stampT, spindle_status spindle, program_status program
				FROM MCDB.AQA_machine_LOG
				WHERE time_stamp BETWEEN ''''' + @qLim + ''''' AND ''''' + @qTo + '''''
				AND event = ''''E'''' AND mach_ID IN (''''' + @mchs + ''''')
				AND (spindle_status IS NOT NULL OR program_status IS NOT NULL)'')')

	-- Spindle runtime
	SELECT @sRun = SUM(IIF(mch = pMch, DATEDIFF(SECOND, stampT, @toDt) * (spindle * 2 - 1),
			IIF(spindle = 1, IIF(stampT > @fromDt, DATEDIFF(SECOND, stampT, @toDt), @rangeSec), 0)))
		FROM (SELECT l.ID, l.mch, l.stampT, l.spindle, LAG(l.spindle) OVER (ORDER BY l.mch, l.ID) pStat
			,LAG(l.mch) OVER (ORDER BY l.mch, l.ID) pMch
			FROM @mLog l
			LEFT JOIN (SELECT mch, MAX(ID) maxID FROM @mLog
				WHERE stampT <= @fromDt AND spindle IS NOT NULL GROUP BY mch) m ON l.mch = m.mch
			WHERE spindle IS NOT NULL AND (m.maxID IS NULL OR ID >= m.maxID)) a
		WHERE spindle <> pStat OR mch <> pMch OR pStat IS NULL
	IF @sRun IS NULL SET @sRun = 0
	
	-- CNC Program runtime
	SELECT @pRun = SUM(IIF(mch = pMch, DATEDIFF(SECOND, stampT, @toDt) * (program * 2 - 1),
			IIF(program = 1, IIF(stampT > @fromDt, DATEDIFF(SECOND, stampT, @toDt), @rangeSec), 0)))
		FROM (SELECT l.ID, l.mch, l.stampT, l.program, LAG(l.program) OVER (ORDER BY l.mch, l.ID) pStat
			,LAG(l.mch) OVER (ORDER BY l.mch, l.ID) pMch
			FROM @mLog l
			LEFT JOIN (SELECT mch, MAX(ID) maxID FROM @mLog
				WHERE stampT <= @fromDt AND program IS NOT NULL GROUP BY mch) m ON l.mch = m.mch
			WHERE program IS NOT NULL AND (m.maxID IS NULL OR ID >= m.maxID)) a
		WHERE program <> pStat OR mch <> pMch OR pStat IS NULL
	IF @pRun IS NULL SET @pRun = 0

	-- Final result
	SELECT @sFrom [time], @sRun [Spindle runtime], @rangeSec * @mchCnt - @pRun [Downtime], @pRun - @sRun [Additional time]

END -- of PROCEDURE

----- Execute
/*
EXEC GrafanaSource.dbo.mashineRun @mch = 'GG032', @sFrom = 1586080440000, @sTo = 1586166840000
EXEC GrafanaSource.dbo.mashinesRun @mchs = 'GG032', @sFrom = 1586080440000, @sTo = 1586166840000
EXEC GrafanaSource.dbo.mashinesRun @mchs = 'GG031,GG032,GG039,GG040,GG096,GG097,GG098,GG200'
	,@sFrom = 1586080440000, @sTo = 1586166840000
*/