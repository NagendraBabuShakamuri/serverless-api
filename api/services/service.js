const sequelize = require("sequelize");

const db = new sequelize(
    // process.env.DATABASE,
    "webapp",
    // process.env.USER_NAME,
    "admin",
    // process.env.PASSWORD,
    "Kissanime123",
    {
        // host: process.env.HOST,
        host: "database.cluster-c33zh61vsd02.us-east-1.rds.amazonaws.com",
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