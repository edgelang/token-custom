// SPDX-License-Identifier: MIT
pragma solidity 0.6.9;

import "./3rdParty/@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "./libraries/LinearReleaseToken.sol";
import "./libraries/IFarm.sol";

contract StandardHashrateToken is LinearReleaseToken{
    using SafeMathUpgradeable for uint256;
    using TokenUtility for *;
    function initialize(string memory name, string memory symbol) public override initializer{
        address owner = msg.sender;
        //初始化 代币线性释放，总共 25 * 7 days ， 25轮
        super.initialize(name,symbol,owner,25*7,25);
    }

    //staking合约
    IFarm public _farmContract;

    /**
     * @dev Modifier throws if called by any account other than the pendingOwner.
     */

    //仅仅允许staking合约地址
    modifier onlyFarm() {
        address farm = address(_farmContract);
        require(msg.sender == farm);
        _;
    }

    //改变staking合约地址
    function changeFarmContract(IFarm newFarm) public onlyOwner {
        require(address(newFarm)!=address(0),"not allowed to change farm contract to address(0)");
        _farmContract = newFarm;
    }

    //转账锁定余额（仅限to地址是staking地址或者交易发起人是staking地址）
    function transferLockedTo(address to,uint256 amount) public  override returns(uint[] memory,uint256[] memory) {
        address farm = address(_farmContract);
        require(to==farm || msg.sender == farm,"direct transfer locked amount only allowed to mining farm contract");
        return super.transferLockedTo(to,amount);
    }


    /**
     * @dev only farm contract can execute transfer locked tokens from farm
     * farm should cost it's origin locked records other than latest record
     * the records was stored in farm's contract, here is the parameter
     * tobeCostKeys array of freeTimeKey which used to be cost
     * tobeCost aligned with tobeCostKeys the tobeCost value
     */
    //staking地址根据记录转账锁定金额（仅限staking地址）
    function transferLockedFromFarmWithRecord(address recipient,
        uint256 amount,uint[] memory tobeCostKeys,uint256[] memory tobeCost) public onlyFarm{
        address farm = address(_farmContract);
        require(_linearLockedBalanceOf(farm)>=amount,"transfer locked amount exceeds farm's locked amount");
        require(recipient != address(0), "Locked ERC20: transfer to the zero address");
        require(balanceOf(farm)>=amount,"farm locked ERC20: transfer amount exceeds balance 3");

        // mapping (uint => uint256) storage records = _timeLockedBalanceRecords[farm];
        mapping (uint => uint256) storage recordsCost = _timeLockedBalanceRecordsCost[farm];
        
        mapping (uint => uint256) storage rcpRecords = _timeLockedBalanceRecords[recipient];
        uint[] memory index = new uint[](tobeCostKeys.length);
        for (uint256 ii=0; ii < tobeCostKeys.length; ++ii){
            uint freeTime = tobeCostKeys[ii];
            index[ii] = freeTime;
            uint256 moreCost = tobeCost[ii];

            //update sender's locked recordsCost
            recordsCost[freeTime] = recordsCost[freeTime].add(moreCost);
            //update recipient's locked records
            rcpRecords[freeTime] = rcpRecords[freeTime].add(moreCost);
        }

        _timeLockedBalances[farm] = _timeLockedBalances[farm].sub(amount, "Locked ERC20: transfer amount exceeds locked balance");
        _transferDirect(farm,recipient,amount);
        _timeLockedBalances[recipient] = _timeLockedBalances[recipient].add(amount);

        emit LockedTransfer(farm,recipient,amount);
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    //重写ERC-20的transfer
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        if (recipient!=address(_farmContract) || address(_farmContract)==address(0) ){
            _transfer(_msgSender(), recipient, amount);
            return true;
        }
        _approve(_msgSender(), recipient, amount);
        _farmContract.depositToMiningBySTokenTransfer(_msgSender(),amount);
        return true;
    }
    
}