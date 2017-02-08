module.exports =
	MWS_SECRET_KEY: process.env.MWS_SECRET_KEY || undefined
	MWS_AUTH_TOKEN: process.env.MWS_AUTH_TOKEN || undefined
	SELLER_ID: process.env.SELLER_ID || undefined
	AWS_ACCESS_KEY: process.env.AWS_ACCESS_KEY || undefined
	SELLER_ACCOUNT: process.env.SELLER_ACCOUNT || undefined
	DATABASE_URL: process.env.DATABASE_URL || 'postgres://postgres:admin@localhost:5432/shipcor'
	IS_WORKER: process.env.IS_WORKER || false
	SALTROUNDS: process.env.SALTROUNDS || 10
	COOKIE_SECRET: process.env.COOKIE_SECRET || 'test'
	PORT: process.env.PORT || 3000