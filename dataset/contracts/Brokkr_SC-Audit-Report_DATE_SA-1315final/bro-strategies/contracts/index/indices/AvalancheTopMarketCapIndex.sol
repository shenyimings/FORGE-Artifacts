// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { IndexAvalanche } from "../bases/IndexAvalanche.sol";
import { IChainlinkAggregatorV3 } from "../dependencies/IChainlinkAggregatorV3.sol";
import { Constants } from "../libraries/Constants.sol";
import { Errors } from "../libraries/Errors.sol";
import { SwapAdapter } from "../libraries/SwapAdapter.sol";

contract AvalancheTopMarketCapIndex is UUPSUpgradeable, IndexAvalanche {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(IndexStrategyInitParams calldata initParams)
        external
        initializer
    {
        __UUPSUpgradeable_init();
        __IndexStrategyUpgradeable_init(initParams);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
