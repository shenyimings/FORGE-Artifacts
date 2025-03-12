// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "./ConfigurablePools.sol";

/**
 * @title RewardsVault
 * @author Aaron Hanson <coffee.becomes.code@gmail.com>
 */
abstract contract RewardsVault is ConfigurablePools {

    uint256 public vaultAvailableBalance;

    function donateToVault(
        uint256 _amount
    )
        external
    {
		uint256 walletBalance = LUFFY.balanceOf(_msgSender());
		require(
            walletBalance >= _amount,
            "Amount cannot be greater than balance"
        );
		if (_amount > walletBalance - 10**9) {
           _amount = walletBalance - 10**9;
        }
        vaultAvailableBalance += _amount;

        LUFFY.transferFrom(
            _msgSender(),
            address(this),
            _amount
        );
    }

    function withdrawFromVault(
        uint256 _amount
    )
        external
        onlyOwner
    {
        vaultAvailableBalance -= _amount;

        LUFFY.transfer(
            _msgSender(),
            _amount
        );
    }

}