/* 1. DELETE Data */
TRUNCATE TABLE direct.flash_report_item;

/* 2. CREATE Data */
INSERT INTO direct.flash_report_item
(
/* 2-1-1. booking info(UQ) */
WITH booking_info_uq AS (
	SELECT
		oms_booking_header.order_no     AS order_no,
		oms_booking_detail.l3_item_code AS l3_item_code,
		SUM(CASE
			WHEN
				(oms_booking_detail.stock_type in ('CONFIRMED_STOCK', 'STOCK_IN_TRANSIT', 'PRE_ORDER_STOCK'))
			THEN
				oms_booking_detail.booking_quantity
			ELSE 0 
			END
			) AS item_quantity
	FROM
		analyticspf.oms_booking_header
	INNER JOIN
		analyticspf.oms_booking_detail
	ON
		oms_booking_header.booking_header_id = oms_booking_detail.booking_header_id
	INNER JOIN
		(
		SELECT
			oms_core_order.order_no AS order_no
		FROM
			analyticspf.oms_core_order
		WHERE
			oms_core_order.order_status in ('ORDER_ACCEPTANCE','SHIPMENT_PENDING','ORDER_CONFIRMATION','SHIPMENT_ORDER_WAIT','SHIPMENT_ORDERED','SHIPMENT_CONFIRMED','DELIVERY_COMPLETE')
		AND
			CASE
				WHEN
					TO_CHAR(GETDATE(),'YYYY-MM-DD' || ' 00:00:00') <= TO_CHAR(GETDATE(),'YYYY-MM-DD HH24:MI:SS')
					AND
					TO_CHAR(GETDATE(),'YYYY-MM-DD HH24:MI:SS') <= TO_CHAR(GETDATE(),'YYYY-MM-DD' || ' 17:59:59')
				THEN
					TO_CHAR(DATEADD('day', -1 ,GETDATE()),'YYYY-MM-DD' || ' 17:00:00') <= oms_core_order.order_confirmed_datetime
					AND
					oms_core_order.order_confirmed_datetime  <= TO_CHAR(GETDATE(),'YYYY-MM-DD' || ' 16:59:59')
				ELSE
					TO_CHAR(GETDATE(),'YYYY-MM-DD' || ' 17:00:00') <= oms_core_order.order_confirmed_datetime
					AND
					oms_core_order.order_confirmed_datetime <= TO_CHAR(DATEADD('day', 1 ,GETDATE()),'YYYY-MM-DD' || ' 16:59:59')
				END
		) AS oms_core_order
		ON
			oms_booking_header.order_no = oms_core_order.order_no
		WHERE
			oms_booking_detail.novelty_item_flag = 'N'
		AND
			oms_booking_header.order_cancel_status IS NULL
		GROUP BY
			oms_booking_header.order_no,
			oms_booking_detail.l3_item_code
),
/* 2-2-1. booking info(GU) */
booking_info_gu AS (
	SELECT
		oms_booking_header.order_no     AS order_no,
		oms_booking_detail.l3_item_code AS l3_item_code,
		SUM(CASE
			WHEN
				(oms_booking_detail.stock_type in ('CONFIRMED_STOCK', 'STOCK_IN_TRANSIT', 'PRE_ORDER_STOCK'))
			THEN
				oms_booking_detail.booking_quantity
			ELSE 0 
			END
			) AS item_quantity
	FROM
		analyticspf.oms_booking_header
	INNER JOIN
		analyticspf.oms_booking_detail
	ON
		oms_booking_header.booking_header_id = oms_booking_detail.booking_header_id
	INNER JOIN
		(
		SELECT
			oms_core_order_gu.order_no AS order_no
		FROM
			analyticspf.oms_core_order_gu
		WHERE
			oms_core_order_gu.order_status in ('ORDER_ACCEPTANCE','SHIPMENT_PENDING','ORDER_CONFIRMATION','SHIPMENT_ORDER_WAIT','SHIPMENT_ORDERED','SHIPMENT_CONFIRMED','DELIVERY_COMPLETE')
		AND
			CASE
				WHEN
					TO_CHAR(GETDATE(),'YYYY-MM-DD' || ' 00:00:00') <= TO_CHAR(GETDATE(),'YYYY-MM-DD HH24:MI:SS')
					AND
					TO_CHAR(GETDATE(),'YYYY-MM-DD HH24:MI:SS') <= TO_CHAR(GETDATE(),'YYYY-MM-DD' || ' 17:59:59')
				THEN
					TO_CHAR(DATEADD('day', -1 ,GETDATE()),'YYYY-MM-DD' || ' 17:00:00') <= oms_core_order_gu.order_confirmed_datetime
					AND
					oms_core_order_gu.order_confirmed_datetime  <= TO_CHAR(GETDATE(),'YYYY-MM-DD' || ' 16:59:59')
				ELSE
					TO_CHAR(GETDATE(),'YYYY-MM-DD' || ' 17:00:00') <= oms_core_order_gu.order_confirmed_datetime
					AND
					oms_core_order_gu.order_confirmed_datetime <= TO_CHAR(DATEADD('day', 1 ,GETDATE()),'YYYY-MM-DD' || ' 16:59:59')
				END
		) AS oms_core_order_gu
		ON
			oms_booking_header.order_no = oms_core_order_gu.order_no
		WHERE
			oms_booking_detail.novelty_item_flag = 'N'
		AND
			oms_booking_header.order_cancel_status IS NULL
		GROUP BY
			oms_booking_header.order_no,
			oms_booking_detail.l3_item_code
),
/* 2-3-1. order info(UQ) */
order_info_uq AS (
	SELECT
		oms_core_order.order_no                 AS order_no,
		oms_core_order_detail.order_detail_no   AS order_detail_no,
		UPPER(oms_core_order.region_code)       AS region_code,
		UPPER(oms_core_order.brand_code)        AS brand_code,
		oms_core_order_detail.g_department_code AS g_department_code,
		(CASE
			WHEN
				TO_CHAR(oms_core_order.order_confirmed_datetime,'YYYY-MM-DD' || ' 15:00:00') <= TO_CHAR(oms_core_order.order_confirmed_datetime,'YYYY-MM-DD HH24:MI:SS')
				AND
				TO_CHAR(oms_core_order.order_confirmed_datetime,'YYYY-MM-DD HH24:MI:SS') <= TO_CHAR(oms_core_order.order_confirmed_datetime,'YYYY-MM-DD' || ' 17:59:59')
			THEN
				TO_DATE(DATEADD('day', -1 ,CONVERT_TIMEZONE('JST', oms_core_order.order_confirmed_datetime)), 'YYYY/MM/DD')
			ELSE
				TO_DATE(CONVERT_TIMEZONE('JST', oms_core_order.order_confirmed_datetime), 'YYYY/MM/DD')
			END) AS business_date,
		oms_core_order_detail.l1_item_code || '-' || oms_core_order_detail.display_color_code || '-' || oms_core_order_detail.display_size_code || '-' || oms_core_order_detail.display_pattern_length_code AS item_code,
		oms_core_inventory_booking.l3_item_code AS l3_item_code,
		oms_core_order_detail.item_name AS item_name,
		oms_core_order_detail.applied_detail_retail_price_tax_excluded AS applied_detail_retail_price_tax_excluded
	FROM
		analyticspf.oms_core_order
	INNER JOIN
		analyticspf.oms_core_order_detail
	ON
		oms_core_order.order_no = oms_core_order_detail.order_no
	LEFT JOIN
		analyticspf.oms_core_inventory_booking
	ON
		oms_core_order.order_no = oms_core_inventory_booking.order_no
	AND 
		oms_core_order_detail.order_detail_no = oms_core_inventory_booking.order_detail_no
	WHERE
		oms_core_order.order_status in ('ORDER_ACCEPTANCE','SHIPMENT_PENDING','ORDER_CONFIRMATION','SHIPMENT_ORDER_WAIT','SHIPMENT_ORDERED','SHIPMENT_CONFIRMED','DELIVERY_COMPLETE')
	AND
		(CASE
			WHEN
				TO_CHAR(GETDATE(),'YYYY-MM-DD' || ' 00:00:00') <= TO_CHAR(GETDATE(),'YYYY-MM-DD HH24:MI:SS')
				AND
				TO_CHAR(GETDATE(),'YYYY-MM-DD HH24:MI:SS') <= TO_CHAR(GETDATE(),'YYYY-MM-DD' || ' 17:59:59')
			THEN
				TO_CHAR(DATEADD('day', -1 ,GETDATE()),'YYYY-MM-DD' || ' 17:00:00') <= oms_core_order.order_confirmed_datetime
				AND
				oms_core_order.order_confirmed_datetime  <= TO_CHAR(GETDATE(),'YYYY-MM-DD' || ' 16:59:59')
			ELSE
				TO_CHAR(GETDATE(),'YYYY-MM-DD' || ' 17:00:00') <= oms_core_order.order_confirmed_datetime
				AND
				oms_core_order.order_confirmed_datetime <= TO_CHAR(DATEADD('day', 1 ,GETDATE()),'YYYY-MM-DD' || ' 16:59:59')
			END)
),
/* 2-4-1. order info(GU) */
order_info_gu AS (
	SELECT
		oms_core_order_gu.order_no                 AS order_no,
		oms_core_order_detail_gu.order_detail_no   AS order_detail_no,
		UPPER(oms_core_order_gu.region_code)       AS region_code,
		UPPER(oms_core_order_gu.brand_code)        AS brand_code,
		oms_core_order_detail_gu.g_department_code AS g_department_code,
		(CASE
			WHEN
				TO_CHAR(oms_core_order_gu.order_confirmed_datetime,'YYYY-MM-DD' || ' 15:00:00') <= TO_CHAR(oms_core_order_gu.order_confirmed_datetime,'YYYY-MM-DD HH24:MI:SS')
				AND
				TO_CHAR(oms_core_order_gu.order_confirmed_datetime,'YYYY-MM-DD HH24:MI:SS') <= TO_CHAR(oms_core_order_gu.order_confirmed_datetime,'YYYY-MM-DD' || ' 17:59:59')
			THEN
				TO_DATE(DATEADD('day', -1 ,CONVERT_TIMEZONE('JST', oms_core_order_gu.order_confirmed_datetime)), 'YYYY/MM/DD')
			ELSE
				TO_DATE(CONVERT_TIMEZONE('JST', oms_core_order_gu.order_confirmed_datetime), 'YYYY/MM/DD')
			END) AS business_date,
		oms_core_order_detail_gu.l1_item_code || '-' || oms_core_order_detail_gu.display_color_code || '-' || oms_core_order_detail_gu.display_size_code || '-' || oms_core_order_detail_gu.display_pattern_length_code AS item_code,
		oms_core_inventory_booking_gu.l3_item_code AS l3_item_code,
		oms_core_order_detail_gu.item_name AS item_name,
		oms_core_order_detail_gu.applied_detail_retail_price_tax_excluded AS applied_detail_retail_price_tax_excluded
	FROM
		analyticspf.oms_core_order_gu
	INNER JOIN
		analyticspf.oms_core_order_detail_gu
	ON
		oms_core_order_gu.order_no = oms_core_order_detail_gu.order_no
	LEFT JOIN
		analyticspf.oms_core_inventory_booking_gu
	ON
		oms_core_order_gu.order_no = oms_core_inventory_booking_gu.order_no
	AND 
		oms_core_order_detail_gu.order_detail_no = oms_core_inventory_booking_gu.order_detail_no
	WHERE
		oms_core_order_gu.order_status in ('ORDER_ACCEPTANCE','SHIPMENT_PENDING','ORDER_CONFIRMATION','SHIPMENT_ORDER_WAIT','SHIPMENT_ORDERED','SHIPMENT_CONFIRMED','DELIVERY_COMPLETE')
	AND
		(CASE
			WHEN
				TO_CHAR(GETDATE(),'YYYY-MM-DD' || ' 00:00:00') <= TO_CHAR(GETDATE(),'YYYY-MM-DD HH24:MI:SS')
				AND
				TO_CHAR(GETDATE(),'YYYY-MM-DD HH24:MI:SS') <= TO_CHAR(GETDATE(),'YYYY-MM-DD' || ' 17:59:59')
			THEN
				TO_CHAR(DATEADD('day', -1 ,GETDATE()),'YYYY-MM-DD' || ' 17:00:00') <= oms_core_order_gu.order_confirmed_datetime
				AND
				oms_core_order_gu.order_confirmed_datetime  <= TO_CHAR(GETDATE(),'YYYY-MM-DD' || ' 16:59:59')
			ELSE
				TO_CHAR(GETDATE(),'YYYY-MM-DD' || ' 17:00:00') <= oms_core_order_gu.order_confirmed_datetime
				AND
				oms_core_order_gu.order_confirmed_datetime <= TO_CHAR(DATEADD('day', 1 ,GETDATE()),'YYYY-MM-DD' || ' 16:59:59')
			END)
),
/* 2-7-1. L3 aggregate*/
order_info_all AS (
	/* 2-5-1. */
	SELECT
		order_info_uq.business_date           AS business_date,
		order_info_uq.region_code             AS region_code,
		order_info_uq.brand_code              AS brand_code,
		order_info_uq.g_department_code       AS g_department_code,
		order_info_uq.item_code               AS item_code,
		order_info_uq.l3_item_code            AS l3_item_code,
		order_info_uq.item_name               AS item_name,
		NVL(ROUND(SUM(order_info_uq.applied_detail_retail_price_tax_excluded),2),0.00) AS item_price,
		NVL(SUM(booking_info_uq.item_quantity),0)   AS item_quantity
	FROM
		order_info_uq
	LEFT JOIN
		booking_info_uq
	ON
		order_info_uq.order_no = booking_info_uq.order_no
	AND
		order_info_uq.l3_item_code = booking_info_uq.l3_item_code
	GROUP BY
		order_info_uq.business_date, order_info_uq.region_code, order_info_uq.brand_code, order_info_uq.g_department_code, 
		order_info_uq.item_code, order_info_uq.l3_item_code, order_info_uq.item_name
	UNION ALL
	/* 2-6-1. */
	SELECT
		order_info_gu.business_date           AS business_date,
		order_info_gu.region_code             AS region_code,
		order_info_gu.brand_code              AS brand_code,
		order_info_gu.g_department_code       AS g_department_code,
		order_info_gu.item_code               AS item_code,
		order_info_gu.l3_item_code            AS l3_item_code,
		order_info_gu.item_name               AS item_name,
		NVL(ROUND(SUM(order_info_gu.applied_detail_retail_price_tax_excluded),2),0.00) AS item_price,
		NVL(SUM(booking_info_gu.item_quantity),0)   AS item_quantity
	FROM
		order_info_gu
	LEFT JOIN
		booking_info_gu
	ON
		order_info_gu.order_no = booking_info_gu.order_no 
	AND
		order_info_gu.l3_item_code = booking_info_gu.l3_item_code
	GROUP BY
		order_info_gu.business_date, order_info_gu.region_code, order_info_gu.brand_code, order_info_gu.g_department_code, 
		order_info_gu.item_code, order_info_gu.l3_item_code, order_info_gu.item_name
)
/* 2-7-2. stock info JOIN*/
	SELECT
		order_info_all.business_date      AS business_date,
		order_info_all.region_code        AS region_code,
		order_info_all.brand_code         AS brand_code,
		order_info_all.g_department_code  AS g_department_code,
		order_info_all.item_code          AS item_code,
		order_info_all.l3_item_code       AS l3_item_code,
		order_info_all.item_name          AS item_name,
		order_info_all.item_price         AS item_price,
		order_info_all.item_quantity      AS item_quantity,
		stock_info.real_stock_qty + stock_info.backordered_stock_qty - order_info_all.item_quantity AS stock_quantity,
		SYSDATE                           AS updated_datetime
	FROM
		order_info_all
	LEFT JOIN
	(
		SELECT
			l3_item_code,
			NVL(SUM(real_stock_qty),0) AS real_stock_qty,
			NVL(SUM(backordered_stock_qty),0) AS backordered_stock_qty
		FROM
			(
				SELECT
					oms_stock_header.l3_item_code AS l3_item_code,
					(CASE
						WHEN
							(oms_stock_detail.stock_status in ('LAYAWAY_STOCK','AVAILABLE_STOCK'))
							AND
							(oms_stock_header.stock_type = 'CONFIRMED_STOCK')
						THEN
							oms_stock_detail.quantity
						ELSE
							0
						END) AS real_stock_qty,
					(CASE
						WHEN
							(oms_stock_detail.stock_status = 'AVAILABLE_STOCK')
							AND
							(oms_stock_header.stock_type in ('STOCK_IN_TRANSIT','PRE_ORDER_STOCK'))
						THEN
							oms_stock_detail.quantity
						ELSE
							0
						END) AS backordered_stock_qty
				FROM
					analyticspf.oms_stock_header
				INNER JOIN
					analyticspf.oms_stock_detail
				ON
					oms_stock_header.stock_id = oms_stock_detail.stock_id
			)
		GROUP BY l3_item_code
	) stock_info
	ON
		order_info_all.l3_item_code = stock_info.l3_item_code
	ORDER BY 
		order_info_all.business_date ASC,
		order_info_all.region_code ASC,
		order_info_all.brand_code ASC,
		order_info_all.item_price DESC,
		order_info_all.g_department_code ASC,
		order_info_all.l3_item_code ASC,
		order_info_all.item_quantity ASC	-- 20191126 GitHubのテスト用に追加
);
COMMIT;
