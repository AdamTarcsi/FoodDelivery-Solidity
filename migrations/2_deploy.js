var Ownable = artifacts.require("./Ownable.sol");
var FoodDelivery = artifacts.require("./FoodDelivery.sol");


module.exports = function(deployer) {
  deployer.deploy(Ownable);
  deployer.deploy(FoodDelivery);
};
