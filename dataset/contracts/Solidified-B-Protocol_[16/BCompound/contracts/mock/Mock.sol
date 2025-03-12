pragma solidity 0.5.16;

/**
 * @notice This mock contract is just to include the external thirdparty contracts
 * that we are using in our TypeChain tests. The below includes enable Hardhat
 * to generate TypeChain Types for the below contracts.
 */
import { Comp } from "../../compound-protocol/contracts/Governance/Comp.sol";
import { Comptroller } from "../../compound-protocol/contracts/Comptroller.sol";
import { CEther } from "../../compound-protocol/contracts/CEther.sol";
import { CErc20 } from "../../compound-protocol/contracts/CErc20.sol";

// OpenZeppelin
import { ERC20Detailed } from "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";