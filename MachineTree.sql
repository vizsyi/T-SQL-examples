WITH mch1 AS (
	SELECT Code, Name, GroupCode, Comments, ProductionFactor, SetupTimeFactor, Res_ResBufferTimeV9Before, Res_ResBufferTimeV9After, ResClass
	, ConstrainResQty, FORMAT(ROW_NUMBER() Over(ORDER BY DisplayOrder, Code), '-0000') Struct, IsGroup, QadResource
	, CHARINDEX(';', GroupCode) ci
	FROM OPENQUERY (MYSQL, 
	'select Code, IFNULL(Recname, '''') Name, GroupCode, Comments, ProductionFactor, SetupTimeFactor, Res_ResBufferTimeV9Before, Res_ResBufferTimeV9After
		, ResClass, ConstrainResQty, DisplayOrder, IF(IsGroup=''True'', 1, 0) IsGroup, QadResource
		from asprova2.asp_resource
		where DisplayOrder is not null and Code is not null
		order by DisplayOrder, Code')),
	mch AS (
	SELECT Code, Name, Struct, IsGroup
	, IIF(ci > 0, LEFT(GroupCode, ci - 1), GroupCode) groupc, IIF(ci > 0, SUBSTRING(GroupCode, ci + 1, 32000), '') marad
	FROM mch1
	UNION ALL
	SELECT Code, Name, Struct, IsGroup
	, IIF(ci > 0, LEFT(marad, ci - 1), marad) groupc, IIF(ci > 0, SUBSTRING(marad, ci + 1, 32000), '') marad
		FROM (SELECT Code, Name, Struct, IsGroup, marad, CHARINDEX(';', marad) ci FROM mch WHERE marad <> '') g
	),
	tree AS (
	SELECT Struct, level = 1, Code, Name, IsGroup FROM mch WHERE groupc IS NULL
	UNION ALL
	SELECT tree.Struct + m.Struct Struct, tree.level + 1 level, m.Code, m.Name, m.IsGroup FROM mch m
		INNER JOIN tree ON m.groupc = tree.Code
	)
SELECT t.Struct, REPLICATE('    ', t.level - 1) + t.Code StLabel, m.Name MName, Comments, ProductionFactor, SetupTimeFactor, Res_ResBufferTimeV9Before
	, Res_ResBufferTimeV9After, m.IsGroup, m.QadResource
	, IIF(m.IsGroup=0, IIF(m.ResClass = 'F3', N'Kemence erõforrás (Spec 3)', N'Egyszerû erõforrás'), N'') Class
	, IIF(m.IsGroup=0, IIF(m.ConstrainResQty = 'N', 'Nem korlátozott', 'Korlátozott'), '') Constrain
	FROM tree t
	INNER JOIN mch1 m ON t.Code = m.Code
	ORDER BY Struct
	OPTION (MAXRECURSION 32)