Sequelize = require('sequelize')

module.exports.define = (sequelize) ->

	sequelize.define('user', {
		email:
			type: Sequelize.STRING
			allowNull: false
			unique: true
		, hash:
			type: Sequelize.STRING
	})