const bcrypt = require("bcryptjs");
const User = require(__dirname + "/../models/User.js");
const Product = require(__dirname + "/../models/Product.js");
const ProductImage = require(__dirname + "/../models/ProductImage.js");

exports.getAllUsers = function(){
    return new Promise(async (resolve, reject) => {
        User.findAll().then(res => {
            resolve(res);
        }).catch((error) => {
            reject(console.error('Failed to retrieve data : ', error));
        });
    });
};

exports.hashPassword = function(password, saltRounds){
    return new Promise((resolve, reject) => {
        bcrypt.hash(password, saltRounds, function(err, hash){
            if(err)
            {
                reject(err);
            }
            else
            {
                resolve(hash);
            }
        });
    });
};

exports.createNewUser = function(username, password, first_name, last_name){
    return new Promise(async (resolve, reject) => {
        User.create({
            username: username,
            password: password,
            first_name: first_name,
            last_name: last_name
        }).then(res => {
            resolve(res);
        }).catch((error) => {
            reject(console.error('Failed to create a new user : ', error));
        });
    });
};

exports.skuExists = function(sku)
{
    return new Promise(async (resolve, reject) => {
       Product.findOne(
           { where: { sku: sku } }
       ).then(res => {
        resolve(res);
        }).catch((error) => {
            reject(console.error('Failed to search for sku : ', error));
        });
    });
};

exports.createNewProduct = function(name, description, sku, manufacturer, quantity, userId, res){
    return new Promise(async (resolve, reject) => {
        Product.create({
            name: name,
            description: description,
            sku: sku,
            manufacturer: manufacturer,
            quantity: quantity,
            owner_user_id: userId
        }).then(res => {
            resolve(res);
        }).catch((error) => {
            res.status(400);
            res.send({"Status": 400, "Message": "Product quantity should be between 0 and 100."});
        });
    });
};

exports.createNewProductImage = function(productId, fileName, bucketPath){
    return new Promise(async (resolve, reject) => {
        ProductImage.create({
            product_id: productId,
            file_name: fileName,
            s3_bucket_path: bucketPath
        }).then(res => {
            resolve(res);
        }).catch((error) => {
            reject(console.error('Failed to create a new Image : ', error));
        });
    });
};

exports.createNewProductImage = function(productId, fileName, bucketPath){
    return new Promise(async (resolve, reject) => {
        ProductImage.create({
            product_id: productId,
            file_name: fileName,
            s3_bucket_path: bucketPath
        }).then(res => {
            resolve(res);
        }).catch((error) => {
            reject(console.error('Failed to create a new Image : ', error));
        });
    });
};