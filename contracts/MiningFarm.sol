// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "./3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./libraries/TokenUtility.sol";

import "./StandardHashrateToken.sol";
import "./BTCST.sol";

contract MiningFarm is Ownable{
    using SafeMath for uint256;
    using SafeMath for uint;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for StandardHashrateToken;
    using EnumerableSet for EnumerableSet.AddressSet;
    using TokenUtility for *;

    //a string to describe our mining farm
    string public _farmDescription;
    //stake this token to mine reward token
    StandardHashrateToken public _stoken;
    //which token to be mined by user's stake action
    IERC20Upgradeable public _rewardToken;
    //a timestamp in seconds used as our mining start base time
    uint public _farmStartedTime;
    // Dev address.
    address public _devaddr;
    
    // a full mining stake period of time in seconds unit
    // if one's stake time was less than this user won't get reward
    uint public _miniStakePeriodInSeconds;

    uint256 public _allTimeTotalMined;
    //total reward still in pool, not claimed
    uint256 public _totalRewardInPool;

    //mining record submit by admin or submiter
    struct MiningReward{
        address lastSubmiter;
        uint256 amount;//how much reward token deposit
        uint256 accumulateAmount;
    }

    //stake to mine record splited by time period
    struct StakeRecord{
        uint    timeKey;//when
        // address account;//which account
        uint256 amount;//how much amount SToken staked 
        uint256 lockedAmount;//how much locked amount SToken staked 
        
        uint256 withdrawed;//how much amount SToken withdrawed from this record
        uint256 lockedWithdrawed;//how much locked amount SToken withdrawed from this record
    }
    /**
    * @dev period denotes (period start time,period end time], 
    * we use period end time for time-key
    * period end time = period start time + _miniStakePeriodInSeconds
    * to store users' info
    * stored in address key-indexed
    */
    struct UserInfo {
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
        mapping(uint => StakeRecord) stakeInfo;
        //store time-key arrays for stakeInfo
        uint[] stakedTimeIndex;
    }
    /**
     * @dev slot stores info of each period's mining info
     */
    struct RoundSlotInfo{
        MiningReward reward;//reward info in this period
        uint256 totalStaked;//totalStaked = previous round's totalStaked + this Round's total staked 
        uint256 stakedLowestWaterMark;//lawest water mark for this slot
        
        uint256 totalStakedInSlot;//this Round's total staked
        //store addresses set which staked in this slot
        EnumerableSet.AddressSet stakedAddressSet;
    }
    

    //user's info
    mapping (address => UserInfo) public _userInfo;
    //reward records split recorded by round slots 
    //time-key => RoundSlotInfo
    mapping (uint=>RoundSlotInfo) private _roundSlots;
    //store time-key arrays for slots
    uint[] public _roundSlotsIndex;
    //account which is mining in this farm
    EnumerableSet.AddressSet private _miningAccountSet;
    

    event DepositReward(address user, uint256 amount,uint indexed time);
    event DepositToMining(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event Claim(address indexed user, uint256 amount);

    constructor(
        StandardHashrateToken SToken,
        IERC20Upgradeable rewardToken,
        uint256 miniStakePeriod,
        uint startTime,
        string memory desc,
        address devaddr
    )public {
        _stoken = SToken;
        _devaddr = devaddr;
        _rewardToken = rewardToken;
        require(miniStakePeriod>0,"mining period should >0");
        _miniStakePeriodInSeconds = miniStakePeriod;
        _farmDescription = desc;
        _farmStartedTime = startTime;
    }
    function changeBaseTime(uint time)public onlyOwner{
        require(time>0,"base time should >0");
        _farmStartedTime = time;
    }

    function changeMiniStakePeriodInSeconds(uint period) public onlyOwner{
        require(period>0,"mining period should >0");
        _miniStakePeriodInSeconds = period;
    }

    function changeRewardToken(IERC20Upgradeable rewardToken) public onlyOwner{
        _rewardToken = rewardToken;
    }
    function changeSToken(StandardHashrateToken stoken)public onlyOwner{
        _stoken =stoken;
    }
    /**
     * @dev return the staked total number of SToken
     */
    function totalStaked()public virtual view returns(uint256){
        uint256 amount = 0;
        uint256 len = _miningAccountSet.length();
        for (uint256 ii=0; ii<len ;++ii){
            address account = _miningAccountSet.at(ii);
            UserInfo memory user = _userInfo[account];
            amount = amount.add(user.amount);
        }
        return amount;
    }

    /**
     * @dev return how many user is mining
     */
    function totalUserMining()public view returns(uint256){
        return _miningAccountSet.length();
    }

    /**
     * @dev return hown much already mined from account 
     */
    function totalMinedRewardFrom(address account)public view returns(uint256){
        UserInfo memory user = _userInfo[account];
        return user.allTimeMinedBalance;
    }


    /**
     * @dev return hown much already mined from account without widthdraw
     */
    function totalRewardInPoolFrom(address account)public view returns(uint256){
        UserInfo memory user = _userInfo[account];
        return user.rewardBalanceInpool;
    }

    /**
     * @dev return hown much reward tokens in mining pool
     */
    function totalRewardInPool()public view returns(uint256){
        return _totalRewardInPool;
    }
    /**
     * @dev return the mining records of specific day
     */
    function miningRewardIn(uint day)public view returns (address,uint256,uint256){
        uint key = day.getTimeKey(_farmStartedTime,_miniStakePeriodInSeconds);
        RoundSlotInfo memory slot = _roundSlots[key];
        return (slot.reward.lastSubmiter,slot.reward.amount,slot.reward.accumulateAmount);
    }

    /**
     * @dev return the stake records of specific day
     */
    function stakeRecord(address account,uint day)public view returns (uint,uint256,uint256,uint256,uint256) {
        uint key = day.getTimeKey(_farmStartedTime,_miniStakePeriodInSeconds);
        UserInfo storage user = _userInfo[account];
        StakeRecord storage record = user.stakeInfo[key];
        return (record.timeKey,record.amount,record.lockedAmount,record.withdrawed,record.lockedWithdrawed);
    }
    function getRewardBalanceInPoolBefore(address account,uint before) public view returns(uint256){
        UserInfo storage user = _userInfo[account];
        uint lastUpdate = user.lastUpdateRewardTime;
        uint256 minedTotal = 0;
        if (user.stakedTimeIndex.length>0){
            for (uint256 xx=0;xx<user.stakedTimeIndex.length;xx++){
                uint time = user.stakedTimeIndex[xx];
                if (time<=before){
                    StakeRecord memory record = user.stakeInfo[time];
                    uint256 mined = _calculateMinedRewardDuringFor(record,lastUpdate,before);
                    minedTotal = minedTotal.add(mined);
                }
            }   
        }
        return minedTotal;
    }
    function getTotalRewardBalanceInPool(address account) public returns (uint256){
        uint alreadyMinedTimeKey = _getMaxAlreadyMinedTimeKey(); 
        UserInfo memory user = _userInfo[account];
        uint256 old = user.rewardBalanceInpool;
        uint256 mined = getRewardBalanceInPoolBefore(account,alreadyMinedTimeKey);
        return old.add(mined);
    }


    function _getRoundSlotInfo(uint timeKey)internal view returns(RoundSlotInfo storage){
        return _roundSlots[timeKey];
    }
    function _safeTokenTransfer(address to,uint256 amount,IERC20Upgradeable token) internal{
        uint256 bal = token.balanceOf(address(this));
        if (amount > bal){
            token.transfer(to,bal);
        }else{
            token.transfer(to,amount);
        }
    }
    function _addMingAccount(address account)internal{
        _miningAccountSet.add(account);
    }
    function _getMingAccount() internal view returns (EnumerableSet.AddressSet memory){
        return _miningAccountSet;
    }
    function getMiningAccountAt(uint256 ii)internal view returns (address){
        return _miningAccountSet.at(ii);
    }
    function _updateIndexAfterDeposit(address account,uint key,uint256 amount)internal {
        UserInfo storage user = _userInfo[account];
        //update round slot
        RoundSlotInfo storage slot = _roundSlots[key];
        //update indexes
        uint maxLast = 0;
        if (user.stakedTimeIndex.length>0){
            maxLast = user.stakedTimeIndex[user.stakedTimeIndex.length-1];
        }
        slot.totalStakedInSlot = slot.totalStakedInSlot.add(amount);
        if (maxLast<key){
            //first time to stake in this slot
            slot.stakedAddressSet.add(account);
            user.stakedTimeIndex.push(key);   
        }

        _initOrUpdateLowestWaterMarkAndTotalStaked(key,amount);
    }
    function _getMaxAlreadyMinedTimeKey() internal view returns (uint){
        uint key = now.getTimeKey(_farmStartedTime,_miniStakePeriodInSeconds);
        return key.sub(_miniStakePeriodInSeconds*2);
    }
    /**
     * @dev denote how to calculate the user's remain staked amount for stake record
     */
    function _getRecordStaked(StakeRecord memory record)internal pure virtual returns(uint256){
        return record.amount.sub(record.withdrawed,"withdrawed>amount");
    }
    /**
     * @dev calculate mined reward during after and before time, from the stake record
     * (after,before]
     */
    function _calculateMinedRewardDuringFor(StakeRecord memory record,
        uint afterTime,uint beforeTime)internal virtual view returns(uint256){
        uint256 remainStaked = _getRecordStaked(record);
        
        if (remainStaked<=0){
            return 0;          
        }
        uint256 mined = 0;
        for (uint256 ii=_roundSlotsIndex.length;ii>0;ii--){
            uint key = _roundSlotsIndex[ii-1];
            if (key<=beforeTime && key>afterTime && key>=record.timeKey){
                //calculate this period of mining reward
                RoundSlotInfo memory slot = _roundSlots[key];
                if (slot.reward.amount>0){
                    if (slot.stakedLowestWaterMark!=0){
                        mined = mined.add(
                            slot.reward.amount.mul(remainStaked)
                            .div(slot.stakedLowestWaterMark));
                    }
                }
            }
            if (key<=afterTime){
                break;
            }
        }
        return mined;
    }
    /**
     * @dev deposit STokens to mine reward tokens
     */
    function depositToMine(uint256 amount)public {
        require(amount>0,"deposit number should greater than 0");
        address account = address(msg.sender);
        //first try to transfer amount from sender to this contract
        _stoken.safeTransferFrom(account,address(this),amount);
        
        //if successed let's update the status
        _miningAccountSet.add(account);
        uint key = now.getTimeKey(_farmStartedTime,_miniStakePeriodInSeconds);
        UserInfo storage user = _userInfo[account];
        StakeRecord storage record = user.stakeInfo[key];
        //update user's record
        record.amount = record.amount.add(amount);
        record.timeKey = key;
        //update staked amount of this user
        user.amount = user.amount.add(amount);
        
        _updateIndexAfterDeposit(account, key, amount);

        emit DepositToMining(msg.sender,amount);
    }

    /**
     * @dev deposit reward token from account to last period
     */
    function depositRewardFrom(address account,uint256 amount)public{
        //deliver reward to 2 rounds agao's stake slot
        //time.getTimeKey(_farmStartedTime,_miniStakePeriodInSeconds);
        uint time= now.sub(_miniStakePeriodInSeconds*2);
        uint key = time.getTimeKey(_farmStartedTime,_miniStakePeriodInSeconds);
        depositRewardFromForTime(account,amount,key);
    }

    function depositRewardFromForTime(address account,uint256 amount,uint time) public{
        require(amount>0,"deposit number should greater than 0");
        _rewardToken.safeTransferFrom(account,address(this),amount);
        uint timeKey= time.getTimeKey(_farmStartedTime,_miniStakePeriodInSeconds);
        RoundSlotInfo storage slot = _roundSlots[timeKey];
        
        _initOrUpdateLowestWaterMarkAndTotalStaked(timeKey,0);

        uint256 accumulate = 0;
        uint256 slotIndex = 0;
        for (uint256 ii=_roundSlotsIndex.length;ii>0;ii--){
            uint key = _roundSlotsIndex[ii-1];
            if (key == timeKey){
                slotIndex == ii-1;
            }
            RoundSlotInfo storage previous = _roundSlots[key];
            if (previous.reward.accumulateAmount>0){
                accumulate = previous.reward.accumulateAmount;
                break;
            }
        }
        slot.reward.amount = slot.reward.amount.add(amount);
        slot.reward.lastSubmiter = account;
        //update all accumulateamount from our slot to the latest one
        for (uint256 ii=slotIndex;ii<_roundSlotsIndex.length;ii++){
            uint key = _roundSlotsIndex[ii];
            RoundSlotInfo storage update = _roundSlots[key];
            update.reward.accumulateAmount = update.reward.accumulateAmount.add(amount);
        }

        _allTimeTotalMined = _allTimeTotalMined.add(amount);
        _totalRewardInPool = _totalRewardInPool.add(amount);

        emit DepositReward(account,amount,timeKey);
    }

    /**
     * @dev exit mining by withdraw all STokens
     */
    function withdrawAllSToken()public virtual{
        address account = address(msg.sender);
        UserInfo storage user = _userInfo[account];
        withdrawLatestSToken(user.amount);
    }


    /**
     * @dev exit mining by withdraw a part of STokens
     */
    function withdrawLatestSToken(uint256 amount)public{
        address account = address(msg.sender);
        UserInfo storage user = _userInfo[account];
        require(amount > 0,"you can't withdraw 0 amount");
        require(user.amount>=amount,"you can't withdraw amount larger than you have deposit");
        uint256 ii = user.stakedTimeIndex.length;
        require(ii>0,"no deposit record found");
        //we can't change the status for calculating reward before 2 rounds agao
        //because the user already staked full for mining 2 rounds agao
        uint alreadyMinedTimeKey = _getMaxAlreadyMinedTimeKey(); 
        uint currentKey = now.getTimeKey(_farmStartedTime,_miniStakePeriodInSeconds);
        uint256 needCost = amount;
        bool updateReward = false;
        bool[] memory toDelete = new bool[](ii);
        _initOrUpdateLowestWaterMarkAndTotalStaked(currentKey,0);
        RoundSlotInfo storage currentSlot = _roundSlots[currentKey];
        uint256 update = 0;
        for (ii;ii>0;ii--){
            if (needCost == 0){
                break;
            }
            uint timeKey = user.stakedTimeIndex[ii-1];
            if (timeKey <= alreadyMinedTimeKey && !updateReward){
                //need to update mined token balance first,only run this once
                updateAlreadyMinedReward(account,alreadyMinedTimeKey);
                updateReward = true;
            }
            StakeRecord storage record = user.stakeInfo[timeKey];
            RoundSlotInfo storage slot = _roundSlots[timeKey];
            update = record.amount.sub(record.withdrawed,"withdrawed>amount");
            if (needCost<=update){
                record.withdrawed = record.withdrawed.add(needCost);
                update = needCost;
                needCost = 0;
            }else{
                needCost = needCost.sub(update,"update>needCost");
                //withdrawed all of this record
                record.withdrawed = record.amount;
                //record maybe can be delete, withdrawed all
                if (_getRecordStaked(record)==0){
                    delete user.stakeInfo[timeKey];
                    toDelete[ii-1]=true;
                }
            }
            if (timeKey > alreadyMinedTimeKey){
                slot.totalStakedInSlot = slot.totalStakedInSlot.sub(update,"update>totalStakedInSlot");
                slot.totalStaked = slot.totalStaked.sub(amount,"amount>totalStaked");
            }
            if (update>0 && timeKey<currentKey){
                if (update<=currentSlot.stakedLowestWaterMark){
                    currentSlot.stakedLowestWaterMark = currentSlot.stakedLowestWaterMark.sub(update);
                }else{
                    currentSlot.stakedLowestWaterMark = 0;
                }
                
            }
        }

        for(uint256 xx=0;xx<toDelete.length;xx++){
            bool del = toDelete[xx];
            if (del){
                delete user.stakedTimeIndex[xx];
            }
        }
        _safeTokenTransfer(account,amount,_stoken);
        user.amount = user.amount.sub(amount,"amount>user.amount");
        emit Withdraw(account,amount); 
    }

    function _initOrUpdateLowestWaterMarkAndTotalStaked(uint nextKey,uint256 amount)internal{
        uint slotMaxLast = 0;
        RoundSlotInfo storage slot = _roundSlots[nextKey];
        if (_roundSlotsIndex.length>0){
            slotMaxLast = _roundSlotsIndex[_roundSlotsIndex.length-1];
        }
        if (slotMaxLast<nextKey){
            _roundSlotsIndex.push(nextKey);
            if (slotMaxLast!=0){
                //we have previous ones
                RoundSlotInfo storage previouSlot = _roundSlots[slotMaxLast];
                slot.totalStaked = previouSlot.totalStaked.add(amount);
                //firsttime init stakedLowestWaterMark
                slot.stakedLowestWaterMark = previouSlot.totalStaked;
            }else{
                //have no previous one
                slot.totalStaked = slot.totalStaked.add(amount);
                slot.stakedLowestWaterMark = 0;
            }
        }else{
            slot.totalStaked = slot.totalStaked.add(amount);
        }
    }

    function getAndUpdateRewardMinedInPool(address account) public returns (uint256){
        uint alreadyMinedTimeKey = _getMaxAlreadyMinedTimeKey(); 
        updateAlreadyMinedReward(account,alreadyMinedTimeKey);
        UserInfo storage user = _userInfo[account];
        return user.rewardBalanceInpool;
    }

    function updateAlreadyMinedReward(address account,uint before) public{
        uint256 minedTotal = getRewardBalanceInPoolBefore(account,before);
        UserInfo storage user = _userInfo[account];
        user.rewardBalanceInpool = user.rewardBalanceInpool.add(minedTotal);
        user.allTimeMinedBalance = user.allTimeMinedBalance.add(minedTotal);
        user.lastUpdateRewardTime = before;
    }


    /**
     * @dev claim all reward tokens
     */
    function claimAllReward(address account)public{
        uint256 totalMined = getAndUpdateRewardMinedInPool(account);
        claimAmountOfReward(account,totalMined,false);
    }

    /**
     * @dev claim amount of reward tokens
     */
    function claimAmountOfReward(address account,uint256 amount,bool reCalculate)public{
        if (reCalculate){
            getAndUpdateRewardMinedInPool(account);
        }
        UserInfo storage user = _userInfo[account];
        require(user.rewardBalanceInpool>=amount,"claim amount should not greater than total mined");

        user.rewardBalanceInpool = user.rewardBalanceInpool.sub(amount,"amount>rewardBalanceInpool");
        _safeTokenTransfer(account,amount,_rewardToken);
        _totalRewardInPool = _totalRewardInPool.sub(amount,"amount>_totalRewardInPool");
        emit Claim(account,amount);
    }

/**

    function depositBonusFrom(address account,
        uint256 amount,IERC20 token,
        uint256 startTime,uint256 periodRound)public{
        token.safeTransferFrom(account,address(this),amount);

    }   
 */    
}