pragma solidity >=0.4.22 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./libraries/LinearReleaseToken.sol";

contract StandardHashrateToken is LinearReleaseToken{

    function initialize(string memory name, string memory symbol) public override initializer{
        address owner = msg.sender;
        super.initialize(name,symbol,owner,25*7,25);
    }
    
}