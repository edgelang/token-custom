// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;


import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";

contract MockERC20 is ERC20PresetMinterPauser{
    constructor (
        string memory name,
        string memory symbol,
        uint256 supply
    ) public ERC20PresetMinterPauser(name,symbol){
        _mint(msg.sender,supply);
    }
}