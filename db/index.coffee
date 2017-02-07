pg = require('pg')
config = require('../config')

Sequelize = require('sequelize')

sequelize = new Sequelize(config.DATABASE_URL)

User = require('./user').define(sequelize)

module.exports =
	sequelize: sequelize
	User: User
	createTablesIfNotExist: ->
		User.sync()