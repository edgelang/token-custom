pragma solidity >=0.4.22 <0.8.0;

import "./StandardHashrateToken.sol";


contract BTCST is StandardHashrateToken{
    function initialize() public initializer{
        super.initialize("StandardBTCHashrateToken","BTCST");
    }
}