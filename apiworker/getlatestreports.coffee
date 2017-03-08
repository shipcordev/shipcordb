Q = require('q')
_ = require('underscore')
csv = require('fast-csv')
pg = require('pg')
MWSClient = require('mws-api')

config = require('../config')

client = new pg.Client(config.DATABASE_URL)

fbaFeesColumns = ["seller",
	"\"snapshot-date\"", 
	"sku",
	"fnsku",
	"asin",
	"\"product-name\"",
	"\"product-group\"",
	"brand",
	"\"fulfilled-by\"",
	"\"your-price\"",
	"\"sales-price\"",
	"\"longest-side\"",
	"\"median-side\"",
	"\"shortest-side\"",
	"\"length-and-girth\"",
	"\"unit-of-dimension\"",
	"\"item-package-weight\"",
	"\"unit-of-weight\"",
	"\"product-size-tier\"",
	"currency",
	"\"estimated-fee-total\"",
	"\"estimated-referral-fee-per-unit\"",
	"\"estimated-variable-closing-fee\"",
	"\"estimated-order-handling-fee-per-order\"",
	"\"estimated-pick-pack-fee-per-unit\"",
	"\"estimated-weight-handling-fee-per-unit\"",
	"\"estimated-future-fee\"",
	"\"estimated-future-order-handling-fee-per-order\"",
	"\"estimated-future-pick-pack-fee-per-unit\"",
	"\"estimated-future-weight-handling-fee-per-unit\"",
	"\"expected-future-fulfillment-fee-per-unit\""]

inventoryHealthColumns = ["seller",
	"\"snapshot-date\"", 
	"sku",
	"fnsku",
	"asin",
	"\"product-name\"",
	"condition",
	"\"sales-rank\"",
	"\"product-group\"",
	"\"total-quantity\"",
	"\"sellable-quantity\"",
	"\"unsellable-quantity\"",
	"\"inv-age-0-to-90-days\"",
	"\"inv-age-91-to-180-days\"",
	"\"inv-age-181-to-270-days\"",
	"\"inv-age-271-to-365-days\"",
	"\"inv-age-365-plus-days\"",
	"\"units-shipped-last-24-hrs\"",
	"\"units-shipped-last-7-days\"",
	"\"units-shipped-last-30-days\"",
	"\"units-shipped-last-90-days\"",
	"\"units-shipped-last-180-days\"",
	"\"units-shipped-last-365-days\"",
	"\"weeks-of-cover-t7\"",
	"\"weeks-of-cover-t30\"",
	"\"weeks-of-cover-t90\"",
	"\"weeks-of-cover-t180\"",
	"\"weeks-of-cover-t365\"",
	"\"num-afn-new-sellers\"",
	"\"num-afn-used-sellers\"",
	"currency",
	"\"your-price\"",
	"\"sales-price\"",
	"\"lowest-afn-new-price\"",
	"\"lowest-afn-used-price\"",
	"\"lowest-mfn-new-price\"",
	"\"lowest-mfn-used-price\"",
	"\"qty-to-be-charged-ltsf-12-mo\"",
	"\"qty-in-long-term-storage-program\"",
	"\"qty-with-removals-in-progress\"",
	"\"projected-ltsf-12-mo\"",
	"\"per-unit-volume\"",
	"\"is-hazmat\"",
	"\"in-bound-quantity\"",
	"\"asin-limit\"",
	"\"inbound-recommend-quantity\"",
	"\"qty-to-be-charged-ltsf-6-mo\"",
	"\"projected-ltsf-6-mo\""]

getReportList = (reportTypes, delay) ->
	Q.all([mws.Reports.GetReportList({
		ReportTypeList: reportTypes
	}), client.query('SELECT * FROM \"report-snapshot-dates\" WHERE seller=\'' + config.SELLER_ACCOUNT + '\' ORDER BY \"snapshot-date\" DESC')])
	.spread (reportListData, snapshotDates) ->
		mostRecentSnapshotByType = []
		for snapshot in snapshotDates.rows
			if mostRecentSnapshotByType[snapshot['type']] == undefined
				snapshotDate = new Date(snapshot['snapshot-date'])
				formattedSnapshotDate = snapshotDate.getFullYear()+'-' + (snapshotDate.getMonth()+1) + '-'+snapshotDate.getDate()
				mostRecentSnapshotByType[snapshot['type']] = formattedSnapshotDate
		console.log "Processing reports..."
		reportIdAndTimestampsByType = []
		if reportListData.result.ReportInfo != undefined
			for reportRequest in reportListData.result.ReportInfo
				if reportRequest.ReportType == "_GET_FBA_ESTIMATED_FBA_FEES_TXT_DATA_" and reportIdAndTimestampsByType["_GET_FBA_ESTIMATED_FBA_FEES_TXT_DATA_"] == undefined
					reportIdAndTimestampsByType["_GET_FBA_ESTIMATED_FBA_FEES_TXT_DATA_"] = {
						id:	reportRequest.ReportId
						timestamp: reportRequest.AvailableDate
					}
				if reportRequest.ReportType == "_GET_FBA_FULFILLMENT_INVENTORY_HEALTH_DATA_" and reportIdAndTimestampsByType["_GET_FBA_FULFILLMENT_INVENTORY_HEALTH_DATA_"] == undefined
					reportIdAndTimestampsByType["_GET_FBA_FULFILLMENT_INVENTORY_HEALTH_DATA_"] = {
						id: reportRequest.ReportId
						timestamp: reportRequest.AvailableDate
					}
					
				if Object.keys(reportIdAndTimestampsByType).length == 2
					break
		Q.allSettled(_.map(Object.keys(reportIdAndTimestampsByType), (reportType) ->
			mws.Reports.GetReport({ReportId: reportIdAndTimestampsByType[reportType].id})
			.then (report) ->
				deferred = Q.defer()
				date = new Date(reportIdAndTimestampsByType[reportType].timestamp)
				formattedDate = date.getFullYear()+'-' + (date.getMonth()+1) + '-'+date.getDate()
				queryParams = []
				if reportType == '_GET_FBA_FULFILLMENT_INVENTORY_HEALTH_DATA_' and mostRecentSnapshotByType['inventory-health'] == formattedDate
					return Q('')
				else if reportType == '_GET_FBA_ESTIMATED_FBA_FEES_TXT_DATA_' and mostRecentSnapshotByType['fba-fees'] == formattedDate
					return Q('')
				else
					csv.fromString(report.result, { headers: true, delimiter: '\t', quote: null})
					.on("data", (data) ->
						insertPlaceholders = new Array()
						count = 0
						insertValues = new Array()
						tableToInsert = "inventory-health"
						insertValues.push(config.SELLER_ACCOUNT)
						insertPlaceholders.push("$" + ++count)
						if !_.contains(Object.keys(data), "snapshot-date")
							tableToInsert = "fba-fees"
							insertValues.push(formattedDate)
							insertPlaceholders.push("$" + ++count)
						for key in Object.keys(data)
							if key == "snapshot-date"
								insertValues.push(formattedDate)
							else if key == "is-hazmat"
								if data[key] == 'N'
									insertValues.push(false)
								else
									insertValues.push(true)
							else if data[key] == null || data[key] == undefined || data[key].trim() == '' || data[key].trim() == '--'
								insertValues.push(null)
							else
								insertValues.push(data[key])
							insertPlaceholders.push("$" + ++count)
						queryString = ''
						if tableToInsert == "fba-fees"
							queryString = 'INSERT INTO "' + tableToInsert + '"(' + fbaFeesColumns.join(',') + ') VALUES (' + insertPlaceholders.join(',') + ') RETURNING id'
						else
							queryString = 'INSERT INTO "' + tableToInsert + '"(' + inventoryHealthColumns.join(',') + ') VALUES (' + insertPlaceholders.join(',') + ') RETURNING id'
						queryParams.push({
							tableName: tableToInsert
							queryString: queryString
							insertValues: insertValues
							date: formattedDate
						})
					)
					.on("error", (data) -> 
						console.log data
						deferred.reject(new Error(data))
					)
					.on("end", () ->
						deferred.resolve(queryParams)
					)
					deferred.promise
			.then (queries) ->
				Q.allSettled(_.map(_.filter(queries, (query) -> query != ''), (query) ->
					deferred = Q.defer()
					client.query(
						query.queryString, query.insertValues
					, (err, result) ->
						if err
							console.log err
							deferred.reject(new Error(err))
						else
							deferred.resolve({
								tableName: query.tableName
								id: result.rows[0].id
								date: query.date
							})
					)
					deferred.promise
				))
			)).then (results) ->
				deferred = Q.defer()
				numReportsCompleted = 0
				for result in results
					if result.state == "fulfilled"
						console.log result.value
						if result.value.length > 0
							firstResult = result.value[0]
							firstResultValue = firstResult.value
							client.query('INSERT INTO \"report-snapshot-dates\"(seller, type, \"snapshot-date\") VALUES (\'' + config.SELLER_ACCOUNT + '\', \'' + firstResultValue.tableName + '\',\'' + firstResultValue.date + '\')')
								.then (err, result) ->
									numReportsCompleted++
									if numReportsCompleted == results.length
										deferred.resolve({
											numReports: numReportsCompleted
										})
						else
							numReportsCompleted++
							if numReportsCompleted == results.length
								deferred.resolve({
									numReports: numReportsCompleted
								})
				deferred.promise
			.then (result) ->
				console.log "Reports completed: " + result.numReports		
				client.end()
		.done()

###
	First, request both reports, then get report request list, then get each
	report once they are ready

	To get the report request list of reports that were just requested
	and not all of them, keep a timestamp of when the process has started
	and only ask for reports requested from that timestamp


###
if config.IS_WORKER
	mws = new MWSClient({
		accessKeyId: config.AWS_ACCESS_KEY
		secretAccessKey: config.MWS_SECRET_KEY
		merchantId: config.SELLER_ID
		meta: 
			retry: true
			next: true
			limit: Infinity	
	})

module.exports.getReports = ->
	currentTime = new Date()
	currentTimestamp = currentTime.toISOString()

	reportTypes = ["_GET_FBA_ESTIMATED_FBA_FEES_TXT_DATA_", "_GET_FBA_FULFILLMENT_INVENTORY_HEALTH_DATA_"]

	client.connect()

	getReportList(reportTypes, 60000)