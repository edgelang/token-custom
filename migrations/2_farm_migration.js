const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');
const {BigNumber} = require("@ethersproject/bignumber");

const STToken = artifacts.require("StandardHashrateToken");
const Migrations = artifacts.require("Migrations");
const BTCST = artifacts.require("BTCST");
const Farm = artifacts.require("FarmWithApi");
const MockERC20 = artifacts.require("MockERC20");

module.exports = async function (deployer,network, accounts) {
  let owner = accounts[0];  
  // const instance = await deployProxy(STToken,
  //   ['StandardBTCHashrateToken','BTCST'],
  //   {deployer:deployer,unsafeAllowCustomTypes:true});
  // return;
  let btcst = await deployProxy(BTCST,[],
    {deployer:deployer,unsafeAllowCustomTypes:true,initializer:"initialize"});
  
  let contract = await BTCST.at(btcst.address);
  let res = await contract.initialized();
  
  let rewardToken = await deployer.deploy(MockERC20,"Bitcoin Mock","MBTC",BigNumber.from("10000000000000000000000"));
  rewardToken = await MockERC20.deployed();
  console.log("btcst initialized:"+res);
  console.log('btcst deployed at:', btcst.address);
  console.log("mock rewardToken deployed at:",rewardToken.address);
  
  let initPeriod = 300;
  let farm = await deployer.deploy(Farm,btcst.address,rewardToken.address,"a testing farm");
  farm = await Farm.deployed();
  await farm.changeMiniStakePeriodInSeconds(initPeriod);
  let now = Date.now()/1000;
  now = now-now%100;
  await farm.changeBaseTime(now-initPeriod*2);

  console.log("farm deployed at:"+farm.address);
  await btcst.changeFarmContract(farm.address);
  let farmContract = await btcst._farmContract();
  
//   await btcst.mint(owner,BigNumber.from("1000000000000000000000000"));
    // await btcst.mint(owner,BigNumber.from(""));
  console.log("mock rewardToken deployed at:"+rewardToken.address);
  console.log('btcst deployed at:', btcst.address); 
  console.log("farmContract address in btcst changed to:"+farmContract);
  console.log("basetime:"+(now-initPeriod*2));
  console.log("initperiod:"+initPeriod);
  console.log("migration finished");


// farm deployed at:0xA2B49Ad2Fb14C91f6b361E03c15C6BDF53D66d5C
// mock rewardToken deployed at:0x38F4Ab9E4EEC0F9AC0Ca9d9eFe42FC7b7C230343
// btcst deployed at: 0xa1ea2f1cadb89B1782b2e4C8C3Aaa472E2104aa1
// farmContract address in btcst changed to:0xA2B49Ad2Fb14C91f6b361E03c15C6BDF53D66d5C

  // const upgraded = await upgradeProxy(instance.address,Token_V2,{deployer});
  
};
