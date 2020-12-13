const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');

const STToken = artifacts.require("StandardHashrateToken");
const Migrations = artifacts.require("Migrations");
const BTCST = artifacts.require("BTCST");
const Farm = artifacts.require("FarmWithApi");
const MockERC20 = artifacts.require("MockERC20");

module.exports = async function (deployer) {
  deployer.deploy(Migrations,{overwrite: false});
  // const instance = await deployProxy(STToken,
  //   ['StandardBTCHashrateToken','BTCST'],
  //   {deployer:deployer,unsafeAllowCustomTypes:true});
  const btcst = await deployProxy(BTCST,[],
    {deployer:deployer,unsafeAllowCustomTypes:true,initializer:"initialize"});
  console.log('btcst deployed at:', btcst.address); 
  let contract = await BTCST.at(btcst.address);
  let res = await contract.initialized();
  console.log("btcst initialized:"+res);
  const rewardToken = await deployer.deploy(MockERC20,"Bitcoin Mock","MBTC",10000);
  console.log("rewardToken deployed");
  const farm = await deployer.deploy(Farm,btcst.address,rewardToken.address,"a testing famr");
  console.log("farm deployed");
  console.log("migration finished");

  // const upgraded = await upgradeProxy(instance.address,Token_V2,{deployer});
  
};
