// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';

/**
 * @title TestAggregateAccount99
 */
contract TestAggregateAccount99 is Initializable, OwnableUpgradeable {
    /// @notice name of the account. E.g BTC for aggregate account containing zBTC, BTC.e, ETH etc.
    string public accountName;

    /// @notice true if the assets represented by the aggregate are stablecoins
    /// @dev will be needed for interpool swapping
    bool public isStable;

    /**
     * @notice Initializer.
     * @param accountName_ The name of the aggregate account
     * @param isStable_ Tells if this aggregate holds stable assets or not
     */
    function initialize(string memory accountName_, bool isStable_) external initializer {
        require(bytes(accountName_).length > 0, 'PLT:ACCOUNT_NAME_VOID');

        __Ownable_init();

        accountName = accountName_;
        isStable = isStable_;
    }

    /**
     * @notice Changes Account Name. Can only be set by the contract owner.
     * @param accountName_ the new name
     */
    function setAccountName(string memory accountName_) external onlyOwner {
        require(bytes(accountName_).length > 0, 'Platypus: Aggregate account name cannot be zero');
        accountName = accountName_;
    }

    function version() external pure returns (uint256) {
        return 99;
    }
}
