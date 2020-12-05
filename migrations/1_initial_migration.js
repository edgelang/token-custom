const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');

const STToken = artifacts.require("StandardHashrateToken");
const Migrations = artifacts.require("Migrations");
const BTCST = artifacts.require("BTCST");

module.exports = async function (deployer) {
  // deployer.deploy(Migrations,{overwrite: false});
  // const instance = await deployProxy(STToken,
  //   ['StandardBTCHashrateToken','BTCST'],
  //   {deployer:deployer,unsafeAllowCustomTypes:true});
  const instance = await deployProxy(BTCST,
    [],
    {deployer:deployer,unsafeAllowCustomTypes:true,initializer:"initialize"});
  console.log('Deployed', instance.address); 
  let contract = await BTCST.at(instance.address);
  let res = await contract.initialized();
  console.log("initialized:"+res);
  // const upgraded = await upgradeProxy(instance.address,Token_V2,{deployer});
  
};
