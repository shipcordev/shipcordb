requestreports = require('./requestreports')
getlatestreports = require('./getlatestreports') 

module.exports.requestReports = ->
	requestreports.requestReports()

module.exports.getLatestReports = ->
	getlatestreports.getReports()