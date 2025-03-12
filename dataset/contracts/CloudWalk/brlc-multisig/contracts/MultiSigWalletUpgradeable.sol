// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { MultiSigWalletBase } from "./base/MultiSigWalletBase.sol";

/**
 * @title MultiSigWalletUpgradeable contract
 * @author CloudWalk Inc.
 * @dev The implementation of the upgradeable multi-signature wallet contract.
 */
contract MultiSigWalletUpgradeable is Initializable, MultiSigWalletBase {
    /**
     * @dev Constructor that prohibits the initialization of the implementation of the upgradable contract.
     *
     * See details
     * https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable#initializing_the_implementation_contract
     *
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev The initializer of the upgradable contract.
     *
     * See details https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable
     *
     * Requirements:
     *
     * - The array of wallet owners must not be empty.
     * - The number of required approvals must not be zero and must not exceed the length of the wallet owners array.
     *
     * @param newOwners An array of wallet owners.
     * @param newRequiredApprovals The number of required approvals to execute a transaction.
     */
    function initialize(address[] memory newOwners, uint16 newRequiredApprovals) external initializer {
        __Multisig_init(newOwners, newRequiredApprovals);
    }

    /**
     * @dev The internal initializer of the upgradable contract.
     *
     * See {MultiSigWalletUpgradeable-initialize}.
     */
    function __Multisig_init(address[] memory newOwners, uint16 newRequiredApprovals) internal onlyInitializing {
        __Multisig_init_unchained(newOwners, newRequiredApprovals);
    }

    /**
     * @dev The unchained internal initializer of the upgradable contract.
     *
     * See {MultiSigWalletUpgradeable-initialize}.
     */
    function __Multisig_init_unchained(address[] memory newOwners, uint16 newRequiredApprovals)
        internal
        onlyInitializing
    {
        _configureExpirationTime(365 days);
        _configureOwners(newOwners, newRequiredApprovals);
    }
}
