Задача 1. Время активности объявлений

-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
-- Подсчитаем общее количество объявлений по регионам
total_count AS (
    SELECT 
        CASE 
            WHEN c.city='Санкт-Петербург' THEN 'Санкт-Петербург'
            WHEN c.city<>'Санкт-Петербург' THEN 'ЛенОбл'
        END AS region,
        COUNT(DISTINCT f.id) AS total_count
    FROM real_estate.flats AS f
    JOIN real_estate.city AS c ON f.city_id = c.city_id
    JOIN real_estate.advertisement AS a ON f.id = a.id
    JOIN real_estate.TYPE AS t ON f.type_id = t.type_id
    WHERE a.days_exposition IS NOT NULL AND f.id IN (SELECT * FROM filtered_id) AND type = 'город'
    GROUP BY region
)
SELECT 
    tc.region AS "Регион",
    CASE 
        WHEN a.days_exposition>=1 AND a.days_exposition<=30 THEN 'менее месяца'
        WHEN a.days_exposition>30 AND a.days_exposition<=90 THEN 'до трех месяцев'
        WHEN a.days_exposition>90 AND a.days_exposition<=180 THEN 'до полугода'
        WHEN a.days_exposition>180 THEN 'более полугода'
        ELSE 'не продано'
    END AS "Сегмент активности",
    COUNT(DISTINCT f.id) AS "Количество объявлений",
    ROUND((COUNT(DISTINCT f.id)::numeric/ tc.total_count),2) AS "Доля к объявлениям региона",
    AVG(a.last_price/f.total_area)::NUMERIC(12,1) AS "Средняя стоимость кв.метра",
    AVG(f.total_area)::NUMERIC(5,1) AS "Средняя площадь",
    PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY f.rooms)::NUMERIC(5,1) AS "Медиана кол-ва комнат",
    PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY f.balcony)::NUMERIC(5,1) AS "Медиана кол-ва балконов",
    PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY f.floor)::NUMERIC(5,1) AS "Медиана этажности"
FROM real_estate.flats AS f
JOIN real_estate.city AS c ON f.city_id = c.city_id
JOIN real_estate.advertisement AS a ON f.id = a.id
JOIN real_estate.TYPE AS t ON f.type_id = t.type_id
JOIN total_count tc ON 
    CASE 
        WHEN c.city='Санкт-Петербург' THEN 'Санкт-Петербург'
        WHEN c.city<>'Санкт-Петербург' THEN 'ЛенОбл'
    END = tc.region
WHERE f.id IN (SELECT * FROM filtered_id) AND type = 'город'
GROUP BY tc.region, "Сегмент активности", tc.total_count
ORDER BY tc.region DESC, "Сегмент активности" DESC;


Задача 2. Сезонность объявлений

--общий запрос, чтоб понимать, какой период лет брать в задаче для анализа 
SELECT 
	MIN(first_day_exposition) AS "первая публикация объявления",
	MAX(first_day_exposition) AS "последняя публикация объявления"
FROM real_estate.advertisement;


-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
ste_1 AS(
	SELECT
		a.id AS id_1,
		EXTRACT (MONTH FROM a.first_day_exposition) AS month_publish,-- выделяем номер месяца из даты публикаци 
		a.last_price/f.total_area AS metropublish,
		f.total_area AS total_area_publish
	FROM real_estate.flats AS f
	JOIN real_estate.city AS c ON f.city_id = c.city_id
	JOIN real_estate.advertisement AS a ON f.id = a.id
	JOIN real_estate.TYPE AS t ON f.type_id = t.type_id
	WHERE t.TYPE = 'город' AND a.id IN (SELECT * FROM filtered_id) AND EXTRACT (YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018),
ste_1_1 AS(
		SELECT 
		CASE 
			WHEN month_publish=1 THEN 'Январь'
			WHEN month_publish=2 THEN 'Февраль'
			WHEN month_publish=3 THEN 'Март'
			WHEN month_publish=4 THEN 'Апрель'
			WHEN month_publish=5 THEN 'Май'
			WHEN month_publish=6 THEN 'Июнь'
			WHEN month_publish=7 THEN 'Июль'
			WHEN month_publish=8 THEN 'Август'
			WHEN month_publish=9 THEN 'Сентябрь'
			WHEN month_publish=10 THEN 'Октябрь'
			WHEN month_publish=11 THEN 'Ноябрь'
			WHEN month_publish=12 THEN 'Декабрь'
		END AS month_name_publish,
		COUNT(id_1) AS count_id_publish,
		AVG(metropublish)::numeric(12,2) AS avg_metropublish,
		AVG(total_area_publish)::numeric(6,2) AS avg_total_area_publish,
		month_publish
	FROM ste_1
	GROUP BY month_publish),
ste_2 AS(
	SELECT
		a.id AS id_2,
		EXTRACT (MONTH FROM (a.first_day_exposition + a.days_exposition:: integer)) AS month_sell,-- выделяем номер месяца из даты снятия с публикаци
		a.last_price/f.total_area AS metrocost,
		f.total_area AS total_area_sell
	FROM real_estate.flats AS f
	JOIN real_estate.city AS c ON f.city_id = c.city_id
	JOIN real_estate.advertisement AS a ON f.id = a.id
	JOIN real_estate.TYPE AS t ON f.type_id = t.type_id
	WHERE t.TYPE = 'город' AND a.id IN (SELECT * FROM filtered_id) AND EXTRACT (YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018),
ste_3 AS(
	SELECT 
		CASE 
			WHEN month_sell=1 THEN 'Январь'
			WHEN month_sell=2 THEN 'Февраль'
			WHEN month_sell=3 THEN 'Март'
			WHEN month_sell=4 THEN 'Апрель'
			WHEN month_sell=5 THEN 'Май'
			WHEN month_sell=6 THEN 'Июнь'
			WHEN month_sell=7 THEN 'Июль'
			WHEN month_sell=8 THEN 'Август'
			WHEN month_sell=9 THEN 'Сентябрь'
			WHEN month_sell=10 THEN 'Октябрь'
			WHEN month_sell=11 THEN 'Ноябрь'
			WHEN month_sell=12 THEN 'Декабрь'
		END AS month_name_sell,
		COUNT(id_2) AS count_id_sell,
		AVG(metrocost)::numeric(12,2) AS avg_metrocost,
		AVG(total_area_sell)::numeric(6,2) AS avg_total_area_sell,
		month_sell
	FROM ste_2
	GROUP BY month_sell)
SELECT
	s1.month_name_publish AS "Месяц",
	s1.count_id_publish AS "Число опубликованных объявлений",
	s2.count_id_sell AS "Число снятых объявлений",
	s2.count_id_sell-s1.count_id_publish AS "Разница (снятые-опубликованные)",
	s1.avg_metropublish AS "Ср. ст-сть 1 кв.м. в опубликованных",
	s2.avg_metrocost AS "Ср. ст-сть 1 кв.м. в снятых",
	s1.avg_total_area_publish AS "Ср. площадь кв. в опубликованных",
	s2.avg_total_area_sell AS "Ср. площадь кв. в снятых"
FROM ste_1_1 AS s1
JOIN ste_3 AS s2 ON s1.month_publish=s2.month_sell 
ORDER BY s1.month_publish;
	

Задача 3. Анализ рынка недвижимости Ленобласти

-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
-- Подсчитаем количество размещённых объявлений по населённым пунктам и типам
published_stats AS (
    SELECT
        c.city,
        STRING_AGG(DISTINCT t.TYPE, ', ') AS types,
        COUNT(DISTINCT a.id) AS published_advert,
        AVG(a.last_price / f.total_area)::NUMERIC(12, 1) AS avg_sqvd_price,
        AVG(f.total_area)::NUMERIC(5, 1) AS avg_sqvd,
        AVG(a.days_exposition)::NUMERIC(5, 1) AS avg_days_published
    FROM real_estate.flats AS f
    JOIN real_estate.city AS c ON f.city_id = c.city_id
    JOIN real_estate.advertisement AS a ON f.id = a.id
    JOIN real_estate.TYPE AS t ON f.type_id = t.type_id
    WHERE c.city <> 'Санкт-Петербург' AND a.id IN (SELECT * FROM filtered_id)
    GROUP BY c.city
),
-- Подсчитаем количество снятых объявлений по населённым пунктам и типам
selled_stats AS (
    SELECT
        c.city,
        STRING_AGG(DISTINCT t.TYPE, ', ') AS types,
        COUNT(DISTINCT a.id) AS selled_advert
    FROM real_estate.flats AS f
    JOIN real_estate.city AS c ON f.city_id = c.city_id
    JOIN real_estate.advertisement AS a ON f.id = a.id
    JOIN real_estate.TYPE AS t ON f.type_id = t.type_id
    WHERE c.city <> 'Санкт-Петербург' AND a.days_exposition > 0 AND a.id IN (SELECT * FROM filtered_id)
    GROUP BY c.city
)
SELECT
    p.city AS "Населённый пункт",
    p.types AS "Типы населённых пунктов",
    p.published_advert AS "Размещённых объявлений",
    s.selled_advert AS "Снятых объявлений",
    ROUND(s.selled_advert::numeric / p.published_advert,2) AS "Доля проданных объектов",
    p.avg_sqvd_price AS "Средняя цена за кв. метр",
    p.avg_sqvd AS "Среднее кол-во кв. метров",
    p.avg_days_published AS "Среднее кол-во дней объявлений"
FROM published_stats p
JOIN selled_stats s ON p.city = s.city
WHERE p.published_advert>100 --отфильровали по количеству, чтобы увидеть топ-15 пунктов числу объявлений
ORDER BY "Доля проданных объектов" DESC, avg_sqvd_price DESC;