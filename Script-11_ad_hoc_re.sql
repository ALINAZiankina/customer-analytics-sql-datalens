/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Зянкина Алина
 * Дата: 01.05.2026
*/


-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
filtered_id AS(
    SELECT a.id
    FROM real_estate.flats AS f
    INNER JOIN real_estate.advertisement AS a ON a.id=f.id
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
        AND EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018
    ),
category_tools AS (
	SELECT id,
		CASE 
			WHEN days_exposition<=30 THEN 'меньше месяца'
			WHEN days_exposition<=90 THEN 'до трех месяцев'
			WHEN days_exposition<=180 THEN 'до полугода'
			WHEN days_exposition>180 THEN 'более полугода'
			ELSE 'non category'
		END AS category_sale
	FROM real_estate.advertisement
		),
city_n AS (
	SELECT f.id,
		CASE 
			WHEN c.city='Санкт-Петербург' THEN 'Санкт-Петербург'
			ELSE 'Ленинградская область'
		END AS city_name
	FROM real_estate.city AS c
	RIGHT JOIN real_estate.flats AS f ON f.city_id=c.city_id 
	LEFT JOIN real_estate.TYPE AS t ON f.type_id=t.type_id
	WHERE t.TYPE='город'
	)
SELECT cn.city_name,
	ct.category_sale,
	count(w.id) AS count_sales,
	round(avg(w.price_metr2)::numeric,2) AS avg_price,
	round(avg(w.total_area)::numeric,2) AS avg_total_area,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS median_balcone,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS median_room
FROM (
	SELECT f.id,
		total_area,
		rooms,
		balcony,
		a.last_price / f.total_area AS price_metr2
		FROM real_estate.flats AS f 
		LEFT JOIN real_estate.advertisement AS a ON a.id=f.id
	) AS w
INNER JOIN filtered_id AS fil ON fil.id=w.id 
LEFT JOIN category_tools AS ct ON ct.id=w.id
LEFT JOIN city_n AS cn ON cn.id=w.id
WHERE city_name IS NOT NULL 
GROUP BY cn.city_name,ct.category_sale
ORDER BY cn.city_name,ct.category_sale,count_sales DESC 

-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
        AND type_id='F8EM'
    ),
 data_adv AS (
 	SELECT f.id,
 		extract(MONTH FROM a.first_day_exposition) AS first_day_exposition,
 		extract(MONTH FROM (a.first_day_exposition::date  + a.days_exposition*INTERVAL '1 day')::date) AS last_day_exposition
 	FROM real_estate.advertisement AS a
 	RIGHT JOIN filtered_id AS f ON f.id=a.id
 	WHERE EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018 
 ),
 stat AS (
 	SELECT a.id,
 		round((a.last_price / f.total_area)::numeric,2) AS price_matr2,
 		total_area
 	FROM real_estate.advertisement AS a
 	LEFT JOIN real_estate.flats AS f ON f.id=a.id
 ), first_stat AS (
 	SELECT first_day_exposition,
		count(stat.id) AS fcount_sales,
		round(avg(price_matr2)::numeric,2) AS favg_price_m2,
		round(avg(total_area)::numeric,2) AS favg_total_area
	FROM data_adv
	LEFT JOIN stat AS stat ON stat.id=data_adv.id 
	GROUP BY first_day_exposition
	ORDER BY first_day_exposition
), last_stat AS (
	SELECT last_day_exposition,
		count(stat.id) AS lcount_sales,
		round(avg(price_matr2)::numeric,2) AS lavg_price_m2,
		round(avg(total_area)::numeric,2) AS lavg_total_area
	FROM data_adv
	LEFT JOIN stat AS stat ON stat.id=data_adv.id
	GROUP BY last_day_exposition
	ORDER BY last_day_exposition
)
SELECT 
	CASE 
		WHEN first_day_exposition=1 THEN 'январь'
		WHEN first_day_exposition=2 THEN 'февраль'
		WHEN first_day_exposition=3 THEN 'март'
		WHEN first_day_exposition=4 THEN 'апрель'
		WHEN first_day_exposition=5 THEN 'май'
		WHEN first_day_exposition=6 THEN 'июнь'
		WHEN first_day_exposition=7 THEN 'июль'
		WHEN first_day_exposition=8 THEN 'август'
		WHEN first_day_exposition=9 THEN 'сентябрь'
		WHEN first_day_exposition=10 THEN 'октябрь'
		WHEN first_day_exposition=11 THEN 'ноябрь'
		WHEN first_day_exposition=12 THEN 'декабрь'
		ELSE 'нет данных'
	END AS month_events,
	fcount_sales AS count_advir,
	favg_price_m2 AS avg_price_advir,
	favg_total_area AS avg_area_advir,
	lcount_sales AS count_sale,
	lavg_price_m2 AS avg_price_sale,
	lavg_total_area AS avg_area_sale
FROM first_stat
FULL JOIN last_stat ON last_stat.last_day_exposition=first_stat.first_day_exposition
WHERE last_stat.last_day_exposition IS NOT NULL 
