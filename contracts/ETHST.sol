// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

import "./StandardHashrateToken.sol";


contract ETHST is StandardHashrateToken{
    function initialize() public initializer{
        super.initialize("StandardETHHashrateToken","ETHST");
    }
}