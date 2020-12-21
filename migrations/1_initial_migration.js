const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');
const {BigNumber} = require("@ethersproject/bignumber");

const STToken = artifacts.require("StandardHashrateToken");
const Migrations = artifacts.require("Migrations");
const BTCST = artifacts.require("BTCST");
const Farm = artifacts.require("FarmWithApi");
const MockERC20 = artifacts.require("MockERC20");

module.exports = async function (deployer,network, accounts) {
  await deployer.deploy(Migrations,{overwrite: false});
  // const instance = await deployProxy(STToken,
  //   ['StandardBTCHashrateToken','BTCST'],
  //   {deployer:deployer,unsafeAllowCustomTypes:true});
  const rewardToken = await deployer.deploy(MockERC20,"Bitcoin Mock","MBTC",BigNumber.from("10000000000000000000000"));
  // return;
  const btcst = await deployProxy(BTCST,[],
    {deployer:deployer,unsafeAllowCustomTypes:true,initializer:"initialize"});
  
  let contract = await BTCST.at(btcst.address);
  let res = await contract.initialized();
  console.log("btcst initialized:"+res);

  
  
  const farm = await deployer.deploy(Farm,btcst.address,rewardToken.address,"a testing farm");
  console.log("farm deployed at:"+farm.address);
  await btcst.changeFarmContract(farm.address);
  let farmContract = await btcst._farmContract();
  
  console.log("mock rewardToken deployed at:"+rewardToken.address);
  console.log('btcst deployed at:', btcst.address); 
  console.log("farmContract address in btcst changed to:"+farmContract);
  console.log("migration finished");

  // const upgraded = await upgradeProxy(instance.address,Token_V2,{deployer});
  
};
