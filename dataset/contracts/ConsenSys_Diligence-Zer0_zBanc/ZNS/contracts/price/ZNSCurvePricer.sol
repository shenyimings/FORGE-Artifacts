// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IZNSCurvePricer } from "./IZNSCurvePricer.sol";
import { StringUtils } from "../utils/StringUtils.sol";
import { AAccessControlled } from "../access/AAccessControlled.sol";
import { ARegistryWired } from "../registry/ARegistryWired.sol";


/**
 * @title Implementation of the Curve Pricing, module that calculates the price of a domain
 * based on its length and the rules set by Zero ADMIN.
 * This module uses an asymptotic curve that starts from `maxPrice` for all domains <= `baseLength`.
 * It then decreases in price, using the calculated price function below, until it reaches `minPrice`
 * at `maxLength` length of the domain name. Price after `maxLength` is fixed and always equal to `minPrice`.
 */
contract ZNSCurvePricer is AAccessControlled, ARegistryWired, UUPSUpgradeable, IZNSCurvePricer {
    using StringUtils for string;

    /**
     * @notice Value used as a basis for percentage calculations,
     * since Solidity does not support fractions.
     */
    uint256 public constant PERCENTAGE_BASIS = 10000;

    /**
     * @notice Mapping of domainHash to the price config for that domain set by the parent domain owner.
     * @dev Zero, for pricing root domains, uses this mapping as well under 0x0 hash.
    */
    mapping(bytes32 domainHash => CurvePriceConfig config) public priceConfigs;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Proxy initializer to set the initial state of the contract after deployment.
     * Only Owner of the 0x0 hash (Zero owned address) can call this function.
     * @dev > Note the for PriceConfig we set each value individually and calling
     * 2 important functions that validate all of the config's values against the formula:
     * - `setPrecisionMultiplier()` to validate precision multiplier
     * - `_validateConfig()` to validate the whole config in order to avoid price spikes
     * @param accessController_ the address of the ZNSAccessController contract.
     * @param registry_ the address of the ZNSRegistry contract.
     * @param zeroPriceConfig_ a number of variables that participate in the price calculation for subdomains.
     */
    function initialize(
        address accessController_,
        address registry_,
        CurvePriceConfig calldata zeroPriceConfig_
    ) external override initializer {
        _setAccessController(accessController_);
        _setRegistry(registry_);

        setPriceConfig(0x0, zeroPriceConfig_);
    }

    /**
     * @notice Get the price of a given domain name
     * @dev `skipValidityCheck` param is added to provide proper revert when the user is
     * calling this to find out the price of a domain that is not valid. But in Registrar contracts
     * we want to do this explicitly and before we get the price to have lower tx cost for reverted tx.
     * So Registrars will pass this bool as "true" to not repeat the validity check.
     * Note that if calling this function directly to find out the price, a user should always pass "false"
     * as `skipValidityCheck` param, otherwise, the price will be returned for an invalid label that is not
     * possible to register.
     * @param parentHash The hash of the parent domain under which price is determined
     * @param label The label of the subdomain candidate to get the price for before/during registration
     * @param skipValidityCheck If true, skips the validity check for the label
     */
    function getPrice(
        bytes32 parentHash,
        string calldata label,
        bool skipValidityCheck
    ) public view override returns (uint256) {
        require(
            priceConfigs[parentHash].isSet,
            "ZNSCurvePricer: parent's price config has not been set properly through IZNSPricer.setPriceConfig()"
        );

        if (!skipValidityCheck) {
            // Confirms string values are only [a-z0-9-]
            label.validate();
        }

        uint256 length = label.strlen();
        // No pricing is set for 0 length domains
        if (length == 0) return 0;

        return _getPrice(parentHash, length);
    }

    /**
     * @notice Part of the IZNSPricer interface - one of the functions required
     * for any pricing contracts used with ZNS. It returns fee for a given price
     * based on the value set by the owner of the parent domain.
     * @param parentHash The hash of the parent domain under which fee is determined
     * @param price The price to get the fee for
    */
    function getFeeForPrice(
        bytes32 parentHash,
        uint256 price
    ) public view override returns (uint256) {
        return (price * priceConfigs[parentHash].feePercentage) / PERCENTAGE_BASIS;
    }

    /**
     * @notice Part of the IZNSPricer interface - one of the functions required
     * for any pricing contracts used with ZNS. Returns both price and fee for a given label
     * under the given parent.
     * @param parentHash The hash of the parent domain under which price and fee are determined
     * @param label The label of the subdomain candidate to get the price and fee for before/during registration
    */
    function getPriceAndFee(
        bytes32 parentHash,
        string calldata label,
        bool skipValidityCheck
    ) external view override returns (uint256 price, uint256 stakeFee) {
        price = getPrice(parentHash, label, skipValidityCheck);
        stakeFee = getFeeForPrice(parentHash, price);
        return (price, stakeFee);
    }

    /**
     * @notice Setter for `priceConfigs[domainHash]`. Only domain owner/operator can call this function.
     * @dev Validates the value of the `precisionMultiplier` and the whole config in order to avoid price spikes,
     * fires `PriceConfigSet` event.
     * Only the owner of the domain or an allowed operator can call this function
     * > This function should ALWAYS be used to set the config, since it's the only place where `isSet` is set to true.
     * > Use the other individual setters to modify only, since they do not set this variable!
     * @param domainHash The domain hash to set the price config for
     * @param priceConfig The new price config to set
     */
    function setPriceConfig(
        bytes32 domainHash,
        CurvePriceConfig calldata priceConfig
    ) public override {
        setPrecisionMultiplier(domainHash, priceConfig.precisionMultiplier);
        priceConfigs[domainHash].baseLength = priceConfig.baseLength;
        priceConfigs[domainHash].maxPrice = priceConfig.maxPrice;
        priceConfigs[domainHash].minPrice = priceConfig.minPrice;
        priceConfigs[domainHash].maxLength = priceConfig.maxLength;
        setFeePercentage(domainHash, priceConfig.feePercentage);
        priceConfigs[domainHash].isSet = true;

        _validateConfig(domainHash);

        emit PriceConfigSet(
            domainHash,
            priceConfig.maxPrice,
            priceConfig.minPrice,
            priceConfig.maxLength,
            priceConfig.baseLength,
            priceConfig.precisionMultiplier,
            priceConfig.feePercentage
        );
    }

    /**
     * @notice Sets the max price for domains. Validates the config with the new price.
     * Fires `MaxPriceSet` event.
     * Only domain owner can call this function.
     * > `maxPrice` can be set to 0 along with `baseLength` or `minPrice` to make all domains free!
     * @dev We are checking here for possible price spike at `maxLength` if the `maxPrice` values is NOT 0.
     * In the case of 0 we do not validate, since setting it to 0 will make all subdomains free.
     * @param maxPrice The maximum price to set
     */
    function setMaxPrice(
        bytes32 domainHash,
        uint256 maxPrice
    ) external override onlyOwnerOrOperator(domainHash) {
        priceConfigs[domainHash].maxPrice = maxPrice;

        if (maxPrice != 0) _validateConfig(domainHash);

        emit MaxPriceSet(domainHash, maxPrice);
    }

    /**
     * @notice Sets the minimum price for domains. Validates the config with the new price.
     * Fires `MinPriceSet` event.
     * Only domain owner/operator can call this function.
     * @param domainHash The domain hash to set the `minPrice` for
     * @param minPrice The minimum price to set in $ZERO
     */
    function setMinPrice(
        bytes32 domainHash,
        uint256 minPrice
    ) external override onlyOwnerOrOperator(domainHash) {
        priceConfigs[domainHash].minPrice = minPrice;

        _validateConfig(domainHash);

        emit MinPriceSet(domainHash, minPrice);
    }

    /**
     * @notice Set the value of the domain name length boundary where the `maxPrice` applies
     * e.g. A value of '5' means all domains <= 5 in length cost the `maxPrice` price
     * Validates the config with the new length. Fires `BaseLengthSet` event.
     * Only domain owner/operator can call this function.
     * > `baseLength` can be set to 0 to make all domains cost `maxPrice`!
     * > This indicates to the system that we are
     * > currently in a special phase where we define an exact price for all domains
     * > e.g. promotions or sales
     * @param domainHash The domain hash to set the `baseLength` for
     * @param length Boundary to set
     */
    function setBaseLength(
        bytes32 domainHash,
        uint256 length
    ) external override onlyOwnerOrOperator(domainHash) {
        priceConfigs[domainHash].baseLength = length;

        _validateConfig(domainHash);

        emit BaseLengthSet(domainHash, length);
    }

    /**
     * @notice Set the maximum length of a domain name to which price formula applies.
     * All domain names (labels) that are longer than this value will cost the fixed price of `minPrice`,
     * and the pricing formula will not apply to them.
     * Validates the config with the new length.
     * Fires `MaxLengthSet` event.
     * Only domain owner/operator can call this function.
     * > `maxLength` can be set to 0 to make all domains cost `minPrice`!
     * @param domainHash The domain hash to set the `maxLength` for
     * @param length The maximum length to set
     */
    function setMaxLength(
        bytes32 domainHash,
        uint256 length
    ) external override onlyOwnerOrOperator(domainHash) {
        priceConfigs[domainHash].maxLength = length;

        if (length != 0) _validateConfig(domainHash);

        emit MaxLengthSet(domainHash, length);
    }

    /**
     * @notice Sets the precision multiplier for the price calculation.
     * Multiplier This should be picked based on the number of token decimals
     * to calculate properly.
     * e.g. if we use a token with 18 decimals, and want precision of 2,
     * our precision multiplier will be equal to `10^(18 - 2) = 10^16`
     * Fires `PrecisionMultiplierSet` event.
     * Only domain owner/operator can call this function.
     * > Multiplier should be less or equal to 10^18 and greater than 0!
     * @param multiplier The multiplier to set
     */
    function setPrecisionMultiplier(
        bytes32 domainHash,
        uint256 multiplier
    ) public override onlyOwnerOrOperator(domainHash) {
        require(multiplier != 0, "ZNSCurvePricer: precisionMultiplier cannot be 0");
        require(multiplier <= 10**18, "ZNSCurvePricer: precisionMultiplier cannot be greater than 10^18");
        priceConfigs[domainHash].precisionMultiplier = multiplier;

        emit PrecisionMultiplierSet(domainHash, multiplier);
    }

    /**
     * @notice Sets the fee percentage for domain registration.
     * @dev Fee percentage is set according to the basis of 10000, outlined in `PERCENTAGE_BASIS`.
     * Fires `FeePercentageSet` event.
     * Only domain owner/operator can call this function.
     * @param domainHash The domain hash to set the fee percentage for
     * @param feePercentage The fee percentage to set
     */
    function setFeePercentage(bytes32 domainHash, uint256 feePercentage)
    public
    override
    onlyOwnerOrOperator(domainHash) {
        require(
            feePercentage <= PERCENTAGE_BASIS,
            "ZNSCurvePricer: feePercentage cannot be greater than PERCENTAGE_BASIS"
        );

        priceConfigs[domainHash].feePercentage = feePercentage;
        emit FeePercentageSet(domainHash, feePercentage);
    }

    /**
     * @notice Sets the registry address in state.
     * @dev This function is required for all contracts inheriting `ARegistryWired`.
    */
    function setRegistry(address registry_) external override(ARegistryWired, IZNSCurvePricer) onlyAdmin {
        _setRegistry(registry_);
    }

    /**
     * @notice Internal function to calculate price based on the config set,
     * and the length of the domain label.
     * @dev Before we calculate the price, 4 different cases are possible:
     * 1. `maxPrice` is 0, which means all subdomains under this parent are free
     * 2. `baseLength` is 0, which means we are returning `maxPrice` as a specific price for all domains
     * 3. `length` is less than or equal to `baseLength`, which means a domain will cost `maxPrice`
     * 4. `length` is greater than `maxLength`, which means a domain will cost `minPrice`
     *
     * The formula itself creates an asymptotic curve that decreases in pricing based on domain name length,
     * base length and max price, the result is divided by the precision multiplier to remove numbers beyond
     * what we care about, then multiplied by the same precision multiplier to get the actual value
     * with truncated values past precision. So having a value of `15.235234324234512365 * 10^18`
     * with precision `2` would give us `15.230000000000000000 * 10^18`
     * @param length The length of the domain name
     */
    function _getPrice(
        bytes32 parentHash,
        uint256 length
    ) internal view returns (uint256) {
        CurvePriceConfig memory config = priceConfigs[parentHash];

        // We use `maxPrice` as 0 to indicate free domains
        if (config.maxPrice == 0) return 0;

        // Setting baseLength to 0 indicates to the system that we are
        // currently in a special phase where we define an exact price for all domains
        // e.g. promotions or sales
        if (config.baseLength == 0) return config.maxPrice;
        if (length <= config.baseLength) return config.maxPrice;
        if (length > config.maxLength) return config.minPrice;

        return (config.baseLength * config.maxPrice / length)
            / config.precisionMultiplier * config.precisionMultiplier;
    }

    /**
     * @notice Internal function called every time we set props of `priceConfigs[domainHash]`
     * to make sure that values being set can not disrupt the price curve or zero out prices
     * for domains. If this validation fails, the parent function will revert.
     * @dev We are checking here for possible price spike at `maxLength`
     * which can occur if some of the config values are not properly chosen and set.
     */
    function _validateConfig(bytes32 domainHash) internal view {
        uint256 prevToMinPrice = _getPrice(domainHash, priceConfigs[domainHash].maxLength);
        require(
            priceConfigs[domainHash].minPrice <= prevToMinPrice,
            "ZNSCurvePricer: incorrect value set causes the price spike at maxLength."
        );
    }

    /**
     * @notice To use UUPS proxy we override this function and revert if `msg.sender` isn't authorized
     * @param newImplementation The new implementation contract to upgrade to.
     */
    // solhint-disable-next-line
    function _authorizeUpgrade(address newImplementation) internal view override {
        accessController.checkGovernor(msg.sender);
    }
}
