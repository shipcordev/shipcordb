pg = require('pg')

config = require('../config')

connectionString = config.DATABASE_URL

client = new pg.Client(connectionString)
client.connect()
query = client.query(
	'CREATE TABLE "fba-fees"(id SERIAL PRIMARY KEY, 
	"snapshot-date" DATE NOT NULL, 
	sku VARCHAR(255),
	fnsku VARCHAR(255),
	asin VARCHAR(255),
	"product-name" TEXT,
	"product-group" VARCHAR(255),
	brand VARCHAR(255),
	"fulfilled-by" VARCHAR(255),
	"your-price" DECIMAL,
	"sales-price" DECIMAL,
	"longest-side" DECIMAL,
	"median-side" DECIMAL,
	"shortest-side" DECIMAL,
	"length-and-girth" DECIMAL,
	"unit-of-dimension" VARCHAR(255),
	"item-package-weight" DECIMAL,
	"unit-of-weight" VARCHAR(255),
	"product-size-tier" VARCHAR(255),
	currency VARCHAR(255),
	"estimated-fee-total" DECIMAL,
	"estimated-referral-fee-per-unit" DECIMAL,
	"estimated-variable-closing-fee" DECIMAL,
	"estimated-order-handling-fee-per-order" DECIMAL,
	"estimated-pick-pack-fee-per-unit" DECIMAL,
	"estimated-weight-handling-fee-per-unit" DECIMAL,
	"estimated-future-fee" DECIMAL,
	"estimated-future-order-handling-fee-per-order" DECIMAL,
	"estimated-future-pick-pack-fee-per-unit" DECIMAL,
	"estimated-future-weight-handling-fee-per-unit" DECIMAL,
	"expected-future-fulfillment-fee-per-unit" DECIMAL)')

query.on('end', () -> client.end())