// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;
pragma experimental ABIEncoderV2;

import "./3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "./MiningFarm.sol";
import "./libraries/TokenUtility.sol";
import "./FarmAllowLockedToken.sol";
import "./interfaces/IMiningFarm.sol";

contract FarmWithApi is FarmAllowLockedToken,IMiningFarm{
    using SafeMath for uint256;
    using TokenUtility for *;
    using EnumerableSet for EnumerableSet.AddressSet;
    constructor(StandardHashrateToken SToken,IERC20Upgradeable  rewardToken,string memory desc)
        FarmAllowLockedToken(SToken,rewardToken,86400,now,desc) public{   
    }
    /**
     * @dev for lookup slot infomation in store
     */
    function viewRoundSlot(uint timeKey) external override view returns(ISlotInfoResult memory){
        RoundSlotInfo storage round = _getRoundSlotInfo(timeKey);
        address[] memory addrs = new address[](round.stakedAddressSet.length());
        for(uint256 ii=0;ii<round.stakedAddressSet.length();ii++){
            addrs[ii] = round.stakedAddressSet.at(ii);
        }
        return ISlotInfoResult({
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
        uint256 total = totalUserMining();
        address[] memory addrs = new address[](total);
        for(uint256 ii=0;ii<total;ii++){
            addrs[ii] = getMiningAccountAt(ii);
        }
        return addrs;
    }
    /**
     * @dev for lookup ming accounts
     */
    function viewUserInfo(address account)external override view returns(IUserInfoResult memory){
        UserInfo storage user = _userInfo[account];
        IStakeRecord[] memory stakeRecords = new IStakeRecord[](user.stakedTimeIndex.length);
        for(uint256 ii=0;ii<user.stakedTimeIndex.length;ii++){
            StakeRecord memory r = user.stakeInfo[user.stakedTimeIndex[ii]];
            stakeRecords[ii].timeKey = r.timeKey;
            stakeRecords[ii].amount = r.amount;
            stakeRecords[ii].lockedAmount = r.lockedAmount;
            stakeRecords[ii].withdrawed = r.withdrawed;
            stakeRecords[ii].lockedWithdrawed = r.lockedWithdrawed;
        }
        return IUserInfoResult({
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

    function apiWithdrawAllSToken()external override{
        withdrawAllSToken();
    }
    function apiWithdrawAllLockedSToken()external override{
        withdrawAllLockedSToken();
    }
    function apiWithdrawLatestLockedSToken(uint256 amount)external override{
        withdrawLatestLockedSToken(amount);
    }

    function apiDepositToMining(uint256 amount)external override{
        depositToMining(amount);
    }
    function apiDepositLockedToMining(uint256 amount) external override{
        depositLockedToMining(amount);
    }

    function apiDepositRewardFromForTime(address account,uint256 amount,uint time) external override{
        depositRewardFromForTime(account,amount,time);
    }
    function apiDepositRewardFrom(address account,uint256 amount)external override{
        depositRewardFrom(account,amount);
    }
    function apiClaimAllReward(address account)external override{
        claimAllReward(account);
    }
    function apiClaimAmountOfReward(address account,uint256 amount,bool reCalculate)external override{
        claimAmountOfReward(account,amount,reCalculate);
    }
    
    function viewGetTotalRewardBalanceInPool(address account) external view override returns (uint256) {
        return getTotalRewardBalanceInPool(account);
    } 
    function viewMiningRewardIn(uint day)external view override returns (address,uint256,uint256) {
        return miningRewardIn(day);
    }

    function viewTotalStaked()external view override returns(uint256) {
        return totalStaked();
    }
    function viewTotalUserMining()external view override returns(uint256) {
        return totalUserMining();
    }
    function viewTotalMinedRewardFrom(address account)external view override returns(uint256) {
        return totalMinedRewardFrom(account);
    }
    function viewTotalRewardInPoolFrom(address account)external view override returns(uint256) {
        return totalRewardInPoolFrom(account);
    }
    function viewTotalRewardInPool()external view override returns(uint256) {
        return totalRewardInPool();
    }

    function viewStakeRecord(address account,uint day)external view override returns (uint,uint256,uint256,uint256,uint256) {
        return stakeRecord(account, day);
    }
}