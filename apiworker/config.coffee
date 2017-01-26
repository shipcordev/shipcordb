module.exports =
	MWS_SECRET_KEY: process.env.MWS_SECRET_KEY || undefined
	MWS_AUTH_TOKEN: process.env.MWS_AUTH_TOKEN || undefined
	SELLER_ID: process.env.SELLER_ID || undefined
	AWS_ACCESS_KEY: process.env.AWS_ACCESS_KEY || undefined
	DATABASE_URL: process.env.DATABASE_URL || 'postgres://postgres:admin@localhost:5432/shipcor'