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
 ,"Our Current Price"
 ,"Lowest Prime Price"
 ,"total-units-shipped-last-24-hrs"
 ,"total-units-shipped-last-7-days"
 ,"total-units-shipped-last-30-days"
 ,"total-units-shipped-last-90-days"
 ,"total-units-shipped-last-180-days"
 ,"total-units-shipped-last-365-days"
 ,"num-afn-new-sellers"
 ,"Remove from Restock report"
 ,"In Stock or OOS - Crenstone"
 ,"InBound Crenstone"
 ,"Days OOS - Crenstone"
 ,"Last 30 days of sales when in stock - Crenstone"
 ,"In Stock or OOS - Oredroc"
 ,"InBound Oredroc"
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
 ,"your-price"
 ,"lowest-afn-new-price"
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
 ,"your-price"
 ,"lowest-afn-new-price"
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
		snapshotDate = new Date(reorderItems[key]['snapshot-date'])
		snapshotDateFormatted = snapshotDate.getFullYear() + '-' + (snapshotDate.getMonth()+1) + '-' + snapshotDate.getDate()
		asin = reorderItems[key]['asin'] 
		seller = reorderItems[key]['seller']
		sameAsins = _.filter(reorderItems, (k) -> k.indexOf(asin) >= 0 and k != key)
		quantityNeededForRestock3x = 3 * (reorderItems[key]['sellable-quantity'] + reorderItems[key]['in-bound-quantity'])
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

		###for similarKey in sameAsins
			if similarKey.indexOf(seller) >= 0
				reorderItems[key]['instock-' + seller] += reorderItems[similarKey]['sellable-quantity']
			else
				reorderItems[key]['instock-' + otherSeller] += reorderItems[similarKey]['sellable-quantity']
		###
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
		reorderItems[key][seller + ' FNSKU'] = reorderItems[key]['fnsku']		

		#finish making reorder row, add to data, then return all the rows and create the output file. Easy.
		reorderRow = [
			snapshotDateFormatted || ''
			 ,reorderItems[key]['asin'] || ''
			 ,reorderItems[key]['product-name'] || ''
			 ,reorderItems[key]['sales-rank'] || ''
			 ,reorderItems[key]['product-group'] || ''
			 ,reorderItems[key]['your-price'] || ''
			 ,reorderItems[key]['lowest-afn-new-price'] || ''
			 ,reorderItems[key]['total-units-shipped-last-24-hrs'] || ''
			 ,reorderItems[key]['total-units-shipped-last-7-days'] || ''
			 ,reorderItems[key]['total-units-shipped-last-30-days'] || ''
			 ,reorderItems[key]['total-units-shipped-last-90-days'] || ''
			 ,reorderItems[key]['total-units-shipped-last-180-days'] || ''
			 ,reorderItems[key]['total-units-shipped-last-365-days'] || ''
			 ,reorderItems[key]['num-afn-new-sellers'] || ''
			 ,reorderItems[key]['Remove from Restock report'] || ''
			 ,reorderItems[key]['In Stock or OOS - crenstone'] || ''
			 ,reorderItems[key]['InBound crenstone'] || ''
			 ,reorderItems[key]['Days OOS - crenstone'] || ''
			 ,reorderItems[key]['Last 30 days of sales when in stock - crenstone'] || ''
			 ,reorderItems[key]['In Stock or OOS - oredroc'] || ''
			 ,reorderItems[key]['InBound oredroc'] || ''
			 ,reorderItems[key]['Days OOS - oredroc'] || ''
			 ,reorderItems[key]['Last 30 days of sales when in stock - oredroc'] || ''
			 ,reorderItems[key]['Total Stock - Both Accounts'] || ''
			 ,reorderItems[key]['Total Sales both accounts - 30 days'] || ''
			 ,reorderItems[key]['Seasonal Tags'] || ''
			 ,reorderItems[key]['OEM MFG Part Number'] || ''
			 ,reorderItems[key]['OEM MFG'] || ''
			 ,reorderItems[key]['Vendor Part number'] || ''
			 ,reorderItems[key]['Item Description'] || ''
			 ,reorderItems[key]['Vendor Name'] || ''
			 ,reorderItems[key]['Vendor Price'] || ''
			 ,reorderItems[key]['Quantity needed per ASIN'] || ''
			 ,reorderItems[key]['Total price of ASIN'] || ''
			 ,reorderItems[key]['Quantity needed for restock order 3x on 30 day sales'] || ''
			 ,reorderItems[key]['Quantity needed for restock order 6x on 30 day sales'] || ''
			 ,reorderItems[key]['Closeout / Retail Tag'] || ''
			 ,reorderItems[key]['Can Order Again?'] || ''
			 ,reorderItems[key]['Selling in accounts'] || ''
			 ,reorderItems[key]['Has stock in accounts'] || ''
			 ,reorderItems[key]['crenstone SKU'] || ''
			 ,reorderItems[key]['crenstone FNSKU'] || ''
			 ,reorderItems[key]['your-price'] || ''
			 ,reorderItems[key]['lowest-afn-new-price'] || ''
			 ,reorderItems[key]['lowest-afn-new-price'] - reorderItems[key]['your-price'] || ''
			 ,reorderItems[key]['brand'] || ''
			 ,reorderItems[key]['your-price'] || ''
			 ,reorderItems[key]['sales-price'] || ''
			 ,reorderItems[key]['estimated-fee-total'] || ''
			 ,reorderItems[key]['estimated-future-fee'] || ''
			 ,reorderItems[key]['estimated-shipping-cost'] || ''
			 ,reorderItems[key]['total-inventory-cost'] || ''
			 ,reorderItems[key]['overhead-rate'] || ''
			 ,reorderItems[key]['profit'] || ''
			 ,reorderItems[key]['future-profit'] || ''
			 ,reorderItems[key]['crenstone-units-shipped-last-24-hrs'] || ''
			 ,reorderItems[key]['crenstone-units-shipped-last-7-days'] || ''
			 ,reorderItems[key]['crenstone-units-shipped-last-30-days'] || ''
			 ,reorderItems[key]['crenstone-units-shipped-last-90-days'] || ''
			 ,reorderItems[key]['crenstone-units-shipped-last-180-days'] || ''
			 ,reorderItems[key]['crenstone-units-shipped-last-365-days'] || ''
			 ,reorderItems[key]['your-price'] || ''
			 ,reorderItems[key]['lowest-afn-new-price'] || ''
			 ,reorderItems[key]['Below Current Price?'] || ''
			 ,reorderItems[key]['brand'] || ''
			 ,reorderItems[key]['your-price'] || ''
			 ,reorderItems[key]['sales-price'] || ''
			 ,reorderItems[key]['estimated-fee-total'] || ''
			 ,reorderItems[key]['estimated-future-fee (Current Selling on Amazon + Future Fulfillment fees)'] || ''
			 ,reorderItems[key]['estimated-shipping-cost'] || ''
			 ,reorderItems[key]['total-inventory-cost'] || ''
			 ,reorderItems[key]['overhead-rate'] || ''
			 ,reorderItems[key]['profit'] || ''
			 ,reorderItems[key]['future-profit'] || ''
			 ,reorderItems[key]['oredroc-units-shipped-last-24-hrs'] || ''
			 ,reorderItems[key]['oredroc-units-shipped-last-7-days'] || ''
			 ,reorderItems[key]['oredroc-units-shipped-last-30-days'] || ''
			 ,reorderItems[key]['oredroc-units-shipped-last-90-days'] || ''
			 ,reorderItems[key]['oredroc-units-shipped-last-180-days'] || ''
			 ,reorderItems[key]['oredroc-units-shipped-last-365-days'] || ''
		]
		reorderData.push(reorderRow)
	reorderData

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
									if oredrocInventoryResult.length > 0
										columnNames = _.filter(Object.keys(oredrocInventoryResult[0]), (key) -> key != 'id' and key != 'seller')
										data = new Array()
										data.push(columnNames)
										for row in oredrocInventoryResult
											uniqueKey = "oredroc:" + row['asin'] + ":" + row['sku']
											if !_.contains(Object.keys(reorderItems), uniqueKey)
												reorderItems[uniqueKey] = {}
											rowData = new Array()
											for key in Object.keys(row)
												if key == 'snapshot-date'
													date = new Date(row[key])
													formattedDate = date.getFullYear() + '-' + (date.getMonth()+1) + '-' + date.getDate()
													rowData.push(formattedDate)
												else if key != 'id' and key != 'seller'
													rowData.push(row[key])
												reorderItems[uniqueKey][key] = row[key]
											data.push(rowData)
										worksheets.push({name: "Oredroc Inventory Health", data: data})
									if oredrocFeesResult.length > 0
										columnNames = _.filter(Object.keys(oredrocFeesResult[0]), (key) -> key != 'id' and key != 'seller')
										data = new Array()
										data.push(columnNames)
										for row in oredrocFeesResult
											uniqueKey = "oredroc:" + row['asin'] + ":" + row['sku']
											if !_.contains(Object.keys(reorderItems), uniqueKey)
												reorderItems[uniqueKey] = {}
											rowData = new Array()
											for key in Object.keys(row)
												if key == 'snapshot-date'
													date = new Date(row[key])
													formattedDate = date.getFullYear() + '-' + (date.getMonth()+1) + '-' + date.getDate()
													rowData.push(formattedDate)
												else if key != 'id' and key != 'seller'
													rowData.push(row[key])
												reorderItems[uniqueKey][key] = row[key]
											data.push(rowData)
										worksheets.push({name: "Oredroc FBA Fees", data: data})
									if crenstoneInventoryResult.length > 0
										columnNames = _.filter(Object.keys(crenstoneInventoryResult[0]), (key) -> key != 'id' and key != 'seller')
										data = new Array()
										data.push(columnNames)
										for row in crenstoneInventoryResult
											uniqueKey = "crenstone:" + row['asin'] + ":" + row['sku']
											if !_.contains(Object.keys(reorderItems), uniqueKey)
												reorderItems[uniqueKey] = {}
											rowData = new Array()
											for key in Object.keys(row)
												if key == 'snapshot-date'
													date = new Date(row[key])
													formattedDate = date.getFullYear() + '-' + (date.getMonth()+1) + '-' + date.getDate()
													rowData.push(formattedDate)
												else if key != 'id' and key != 'seller'
													rowData.push(row[key])
												reorderItems[uniqueKey][key] = row[key]
											data.push(rowData)
										worksheets.push({name: "Crenstone Inventory Health", data: data})
									if crenstoneFeesResult.length > 0
										columnNames = _.filter(Object.keys(crenstoneFeesResult[0]), (key) -> key != 'id' and key != 'seller')
										data = new Array()
										data.push(columnNames)
										for row in crenstoneFeesResult
											uniqueKey = "crenstone:" + row['asin'] + ":" + row['sku']
											if !_.contains(Object.keys(reorderItems), uniqueKey)
												reorderItems[uniqueKey] = {}
											rowData = new Array()
											for key in Object.keys(row)
												if key == 'snapshot-date'
													date = new Date(row[key])
													formattedDate = date.getFullYear() + '-' + (date.getMonth()+1) + '-' + date.getDate()
													rowData.push(formattedDate)
												else if key != 'id' and key != 'seller'
													rowData.push(row[key])
												reorderItems[uniqueKey][key] = row[key]
											data.push(rowData)
										worksheets.push({name: "Crenstone FBA Fees", data: data})

									###for key in Object.keys(reorderItems)
										if reorderItems[key]['condition'] != undefined
											console.log reorderItems[key]###

									reorderData = buildReorderData(reorderItems)
									worksheets.unshift({name: "Reorder File", data: reorderData})

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