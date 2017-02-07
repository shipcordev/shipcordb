pg = require('pg')

config = require('../config')

connectionString = config.DATABASE_URL

client = new pg.Client(connectionString)
client.connect()
query = client.query(
	'CREATE TABLE "report-snapshot-dates"(id SERIAL PRIMARY KEY, 
	type VARCHAR(255),
	seller VARCHAR(255), 
	"snapshot-date" DATE NOT NULL)')

query.on('end', () -> client.end())