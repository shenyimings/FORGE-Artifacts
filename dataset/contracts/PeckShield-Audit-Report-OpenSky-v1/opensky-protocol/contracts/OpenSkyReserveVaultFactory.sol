// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import './interfaces/IOpenSkySettings.sol';
import './interfaces/IOpenSkyReserveVaultFactory.sol';
import './OpenSkyOToken.sol';
import './libraries/helpers/Errors.sol';

contract OpenSkyReserveVaultFactory is IOpenSkyReserveVaultFactory {
    IOpenSkySettings public immutable SETTINGS;

    modifier onlyPool() {
        require(msg.sender == SETTINGS.poolAddress(), Errors.ACL_ONLY_POOL_CAN_CALL);
        _;
    }

    constructor(address _settings) {
        SETTINGS = IOpenSkySettings(_settings);
    }

    function create(
        uint256 reserveId,
        string memory name,
        string memory symbol
    ) external override onlyPool returns (address oTokenAddress) {
        address pool = msg.sender;
        address incentiveController = SETTINGS.incentiveControllerAddress();
        oTokenAddress = address(new OpenSkyOToken(pool, reserveId, name, symbol, incentiveController, address(SETTINGS)));
    }
}
