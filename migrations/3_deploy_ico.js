var ICO = artifacts.require("./ICO.sol");

module.exports = function(deployer) {
  deployer.deploy(ICO,'My Token','MTK',18,1000);
};
