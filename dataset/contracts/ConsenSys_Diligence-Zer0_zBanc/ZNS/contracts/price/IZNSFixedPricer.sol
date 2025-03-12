// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IZNSPricer } from "../types/IZNSPricer.sol";

/**
 * @title IZNSFixedPricer.sol Below is the doc for PriceConfig struct.
 * @notice Struct for price configurations per domainHash that is used in the `priceConfigs` mapping
 *  - price The value determining how much a subdomain under a particular parent would cost
 *  - feePercentage The value determining how much fee is charged for a subdomain registration
 * @dev Please note that the `feePercentage` is set in the basis of 10,000 where 1% = 100
 *  and feePercentage is NOT being read when used with PaymentType.DIRECT. This value is only
 *  used when PaymentType.STAKE is set in ZNSSubRegistrar.
 */
interface IZNSFixedPricer is IZNSPricer {
    /**
     * @notice Emitted when the `PriceConfig.price` is set in state for a specific `domainHash`
     * @param domainHash The hash of the domain who sets the price for subdomains
     * @param newPrice The new price value set
    */
    event PriceSet(bytes32 indexed domainHash, uint256 indexed newPrice);

    /**
     * @notice Emitted when the `PriceConfig.feePercentage` is set in state for a specific `domainHash`
     * @param domainHash The hash of the domain who sets the feePercentage for subdomains
     * @param feePercentage The new feePercentage value set
    */
    event FeePercentageSet(bytes32 indexed domainHash, uint256 indexed feePercentage);

    struct PriceConfig {
        uint256 price;
        uint256 feePercentage;
        bool isSet;
    }

    function initialize(address _accessController, address _registry) external;

    function setPrice(bytes32 domainHash, uint256 _price) external;

    function getPrice(
        bytes32 parentHash,
        string calldata label,
        bool skipValidityCheck
    ) external view returns (uint256);

    function setFeePercentage(
        bytes32 domainHash,
        uint256 feePercentage
    ) external;

    function getFeeForPrice(
        bytes32 parentHash,
        uint256 price
    ) external view returns (uint256);

    function getPriceAndFee(
        bytes32 parentHash,
        string calldata label,
        bool skipValidityCheck
    ) external view returns (uint256 price, uint256 fee);

    function setPriceConfig(
        bytes32 domainHash,
        PriceConfig calldata priceConfig
    ) external;

    function setRegistry(address registry_) external;
}
