// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

import "../3rdParty/@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

library TokenUtility{
    using SafeMathUpgradeable for uint256;
    /**
     * @dev cost already freed amount
     */
    // function calculateCostLockedAlreadyFreed(mapping (uint => uint256) storage records,uint256 _lockTime,uint256 _lockRounds,uint256 _lockTimeUnitPerSeconds,uint256 toCost,uint[] memory keys,mapping (uint => uint256) storage recordsCost) internal returns(uint256,uint256[] memory){
    //     uint256 allFreed = 0;
    //     uint256[] memory cost = new uint256[](keys.length);
    //     uint freeTime =0;
    //     uint256 lockedBal = 0;
    //     uint256 alreadyCost = 0;
    //     uint256 freeAmount = 0;
    //     uint256 roundPerDay = 0;
    //     uint start = 0;
    //     uint passed;
    //     uint passedRound;
    //     uint256 freeToMove;
    //     for (uint256 ii=0; ii < keys.length; ++ii){
    //         //_lockTimeUnitPerSeconds:days:25*7,rounds:25
    //         if (toCost==0){
    //             break;
    //         }
    //         freeTime = keys[ii];
    //         lockedBal = records[freeTime];
    //         alreadyCost = recordsCost[freeTime];
            
    //         freeAmount = 0;
    //         if (freeTime<=now){
    //             freeAmount = lockedBal;
    //         }else{
    //             //to calculate how much rounds still remain
    //             roundPerDay = _lockTime.div(_lockRounds);
    //             start = freeTime - _lockTime * _lockTimeUnitPerSeconds;
    //             passed = now - start;
    //             passedRound = passed.div(roundPerDay * _lockTimeUnitPerSeconds);
    //             freeAmount = lockedBal.mul(passedRound).div(_lockRounds);
    //         }
    //         freeToMove = freeAmount.sub(alreadyCost);
    //         allFreed = allFreed.add(freeToMove);
    //         if (freeToMove >= toCost){
    //             cost[ii] = toCost;
    //             toCost = 0;
    //         }else{
    //             cost[ii] = freeToMove;
    //             toCost = toCost.sub(freeToMove);
    //         }
    //     }
    //     return (allFreed,cost);
    // }

    /**
     * @dev cost amount of token among balanceFreeTime Keys indexed in records with recordCostRecords
     * return cost keys and cost values one to one 
     */
    function calculateCostLocked(mapping (uint => uint256) storage records,uint256 toCost,uint[] memory keys,mapping (uint => uint256) storage recordsCost)internal view returns(uint256,uint256[] memory){
        uint256 lockedFreeToMove = 0;
        uint256[] memory cost = new uint256[](keys.length);
        for (uint256 ii=0; ii < keys.length; ++ii){
            //_lockTimeUnitPerSeconds:days:25*7,rounds:25
            if (toCost==0){
                break;
            }
            uint freeTime = keys[ii];
            uint256 lockedBal = records[freeTime];
            uint256 alreadyCost = recordsCost[freeTime];
            
            uint256 lockedToMove = lockedBal.sub(alreadyCost);

            lockedFreeToMove = lockedFreeToMove.add(lockedToMove);
            if (lockedToMove >= toCost){
                cost[ii] = toCost;
                toCost = 0;
            }else{
                cost[ii] = lockedToMove;
                toCost = toCost.sub(lockedToMove);
            }
        }
        return (lockedFreeToMove,cost);
    }

    /**
     * @dev a method to get time-key from a time parameter
     * returns time-key and round
     */
    function getTimeKey(uint time,uint256 _farmStartedTime,uint256 _miniStakePeriodInSeconds)internal pure returns (uint){
        require(time>_farmStartedTime,"time should larger than all thing stated time");
        //get the end time of period
        uint round = time.sub(_farmStartedTime).div(_miniStakePeriodInSeconds);
        uint end = _farmStartedTime.add(round.mul(_miniStakePeriodInSeconds));
        if (end < time){
            return end.add(_miniStakePeriodInSeconds);
        }
        return end;
    }
}