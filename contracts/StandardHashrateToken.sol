// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

import "./libraries/LinearReleaseToken.sol";

contract StandardHashrateToken is LinearReleaseToken{
    using TokenUtility for *;
    function initialize(string memory name, string memory symbol) public override initializer{
        address owner = msg.sender;
        super.initialize(name,symbol,owner,25*7,25);
    }
    
    address public _farmContract;

    /**
     * @dev Modifier throws if called by any account other than the pendingOwner.
     */
    modifier onlyFarm() {
        require(msg.sender == _farmContract);
        _;
    }

    function changeFarmContract(address newFarm) public onlyOwner {
        require(newFarm!=address(0),"not allowed to change farm contract to address(0)");
        _farmContract = newFarm;
    }

    function transferLockedTo(address to,uint256 amount) public  override returns(uint[] memory,uint256[] memory) {
        require(to==_farmContract || msg.sender == _farmContract,"direct transfer locked amount only allowed to mining farm contract");
        return super.transferLockedTo(to,amount);
    }


    /**
     * @dev only farm contract can execute transfer locked tokens from farm
     * farm should cost it's origin locked records other than latest record
     * the records was stored in farm's contract, here is the parameter
     * tobeCostKeys array of freeTimeKey which used to be cost
     * tobeCost aligned with tobeCostKeys the tobeCost value
     */
    function transferLockedFromFarmWithRecord(address recipient,
        uint256 amount,uint[] memory tobeCostKeys,uint256[] memory tobeCost) public onlyFarm{
        require(linearLockedBalanceOf(_farmContract)>=amount,"transfer locked amount exceeds farm's locked amount");
        require(recipient != address(0), "Locked ERC20: transfer to the zero address");
        require(balanceOf(_farmContract)>=amount,"ERC20: transfer amount exceeds balance");

        // mapping (uint => uint256) storage records = _timeLockedBalanceRecords[_farmContract];
        mapping (uint => uint256) storage recordsCost = _timeLockedBalanceRecordsCost[_farmContract];
        
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

        _timeLockedBalances[_farmContract] = _timeLockedBalances[_farmContract].sub(amount, "Locked ERC20: transfer amount exceeds locked balance");
        _transferDirect(_farmContract,recipient,amount);
        _timeLockedBalances[recipient] = _timeLockedBalances[recipient].add(amount);

        emit LockedTransfer(_farmContract,recipient,amount);
    }

    /**
     * @dev cost amount of token among balanceFreeTime Keys indexed in records with recordCostRecords
     * return cost keys and cost values one to one 
     */
    // function calculateCostLocked(uint256 toCost,uint[] memory keys,
    //     mapping (uint => uint256) storage records,
    //     mapping (uint => uint256) storage recordsCost)public view returns(uint256,uint256[] memory){
    //     return records._costLocked(toCost, keys, recordsCost);
    // }
    
}