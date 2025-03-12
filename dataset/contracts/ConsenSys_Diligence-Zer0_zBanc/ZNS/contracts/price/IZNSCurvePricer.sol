// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ICurvePriceConfig } from "../types/ICurvePriceConfig.sol";
import { IZNSPricer } from "../types/IZNSPricer.sol";


interface IZNSCurvePricer is ICurvePriceConfig, IZNSPricer {

    /**
     * @notice Emitted when the `maxPrice` is set in `CurvePriceConfig`
     * @param price The new maxPrice value
     */
    event MaxPriceSet(bytes32 domainHash, uint256 price);

    /**
     * @notice Emitted when the `minPrice` is set in `CurvePriceConfig`
     * @param price The new minPrice value
     */
    event MinPriceSet(bytes32 domainHash, uint256 price);

    /**
     * @notice Emitted when the `baseLength` is set in `CurvePriceConfig`
     * @param length The new baseLength value
     */
    event BaseLengthSet(bytes32 domainHash, uint256 length);

    /**
     * @notice Emitted when the `maxLength` is set in `CurvePriceConfig`
     * @param length The new maxLength value
     */
    event MaxLengthSet(bytes32 domainHash, uint256 length);

    /**
     * @notice Emitted when the `precisionMultiplier` is set in `CurvePriceConfig`
     * @param precision The new precisionMultiplier value
     */
    event PrecisionMultiplierSet(bytes32 domainHash, uint256 precision);

    /**
     * @notice Emitted when the `feePercentage` is set in state
     * @param feePercentage The new feePercentage value
     */
    event FeePercentageSet(bytes32 domainHash, uint256 feePercentage);

    /**
     * @notice Emitted when the full `CurvePriceConfig` is set in state
     * @param maxPrice The new `maxPrice` value
     * @param minPrice The new `minPrice` value
     * @param maxLength The new `maxLength` value
     * @param baseLength The new `baseLength` value
     * @param precisionMultiplier The new `precisionMultiplier` value
     */
    event PriceConfigSet(
        bytes32 domainHash,
        uint256 maxPrice,
        uint256 minPrice,
        uint256 maxLength,
        uint256 baseLength,
        uint256 precisionMultiplier,
        uint256 feePercentage
    );

    function initialize(
        address accessController_,
        address registry_,
        CurvePriceConfig calldata zeroPriceConfig_
    ) external;

    function getPrice(
        bytes32 parentHash,
        string calldata label,
        bool skipValidityCheck
    ) external view returns (uint256);

    function getFeeForPrice(
        bytes32 parentHash,
        uint256 price
    ) external view returns (uint256);

    function getPriceAndFee(
        bytes32 parentHash,
        string calldata label,
        bool skipValidityCheck
    ) external view returns (
        uint256 price,
        uint256 stakeFee
    );

    function setPriceConfig(
        bytes32 domainHash,
        CurvePriceConfig calldata priceConfig
    ) external;

    function setMaxPrice(bytes32 domainHash, uint256 maxPrice) external;

    function setMinPrice(bytes32 domainHash, uint256 minPrice) external;

    function setBaseLength(bytes32 domainHash, uint256 length) external;

    function setMaxLength(bytes32 domainHash, uint256 length) external;

    function setPrecisionMultiplier(bytes32 domainHash, uint256 multiplier) external;

    function setFeePercentage(bytes32 domainHash, uint256 feePercentage) external;

    function setRegistry(address registry_) external;
}
