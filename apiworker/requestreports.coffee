Q = require('q')
MWSClient = require('mws-api')

config = require('../config')

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

module.exports.requestReports = ->
	currentTime = new Date()
	fbaFeesThirtyDaysAgo = new Date(currentTime.getTime() - (720 * 60 * 60 * 1000))
	fbaFeesThirtyDaysAgoTimestamp = fbaFeesThirtyDaysAgo.toISOString()
	console.log fbaFeesThirtyDaysAgoTimestamp

	Q.all([mws.Reports.RequestReport({ReportType: "_GET_FBA_ESTIMATED_FBA_FEES_TXT_DATA_"}), mws.Reports.RequestReport({
		ReportType: "_GET_FBA_FULFILLMENT_INVENTORY_HEALTH_DATA_"
		StartDate: fbaFeesThirtyDaysAgoTimestamp})])
	.spread (fbaFeesData, inventoryHealthData) ->
		console.log "Report Requests Complete"
	.catch (err) ->
		console.log err