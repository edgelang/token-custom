// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;
pragma experimental ABIEncoderV2;

import "./3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "./MiningFarm.sol";
import "./libraries/TokenUtility.sol";
import "./FarmAllowLockedToken.sol";

contract FarmWithApi is FarmAllowLockedToken{
    using SafeMath for uint256;
    using TokenUtility for *;
    using EnumerableSet for EnumerableSet.AddressSet;
    struct SlotInfoResult{
        address rewardLastSubmiter;
        uint256 rewardAmount;
        uint256 rewardAccumulateAmount;
        uint256 totalStaked;
        uint256 stakedLowestWaterMark;
        uint256 totalStakedInSlot;
        address[] stakedAddresses;
    }
    struct UserInfoResult{
        //how many STokens the user has provided in all
        uint256 amount;
        //how many locked STokens the user has provided in all
        uint256 lockedAmount;

        //when >0 denotes that reward before this time already update into rewardBalanceInpool
        uint lastUpdateRewardTime;

        //all his lifetime mined target token amount
        uint256 allTimeMinedBalance;
        //mining reward balances in pool without widthdraw
        uint256 rewardBalanceInpool;
        
        //stake info account =>(time-key => staked record)
        StakeRecord[] stakeInfo;
        //store time-key arrays for stakeInfo
        uint[] stakedTimeIndex;
    }
    constructor(StandardHashrateToken SToken,IERC20Upgradeable  rewardToken,
        uint256 miniStakePeriod,uint startTime,string memory desc)
        FarmAllowLockedToken(SToken,rewardToken,miniStakePeriod,startTime,desc) public{   
    }
    /**
     * @dev for lookup slot infomation in store
     */
    function viewRoundSlot(uint timeKey) external view returns(SlotInfoResult memory){
        RoundSlotInfo storage round = _getRoundSlotInfo(timeKey);
        address[] memory addrs = new address[](round.stakedAddressSet.length());
        for(uint256 ii=0;ii<round.stakedAddressSet.length();ii++){
            addrs[ii] = round.stakedAddressSet.at(ii);
        }
        return SlotInfoResult({
            rewardLastSubmiter:round.reward.lastSubmiter,
            rewardAmount:round.reward.amount,
            rewardAccumulateAmount:round.reward.accumulateAmount,
            totalStaked:round.totalStaked,
            stakedLowestWaterMark:round.stakedLowestWaterMark,
            totalStakedInSlot:round.totalStakedInSlot,
            stakedAddresses:addrs
        });
    }
    /**
     * @dev for lookup ming accounts
     */
    function viewMiningAccounts()external view returns(address[] memory){
        address[] memory addrs = new address[](totalUserMining());
        for(uint256 ii=0;ii<totalUserMining();ii++){
            addrs[ii] = getMiningAccountAt(ii);
        }
        return addrs;
    }
    /**
     * @dev for lookup ming accounts
     */
    function viewUserInfo(address account)external view returns(UserInfoResult memory){
        UserInfo storage user = _userInfo[account];
        StakeRecord[] memory stakeRecords = new StakeRecord[](user.stakedTimeIndex.length);
        for(uint256 ii=0;ii<user.stakedTimeIndex.length;ii++){
            StakeRecord memory r = user.stakeInfo[user.stakedTimeIndex[ii]];
            stakeRecords[ii] = r;
        }
        return UserInfoResult({
            amount:user.amount,
            lockedAmount:user.lockedAmount,
            lastUpdateRewardTime:user.lastUpdateRewardTime,
            allTimeMinedBalance:user.allTimeMinedBalance,
            rewardBalanceInpool:user.rewardBalanceInpool,
            stakeInfo:stakeRecords,
            stakedTimeIndex:user.stakedTimeIndex
        });
    }

    /**
     * @dev emergency withdraw reward tokens to owner's account if there is some unusual thing happend
     */
    function emergencyWithdrawReward(uint256 amount) external onlyOwner{
        uint256 bal =_rewardToken.balanceOf(address(this));
        require(bal>=amount,"withdraw amount exceeds the reward balance");
        _rewardToken.transfer(owner(),amount);
    }
    /**
     * @dev emergency withdraw hashrate tokens to owner's account if there is some unusual thing happend
     */
    function emergencyWithdrawSToken(uint256 amount) external onlyOwner{
        uint256 bal =_stoken.balanceOf(address(this));
        require(bal>=amount,"withdraw amount exceeds the reward balance");
        _stoken.transfer(owner(),amount);
    }
}