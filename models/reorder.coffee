pg = require('pg')

config = require('../config')

connectionString = config.DATABASE_URL

client = new pg.Client(connectionString)
client.connect()
query = client.query(
	'CREATE TABLE reorder(id SERIAL PRIMARY KEY, 
	"snapshot-date" DATE NOT NULL,
	asin VARCHAR(255),
	"product-name" TEXT,
	"sales-rank" INTEGER,	
	"product-group" VARCHAR(255),
	"your-price" DECIMAL,
	"lowest-afn-new-price" DECIMAL,
	"units-shipped-last-24-hrs" INTEGER,
	"units-shipped-last-7-days" INTEGER,
	"units-shipped-last-30-days" INTEGER,
	"units-shipped-last-90-days" INTEGER,
	"units-shipped-last-180-days" INTEGER,
	"units-shipped-last-365-days" INTEGER,
	"num-afn-new-sellers" INTEGER,
	"remove-from-restock-report" BOOLEAN,
	"in-stock-crenstone" INTEGER,
	"inbound-crenstone" INTEGER,
	"days-oos-crenstone" INTEGER,
	"last-30-days-sales-crenstone" INTEGER,
	"in-stock-oredroc" INTEGER,
	"inbound-crenstone" INTEGER,
	"days-oos-oredroc" INTEGER,
	"last-30-days-sales-oredroc" INTEGER,
	"total-stock" INTEGER,
	"total-sales-30-days" INTEGER,
	"seasonal-tags" VARCHAR(255),
	"oem-mfg-part-number" VARCHAR(255),
	"oem-mfg" VARCHAR(255),
	"vendor-part-number" VARCHAR(255),
	"item-description" TEXT,
	"vendor-name" VARCHAR(255),
	"vendor-price" DECIMAL,
	"quantity-needed-per-asin" INTEGER,
	"type-pf-order" VARCHAR(255),
	"can-order" BOOLEAN,
	"sku-crenstone" VARCHAR(255),
	"fnsku-crenstone" VARCHAR(255),
	brand VARCHAR(255),
	"sales-price" DECIMAL,
	"estimated-fee-total" DECIMAL,
	"estimated-future-fee" DECIMAL,
	"estimated-shipping-cost" DECIMAL,
	"overhead-rate" DECIMAL,
	"sku-oredroc" VARCHAR(255),
	"fnsku-oredroc" VARCHAR(255))')

query.on('end', () -> client.end())