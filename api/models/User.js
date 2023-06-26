const sequelize = require("sequelize");

const db = require(__dirname + "/../services/service.js");

const User = db.define("users", {
    id: {
        type: sequelize.INTEGER,
        autoIncrement: true,
        primaryKey: true
    },
    username: {
        type: sequelize.STRING,
        allowNull: false
    },
    password: {
        type: sequelize.STRING,
        allowNull: false
    },
    first_name: {
        type: sequelize.STRING,
        allowNull: false
    },
    last_name: {
        type: sequelize.STRING,
        allowNull: false
    }},
    {
    createdAt: 'account_created',
    updatedAt: 'account_updated'
});

module.exports = User;