USE [Kontrolling]
GO

--------------------------------------
-- Created by Vizsy István
-- for Yearly Blocked Stock KPI report
-- on 2026.03.04.
--------------------------------------


CREATE VIEW [dbo].[PM_Blocked_Stock_Yearly]
AS

WITH Dates AS (
	SELECT periodStart, DATEFROMPARTS(YEAR(periodStart) + 1, 1, 1) AS dayAfterPeriod
		,GETDATE() now_
		FROM (SELECT CAST('2026-03-01' AS DATE) AS periodStart) td
)
--select *
--from Dates
SELECT ld.[Item No_], i.Description, ld.[Lot No_]
	,ld.Pcs - ISNULL(ld.lmPcs, 0) StartPcs, ld.Pcs EndPcs, ld.TotalPcs
	,CASE WHEN ld.isSample = 0 THEN 'N' ELSE 'I' END AS Minta
	,ld.firstMove Blocked, CASE WHEN ld.Pcs = 0 THEN ld.lastMove ELSE NULL END AS Realese
	,nwd.NonWorkDays, DATEDIFF(MINUTE, ld.firstMove, ld.lastMove) / 60.0 - nwd.NonWorkDays * 24 Hours_
	FROM
	 --ld start
	(SELECT [Item No_], [Lot No_], lmPcs, Pcs, TotalPcs, isSample, firstMove,CAST(firstMove AS DATE) firstDate
		,CASE WHEN Pcs = 0 THEN lastMove ELSE now_ END AS lastMove
		,CAST(CASE WHEN Pcs = 0 THEN lastMove ELSE now_ END AS DATE) AS lastDate
		FROM
		(SELECT lots.[Item No_], lots.[Lot No_], lots.lmPcs
			,su.Pcs, su.TotalPcs, su.isSample
			,su.firstMove, su.lastMove
			,d.now_
			FROM
			(SELECT isnull(hist.[Item No_], lm.[Item No_]) [Item No_], isnull(hist.[Lot No_], lm.[Lot No_]) [Lot No_]
				,lm.lmPcs
				FROM
				(SELECT we.[Item No_], we.[Lot No_]
					FROM [P_BC].[ELES].[dbo].[$Warehouse Entry] we WITH (NOLOCK)
					CROSS JOIN Dates d
					WHERE we.[Location Code] = 'N06'
						and we.[$systemCreatedAt] < d.periodStart
					GROUP BY we.[Item No_], we.[Lot No_]
					HAVING SUM(we.[Quantity]) <> 0
				) hist
				FULL OUTER JOIN
				(SELECT we.[Item No_], we.[Lot No_], SUM(we.[Quantity]) lmPcs
					FROM [P_BC].[ELES].[dbo].[$Warehouse Entry] we WITH (NOLOCK)
					CROSS JOIN Dates d
					WHERE we.[Location Code] = 'N06' and we.[Quantity] <> 0
						and we.[$systemCreatedAt] >= d.periodStart and we.[$systemCreatedAt] < d.dayAfterPeriod
					GROUP BY we.[Item No_], we.[Lot No_]
				)lm ON hist.[Item No_] = lm.[Item No_] and hist.[Lot No_] = lm.[Lot No_]
			) lots
			CROSS JOIN Dates d
			CROSS APPLY (
				SELECT SUM(we.[Quantity]) Pcs, SUM(CASE WHEN we.[Quantity] > 0 THEN we.[Quantity] ELSE 0 END) AS TotalPcs
					,MAX(CASE WHEN we.[Bin Code] = 'MINTA' THEN 1 ELSE 0 END) AS isSample
					,min(we.[$systemCreatedAt]) firstMove, max(we.[$systemCreatedAt]) lastMove
					FROM [P_BC].[ELES].[dbo].[$Warehouse Entry] we
					WHERE lots.[Item No_] = we.[Item No_] and lots.[Lot No_] = we.[Lot No_]
						AND we.[Location Code] = 'N06' and we.[Quantity] <> 0
			) su
		) lmoves
	) ld
	OUTER APPLY (
		SELECT COUNT(pd.Datum) NonWorkDays
		FROM PM_Planned_day pd
		WHERE pd.Datum >= ld.firstDate AND pd.Datum < ld.lastDate
			AND pd.Workday = 0
	) AS nwd
	LEFT JOIN [P_BC].[BC_Reports].dbo.[_ELES_ $Item] i WITH (NOLOCK) on ld.[Item No_] = i.No_
--	ORDER BY ld.firstMove, ld.[Item No_], ld.[Lot No_]
