// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../interfaces/BEP20Interface.sol";
import "../interfaces/VBep20Interface.sol";
import "../interfaces/OracleInterface.sol";

struct ValidateConfig {
    /// @notice asset address
    address asset;
    /// @notice upper bound of deviation between reported price and anchor price,
    /// beyond which the reported price will be invalidated
    uint256 upperBoundRatio;
    /// @notice lower bound of deviation between reported price and anchor price,
    /// below which the reported price will be invalidated
    uint256 lowerBoundRatio;
}

// BoundValidator provides some common functions and can be used
// to wrap up other contracts to form pivot oracles
contract BoundValidator is OwnableUpgradeable, BoundValidatorInterface {
    /// @notice validation configs by asset
    mapping(address => ValidateConfig) public validateConfigs;

    /// @notice Emit this event when new validate configs are added
    event ValidateConfigAdded(address indexed asset, uint256 indexed upperBound, uint256 indexed lowerBound);

    function initialize() public initializer {
        __Ownable_init();
    }

    /**
     * @notice Add multiple validation configs at the same time
     * @param configs config array
     */
    function setValidateConfigs(ValidateConfig[] memory configs) external virtual onlyOwner {
        require(configs.length > 0, "invalid validate config length");
        for (uint8 i = 0; i < configs.length; i++) {
            setValidateConfig(configs[i]);
        }
    }

    /**
     * @notice Add single validation config
     * @param config config struct
     */
    function setValidateConfig(ValidateConfig memory config) public virtual onlyOwner {
        require(config.asset != address(0), "asset can't be zero address");
        require(config.upperBoundRatio > 0 && config.lowerBoundRatio > 0, "bound must be positive");
        require(config.upperBoundRatio > config.lowerBoundRatio, "upper bound must be higher than lowner bound");
        validateConfigs[config.asset] = config;
        emit ValidateConfigAdded(config.asset, config.upperBoundRatio, config.lowerBoundRatio);
    }

    /**
     * @notice Test reported asset price against anchor price
     * @param vToken vToken address
     * @param reporterPrice the price to be tested
     */
    function validatePriceWithAnchorPrice(
        address vToken,
        uint256 reporterPrice,
        uint256 anchorPrice
    ) public view virtual override returns (bool) {
        address asset = VBep20Interface(vToken).underlying();

        require(validateConfigs[asset].upperBoundRatio != 0, "validation config not exist");
        require(anchorPrice != 0, "anchor price is not valid");
        return _isWithinAnchor(asset, reporterPrice, anchorPrice);
    }

    /**
     * @notice Test whether the reported price is within the predefined bounds
     * @param asset asset address
     * @param reporterPrice the price to be tested
     * @param anchorPrice anchor price as testing anchor
     */
    function _isWithinAnchor(address asset, uint256 reporterPrice, uint256 anchorPrice) internal view returns (bool) {
        if (reporterPrice > 0) {
            uint256 anchorRatio = (anchorPrice * 100e16) / reporterPrice;
            uint256 upperBoundAnchorRatio = validateConfigs[asset].upperBoundRatio;
            uint256 lowerBoundAnchorRatio = validateConfigs[asset].lowerBoundRatio;
            return anchorRatio <= upperBoundAnchorRatio && anchorRatio >= lowerBoundAnchorRatio;
        }
        return false;
    }

    // BoundValidator is to get inherited, so it's a good practice to add some storage gaps like
    // OpenZepplin proposed in their contracts: https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
    uint256[49] private __gap;
}
