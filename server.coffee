Q = require('q')
_ = require('underscore')
express = require('express')
bodyParser = require('body-parser')
compression = require('compression')
session = require('express-session')
flash = require('connect-flash')
Busboy = require('busboy')
toArray = require('stream-to-array')
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
 ,"Last 30 days of sales when in stock - Crenstone" #16
 ,"In Stock or OOS - Oredroc"
 ,"Inbound Oredroc"
 ,"Days OOS - Oredroc"
 ,"Last 30 days of sales when in stock - Oredroc" #20
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
 ,"sales-price" #45
 ,"estimated-fee-total"
 ,"estimated-future-fee (Current Selling on Amazon + Future Fulfillment fees)"
 ,"estimated-shipping-cost"
 ,"total-inventory-cost" #49
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
 ,"total-inventory-cost" #70
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
	asinKeys = new Set()
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
		totalUnitsShippedLast24Hours = Number(reorderItems[key]['crenstone']['units-shipped-last-24-hrs
'] || 0) + Number(reorderItems[key]['oredroc']['units-shipped-last-24-hrs
'] || 0)
		totalUnitsShippedLast7Days = Number(reorderItems[key]['crenstone']['units-shipped-last-7-days
'] || 0) + Number(reorderItems[key]['oredroc']['units-shipped-last-7-days
'] || 0)
		totalUnitsShippedLast30Days = Number(reorderItems[key]['crenstone']['units-shipped-last-30-days
'] || 0) + Number(reorderItems[key]['oredroc']['units-shipped-last-30-days
'] || 0)
		totalUnitsShippedLast90Days = Number(reorderItems[key]['crenstone']['units-shipped-last-90-days
'] || 0) + Number(reorderItems[key]['oredroc']['units-shipped-last-90-days
'] || 0)
		totalUnitsShippedLast180Days = Number(reorderItems[key]['crenstone']['units-shipped-last-180-days
'] || 0) + Number(reorderItems[key]['oredroc']['units-shipped-last-180-days
'] || 0)
		totalUnitsShippedLast365Days = Number(reorderItems[key]['crenstone']['units-shipped-last-365-days
'] || 0) + Number(reorderItems[key]['oredroc']['units-shipped-last-365-days
'] || 0)
		numAfnNewSellers = reorderItems[key]['crenstone']['num-afn-new-sellers'] || reorderItems[key]['oredroc']['num-afn-new-sellers'] || ''
		removeFromRestockReport = reorderItems[key]['crenstone']['remove-from-restock-report'] || reorderItems[key]['oredroc']['remove-from-restock-report'] || ''
		inStockOrOOSCrenstone = reorderItems[key]['crenstone']['sellable-quantity'] || ''
		inboundCrenstone = reorderItems[key]['crenstone']['inbound-recommend-quantity'] || ''
		daysOOSCrenstone = reorderItems[key]['crenstone']['days-OOS'] || ''
		last30DaysOfSalesWhenInStockCrenstone = reorderItems[key]['crenstone']['units-shipped-last-30-days'] || 0
		inStockOrOOSOredroc = reorderItems[key]['oredroc']['sellable-quantity'] || ''
		inboundOredroc = reorderItems[key]['oredroc']['inbound-recommend-quantity'] || ''
		daysOOSOredroc = reorderItems[key]['oredroc']['days-OOS'] || ''
		last30DaysOfSalesWhenInStockOredroc = reorderItems[key]['oredroc']['units-shipped-last-30-days'] || 0
		totalStockBothAccounts = Number(reorderItems[key]['crenstone']['sellable-quantity'] || 0) + Number(reorderItems[key]['crenstone']['in-bound-quantity'] || 0) + Number(reorderItems[key]['oredroc']['sellable-quantity'] || 0) + Number(reorderItems[key]['oredroc']['in-bound-quantity'] || 0)
		totalSalesBothAccounts30Days = last30DaysOfSalesWhenInStockCrenstone + last30DaysOfSalesWhenInStockOredroc
		seasonalTags = reorderItems[key]['crenstone']['seasonal-tags'] || reorderItems[key]['oredroc']['seasonal-tags'] || ''
		oemMfgPartNumber = reorderItems[key]['crenstone']['oem-mfg-part-number'] || reorderItems[key]['oredroc']['oem-mfg-part-number'] || ''
		oemMfg = reorderItems[key]['crenstone']['oem-mfg'] || reorderItems[key]['oredroc']['oem-mfg'] || ''
		vendorPartNumber = reorderItems[key]['crenstone']['vendor-part-number'] || reorderItems[key]['oredroc']['vendor-part-number'] || ''
		itemDescription = reorderItems[key]['crenstone']['item-description'] || reorderItems[key]['oredroc']['item-description'] || ''
		vendorName = reorderItems[key]['crenstone']['vendor-name'] || reorderItems[key]['oredroc']['vendor-name'] || ''
		vendorPrice = Number(reorderItems[key]['crenstone']['vendor-price']) || Number(reorderItems[key]['oredroc']['vendor-price']) || null
		quantityNeededPerASIN = Number(reorderItems[key]['crenstone']['quantity-needed-per-asin']) || Number(reorderItems[key]['oredroc']['quantity-needed-per-asin']) || null
		totalPricePerASIN = null
		quantityNeededForRestockOrder3xOn30DaySales = 3 * totalSalesBothAccounts30Days - totalStockBothAccounts
		quantityNeededForRestockOrder6xOn30DaySales = 6 * totalSalesBothAccounts30Days - totalStockBothAccounts
		closeoutRetailTag = reorderItems[key]['crenstone']['closeout-retail-tag'] || reorderItems[key]['oredroc']['closeout-retail-tag'] || ''
		canOrderAgain = reorderItems[key]['crenstone']['can-order-again'] || reorderItems[key]['oredroc']['can-order-again'] || ''
		sellingInAccounts = ''
		if Number(reorderItems[key]['crenstone']['sellable-quantity'] || 0) > 0
			sellingInAccounts += 'Crenstone '
		if Number(reorderItems[key]['oredroc']['sellable-quantity'] || 0) > 0
			sellingInAccounts += 'Oredroc'
		hasStockInAccounts = ''
		if Number(reorderItems[key]['crenstone']['sellable-quantity'] || 0) > 0
			hasStockInAccounts += 'Crenstone '
		if Number(reorderItems[key]['oredroc']['sellable-quantity'] || 0) > 0
			hasStockInAccounts += 'Oredroc'
		crenstoneSKU = reorderItems[key]['crenstone']['sku'] || ''
		crenstoneFNSKU = reorderItems[key]['crenstone']['fnsku'] || ''
		ourCurrentPriceInventoryCrenstone = parseFloat(reorderItems[key]['crenstone']['your-price'] || 0)
		lowestPrimePriceCrenstone = parseFloat(reorderItems[key]['crenstone']['lowest-afn-new-price'] || 0)
		belowCurrentPriceCrenstone = lowestPrimePriceCrenstone - ourCurrentPriceInventoryCrenstone
		brand = reorderItems[key]['crenstone']['brand'] || reorderItems[key]['oredroc']['brand'] || ''
		yourPrice = parseFloat(reorderItems[key]['crenstone']['your-price']) || parseFloat(reorderItems[key]['oredroc']['your-price']) || null
		salesPrice = parseFloat(reorderItems[key]['crenstone']['sales-price']) || parseFloat(reorderItems[key]['oredroc']['sales-price']) || null
		estimatedFeeTotal = parseFloat(reorderItems[key]['crenstone']['estimated-fee-total']) || parseFloat(reorderItems[key]['oredroc']['estimated-fee-total']) || null
		estimatedFutureFee = lowestPrimePriceCrenstone + parseFloat(reorderItems[key]['crenstone']['estimated-future-fee'] || reorderItems[key]['oredroc']['estimated-future-fee'] || 0)
		estimatedShippingCost = parseFloat(reorderItems[key]['crenstone']['estimated-shipping-cost'] || reorderItems[key]['oredroc']['estimated-shipping-cost']) || null
		totalInventoryCost = ''
		overheadRate = ''
		profit = ''
		futureProfit = ''
		crenstoneUnitsShippedLast24Hours = Number(reorderItems[key]['crenstone']['units-shipped-last-24-hrs'] || 0)
		crenstoneUnitsShippedLast7Days = Number(reorderItems[key]['crenstone']['units-shipped-last-7-days'] || 0)
		crenstoneUnitsShippedLast30Days = Number(reorderItems[key]['crenstone']['units-shipped-last-30-days'] || 0)
		crenstoneUnitsShippedLast90Days = Number(reorderItems[key]['crenstone']['units-shipped-last-90-days'] || 0)
		crenstoneUnitsShippedLast180Days = Number(reorderItems[key]['crenstone']['units-shipped-last-180-days'] || 0)
		crenstoneUnitsShippedLast365Days = Number(reorderItems[key]['crenstone']['units-shipped-last-365-days'] || 0)
		oredrocSKU = reorderItems[key]['oredroc']['sku'] || ''
		oredrocFNSKU = reorderItems[key]['oredroc']['fnsku'] || ''
		ourCurrentPriceInventoryOredroc = parseFloat(reorderItems[key]['oredroc']['your-price'] || 0)
		lowestPrimePriceOredroc = parseFloat(reorderItems[key]['oredroc']['lowest-afn-new-price'] || 0)
		belowCurrentPriceOredroc = lowestPrimePriceOredroc - ourCurrentPriceInventoryOredroc
		oredrocUnitsShippedLast24Hours = Number(reorderItems[key]['oredroc']['units-shipped-last-24-hrs'] || 0)
		oredrocUnitsShippedLast7Days = Number(reorderItems[key]['oredroc']['units-shipped-last-7-days'] || 0)
		oredrocUnitsShippedLast30Days = Number(reorderItems[key]['oredroc']['units-shipped-last-30-days'] || 0)
		oredrocUnitsShippedLast90Days = Number(reorderItems[key]['oredroc']['units-shipped-last-90-days'] || 0)
		oredrocUnitsShippedLast180Days = Number(reorderItems[key]['oredroc']['units-shipped-last-180-days'] || 0)
		oredrocUnitsShippedLast365Days = Number(reorderItems[key]['oredroc']['units-shipped-last-365-days'] || 0)

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
		asinKeys.add(asin)

	asinKeyArray = Array.from(asinKeys)
	asinKeyQuery = '(' + _.map(asinKeyArray, (asin) -> '\'' + asin + '\'').join(',') + ')'
	selectQuery = 'SELECT * FROM \"manual-inputs\" WHERE asin IN ' + asinKeyQuery 
	deferred = Q.defer()
	db.sequelize.query(selectQuery, { type: db.sequelize.QueryTypes.SELECT})
	.then (manualInputs) ->
		newReorderRows = []
		if manualInputs.length > 0
			manualInputsByAsin = _.groupBy(manualInputs, (manualInput) -> manualInput['asin'])
			for manualInputAsin in Object.keys(manualInputsByAsin)
				for manualInput in manualInputsByAsin[manualInputAsin]
					row = _.findIndex(reorderData, (data) ->
						crenstoneSKU = manualInput['crenstone-sku'] || ''
						oredrocSKU = manualInput['oredroc-sku'] || ''
						data[1] == manualInputAsin and data[38] == crenstoneSKU and data[59] == oredrocSKU
					)
					if row == -1
						asinRow = _.findIndex(reorderData, (data) ->
							data[1] == manualInputAsin
						)
						reorderRow = [
							 reorderData[asinRow][0]
							 ,manualInput['asin']
							 ,reorderData[asinRow][2]
							 ,reorderData[asinRow][3]
							 ,reorderData[asinRow][4]
							 ,reorderData[asinRow][5]
							 ,reorderData[asinRow][6]
							 ,reorderData[asinRow][7]
							 ,reorderData[asinRow][8]
							 ,reorderData[asinRow][9]
							 ,reorderData[asinRow][10]
							 ,reorderData[asinRow][11]
							 ,manualInput['remove-from-restock-report']
							 ,reorderData[asinRow][13]
							 ,reorderData[asinRow][14]
							 ,reorderData[asinRow][15]
							 ,reorderData[asinRow][16]
							 ,reorderData[asinRow][17]
							 ,reorderData[asinRow][18]
							 ,reorderData[asinRow][19]
							 ,reorderData[asinRow][20]
							 ,reorderData[asinRow][21]
							 ,reorderData[asinRow][22]
							 ,manualInput['seasonal-tags']
							 ,manualInput['oem-mfg-part-number']
							 ,manualInput['oem-mfg']
							 ,manualInput['vendor-part-number']
							 ,manualInput['item-description']
							 ,manualInput['vendor-name']
							 ,manualInput['vendor-price']
							 ,manualInput['quantity-needed-per-asin']
							 ,reorderData[asinRow][31]
							 ,reorderData[asinRow][32]
							 ,reorderData[asinRow][33]
							 ,manualInput['closeout-retail-tag']
							 ,manualInput['can-order-again']
							 ,reorderData[asinRow][36]
							 ,reorderData[asinRow][37]
							 ,reorderData[asinRow][38]
							 ,reorderData[asinRow][39]
							 ,reorderData[asinRow][40]
							 ,reorderData[asinRow][41]
							 ,reorderData[asinRow][42]
							 ,reorderData[asinRow][43]
							 ,reorderData[asinRow][44]
							 ,reorderData[asinRow][45]
							 ,reorderData[asinRow][46]
							 ,reorderData[asinRow][47]
							 ,manualInput['estimated-shipping-cost']
							 ,reorderData[asinRow][49]
							 ,manualInput['overhead-rate']
							 ,reorderData[asinRow][51]
							 ,reorderData[asinRow][52]
							 ,reorderData[asinRow][53]
							 ,reorderData[asinRow][54]
							 ,reorderData[asinRow][55]
							 ,reorderData[asinRow][56]
							 ,reorderData[asinRow][57]
							 ,reorderData[asinRow][58]
							 ,reorderData[asinRow][59]
							 ,reorderData[asinRow][60]
							 ,reorderData[asinRow][61]
							 ,reorderData[asinRow][62]
							 ,reorderData[asinRow][63]
							 ,reorderData[asinRow][64]
							 ,reorderData[asinRow][65]
							 ,reorderData[asinRow][66]
							 ,reorderData[asinRow][67]
							 ,reorderData[asinRow][68]
							 ,manualInput['estimated-shipping-cost']
							 ,reorderData[asinRow][70]
							 ,manualInput['overhead-rate']
							 ,reorderData[asinRow][72]
							 ,reorderData[asinRow][73]
							 ,reorderData[asinRow][74]
							 ,reorderData[asinRow][75]
							 ,reorderData[asinRow][76]
							 ,reorderData[asinRow][77]
							 ,reorderData[asinRow][78]
							 ,reorderData[asinRow][79]
						]
						newReorderRows.push(reorderRow)
					else
						reorderData[row][12] = manualInput['remove-from-restock-report']
						reorderData[row][23] = manualInput['seasonal-tags']
						reorderData[row][24] = manualInput['oem-mfg-part-number']
						reorderData[row][25] = manualInput['oem-mfg']
						reorderData[row][26] = manualInput['vendor-part-number']
						reorderData[row][27] = manualInput['item-description']
						reorderData[row][28] = manualInput['vendor-name']
						reorderData[row][29] = manualInput['vendor-price']
						reorderData[row][30] = manualInput['quantity-needed-per-asin']
						reorderData[row][34] = manualInput['closeout-retail-tag']
						reorderData[row][35] = manualInput['can-order-again']
						reorderData[row][48] = manualInput['estimated-shipping-cost']
						reorderData[row][69] = manualInput['estimated-shipping-cost']
						reorderData[row][50] = manualInput['overhead-rate']
						reorderData[row][71] = manualInput['overhead-rate']
		for row in newReorderRows
			reorderData.push(row)
		calculateCalculatedOutputs(reorderData)
		reorderData = _.sortBy(reorderData, (row) -> row[1])
		reorderData.unshift(outputReorderColumns)
		deferred.resolve(reorderData)
	deferred.promise

calculateCalculatedOutputs = (data) ->
	for row in data
		totalStock = Number(row[13] || 0) + Number(row[14] || 0) + Number(row[17] || 0) + Number(row[18] || 0)
		totalSales = Number(row[16] || 0) + Number(row[20] || 0)
		totalPriceOfASIN = parseFloat(row[29] || 0) * parseFloat(row[30] || 0)
		for row2 in data
			if row[1] == row2[1] and row[26] != row2[26]
				totalPriceOfASIN += parseFloat(row2[29] || 0) * parseFloat(row[30] || 0)
		quantityNeeded3x = totalSales * Number(row[30] || 0) * 3
		quantityNeeded6x = totalSales * Number(row[30] || 0) * 6
		overheadRate = totalPriceOfASIN / 5
		estimatedShippingCost = parseFloat(row[48] || 0)
		profit = parseFloat(row[45] || 0) - totalPriceOfASIN - overheadRate - estimatedShippingCost - parseFloat(row[46] || 0)
		futureProfit = parseFloat(row[45] || 0) - totalPriceOfASIN - overheadRate - estimatedShippingCost - parseFloat(row[47] || 0)

		row[21] = totalStock
		row[22] = totalSales
		row[31] = if totalPriceOfASIN != 0 then totalPriceOfASIN.toFixed(2) else null
		row[32] = if quantityNeeded3x != 0 then quantityNeeded3x else null
		row[33] = if quantityNeeded6x != 0 then quantityNeeded6x else null
		row[49] = if totalPriceOfASIN != 0 then totalPriceOfASIN.toFixed(2) else null
		row[70] = if totalPriceOfASIN != 0 then totalPriceOfASIN.toFixed(2) else null
		row[50] = overheadRate
		row[71] = overheadRate
		row[51] = if profit > 0 then parseFloat(profit.toFixed(2)) else 0
		row[72] = if profit > 0 then parseFloat(profit.toFixed(2)) else 0
		row[52] = if futureProfit > 0 then parseFloat(futureProfit.toFixed(2)) else 0
		row[73] = if futureProfit > 0 then parseFloat(futureProfit.toFixed(2)) else 0

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

parseAndStoreManualInputs = (file, req, res) ->
	getFileWithLength(req, file)
	.then (file) ->
		workbook = xlsx.parse(file.data)
		reorderSheet = workbook[0]
		count = 0
		manualInputsToUpdate = []
		for row in reorderSheet.data
			asin = null
			crenstoneSKU = null
			oredrocSKU = null
			removeFromRestockReport = null
			seasonalTags = null
			oemMfgPartNumber = null
			oemMfg = null
			vendorPartNumber = null
			itemDescription = null
			vendorName = null
			vendorPrice = null
			quantityNeededPerASIN = null
			closeoutRetailTag = null
			canOrderAgain = null
			estimatedShippingCost = null
			overheadRate = null
			if count > 0 
				###
				Do not parse the headers. We need to check for existence because
				not all rows are the same length (empty columns past the last filled in column
				are not reflected in the row length!)
				###
				asin = row[1]
				if row[38] != null
					crenstoneSKU = row[38]
				if row[59] != null
					oredrocSKU = row[59]
				if row[12] != null and row[12] != ''
					removeFromRestockReport = row[12]
				if row[23] != null
					seasonalTags = row[23]
				if row[24] != null
					oemMfgPartNumber = row[24]
				if row[25] != null
					oemMfg = row[25]
				if row[26] != null
					vendorPartNumber = row[26]
				if row[27] != null
					itemDescription = row[27]
				if row[28] != null
					vendorName = row[28]
				if row[29] != null
					vendorPrice = row[29]
				if row[30] != null
					quantityNeededPerASIN = row[30]
				if row[34] != null
					closeoutRetailTag = row[34]
				if row[35] != null and row[35] != ''
					canOrderAgain = row[35]
				if row[48] != null
					estimatedShippingCost = row[48]
				if row[50] != null
					overheadRate = row[50]
				manualInputsToUpdate.push([
					asin
					,crenstoneSKU
					,oredrocSKU
					,removeFromRestockReport
					,seasonalTags
					,oemMfgPartNumber
					,oemMfg
					,vendorPartNumber
					,itemDescription
					,vendorName
					,vendorPrice
					,quantityNeededPerASIN
					,closeoutRetailTag
					,canOrderAgain || false
					,estimatedShippingCost
					,overheadRate
				])
			++count
		Q.all(_.each(manualInputsToUpdate, (row) -> upsertIntoDb(row)))
    .then (result) ->
    	res.redirect('/')
    .fail (err) ->
    	res.status(500).json(error: "Internal server error saving manual inputs")
    	console.log(err.stack || err)

upsertIntoDb = (inputRow) ->
	if inputRow[0] == undefined
		return
	inputRow = _.map(inputRow, (val) ->
		if typeof(val) == "boolean"
			return val
		else if val != null and val != undefined
			return '\'' + val + '\''
		else
			return 'null'
	)

	inputRowValues = inputRow.join(",")

	selectQuery = 'SELECT id FROM \"manual-inputs\" WHERE asin=' + inputRow[0] + ' and \"vendor-part-number\"'
	if inputRow[7] == 'null'
		selectQuery += ' IS NULL'
	else
		selectQuery += '=' + inputRow[7]
	if inputRow[1] == 'null'
		selectQuery += ' AND \"crenstone-sku\" IS NULL'
	else
		selectQuery += ' AND \"crenstone-sku\"=' + inputRow[1]
	if inputRow[2] == 'null'
		selectQuery += ' AND \"oredroc-sku\" IS NULL'
	else
		selectQuery += ' AND \"oredroc-sku\"=' + inputRow[2]
	insertQuery = 'INSERT INTO \"manual-inputs\"(asin, \"crenstone-sku\", \"oredroc-sku\", \"remove-from-restock-report\", \"seasonal-tags\", \"oem-mfg-part-number\", \"oem-mfg\", \"vendor-part-number\", \"item-description\", \"vendor-name\", \"vendor-price\", \"quantity-needed-per-asin\", \"closeout-retail-tag\", \"can-order-again\", \"estimated-shipping-cost\", \"overhead-rate\") VALUES (' + inputRowValues + ')'
	updateQuery = 'UPDATE \"manual-inputs\" SET (asin, \"crenstone-sku\", \"oredroc-sku\", \"remove-from-restock-report\", \"seasonal-tags\", \"oem-mfg-part-number\", \"oem-mfg\", \"vendor-part-number\", \"item-description\", \"vendor-name\", \"vendor-price\", \"quantity-needed-per-asin\", \"closeout-retail-tag\", \"can-order-again\", \"estimated-shipping-cost\", \"overhead-rate\") = (' + inputRowValues + ') WHERE id='

	db.sequelize.query(selectQuery, { type: db.sequelize.QueryTypes.SELECT})
	.then (manualInputs) ->
		if manualInputs.length == 0
			db.sequelize.query(insertQuery)
		else
			db.sequelize.query(updateQuery + manualInputs[0].id)
	.then (res) ->
		res

getFileWithLength = (req, file) ->
	if req.headers['file-length']
		file.knownLength = req.headers['file-length']
		return Q.resolve(file)
	deferred = Q.defer()
	toArray file.data, (err, arr) ->
   		if err then deferred.reject(err)
    	file.data = Buffer.concat(arr)
    	file.knownLength = file.data.length
    	deferred.resolve(file)
	deferred.promise

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
												reorderItems[uniqueKey]["crenstone"] = {}
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
									if oredrocFeesResult.length > 0
										for row in oredrocFeesResult
											uniqueKey = row['asin']
											if !_.contains(Object.keys(reorderItems), uniqueKey)
												reorderItems[uniqueKey] = {}
												reorderItems[uniqueKey]["oredroc"] = {}
												reorderItems[uniqueKey]["crenstone"] = {}
											rowData = new Array()
											for key in Object.keys(row)
												if key != 'id' and key != 'seller' and key != 'snapshot-date'
													rowData.push(row[key])
												reorderItems[uniqueKey]["oredroc"][key] = row[key]
											feeData.push(rowData)
									if crenstoneInventoryResult.length > 0
										for row in crenstoneInventoryResult
											uniqueKey = row['asin']
											if !_.contains(Object.keys(reorderItems), uniqueKey)
												reorderItems[uniqueKey] = {}
												reorderItems[uniqueKey]["crenstone"] = {}
												reorderItems[uniqueKey]["oredroc"] = {}
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
									if crenstoneFeesResult.length > 0
										for row in crenstoneFeesResult
											uniqueKey = row['asin']
											if !_.contains(Object.keys(reorderItems), uniqueKey)
												reorderItems[uniqueKey] = {}
												reorderItems[uniqueKey]["crenstone"] = {}
												reorderItems[uniqueKey]["oredroc"] = {}
											rowData = new Array()
											for key in Object.keys(row)
												if key != 'id' and key != 'seller' and key != 'snapshot-date'
													rowData.push(row[key])
												reorderItems[uniqueKey]["crenstone"][key] = row[key]
											feeData.push(rowData)

									inventoryData = sortInventoryDataByAsin(inventoryData)
									feeData = removeFeeDataDuplicates(feeData)
									Q.all([Q.fcall(() -> inventoryData), Q.fcall(() -> feeData), buildReorderData(reorderItems)])
									.spread (inventoryData, feeData, reorderData) ->
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

	app.post('/reports/upload', (req, res) ->
		if !req.user
			res.redirect('/')
		else
			busboy = new Busboy({
				headers: req.headers, 
				limits: {
				  fileSize: 500 * 1024 * 1024 # 500 MB
				}
			})
			busboy.on 'file', (fieldName, fileStream, fileName, encoding, mimetype) ->
				if fieldName != "reorder"
				  console.error "fieldName is not reorder. It's: " + fieldName
				  return res.json(400, error: "Bad upload request. 'document' field not provided")
				if !fileStream?
				  console.error ""
				  return res.json(400, error: "Bad upload request. 'document' field value is null")
				file = {
				  data: fileStream
				  name: fileName
				  encoding: encoding
				  mimetype: mimetype
				}
				parseAndStoreManualInputs(file, req, res)
			busboy.on 'error', (err) ->
				bugsnag.notify("Error on document upload", err)
				console.error("Error parsing multipart form data during document upload")
				console.log(err.stack || err)
				return res.json(500, error: "Internal server error uploading document for investor verification form with id #{req.params.id}")
			req.pipe(busboy)
	)

app.listen(config.PORT)