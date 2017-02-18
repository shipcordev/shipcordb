Q = require('q')
_ = require('underscore')
express = require('express')
bodyParser = require('body-parser')
compression = require('compression')
session = require('express-session')
flash = require('connect-flash')
bcrypt = require('bcrypt')
passport = require('passport')
xlsx = require('node-xlsx').default
csrf = require('csurf')
LocalStrategy = require('passport-local').Strategy

config = require('./config')
db = require('./db')
apiworker = require('./apiworker')

app = express()

app.use(bodyParser.json())
app.use(bodyParser.urlencoded({ extended: false }))

if !config.IS_WORKER
	app.use(session({
		secret: config.COOKIE_SECRET
		resave: false
		saveUninitialized: false
	}))

	app.use(flash())
	app.use(passport.initialize())
	app.use(passport.session())
	app.use(compression())
	app.use(express.static('public'))
	app.use(csrf())
	app.use((req, res, next) ->
		csrfToken = req.csrfToken()
		res.cookie('XSRF-TOKEN', csrfToken)
		res.locals.csrfToken = csrfToken
		next()
	)
	app.use((req, res, next) ->
		res.locals.messages = req.flash('error');
		next();
	)

	app.set('views', __dirname + '/views')
	app.set('view engine', 'pug')

	passport.use(new LocalStrategy({
		usernameField: 'email'}, (email, password, done) ->
			db.User.findOne({
				where: { email: email }
			}).then (user) ->
				if !user
					return done(null, false, { message: 'Incorrect username or password' })
				userValues = user.dataValues
				if userValues.hash == null
					return done(null, userValues)
				bcrypt.compare(password, userValues.hash)
					.then (result) ->
						if result
							return done(null, userValues)
						return done(null, false, { message: 'Incorrect username or password'})
	))

	passport.serializeUser((user, done) ->
		done(null, user.id)
	)

	passport.deserializeUser((id, done) ->
		db.User.findById(id)
		.then (user) ->
			done(null, user.dataValues)
	)

db.createTablesIfNotExist()

outputReorderColumns = ["snapshot-date"
 ,"ASIN"
 ,"product-name"
 ,"Sales Rank"
 ,"product-group"
 ,"total-units-shipped-last-24-hrs"
 ,"total-units-shipped-last-7-days"
 ,"total-units-shipped-last-30-days"
 ,"total-units-shipped-last-90-days"
 ,"total-units-shipped-last-180-days"
 ,"total-units-shipped-last-365-days"
 ,"num-afn-new-sellers"
 ,"Remove from Restock report"
 ,"In Stock or OOS - Crenstone"
 ,"Inbound Crenstone"
 ,"Days OOS - Crenstone"
 ,"Last 30 days of sales when in stock - Crenstone"
 ,"In Stock or OOS - Oredroc"
 ,"Inbound Oredroc"
 ,"Days OOS - Oredroc"
 ,"Last 30 days of sales when in stock - Oredroc"
 ,"Total Stock - Both Accounts"
 ,"Total Sales both accounts - 30 days"
 ,"Seasonal Tags"
 ,"OEM MFG Part Number"
 ,"OEM MFG"
 ,"Vendor Part number"
 ,"Item Description"
 ,"Vendor Name"
 ,"Vendor Price"
 ,"Quantity needed per ASIN"
 ,"Total price of ASIN"
 ,"Quantity needed for restock order 3x on 30 day sales"
 ,"Quantity needed for restock order 6x on 30 day sales"
 ,"Closeout / Retail Tag"
 ,"Can Order Again?"
 ,"Selling in accounts"
 ,"Has stock in accounts"
 ,"Crenstone SKU"
 ,"Crenstone FNSKU"
 ,"Our Current Price"
 ,"Lowest Prime Price"
 ,"Below Current Price?"
 ,"brand"
 ,"your-price"
 ,"sales-price"
 ,"estimated-fee-total"
 ,"estimated-future-fee (Current Selling on Amazon + Future Fulfillment fees)"
 ,"estimated-shipping-cost"
 ,"total-inventory-cost"
 ,"overhead-rate"
 ,"profit"
 ,"future-profit"
 ,"crenstone-units-shipped-last-24-hrs"
 ,"crenstone-units-shipped-last-7-days"
 ,"crenstone-units-shipped-last-30-days"
 ,"crenstone-units-shipped-last-90-days"
 ,"crenstone-units-shipped-last-180-days"
 ,"crenstone-units-shipped-last-365-days"
 ,"Oredroc SKU"
 ,"Oredroc FNSKU"
 ,"Our Current Price"
 ,"Lowest Prime Price"
 ,"Below Current Price?"
 ,"brand"
 ,"your-price"
 ,"sales-price"
 ,"estimated-fee-total"
 ,"estimated-future-fee (Current Selling on Amazon + Future Fulfillment fees)"
 ,"estimated-shipping-cost"
 ,"total-inventory-cost"
 ,"overhead-rate"
 ,"profit"
 ,"future-profit"
 ,"oredroc-units-shipped-last-24-hrs"
 ,"oredroc-units-shipped-last-7-days"
 ,"oredroc-units-shipped-last-30-days"
 ,"oredroc-units-shipped-last-90-days"
 ,"oredroc-units-shipped-last-180-days"
 ,"oredroc-units-shipped-last-365-days"
]

buildReorderData = (reorderItems) ->
	reorderData = []
	reorderData.push(outputReorderColumns)
	for key in Object.keys(reorderItems)
		if reorderItems[key]['crenstone'] == undefined
			reorderItems[key]['crenstone'] = {}
		if reorderItems[key]['oredroc'] == undefined
			reorderItems[key]['oredroc'] = {}
		snapshotDate = null
		snapshotDateFormatted = null
		if reorderItems[key]["crenstone"] != undefined and reorderItems[key]["crenstone"]["snapshot-date"] != undefined
			snapshotDate = new Date(reorderItems[key]["crenstone"]['snapshot-date'])
			snapshotDateFormatted = snapshotDate.getFullYear() + '-' + (snapshotDate.getMonth()+1) + '-' + snapshotDate.getDate()
		else
			snapshotDate = new Date(reorderItems[key]["oredroc"]['snapshot-date'])
			snapshotDateFormatted = snapshotDate.getFullYear() + '-' + (snapshotDate.getMonth()+1) + '-' + snapshotDate.getDate()
		asin = reorderItems[key]['crenstone']['asin'] || reorderItems[key]['oredroc']['asin'] || ''
		productName = reorderItems[key]['crenstone']['product-name'] || reorderItems[key]['oredroc']['product-name'] || ''
		salesRank = reorderItems[key]['crenstone']['sales-rank'] || reorderItems[key]['oredroc']['sales-rank'] || '' 
		productGroup = reorderItems[key]['crenstone']['product-group'] || reorderItems[key]['oredroc']['product-group'] || ''
		totalUnitsShippedLast24Hours = (reorderItems[key]['crenstone']['units-shipped-last-24-hrs
'] || 0) + (reorderItems[key]['oredroc']['units-shipped-last-24-hrs
'] || 0)
		totalUnitsShippedLast7Days = (reorderItems[key]['crenstone']['units-shipped-last-7-days
'] || 0) + (reorderItems[key]['oredroc']['units-shipped-last-7-days
'] || 0)
		totalUnitsShippedLast30Days = (reorderItems[key]['crenstone']['units-shipped-last-30-days
'] || 0) + (reorderItems[key]['oredroc']['units-shipped-last-30-days
'] || 0)
		totalUnitsShippedLast90Days = (reorderItems[key]['crenstone']['units-shipped-last-90-days
'] || 0) + (reorderItems[key]['oredroc']['units-shipped-last-90-days
'] || 0)
		totalUnitsShippedLast180Days = (reorderItems[key]['crenstone']['units-shipped-last-180-days
'] || 0) + (reorderItems[key]['oredroc']['units-shipped-last-180-days
'] || 0)
		totalUnitsShippedLast365Days = (reorderItems[key]['crenstone']['units-shipped-last-365-days
'] || 0) + (reorderItems[key]['oredroc']['units-shipped-last-365-days
'] || 0)
		numAfnNewSellers = reorderItems[key]['crenstone']['num-afn-new-sellers'] || reorderItems[key]['oredroc']['num-afn-new-sellers'] || ''
		removeFromRestockReport = reorderItems[key]['crenstone']['remove-from-restock-report'] || reorderItems[key]['oredroc']['remove-from-restock-report'] || ''
		inStockOrOOSCrenstone = reorderItems[key]['crenstone']['sellable-quantity'] || ''
		inboundCrenstone = reorderItems[key]['crenstone']['in-bound-quantity'] || ''
		daysOOSCrenstone = reorderItems[key]['crenstone']['days-OOS'] || ''
		last30DaysOfSalesWhenInStockCrenstone = reorderItems[key]['crenstone']['units-shipped-last-30-days'] || ''
		inStockOrOOSOredroc = reorderItems[key]['oredroc']['sellable-quantity'] || ''
		inboundOredroc = reorderItems[key]['oredroc']['in-bound-quantity'] || ''
		daysOOSOredroc = reorderItems[key]['oredroc']['days-OOS'] || ''
		last30DaysOfSalesWhenInStockOredroc = reorderItems[key]['oredroc']['units-shipped-last-30-days'] || ''
		totalStockBothAccounts = (reorderItems[key]['crenstone']['sellable-quantity'] || 0) + (reorderItems[key]['crenstone']['in-bound-quantity'] || 0) + (reorderItems[key]['oredroc']['sellable-quantity'] || 0) + (reorderItems[key]['oredroc']['in-bound-quantity'] || 0)
		totalSalesBothAccounts30Days = (reorderItems[key]['crenstone']['units-shipped-last-30-days'] || 0) + (reorderItems[key]['oredroc']['units-shipped-last-30-days'] || 0)
		seasonalTags = reorderItems[key]['crenstone']['seasonal-tags'] || reorderItems[key]['oredroc']['seasonal-tags'] || ''
		oemMfgPartNumber = reorderItems[key]['crenstone']['oem-mfg-part-number'] || reorderItems[key]['oredroc']['oem-mfg-part-number'] || ''
		oemMfg = reorderItems[key]['crenstone']['oem-mfg'] || reorderItems[key]['oredroc']['oem-mfg'] || ''
		vendorPartNumber = reorderItems[key]['crenstone']['vendor-part-number'] || reorderItems[key]['oredroc']['vendor-part-number'] || ''
		itemDescription = reorderItems[key]['crenstone']['item-description'] || reorderItems[key]['oredroc']['item-description'] || ''
		vendorName = reorderItems[key]['crenstone']['vendor-name'] || reorderItems[key]['oredroc']['vendor-name'] || ''
		vendorPrice = reorderItems[key]['crenstone']['vendor-price'] || reorderItems[key]['oredroc']['vendor-price'] || ''
		quantityNeededPerASIN = reorderItems[key]['crenstone']['quantity-needed-per-asin'] || reorderItems[key]['oredroc']['quantity-needed-per-asin'] || ''
		totalPricePerASIN = ''
		quantityNeededForRestockOrder3xOn30DaySales = 3 * ((reorderItems[key]['crenstone']['quantity-needed-per-asin'] || reorderItems[key]['oredroc']['quantity-needed-per-asin'] || 0) - totalStockBothAccounts)
		quantityNeededForRestockOrder6xOn30DaySales = 6 * ((reorderItems[key]['crenstone']['quantity-needed-per-asin'] || reorderItems[key]['oredroc']['quantity-needed-per-asin'] || 0) - totalStockBothAccounts)
		closeoutRetailTag = reorderItems[key]['crenstone']['closeout-retail-tag'] || reorderItems[key]['oredroc']['closeout-retail-tag'] || ''
		canOrderAgain = reorderItems[key]['crenstone']['can-order-again'] || reorderItems[key]['oredroc']['can-order-again'] || ''
		sellingInAccounts = ''
		if (reorderItems[key]['crenstone']['sellable-quantity'] || 0) > 0
			sellingInAccounts += 'Crenstone '
		if (reorderItems[key]['oredroc']['sellable-quantity'] || 0) > 0
			sellingInAccounts += 'Oredroc'
		hasStockInAccounts = ''
		if (reorderItems[key]['crenstone']['sellable-quantity'] || 0) > 0
			hasStockInAccounts += 'Crenstone '
		if (reorderItems[key]['oredroc']['sellable-quantity'] || 0) > 0
			hasStockInAccounts += 'Oredroc'
		crenstoneSKU = reorderItems[key]['crenstone']['sku'] || ''
		crenstoneFNSKU = reorderItems[key]['crenstone']['fnsku'] || ''
		ourCurrentPriceInventoryCrenstone = reorderItems[key]['crenstone']['your-price'] || 0
		lowestPrimePriceCrenstone = reorderItems[key]['crenstone']['lowest-afn-new-price'] || 0
		belowCurrentPriceCrenstone = lowestPrimePriceCrenstone - ourCurrentPriceInventoryCrenstone
		brand = reorderItems[key]['crenstone']['brand'] || reorderItems[key]['oredroc']['brand'] || ''
		yourPrice = reorderItems[key]['crenstone']['your-price'] || reorderItems[key]['oredroc']['your-price'] || ''
		salesPrice = reorderItems[key]['crenstone']['sales-price'] || reorderItems[key]['oredroc']['sales-price'] || ''
		estimatedFeeTotal = reorderItems[key]['crenstone']['estimated-fee-total'] || reorderItems[key]['oredroc']['estimated-fee-total'] || ''
		estimatedFutureFee = lowestPrimePriceCrenstone + (reorderItems[key]['crenstone']['expected-future-fulfillment-fee-per-unit'] || reorderItems[key]['oredroc']['expected-future-fulfillment-fee-per-unit'] || 0)
		estimatedShippingCost = reorderItems[key]['crenstone']['estimated-shipping-cost'] || reorderItems[key]['oredroc']['estimated-shipping-cost'] || ''
		totalInventoryCost = ''
		overheadRate = ''
		profit = ''
		futureProfit = ''
		crenstoneUnitsShippedLast24Hours = reorderItems[key]['crenstone']['units-shipped-last-24-hrs'] || 0
		crenstoneUnitsShippedLast7Days = reorderItems[key]['crenstone']['units-shipped-last-7-days'] || 0
		crenstoneUnitsShippedLast30Days = reorderItems[key]['crenstone']['units-shipped-last-30-days'] || 0
		crenstoneUnitsShippedLast90Days = reorderItems[key]['crenstone']['units-shipped-last-90-days'] || 0
		crenstoneUnitsShippedLast180Days = reorderItems[key]['crenstone']['units-shipped-last-180-days'] || 0
		crenstoneUnitsShippedLast365Days = reorderItems[key]['crenstone']['units-shipped-last-365-days'] || 0
		oredrocSKU = reorderItems[key]['oredroc']['sku'] || ''
		oredrocFNSKU = reorderItems[key]['oredroc']['fnsku'] || ''
		ourCurrentPriceInventoryOredroc = reorderItems[key]['oredroc']['your-price'] || 0
		lowestPrimePriceOredroc = reorderItems[key]['oredroc']['lowest-afn-new-price'] || 0
		belowCurrentPriceOredroc = lowestPrimePriceOredroc - ourCurrentPriceInventoryOredroc
		oredrocUnitsShippedLast24Hours = reorderItems[key]['oredroc']['units-shipped-last-24-hrs'] || 0
		oredrocUnitsShippedLast7Days = reorderItems[key]['oredroc']['units-shipped-last-7-days'] || 0
		oredrocUnitsShippedLast30Days = reorderItems[key]['oredroc']['units-shipped-last-30-days'] || 0
		oredrocUnitsShippedLast90Days = reorderItems[key]['oredroc']['units-shipped-last-90-days'] || 0
		oredrocUnitsShippedLast180Days = reorderItems[key]['oredroc']['units-shipped-last-180-days'] || 0
		oredrocUnitsShippedLast365Days = reorderItems[key]['oredroc']['units-shipped-last-365-days'] || 0
			
		###quantityNeededForRestock3x = 3 * (reorderItems[key]['sellable-quantity'] + reorderItems[key]['in-bound-quantity'])
		quantityNeededForRestock6x = 6 * (reorderItems[key]['sellable-quantity'] + reorderItems[key]['in-bound-quantity'])
		reorderItems[key]['quantity-needed-for-restock-3x'] = quantityNeededForRestock3x
		reorderItems[key]['quantity-needed-for-restock-6x'] = quantityNeededForRestock6x		
		reorderItems[key]['below-current-price'] = reorderItems[key]['lowest-afn-new-price'] - reorderItems[key]['your-price']
		reorderItems[key]['instock-' + seller] = reorderItems[key]['sellable-quantity']
		if seller == 'crenstone'
			otherSeller = 'oredroc'
		else
			otherSeller = 'crenstone'
		reorderItems[key]['instock-' + otherSeller] = 0

		reorderItems[key][seller + '-units-shipped-last-24-hrs'] = reorderItems[key]['units-shipped-last-24-hrs']
		reorderItems[key][seller + '-units-shipped-last-7-days'] = reorderItems[key]['units-shipped-last-7-days']
		reorderItems[key][seller + '-units-shipped-last-30-days'] = reorderItems[key]['units-shipped-last-30-days']
		reorderItems[key][seller + '-units-shipped-last-90-days'] = reorderItems[key]['units-shipped-last-90-days']
		reorderItems[key][seller + '-units-shipped-last-180-days'] = reorderItems[key]['units-shipped-last-180-days']
		reorderItems[key][seller + '-units-shipped-last-365-days'] = reorderItems[key]['units-shipped-last-365-days']
		reorderItems[key]['In Stock or OOS - ' + seller] = reorderItems[key]['total-quantity']
		reorderItems[key]['InBound ' + seller] = reorderItems[key]['in-bound-quantity']
		reorderItems[key]['Last 30 days of sales when in stock - ' + seller] = reorderItems[key]['units-shipped-last-30-days']
		reorderItems[key]['Total Stock - Both Accounts'] = reorderItems[key]['total-quantity']
		reorderItems[key]['Total Sales both accounts - 30 days'] = reorderItems[key]['units-shipped-last-30-days']
		reorderItems[key]['Selling in accounts'] = seller
		reorderItems[key]['Has stock in accounts'] = if reorderItems[key]['sellable-quantity'] != undefined and reorderItems[key]['sellable-quantity'] > 0 then seller else ''
		reorderItems[key][seller + ' SKU'] = reorderItems[key]['sku']
		reorderItems[key][seller + ' FNSKU'] = reorderItems[key]['fnsku']###		

		#finish making reorder row, add to data, then return all the rows and create the output file. Easy.

		reorderRow = [
			snapshotDateFormatted || ''
			 ,asin
			 ,productName
			 ,salesRank
			 ,productGroup
			 ,totalUnitsShippedLast24Hours
			 ,totalUnitsShippedLast7Days
			 ,totalUnitsShippedLast30Days
			 ,totalUnitsShippedLast90Days
			 ,totalUnitsShippedLast180Days
			 ,totalUnitsShippedLast365Days
			 ,numAfnNewSellers
			 ,removeFromRestockReport
			 ,inStockOrOOSCrenstone
			 ,inboundCrenstone
			 ,daysOOSCrenstone
			 ,last30DaysOfSalesWhenInStockCrenstone
			 ,inStockOrOOSOredroc
			 ,inboundOredroc
			 ,daysOOSOredroc
			 ,last30DaysOfSalesWhenInStockOredroc
			 ,totalStockBothAccounts
			 ,totalSalesBothAccounts30Days
			 ,seasonalTags
			 ,oemMfgPartNumber
			 ,oemMfg
			 ,vendorPartNumber
			 ,itemDescription
			 ,vendorName
			 ,vendorPrice
			 ,quantityNeededPerASIN
			 ,totalPricePerASIN
			 ,quantityNeededForRestockOrder3xOn30DaySales
			 ,quantityNeededForRestockOrder6xOn30DaySales
			 ,closeoutRetailTag
			 ,canOrderAgain
			 ,sellingInAccounts
			 ,hasStockInAccounts
			 ,crenstoneSKU
			 ,crenstoneFNSKU
			 ,ourCurrentPriceInventoryCrenstone
			 ,lowestPrimePriceCrenstone
			 ,belowCurrentPriceCrenstone
			 ,brand
			 ,yourPrice
			 ,salesPrice
			 ,estimatedFeeTotal
			 ,estimatedFutureFee
			 ,estimatedShippingCost
			 ,totalInventoryCost
			 ,overheadRate
			 ,profit
			 ,futureProfit
			 ,crenstoneUnitsShippedLast24Hours
			 ,crenstoneUnitsShippedLast7Days
			 ,crenstoneUnitsShippedLast30Days
			 ,crenstoneUnitsShippedLast90Days
			 ,crenstoneUnitsShippedLast180Days
			 ,crenstoneUnitsShippedLast365Days
			 ,oredrocSKU
			 ,oredrocFNSKU
			 ,ourCurrentPriceInventoryOredroc
			 ,lowestPrimePriceOredroc
			 ,belowCurrentPriceOredroc
			 ,brand
			 ,yourPrice
			 ,salesPrice
			 ,estimatedFeeTotal
			 ,estimatedFutureFee
			 ,estimatedShippingCost
			 ,totalInventoryCost
			 ,overheadRate
			 ,profit
			 ,futureProfit
			 ,oredrocUnitsShippedLast24Hours
			 ,oredrocUnitsShippedLast7Days
			 ,oredrocUnitsShippedLast30Days
			 ,oredrocUnitsShippedLast90Days
			 ,oredrocUnitsShippedLast180Days
			 ,oredrocUnitsShippedLast365Days
		]
		reorderData.push(reorderRow)
	reorderData

sortInventoryDataByAsin = (data) ->
	nameColumn = data.shift()
	data.sort((a, b) ->
		if a[3] == b[3]
			0
		else
			a[3] < b[3] ? -1 : 1 #ASIN is in the 4th column
	)
	data.unshift(nameColumn)
	data

removeFeeDataDuplicates = (data) ->
	_.uniq(data, false, (row) -> row[2])

app.get('/ping', (req, res) ->
	res.sendStatus(200)
)

if config.IS_WORKER
	app.post('/worker', (req, res) ->
		res.sendStatus(200)
	)

	app.post('/reports/request', (req, res) ->
		apiworker.requestReports()
			.then (result) ->
				res.sendStatus(200)
	)

	app.post('/reports/getlatest', (req, res) ->
		apiworker.getLatestReports()
			.then (result) ->
				res.sendStatus(200)
	)
else
	app.get('/', (req, res) ->
		if !req.user
			res.redirect('/login')
		else
			res.render('index', { user: req.user })
	)

	app.get('/reports/download', (req, res) ->
		if !req.user
			res.redirect('/')
		else
			date = new Date()
			originalFormattedDate = date.getFullYear() + '-' + (date.getMonth()+1) + '-' + date.getDate()
			
			#get all report dates for both seller accounts, then grab the latest time snapshot for each to grab the reports
			oredrocInventoryDateQuery = 'SELECT * FROM \"report-snapshot-dates\" WHERE seller=\'oredroc\' AND type=\'inventory-health\' ORDER BY \"snapshot-date\" DESC'
			crenstoneInventoryDateQuery = 'SELECT * FROM \"report-snapshot-dates\" WHERE seller=\'crenstone\' AND type=\'inventory-health\' ORDER BY \"snapshot-date\" DESC'
			oredrocFeesDateQuery = 'SELECT * FROM \"report-snapshot-dates\" WHERE seller=\'oredroc\' AND type=\'fba-fees\' ORDER BY \"snapshot-date\" DESC'
			crenstoneFeesDateQuery = 'SELECT * FROM \"report-snapshot-dates\" WHERE seller=\'crenstone\' AND type=\'fba-fees\' ORDER BY \"snapshot-date\" DESC'

			Q.all([db.sequelize.query(oredrocInventoryDateQuery), db.sequelize.query(crenstoneInventoryDateQuery), db.sequelize.query(oredrocFeesDateQuery), db.sequelize.query(crenstoneFeesDateQuery)])
				.spread (oredrocInventoryDateResult, crenstoneInventoryDateResult, oredrocFeesDateResult, crenstoneFeesDateResult) ->
					if oredrocInventoryDateResult[1].rowCount == 0 and crenstoneInventoryDateResult[1].rowCount == 0 and oredrocFeesDateResult[1].rowCount == 0 and crenstoneFeesDateResult[1].rowCount == 0
						res.redirect('/')
					else
						oredrocInventoryByDateQuery = 'SELECT * FROM "inventory-health" WHERE seller=\'oredroc\''
						if oredrocInventoryDateResult[1].rowCount > 0
							oredrocInventoryDate = new Date(oredrocInventoryDateResult[0][0]['snapshot-date'])
							oredrocInventoryDateFormatted = oredrocInventoryDate.getFullYear() + '-' + (oredrocInventoryDate.getMonth()+1) + '-' + oredrocInventoryDate.getDate()
							oredrocInventoryByDateQuery += ' AND \"snapshot-date\"=\'' + oredrocInventoryDateFormatted + '\''
						crenstoneInventoryByDateQuery = 'SELECT * FROM "inventory-health" WHERE seller=\'crenstone\''
						if crenstoneInventoryDateResult[1].rowCount > 0
							crenstoneInventoryDate = new Date(crenstoneInventoryDateResult[0][0]['snapshot-date'])
							crenstoneInventoryDateFormatted = crenstoneInventoryDate.getFullYear() + '-' + (crenstoneInventoryDate.getMonth()+1) + '-' + crenstoneInventoryDate.getDate()
							crenstoneInventoryByDateQuery += ' AND \"snapshot-date\"=\'' + crenstoneInventoryDateFormatted + '\''
						oredrocFeesByDateQuery = 'SELECT * FROM "fba-fees" WHERE seller=\'oredroc\''
						if oredrocFeesDateResult[1].rowCount > 0
							oredrocFeesDate = new Date(oredrocFeesDateResult[0][0]['snapshot-date'])	
							oredrocFeesDateFormatted = oredrocFeesDate.getFullYear() + '-' + (oredrocFeesDate.getMonth()+1) + '-' + oredrocFeesDate.getDate()
							oredrocFeesByDateQuery += ' AND \"snapshot-date\"=\'' + oredrocFeesDateFormatted + '\''
						crenstoneFeesByDateQuery = 'SELECT * FROM "fba-fees" WHERE seller=\'crenstone\''
						if crenstoneFeesDateResult[1].rowCount > 0
							crenstoneFeesDate = new Date(crenstoneFeesDateResult[0][0]['snapshot-date'])
							crenstoneFeesDateFormatted = crenstoneFeesDate.getFullYear() + '-' + (crenstoneFeesDate.getMonth()+1) + '-' + crenstoneFeesDate.getDate()
							crenstoneFeesByDateQuery += ' AND \"snapshot-date\"=\'' + crenstoneFeesDateFormatted + '\''

						Q.all([db.sequelize.query(oredrocInventoryByDateQuery, { type: db.sequelize.QueryTypes.SELECT}), 
								db.sequelize.query(oredrocFeesByDateQuery, { type: db.sequelize.QueryTypes.SELECT})
								db.sequelize.query(crenstoneInventoryByDateQuery, { type: db.sequelize.QueryTypes.SELECT})
								db.sequelize.query(crenstoneFeesByDateQuery, { type: db.sequelize.QueryTypes.SELECT})						
							])
							.spread (oredrocInventoryResult, oredrocFeesResult, crenstoneInventoryResult, crenstoneFeesResult) ->
								if oredrocInventoryResult.length == 0 and oredrocFeesResult.length == 0 and crenstoneInventoryResult.length == 0 and crenstoneFeesResult.length == 0
									res.redirect('/')
								else
									worksheets = []
									reorderItems = []
									inventoryData = new Array()
									feeData = new Array()
									inventoryColumnNames = []
									feeColumnNames = []
									if oredrocInventoryResult.length > 0
										inventoryColumnNames = _.filter(Object.keys(oredrocInventoryResult[0]), (key) -> key != 'id' and key != 'seller')
										inventoryColumnNames.push("Account")
										inventoryColumnNames.push("Have to send?")
										inventoryColumnNames.push("10x total sales x 30 d")
									else if crenstoneInventoryResult.length > 0
										inventoryColumnNames = _.filter(Object.keys(oredrocInventoryResult[0]), (key) -> key != 'id' and key != 'seller')
										inventoryColumnNames.push("Account")
										inventoryColumnNames.push("Have to send?")
										inventoryColumnNames.push("10x total sales x 30 d")
									inventoryData.push(inventoryColumnNames)

									if oredrocFeesResult.length > 0
										feeColumnNames = _.filter(Object.keys(oredrocFeesResult[0]), (key) -> key != 'id' and key != 'seller' and key != 'snapshot-date')
									else if crenstoneFeesResult.length > 0
										feeColumnNames = _.filter(Object.keys(crenstoneFeesResult[0]), (key) -> key != 'id' and key != 'seller' and key != 'snapshot-date')
									feeData.push(feeColumnNames)

									if oredrocInventoryResult.length > 0
										for row in oredrocInventoryResult
											uniqueKey = row['asin']
											if !_.contains(Object.keys(reorderItems), uniqueKey)
												reorderItems[uniqueKey] = {}
												reorderItems[uniqueKey]["oredroc"] = {}
											rowData = new Array()
											for key in Object.keys(row)
												if key == 'snapshot-date'
													date = new Date(row[key])
													formattedDate = date.getFullYear() + '-' + (date.getMonth()+1) + '-' + date.getDate()
													rowData.push(formattedDate)
												else if key != 'id' and key != 'seller'
													rowData.push(row[key])
												reorderItems[uniqueKey]["oredroc"][key] = row[key]
											rowData.push('Oredroc')
											inventoryData.push(rowData)
										#worksheets.push({name: "Oredroc Inventory Health", data: data})
									if oredrocFeesResult.length > 0
										for row in oredrocFeesResult
											uniqueKey = row['asin']
											if !_.contains(Object.keys(reorderItems), uniqueKey)
												reorderItems[uniqueKey] = {}
												reorderItems[uniqueKey]["oredroc"] = {}
											if !_.contains(Object.keys(reorderItems[uniqueKey], 'oredroc'))
												reorderItems[uniqueKey]["oredroc"] = {}
											rowData = new Array()
											for key in Object.keys(row)
												if key != 'id' and key != 'seller' and key != 'snapshot-date'
													rowData.push(row[key])
												reorderItems[uniqueKey]["oredroc"][key] = row[key]
											feeData.push(rowData)
										#worksheets.push({name: "Oredroc FBA Fees", data: data})
									if crenstoneInventoryResult.length > 0
										for row in crenstoneInventoryResult
											uniqueKey = row['asin']
											if !_.contains(Object.keys(reorderItems), uniqueKey)
												reorderItems[uniqueKey] = {}
												reorderItems[uniqueKey]["crenstone"] = {}
											if !_.contains(Object.keys(reorderItems[uniqueKey], 'crenstone'))
												reorderItems[uniqueKey]["crenstone"] = {}
											rowData = new Array()
											for key in Object.keys(row)
												if key == 'snapshot-date'
													date = new Date(row[key])
													formattedDate = date.getFullYear() + '-' + (date.getMonth()+1) + '-' + date.getDate()
													rowData.push(formattedDate)
												else if key != 'id' and key != 'seller'
													rowData.push(row[key])
												reorderItems[uniqueKey]["crenstone"][key] = row[key]
											rowData.push('Crenstone')
											inventoryData.push(rowData)
										#worksheets.push({name: "Crenstone Inventory Health", data: data})
									if crenstoneFeesResult.length > 0
										for row in crenstoneFeesResult
											uniqueKey = row['asin']
											if !_.contains(Object.keys(reorderItems), uniqueKey)
												reorderItems[uniqueKey] = {}
												reorderItems[uniqueKey]["crenstone"] = {}
											if !_.contains(Object.keys(reorderItems[uniqueKey], 'crenstone'))
												reorderItems[uniqueKey]["crenstone"] = {}
											rowData = new Array()
											for key in Object.keys(row)
												if key != 'id' and key != 'seller' and key != 'snapshot-date'
													rowData.push(row[key])
												reorderItems[uniqueKey]["crenstone"][key] = row[key]
											feeData.push(rowData)

									inventoryData = sortInventoryDataByAsin(inventoryData)
									feeData = removeFeeDataDuplicates(feeData)
									reorderData = buildReorderData(reorderItems)
									
									worksheets.push({name: "Reorder File", data: reorderData})
									worksheets.push({name: "From Amazon INV Health", data: inventoryData})
									worksheets.push({name: "From Amazon Fee Preview", data: feeData})

									buffer = xlsx.build(worksheets)

									fileName = originalFormattedDate + "-reorder.xlsx"
									res.type('xlsx')
									res.setHeader('Content-disposition', 'attachment; filename=' + fileName)
									res.send(buffer)
	)

	app.get('/signup', (req, res) ->
		if req.user
			if req.user.hash == null
				res.render('signup')
			else
				res.redirect('/')
		else
			res.redirect('/login')
	)

	app.get('/login', (req, res) ->
		if req.user
			if req.user.hash == null
				res.redirect('/signup')
			else
				res.redirect('/')
		else
			res.render('login')
	)

	app.get('/logout', (req, res) ->
		if req.user
			req.session.destroy()
		res.redirect('/')
	)

	app.post('/signup', (req,res) ->
		if !req.user
			res.redirect('/login')
		else
			password = req.body.password
			if password == req.body.confirmPassword
				db.User.findOne({
					where: { email: req.user.email }
				}).then (user) ->
					if !user?
						throw notFound: true
					else
						bcrypt.hash(password, parseInt(config.SALTROUNDS))
							.then (hash) ->
								user.updateAttributes({
									hash: hash
								})
							.then (user) ->
								req.session.destroy()
								res.redirect('/login')
			else
				req.flash('error', 'The passwords do not match')
				res.redirect('/signup')
	)

	app.post('/login', passport.authenticate('local', { failureRedirect: '/login', failureFlash: true }), (req, res) ->
		if req.user
			if req.user.hash == null
				res.redirect('/signup')
			else
				res.redirect('/')
		else
			res.redirect('/login')
	)

app.listen(config.PORT)