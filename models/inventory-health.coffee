pg = require('pg')

config = require('../config')

connectionString = config.DATABASE_URL

client = new pg.Client(connectionString)
client.connect()
query = client.query(
	'CREATE TABLE "inventory-health"(id SERIAL PRIMARY KEY, 
	seller VARCHAR(255),
	"snapshot-date" DATE NOT NULL,
	sku VARCHAR(255),
	fnsku VARCHAR(255),
	asin VARCHAR(255),
	"product-name" TEXT,
	condition VARCHAR(255),
	"sales-rank" INTEGER,
	"product-group" VARCHAR(255),
	"total-quantity" INTEGER,
	"sellable-quantity" INTEGER,
	"unsellable-quantity" INTEGER,
	"inv-age-0-to-90-days" INTEGER,
	"inv-age-91-to-180-days" INTEGER,
	"inv-age-181-to-270-days" INTEGER,
	"inv-age-271-to-365-days" INTEGER,
	"inv-age-365-plus-days" INTEGER,
	"units-shipped-last-24-hrs" INTEGER,
	"units-shipped-last-7-days" INTEGER,
	"units-shipped-last-30-days" INTEGER,
	"units-shipped-last-90-days" INTEGER,
	"units-shipped-last-180-days" INTEGER,
	"units-shipped-last-365-days" INTEGER,
	"weeks-of-cover-t7" VARCHAR(255),
	"weeks-of-cover-t30" VARCHAR(255),
	"weeks-of-cover-t90" VARCHAR(255),
	"weeks-of-cover-t180" VARCHAR(255),
	"weeks-of-cover-t365" VARCHAR(255),
	"num-afn-new-sellers" INTEGER,
	"num-afn-used-sellers" INTEGER,
	currency VARCHAR(255),
	"your-price" DECIMAL,
	"sales-price" DECIMAL,
	"lowest-afn-new-price" DECIMAL,
	"lowest-afn-used-price" DECIMAL,
	"lowest-mfn-new-price" DECIMAL,
	"lowest-mfn-used-price" DECIMAL,
	"qty-to-be-charged-ltsf-12-mo" INTEGER,
	"qty-in-long-term-storage-program" INTEGER,
	"qty-with-removals-in-progress" INTEGER,
	"projected-ltsf-12-mo" DECIMAL,
	"per-unit-volume" DECIMAL,
	"is-hazmat" BOOLEAN,
	"in-bound-quantity" INTEGER,
	"asin-limit" INTEGER,
	"inbound-recommend-quantity" INTEGER,
	"qty-to-be-charged-ltsf-6-mo" INTEGER,
	"projected-ltsf-6-mo" DECIMAL)')

query.on('end', () -> client.end())