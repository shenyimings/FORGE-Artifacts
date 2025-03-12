// SPDX-License-Identifier: MIT
pragma solidity >=0.7.2;

import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {
    ERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import {IRibbonFactory} from "../interfaces/IRibbonFactory.sol";

contract OptionsVaultStorageV0 {
    // Gap just in case we push storage in front of the OptionsVaultStorage contract
    uint256[50] private __gap;
}

contract OptionsVaultStorageV1 is
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    ERC20Upgradeable
{
    // Asset for which we create a covered call for
    address public asset;

    // Privileged role that is able to select the option terms (strike price, expiry) to short
    address public manager;

    // Option that the vault is shorting in the next cycle
    address public nextOption;

    // The timestamp when the `nextOption` can be used by the vault
    uint256 public nextOptionReadyAt;

    // Option that the vault is currently shorting
    address public currentOption;

    // Amount that is currently locked for selling options
    uint256 public lockedAmount;

    // Cap for total amount deposited into vault
    uint256 public cap;

    // Fee incurred when withdrawing out of the vault, in the units of 10**18
    // where 1 ether = 100%, so 0.005 means 0.005% fee
    uint256 public instantWithdrawalFee;

    // Recipient for withdrawal fees
    address public feeRecipient;
}

// We are following Compound's method of upgrading new contract implementations
// When we need to add new storage variables, we create a new version of OptionsVaultStorage
// e.g. OptionsVaultStorageV<versionNumber>, so finally it would look like
// contract OptionsVaultStorage is OptionsVaultStorageV1, OptionsVaultStorageV2
contract OptionsVaultStorage is OptionsVaultStorageV1 {

}
