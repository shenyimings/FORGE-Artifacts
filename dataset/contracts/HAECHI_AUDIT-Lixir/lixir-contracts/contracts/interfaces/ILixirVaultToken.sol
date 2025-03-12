pragma solidity ^0.7.0;

import 'contracts/interfaces/IERC20Permit.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface ILixirVaultToken is IERC20, IERC20Permit {}
