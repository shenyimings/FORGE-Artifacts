// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IMDLP is IERC20{
    function deposit(uint256 _amount) external;

    function convertWithZapRadiant(address _for, uint256 _rdnt, uint8 _mode) external payable returns(uint256);

    function convertWithLp(address _for, uint256 _amount, uint8 _mode) external;
    
}
