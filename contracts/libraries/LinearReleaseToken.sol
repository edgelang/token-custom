pragma solidity >=0.4.22 <0.8.0;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./PeggyToken.sol";

contract LinearReleaseToken is PeggyToken,ReentrancyGuardUpgradeable{
    using SafeMathUpgradeable for uint256;
    
    /**
     * @dev how many days inall for linear time release minted tokens to unlock
     *
     */
    uint256 public _lockDays;
    /**
     * @dev during how many rounds, the token owner's token could be released
     */
    uint256 public _lockRounds;

    /**
     * @dev statistic data total supply which was mint by time lock
     */
    uint256 private _totalSupplyReleaseByTimeLock;

    /**
     * @dev statistic data released total supply which was mint by time lock already
     */
    uint256 private _totalReleasedSupplyReleaseByTimeLock;
    
    /**
     * @dev store user's time locked balance number
     *
     */
    mapping (address => uint256) private _timeLockedBalances;
    /**
     * @dev store each users' time locked balance records by mint
     * the second array time is when this records' balance could be all freed
     */
    mapping (address => mapping (uint => uint256)) private _timeLockedBalanceRecords;

    /**
     * @dev store each users' time locked balance records by mint which was already cost and the cost sum
     * the second array time is when this records' balance could be all freed
     */
    mapping (address => mapping (uint => uint256)) private _timeLockedBalanceRecordsCost;


    /**
     * @dev store user's balance locked records keys which is when to free all of user's balance
     *
     */
    mapping (address => uint[]) private _balanceFreeTimeKeys;

    /**
     * @dev sets 0 initials tokens, the owner, and the supplyController.
     * this serves as the constructor for the proxy but compiles to the
     * memory model of the Implementation contract.
     */
    function initialize(string memory name, string memory symbol, address owner,uint256 lockDays,uint256 lockRounds) public virtual initializer {
        require(lockRounds > 0,"Lock Rounds should greater than 0");
        super.initialize(name,symbol,owner);
        _lockDays = lockDays;
        _lockRounds = lockRounds;

    }

    function mintWithTimeLock(address account, uint256 amount) public virtual onlyOwner{
        require(hasRole(MINTER_ROLE, _msgSender()), "LinearReleaseToken: must have minter role to mint");
        require(account != address(0), "ERC20: mint to the zero address");
        if (_lockDays>0){
            uint freeTime = now + _lockDays * 1 days;
            uint[] memory arr = _balanceFreeTimeKeys[account];
            if (arr.length >0 ){
                uint max = arr[arr.length-1];
                if (freeTime <= max){
                    freeTime = max.add(1);
                }
            }
            _balanceFreeTimeKeys[account].push(freeTime);
            _timeLockedBalanceRecords[account][freeTime].add(amount);
            _timeLockedBalances[account].add(amount);  
            _totalSupplyReleaseByTimeLock.add(amount);  
        }
        super.mint(account,amount);
    }

    /**
     * @dev return how much free tokens the address could be used
     */
    function getFreeToTransferAmount(address account) public view returns (uint256){
        uint256 balance = balanceOf(account);
        uint256 lockedBalance = _timeLockedBalances[account];
        if (lockedBalance == 0){
            return balance;
        }

        uint[] memory keys = _balanceFreeTimeKeys[account];
        uint256 allFreed = 0;
        mapping (uint => uint256) storage records = _timeLockedBalanceRecords[account];
        mapping (uint => uint256) storage recordsCost = _timeLockedBalanceRecordsCost[account];
        for (uint256 ii=0; ii < keys.length; ++ii){
            //days:25*7,rounds:25
            uint freeTime = keys[ii];
            uint256 lockedBal = records[freeTime];
            uint256 alreadyCost = recordsCost[freeTime];
            uint256 freeAmount = 0;
            if (freeTime<=now){
                freeAmount = lockedBal;
            }else{
                //to calculate how much rounds still remain
                uint256 roundPerDay = _lockDays.div(_lockRounds);
                uint start = freeTime - _lockDays * 1 days;
                uint passed = now - start;
                uint passedRound = passed.div(roundPerDay * 1 days);
                freeAmount = lockedBal.mul(passedRound).div(_lockRounds);
            }
            allFreed.add(freeAmount.sub(alreadyCost));
        }
        if (allFreed < lockedBalance){
            return balance.sub(lockedBalance).add(allFreed);
        }
        return balance;
    }

    /**
     * @dev total supply which was minted by time lock
     */
    function totalSupplyReleaseByTimeLock() public view returns (uint256) {
        return _totalSupplyReleaseByTimeLock;
    }

    /**
     * @dev total supply which was already released to circulation from locked supply
     */
    function totalReleasedSupplyReleaseByTimeLock() public view returns (uint256) {
        return _totalReleasedSupplyReleaseByTimeLock;
    }

    /**
     * @dev total remaining locked supply tokens
     */
    function getTotalRemainingSupplyLocked() public view returns (uint256) {
        return _totalSupplyReleaseByTimeLock.sub(_totalReleasedSupplyReleaseByTimeLock);
    }

    function changeLockDays(uint256 nLockDays) public onlyOwner{
        _lockDays = nLockDays;
    }

    function changeLockRounds(uint256 nLockRounds) public onlyOwner{
        require(nLockRounds > 0,"Lock Rounds should greater than 0");
        _lockRounds = nLockRounds;
    }

    /**
     * @dev check about the time release locked balance
     *
     */
    function _beforeTokenTransfer(address account, address to, uint256 amount) internal virtual override(PeggyToken) nonReentrant { 
        super._beforeTokenTransfer(account, to, amount);
        //pass check by mint process
        if(account == address(0)){
            return;
        }
        uint256 balance = balanceOf(account);
        uint256 lockedBalance = _timeLockedBalances[account];
        if (lockedBalance == 0 || amount > balance){
            //no locked balance or amount greater than whole balance pass check
            return;
        }
        uint256 totalFree = balance.sub(lockedBalance);
        if (amount <= totalFree){
            //amount less than pure unlocked balance
            return;
        }

        //following step indicates that user want to send part of locked balances which was already unlocked during passed time
        //remain should be no greater than freed amounts
        uint256 remain = amount.sub(totalFree);

        uint[] memory keys = _balanceFreeTimeKeys[account];
        uint256 allFreed = 0;
        uint[] memory cost = new uint[](keys.length);

        uint256 toCost = remain;
        mapping (uint => uint256) storage records = _timeLockedBalanceRecords[account];
        mapping (uint => uint256) storage recordsCost = _timeLockedBalanceRecordsCost[account];

        for (uint256 ii=0; ii < keys.length; ++ii){
            //days:25*7,rounds:25
            if (toCost==0){
                break;
            }
            uint freeTime = keys[ii];
            uint256 lockedBal = records[freeTime];
            uint256 alreadyCost = recordsCost[freeTime];
            
            uint256 freeAmount = 0;
            if (freeTime<=now){
                freeAmount = lockedBal;
            }else{
                //to calculate how much rounds still remain
                uint256 roundPerDay = _lockDays.div(_lockRounds);
                uint start = freeTime - _lockDays * 1 days;
                uint passed = now - start;
                uint passedRound = passed.div(roundPerDay * 1 days);
                freeAmount = lockedBal.mul(passedRound).div(_lockRounds);
            }
            uint256 freeToMove = freeAmount.sub(alreadyCost);
            allFreed.add(freeToMove);
            if (freeToMove >= toCost){
                cost[ii] = toCost;
                toCost = 0;
            }else{
                cost[ii] = freeToMove;
                toCost = toCost.sub(freeToMove);
            }

        }
        require(remain <= allFreed,"user has locked amount,sending amounts exceeds the free amounts");
        //passed lock amount striction check,need to update cost,if not passed, we shouldn;t update the cost array

        for (uint256 ii=0; ii < keys.length; ++ii){
            uint freeTime = keys[ii];
            uint256 moreCost = cost[ii];
            uint256 alreadyCost = recordsCost[freeTime];
            recordsCost[freeTime] = alreadyCost.add(moreCost);
        }

        _timeLockedBalances[account] = lockedBalance.sub(remain);
        _totalReleasedSupplyReleaseByTimeLock = _totalReleasedSupplyReleaseByTimeLock.add(remain);

        
    }

    /**
     * @dev clear our expired and used out mint records to decrease everytime gas consumption when we are sending coins
     *
     */
    function decreaseGasConsumptionByClearExpiredRecords(address account) public nonReentrant returns (uint256){
        uint[] memory keys = _balanceFreeTimeKeys[account];
        uint[] memory toBeClear = new uint[](keys.length);
        uint256 cleared = 0;
        mapping (uint => uint256) storage records = _timeLockedBalanceRecords[account];
        mapping (uint => uint256) storage recordsCost = _timeLockedBalanceRecordsCost[account];
        for (uint256 ii=0; ii < keys.length; ++ii){
            uint freeTime = keys[ii];
            uint256 lockedBal = records[freeTime];
            uint256 alreadyCost = recordsCost[freeTime];
            if (lockedBal == alreadyCost){
                //this minted coins were all cost, so we can remove this record
                toBeClear[ii] = 2;
                delete records[freeTime];
                delete recordsCost[freeTime];
                cleared = cleared.add(1);
            }
        }
        for (uint256 ii=0; ii < keys.length; ++ii){
            uint shouldClear = toBeClear[ii];
            if (shouldClear>1){
                delete _balanceFreeTimeKeys[account][ii];
            }
        }
        return cleared;
    }
}