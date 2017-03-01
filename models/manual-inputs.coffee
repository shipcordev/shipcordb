pg = require('pg')

config = require('../config')

connectionString = config.DATABASE_URL

client = new pg.Client(connectionString)
client.connect()
query = client.query(
	'CREATE TABLE "manual-inputs"(id SERIAL PRIMARY KEY, 
	asin VARCHAR(255),
	"crenstone-sku" VARCHAR(255),
	"oredroc-sku" VARCHAR(255),
	"remove-from-restock-report" BOOLEAN,
	"seasonal-tags" VARCHAR(255),
	"oem-mfg-part-number" VARCHAR(255),
	"oem-mfg" VARCHAR(255),
	"vendor-part-number" VARCHAR(255),
	"item-description" TEXT,
	"vendor-name" VARCHAR(255),
	"vendor-price" DECIMAL,
	"quantity-needed-per-asin" INTEGER,
	"closeout-retail-tag" VARCHAR(255),
	"can-order-again" BOOLEAN,
	"estimated-shipping-cost" DECIMAL,
	"overhead-rate" DECIMAL)')

query.on('end', () -> client.end())