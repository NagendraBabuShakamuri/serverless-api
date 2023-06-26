const Product = require(__dirname + "/../models/Product.js");
const ProductImage = require(__dirname + "/../models/ProductImage.js");

exports.deleteProduct = function(productId){
    return new Promise(async (resolve, reject) => {       
        Product.destroy({
            where: {
                id : productId
            }
        }).then(res => {
            resolve(res);
        }).catch((error) => {
            reject(console.error('Failed to delete data : ', error));
        });
    });
};

exports.productExists = function(productId){
    return new Promise(async (resolve, reject) => {
        Product.findOne({
            where: {
                id : productId
            }
        }).then(res => {
            resolve(res);
        }).catch((error) => {
            reject(console.error('Failed to find the product : ', error));
        });
    });
};

exports.isUserProduct = function(productId, userId){
    return new Promise(async (resolve, reject) => {
        Product.findOne({
            where: {
                id : productId,
                owner_user_id: userId
            }
        }).then(res => {
            resolve(res);
        }).catch((error) => {
            reject(console.error('Failed to check if the product belongs to the user : ', error));
        });
    });
};

exports.deleteProductImage = function(imageId){
    return new Promise(async (resolve, reject) => {
        ProductImage.destroy({
            where: {
                image_id : imageId
            }
        }).then(res => {
            resolve(res);
        }).catch((error) => {
            reject(console.error('Failed to delete data : ', error));
        });
    });
};

exports.deleteProductImages = function(productId){
    return new Promise(async (resolve, reject) => {
        ProductImage.destroy({
            where: {
                product_id : productId
            }
        }).then(res => {
            resolve(res);
        }).catch((error) => {
            reject(console.error('Failed to delete data : ', error));
        });
    });
};