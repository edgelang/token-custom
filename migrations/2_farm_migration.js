const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');
const {BigNumber} = require("@ethersproject/bignumber");
var dateFormat = require("dateformat");

const STToken = artifacts.require("StandardHashrateToken");
const Migrations = artifacts.require("Migrations");
const BTCST = artifacts.require("BTCST");
const Farm = artifacts.require("FarmWithApi");
const MockERC20 = artifacts.require("MockERC20");

module.exports = async function (deployer,network, accounts) {
  let owner = accounts[0]; 
  if (network=="bsc"|| network=="ethmain" 
        // && network!="testbsc"
      ){
    owner = accounts[2]; 
    accounts[2] = accounts[0];
    accounts[0] = owner;
  }
  
  // console.log(deployer);
  // const instance = await deployProxy(STToken,
  //   ['StandardBTCHashrateToken','BTCST'],
  //   {deployer:deployer,unsafeAllowCustomTypes:true});
  // return;
  let farm_desc= "a testing farm";
  let rewardToken = {};
  if (network!="bsc" && network!="ethmain" 
        // && network!="testbsc"
      ){
    rewardToken = await deployer.deploy(MockERC20,"Bitcoin Mock","MBTC",BigNumber.from("10000000000000000000000"),{from:owner});
    rewardToken = await MockERC20.deployed();
  }else if (network=="bsc"
        // ||network=="testbsc"
    ){
    //btcb token address
    rewardToken = {"address":"0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c"};
    farm_desc="Our mining farm for BTC";
  }
  BTCST.class_defaults = {from:owner,
    gas:deployer.networks[network].gas,
    gasPrice:deployer.networks[network].gasPrice};
  console.log(BTCST.class_defaults);

  let btcst = await deployProxy(BTCST,[],
    {deployer:deployer,unsafeAllowCustomTypes:true,initializer:"initialize",from:owner});

  let contract = await BTCST.at(btcst.address);
  let res = await contract.initialized();


  console.log("btcst initialized:"+res);
  console.log('btcst deployed at:', btcst.address);
  console.log("mock rewardToken deployed at:",rewardToken.address);
  
  let farm = await deployer.deploy(Farm,btcst.address,rewardToken.address,farm_desc,{from:owner});
  farm = await Farm.deployed();

  if (network!="bsc" && network!="ethmain"
        // && network!="testbsc"
    ){
    let initPeriod = 300;
    await farm.changeMiniStakePeriodInSeconds(initPeriod,{from:owner});
    let now = Date.now()/1000;
    now = now-now%100;
    await farm.changeBaseTime(now-initPeriod*2,{from:owner});
  }else{
    let date = new Date(dateFormat(Date.now(),"yyyy-mm-dd")+" 20:00"+" GMT+0800");
    let time = date.getTime()/1000-86400*5;
    await farm.changeBaseTime(time,{from:owner});
  }


  console.log("farm deployed at:"+farm.address);
  await btcst.changeFarmContract(farm.address,{from:owner});
  let farmContract = await btcst._farmContract();

  //   await btcst.mint(owner,BigNumber.from("1000000000000000000000000"));
    // await btcst.mint(owner,BigNumber.from(""));
  console.log("rewardToken deployed at:"+rewardToken.address);
  console.log('btcst deployed at:', btcst.address); 
  console.log("farmContract address in btcst changed to:"+farmContract);
  console.log("basetime:"+ (await farm._farmStartedTime({from:owner})));
  console.log("_miniStakePeriodInSeconds"+(await farm._miniStakePeriodInSeconds({from:owner})));
  console.log("migration finished");
  console.log("btcst owner:"+await btcst.getOwner({from:owner}));
  console.log("farm owner:"+await btcst.owner({from:owner}));


  // farm deployed at:0xA2B49Ad2Fb14C91f6b361E03c15C6BDF53D66d5C
  // mock rewardToken deployed at:0x38F4Ab9E4EEC0F9AC0Ca9d9eFe42FC7b7C230343
  // btcst deployed at: 0xa1ea2f1cadb89B1782b2e4C8C3Aaa472E2104aa1
  // farmContract address in btcst changed to:0xA2B49Ad2Fb14C91f6b361E03c15C6BDF53D66d5C

  // const upgraded = await upgradeProxy(instance.address,Token_V2,{deployer});

};
