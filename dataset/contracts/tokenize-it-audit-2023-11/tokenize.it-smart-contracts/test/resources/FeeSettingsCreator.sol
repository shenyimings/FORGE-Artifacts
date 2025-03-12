// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../../lib/forge-std/src/Test.sol";
import "../../contracts/factories/FeeSettingsCloneFactory.sol";

function createFeeSettings(
    address _trustedForwarder,
    address _owner,
    Fees memory _fees,
    address _tokenFeeCollector,
    address _crowdinvestingFeeCollector,
    address _privateOfferFeeCollector
) returns (FeeSettings) {
    FeeSettings logicContract = new FeeSettings(_trustedForwarder);
    FeeSettingsCloneFactory factory = new FeeSettingsCloneFactory(address(logicContract));
    FeeSettings clone = FeeSettings(
        factory.createFeeSettingsClone(
            "someSalt",
            _trustedForwarder,
            _owner,
            _fees,
            _tokenFeeCollector,
            _crowdinvestingFeeCollector,
            _privateOfferFeeCollector
        )
    );

    return clone;
}
