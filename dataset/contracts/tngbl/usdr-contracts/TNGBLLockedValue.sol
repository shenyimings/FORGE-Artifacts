// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./AddressAccessor.sol";
import "./constants/addresses.sol";
import "./interfaces/IPriceOracle.sol";

contract TNGBLLockedValue is AddressAccessor {
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function getTngblLockedValue() external view returns (uint256 lockedValue) {
        (address tngblOracle, address tngbl, address piNFT) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(
                    TNGBL_ORACLE_ADDRESS,
                    TNGBL_ADDRESS,
                    TANGIBLE_PINFT_ADDRESS
                )
            ),
            (address, address, address)
        );
        uint256 TNGBL = 10**IERC20Metadata(tngbl).decimals();
        uint256 tngblPrice = IPriceOracle(tngblOracle).quote(TNGBL);
        lockedValue = (IERC20(tngbl).balanceOf(piNFT) * tngblPrice) / TNGBL;
    }
}
