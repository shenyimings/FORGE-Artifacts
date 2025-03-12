// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../../lib/forge-std/src/Test.sol";
import "../../contracts/Token.sol";
import "../../contracts/FeeSettings.sol";

/*
    fake crowdinvesting that allows polling fees
*/
contract FakeCrowdinvesting {
    Token public token;

    constructor(address _token) {
        token = Token(_token);
    }

    function fee(uint256 amount) public view returns (uint256) {
        IFeeSettingsV2 feeSettings = token.feeSettings();
        return feeSettings.crowdinvestingFee(amount, address(token));
    }

    function feeV1(uint256 amount) public view returns (uint256) {
        IFeeSettingsV1 feeSettings = IFeeSettingsV1(address(token.feeSettings()));
        return feeSettings.continuousFundraisingFee(amount);
    }
}

/**
 * fake token that allows polling fees
 */
contract FakeToken {
    IFeeSettingsV2 public feeSettings;

    constructor(address _feeSettings) {
        feeSettings = FeeSettings(_feeSettings);
    }

    function fee(uint256 amount) public view returns (uint256) {
        return feeSettings.tokenFee(amount, address(this));
    }
}
