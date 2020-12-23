const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');
const {BigNumber} = require("@ethersproject/bignumber");

const STToken = artifacts.require("StandardHashrateToken");
const Migrations = artifacts.require("Migrations");
const BTCST = artifacts.require("BTCST");
const Farm = artifacts.require("FarmWithApi");
const MockERC20 = artifacts.require("MockERC20");

module.exports = async function (deployer,network, accounts) {
    if (network!="bsc" && network!="ethmain"){
        let migrate = await deployer.deploy(Migrations,{overwrite: false});
    }

};
