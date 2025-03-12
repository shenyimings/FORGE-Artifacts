// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;

import "@kyber.network/utils-sc/contracts/Withdrawable.sol";
import "@kyber.network/utils-sc/contracts/IERC20Ext.sol";

contract FetchTokenBalances is Withdrawable {
    constructor(address _admin) Withdrawable(_admin) {}

    IERC20Ext internal constant NATIVE_TOKEN_ADDRESS =
        IERC20Ext(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    function getBalances(address account, IERC20Ext[] calldata tokens)
        external
        view
        returns (uint256[] memory balances)
    {
        balances = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == NATIVE_TOKEN_ADDRESS) {
                balances[i] = account.balance;
            } else {
                try tokens[i].balanceOf(account) returns (uint256 bal) {
                    balances[i] = bal;
                } catch {}
            }
        }
    }
}
