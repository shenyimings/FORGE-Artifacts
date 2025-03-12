// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { AAccessControlled } from "../access/AAccessControlled.sol";
import { ARegistryWired } from "../registry/ARegistryWired.sol";
import { IZNSFixedPricer } from "./IZNSFixedPricer.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { StringUtils } from "../utils/StringUtils.sol";


/**
 * @notice Pricer contract that uses the most straightforward fixed pricing model
 * that doesn't depend on the length of the label.
*/
contract ZNSFixedPricer is AAccessControlled, ARegistryWired, UUPSUpgradeable, IZNSFixedPricer {
    using StringUtils for string;

    uint256 public constant PERCENTAGE_BASIS = 10000;

    /**
     * @notice Mapping of domainHash to price config set by the domain owner/operator
    */
    mapping(bytes32 domainHash => PriceConfig config) public priceConfigs;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _accessController, address _registry) external override initializer {
        _setAccessController(_accessController);
        setRegistry(_registry);
    }

    /**
     * @notice Sets the price for a domain. Only callable by domain owner/operator. Emits a `PriceSet` event.
     * @param domainHash The hash of the domain who sets the price for subdomains
     * @param _price The new price value set
    */
    function setPrice(bytes32 domainHash, uint256 _price) public override onlyOwnerOrOperator(domainHash) {
        _setPrice(domainHash, _price);
    }

    /**
     * @notice Gets the price for a subdomain candidate label under the parent domain.
     * @dev `skipValidityCheck` param is added to provide proper revert when the user is
     * calling this to find out the price of a domain that is not valid. But in Registrar contracts
     * we want to do this explicitly and before we get the price to have lower tx cost for reverted tx.
     * So Registrars will pass this bool as "true" to not repeat the validity check.
     * Note that if calling this function directly to find out the price, a user should always pass "false"
     * as `skipValidityCheck` param, otherwise, the price will be returned for an invalid label that is not
     * possible to register.
     * @param parentHash The hash of the parent domain to check the price under
     * @param label The label of the subdomain candidate to check the price for
     * @param skipValidityCheck If true, skips the validity check for the label
    */
    // solhint-disable-next-line no-unused-vars
    function getPrice(
        bytes32 parentHash,
        string calldata label,
        bool skipValidityCheck
    ) public override view returns (uint256) {
        require(
            priceConfigs[parentHash].isSet,
            "ZNSFixedPricer: parent's price config has not been set properly through IZNSPricer.setPriceConfig()"
        );

        if (!skipValidityCheck) {
            // Confirms string values are only [a-z0-9-]
            label.validate();
        }

        return priceConfigs[parentHash].price;
    }

    /**
     * @notice Sets the feePercentage for a domain. Only callable by domain owner/operator.
     * Emits a `FeePercentageSet` event.
     * @dev `feePercentage` is set as a part of the `PERCENTAGE_BASIS` of 10,000 where 1% = 100
     * @param domainHash The hash of the domain who sets the feePercentage for subdomains
     * @param feePercentage The new feePercentage value set
    */
    function setFeePercentage(
        bytes32 domainHash,
        uint256 feePercentage
    ) public override onlyOwnerOrOperator(domainHash) {
        _setFeePercentage(domainHash, feePercentage);
    }

    /**
     * @notice Setter for `priceConfigs[domainHash]`. Only domain owner/operator can call this function.
     * @dev Sets both `PriceConfig.price` and `PriceConfig.feePercentage` in one call, fires `PriceSet`
     * and `FeePercentageSet` events.
     * > This function should ALWAYS be used to set the config, since it's the only place where `isSet` is set to true.
     * > Use the other individual setters to modify only, since they do not set this variable!
     * @param domainHash The domain hash to set the price config for
     * @param priceConfig The new price config to set
     */
    function setPriceConfig(
        bytes32 domainHash,
        PriceConfig calldata priceConfig
    ) external override {
        setPrice(domainHash, priceConfig.price);
        setFeePercentage(domainHash, priceConfig.feePercentage);
        priceConfigs[domainHash].isSet = true;
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
     * @param skipValidityCheck If true, skips the validity check for the label
    */
    function getPriceAndFee(
        bytes32 parentHash,
        string calldata label,
        bool skipValidityCheck
    ) external view override returns (uint256 price, uint256 fee) {
        price = getPrice(parentHash, label, skipValidityCheck);
        fee = getFeeForPrice(parentHash, price);
        return (price, fee);
    }

    /**
     * @notice Sets the registry address in state.
     * @dev This function is required for all contracts inheriting `ARegistryWired`.
    */
    function setRegistry(address registry_) public override(ARegistryWired, IZNSFixedPricer) onlyAdmin {
        _setRegistry(registry_);
    }

    /**
     * @notice Internal function for set price
     * @param domainHash The hash of the domain
     * @param price The new price
     */
    function _setPrice(bytes32 domainHash, uint256 price) internal {
        priceConfigs[domainHash].price = price;
        emit PriceSet(domainHash, price);
    }

    /**
     * @notice Internal function for setFeePercentage
     * @param domainHash The hash of the domain
     * @param feePercentage The new feePercentage
     */
    function _setFeePercentage(bytes32 domainHash, uint256 feePercentage) internal {
        require(
            feePercentage <= PERCENTAGE_BASIS,
            "ZNSFixedPricer: feePercentage cannot be greater than PERCENTAGE_BASIS"
        );

        priceConfigs[domainHash].feePercentage = feePercentage;
        emit FeePercentageSet(domainHash, feePercentage);
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
