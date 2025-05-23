USE [XReports]
GO

-- =============================================
-- Author:		<Vizsy István>
-- Create date: <2018.12.12.>
-- Description:	<Figyelmeztető e-mail-t küld, ha az elvárttól eltérő karakterszámú szériaszámot észlel, illetve ha egy tételhez tartozik szériaszám, de nem állítottak be hozza elvárt hosszúságot.>
-- =============================================

ALTER PROCEDURE [dbo].[sp_SerialNumberCheck_Mail]

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	DECLARE @FUNCTION_NAME nvarchar(20);
	DECLARE @email BIT;
    DECLARE @RecordCount int;
	DECLARE @xml NVARCHAR(MAX);
	DECLARE @body NVARCHAR(MAX);
	DECLARE @crec NVARCHAR(100), @recipients NVARCHAR(100), @subject NVARCHAR(100);

	SET @email = 0;

	CREATE TABLE #tdLot (
		part VARCHAR(18),
		lot NVARCHAR(max),
		alen INT,
		dlen INT,
		color VARCHAR(7))

	CREATE TABLE #tundLot (
		part VARCHAR(18),
		lot NVARCHAR(max),
		alen INT)

	-- Eltérő Lotok keresése
	INSERT INTO #tdLot SELECT ld_part part, ld_lot lot, alen, xptk_dec04 dlen, IIF(alen = xptk_dec04, 'd6f5d6', '#ffcccc') color FROM OPENQUERY(MFGSRV,
		'SELECT a.ld_part, a.xptk_dec04, d.ld_lot, LENGTH(RTRIM(d.ld_lot)) alen
			FROM (SELECT ld_domain, ld_part, xptk_dec04
				FROM PUB.ld_det l
				LEFT JOIN PUB.xptk_mstr x ON l.ld_domain = x.xptk_domain AND l.ld_part = x.xptk_part
				WHERE ld_domain = ''A'' AND xptk_site = ''T2'' AND xptk_dec04 <> 0 AND LENGTH(RTRIM(ld_lot)) <> xptk_dec04
				GROUP BY ld_domain, ld_part, xptk_dec04) a
			LEFT JOIN PUB.ld_det d ON a.ld_domain = d.ld_domain AND a.ld_part = d.ld_part
			WITH(NOLOCK)')

	SELECT @RecordCount = COUNT(*)
		FROM #tdLot;

	IF (@RecordCount > 0) BEGIN
		SET @xml = CAST((SELECT [color] as "@bgcolor",
							[part] AS 'td', '',
							[lot] AS 'td', '',
							[alen] AS 'td', '',
							[dlen] AS 'td'
			FROM #tdLot
			FOR XML PATH('tr'), ELEMENTS ) AS NVARCHAR(MAX));

		SET @body ='<H3>Az elvárttól eltéro&#779 szériaszám hosszúságok:</H3>
			<table border = 1 border-spacing = 50px> 
			<tr bgcolor="#e6e6e6"><th> Tételkód <th> Szériaszám <th> Sz.sz. hossza <th> Elvárt hosszúság
			</tr>' +  @xml +'</table>';

		SET @email = 1;
	END
	ELSE SET @body = ''

	-- Beállítandó szériaszám hosszúságok
	INSERT INTO #tundLot SELECT ld_part part, ld_lot lot, alen FROM OPENQUERY(MFGSRV,
		'SELECT a.ld_part, d.ld_lot, LENGTH(RTRIM(d.ld_lot)) alen
			FROM (SELECT l.ld_domain, l.ld_part
				FROM PUB.ld_det l
				LEFT JOIN PUB.xptk_mstr x ON l.ld_domain = x.xptk_domain AND l.ld_part = x.xptk_part
				WHERE l.ld_domain = ''A'' AND l.ld_lot <> '''' AND (l.ld_part LIKE ''MA%'' OR l.ld_part LIKE ''MC%'')
				AND x.xptk_site = ''T2'' AND x.xptk_dec04 = 0
				GROUP BY l.ld_domain, l.ld_part) a
			LEFT JOIN PUB.ld_det d ON a.ld_domain = d.ld_domain AND a.ld_part = d.ld_part
			WITH(NOLOCK)')

	SELECT @RecordCount = COUNT(*)
		FROM #tundLot;

	IF (@RecordCount > 0) BEGIN
		SET @xml = CAST((SELECT [part] AS 'td', '',
							[lot] AS 'td', '',
							[alen] AS 'td'
			FROM #tundLot
			FOR XML PATH('tr'), ELEMENTS ) AS NVARCHAR(MAX));

		SET @body = @body + '<H3>Tételek, melyek szériaszáma még nem lett beállítva, vagy tévesen kaptak szériaszámot:</H3>
			<table border = 1 border-spacing = 50px> 
			<tr bgcolor="#e6e6e6"><th> Tételkód <th> Szériaszám <th> Sz.sz. hossza
			</tr>' +  @xml +'</table>';

		SET @email = 1;
	END

	-- E-mail küldése
	IF (@email = 1) BEGIN
		SET @FUNCTION_NAME = 'LotLengthCheck';

		SELECT @subject = mail_subject FROM AntonReports.dbo.SystemMails WHERE function_name = @FUNCTION_NAME;
		SELECT @recipients = AntonReports.dbo.GetMailRecipients(@FUNCTION_NAME, 0);
		SELECT @crec = AntonReports.dbo.GetMailRecipients(@FUNCTION_NAME, 1);

		SET @body ='<html><head><style>td {text-align: center; padding-left: 5px; padding-right: 5px;}</style></head>
			<body><p>Kedves Kollégák!
				<p>Kérem az alábbi halványpiros hátteru&#779 szériaszámok javítását, vagy az elvárt szériaszám hosszúság beállítását.'
			+  @body +'</body></html>';

		-- Teszt: SET @recipientS = 'istvan.vizsy@aqg.se';
		-- Teszt: SET @crec = 'istvan.vizsy@aqg.se';
		EXEC msdb.dbo.sp_send_dbmail
			@profile_name = 'System',
			@body = @body,
			@body_format ='HTML',
			@recipients = @recipients,
			@copy_recipients = @crec,
			@subject = @subject;

	END;

	DROP TABLE #tdLot
	DROP TABLE #tundLot

END -- Procedure
