const sequelize = require("sequelize");
const AWS = require("aws-sdk");

async function getSecret() {

    return new Promise(async (resolve, reject) => {
        AWS.config.update({
            region: process.env.REGION
        });
        const secretsManager = new AWS.SecretsManager();

        const response = await secretsManager.getSecretValue({ SecretId: process.env.MASTER_CREDENTIALS_ARN }).promise();

        if (response.SecretString) {
            const secretValue = JSON.parse(response.SecretString);
            resolve(secretValue);
        }
        else
        {
            reject();
        }
    });
}

function getDB()
{
    console.log(getSecret());
    const db = new sequelize(
        process.env.DATABASE,
        process.env.USER_NAME,
        getSecret(),
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
    
    return db;
}

const db = getDB();

module.exports = db;