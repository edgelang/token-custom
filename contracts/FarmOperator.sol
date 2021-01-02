// SPDX-License-Identifier: MIT
pragma solidity 0.6.9;

import "./interfaces/IMiningFarm.sol";
import "./libraries/PeggyToken.sol";
import "./3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

contract FarmOperator is PeggyToken{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    address public _farmContract;
    IERC20Upgradeable public _rtokenContract;
    IERC20Upgradeable public _stokenContract;
    bytes32 public constant FARM_OP_ROLE = keccak256("FARM_OP_ROLE");
    // n order to make manage standard hashrate token more easy,we use farm op token to achieve some thing
    //especially for easy distribute reward tokens for mining
    function initialize() public initializer{
        address owner = msg.sender;
        super.initialize("Farm op token","OPT",owner);
        _setupRole(FARM_OP_ROLE, _msgSender());
    }

    function adminChangeFarm(address farm)public onlyOwner{
        _farmContract = farm;
    }

    function adminChangeRToken(address rtoken)public onlyOwner{
        _rtokenContract = IERC20Upgradeable(rtoken);
    }

    function adminChangeSToken(address stoken)public onlyOwner{
        _stokenContract = IERC20Upgradeable(stoken);
    }

    /**
     * @dev check about the to address, tomake deposit mining reward for mining farm contract
     *
     */
    function _beforeTokenTransfer(address account, address to, uint256 amount) internal virtual override(PeggyToken) nonReentrant { 
        super._beforeTokenTransfer(account, to, amount);
        if (to!=address(_farmContract) || address(_farmContract)==address(0)){
            return;
        }
        if (address(_rtokenContract)==address(0)){
            return;
        }
        //check operation right
        require(hasRole(FARM_OP_ROLE, _msgSender()), "FarmOperator: must have FARM_OP_ROLE to distribute reward token");
        require(amount<=balanceOf(account),"amount exceeds opt balance,contact admin to get more OPTs");
        require(amount<=_rtokenContract.balanceOf(address(this)),"amount exceeds farm-op's reward token's balance,please deposit reward token to this contract first");

        //if the transfer destination is our mining farm contract, call increase allowance for reward token first
        //and then call deposit reward for mining farm,this will deposit same amount of reward token to farm's
        //yesterday's slot, ms.sender will be farm-op
        //increased rewardtoken's allowance for farm-op->farm-contract
        _rtokenContract.safeIncreaseAllowance(_farmContract,amount);
        //deposit from farm-op->farm-contract
        IMiningFarm(_farmContract).apiDepositRewardFrom(amount);
    } 
}