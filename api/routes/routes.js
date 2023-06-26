const express = require('express');
const router = express.Router();

const { 
    health, 
    getUser, 
    getProduct, 
    getProductImages, 
    getProductImage, 
    createUser, 
    createProduct, 
    uploadProductImage,
    updateUser, 
    updateFullProduct, 
    updateProduct, 
    deleteProduct, 
    deleteProductImage 
} = require('../controllers/controller');

router.get("/healthz", health);

router.get("/v1/user/:userId", getUser);

router.get("/v1/product/:productId", getProduct);

router.get("/v1/product/:product_id/image", getProductImages);

router.get("/v1/product/:product_id/image/:image_id", getProductImage);

router.post("/v1/user", createUser);

router.post("/v1/product", createProduct);

router.post("/v1/product/:product_id/image", uploadProductImage);

router.put("/v1/user/:userId", updateUser);

router.put("/v1/product/:productId", updateFullProduct);

router.patch("/v1/product/:productId", updateProduct);

router.delete("/v1/product/:productId", deleteProduct);

router.delete("/v1/product/:product_id/image/:image_id", deleteProductImage);

module.exports = router;