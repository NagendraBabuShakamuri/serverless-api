const sequelize = require("sequelize");
const db = new sequelize(
    process.env.DATABASE,
    process.env.USER_NAME,
    process.env.SECRET,
    {
        host: process.env.HOST,
        dialect: 'mysql',
        timezone: '-05:00'
    }
);

db.authenticate().then(() => {
    console.log('Connection has been established successfully.');
}).catch((error) => {
    console.log('Unable to connect to the database: ', error);
});

module.exports = db;