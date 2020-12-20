// SPDX-License-Identifier: MIT
pragma solidity 0.6.9;

interface ISTokenERC20{
    // event Approval(address indexed owner, address indexed spender, uint value);
    // event Transfer(address indexed from, address indexed to, uint value);
    
    // function getOwner() external view returns (address);
    // function name() external view returns (string memory);
    // function symbol() external view returns (string memory);
    // function decimals() external view returns (uint8);
    // function totalSupply() external view returns (uint);
    // function balanceOf(address owner) external view returns (uint);
    // function allowance(address owner, address spender) external view returns (uint);

    // function approve(address spender, uint value) external returns (bool);
    // function transfer(address to, uint value) external returns (bool);
    // function transferFrom(address from, address to, uint value) external returns (bool);

    function linearLockedBalanceOf(address account) external view returns (uint256);
    function getFreeToTransferAmount(address account) external view returns (uint256);

    function totalSupplyReleaseByTimeLock() external view returns (uint256);
    function totalReleasedSupplyReleaseByTimeLock() external view returns (uint256);
    function getTotalRemainingSupplyLocked() external view returns (uint256);

    function transferLockedFrom(address from,address to,uint256 amount) external  returns(uint[] memory,uint256[] memory);   
    function approveLocked(address spender,uint256 amount) external returns(bool);
    function allowanceLocked(address owner, address spender) external view returns (uint256);

}