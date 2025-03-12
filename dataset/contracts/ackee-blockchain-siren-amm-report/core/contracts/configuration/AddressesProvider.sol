// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IAddressesProvider} from "./IAddressesProvider.sol";
import "../proxy/Proxiable.sol";

/**
 * @title AddressesProvider contract
 * @dev Main registry of addresses part of or connected to the protocol, including permissioned roles
 * @author Dakra-Mystic
 **/
contract AddressesProvider is
    IAddressesProvider,
    Proxiable,
    OwnableUpgradeable
{
    mapping(bytes32 => address) private _addresses;

    bytes32 private constant PRICE_ORACLE = "PRICE_ORACLE";
    bytes32 private constant AMM_DATA_PROVIDER = "AMM_DATA_PROVIDER";
    bytes32 private constant SERIES_CONTROLLER = "SERIES_CONTROLLER";
    bytes32 private constant VOLATILITY_ORACLE = "VOLATILITY_ORACLE";
    bytes32 private constant BLACKSCHOLES = "BLACKSCHOLES";
    bytes32 private constant AIRSWAP_LIGHT = "AIRSWAP_LIGHT";
    bytes32 private constant AMM_FACTORY = "AMM_FACTORY";
    bytes32 private constant DIRECT_BUY_MANAGER = "DIRECT_BUY_MANAGER";
    bytes32 private constant WTOKEN_VAULT = "WTOKEN_VAULT";
    bytes32 private constant AMM_CONFIG = "AMM_CONFIG";

    ///////////////////// MUTATING FUNCTIONS /////////////////////

    /// @notice Perform inherited contracts' initializations
    function __AddressessProvider_init() external initializer {
        __Ownable_init_unchained();
    }

    /// @notice update the logic contract for this proxy contract
    /// @param _newImplementation the address of the new AddressesProvider implementation
    /// @dev only the admin address may call this function
    function updateImplementation(address _newImplementation)
        external
        onlyOwner
    {
        require(
            _newImplementation != address(0x0),
            "Invalid _newImplementation address"
        );
        _updateCodeAddress(_newImplementation);
    }

    /**
     * @dev Sets an address for an id replacing the address saved in the addresses map
     * IMPORTANT Use this function carefully, as it will do a hard replacement
     * @param id The id
     * @param newAddress The address to set
     */
    function setAddress(bytes32 id, address newAddress)
        external
        override
        onlyOwner
    {
        _addresses[id] = newAddress;
        emit AddressSet(id, newAddress, false);
    }

    /**
     * @dev Returns an address by id
     * @return The address
     */
    function getAddress(bytes32 id) public view override returns (address) {
        return _addresses[id];
    }

    /**
     * @dev The functions below are getters/setters of addresses that are outside the context
     * of the protocol hence the upgradable proxy pattern is not used
     **/

    function getPriceOracle() external view override returns (address) {
        return getAddress(PRICE_ORACLE);
    }

    function setPriceOracle(address priceOracle) external override onlyOwner {
        _addresses[PRICE_ORACLE] = priceOracle;
        emit PriceOracleUpdated(priceOracle);
    }

    function getAmmDataProvider() external view override returns (address) {
        return getAddress(AMM_DATA_PROVIDER);
    }

    function setAmmDataProvider(address ammDataProvider)
        external
        override
        onlyOwner
    {
        _addresses[AMM_DATA_PROVIDER] = ammDataProvider;
        emit AmmDataProviderUpdated(ammDataProvider);
    }

    function getSeriesController() external view override returns (address) {
        return getAddress(SERIES_CONTROLLER);
    }

    function setSeriesController(address seriesController)
        external
        override
        onlyOwner
    {
        _addresses[SERIES_CONTROLLER] = seriesController;
        emit SeriesControllerUpdated(seriesController);
    }

    function getVolatilityOracle() external view override returns (address) {
        return getAddress(VOLATILITY_ORACLE);
    }

    function setVolatilityOracle(address volatilityOracle)
        external
        override
        onlyOwner
    {
        _addresses[VOLATILITY_ORACLE] = volatilityOracle;
        emit VolatilityOracleUpdated(volatilityOracle);
    }

    function getBlackScholes() external view override returns (address) {
        return getAddress(BLACKSCHOLES);
    }

    function setBlackScholes(address blackScholes) external override onlyOwner {
        _addresses[BLACKSCHOLES] = blackScholes;
        emit BlackScholesUpdated(blackScholes);
    }

    function getAirswapLight() external view override returns (address) {
        return getAddress(AIRSWAP_LIGHT);
    }

    function setAirswapLight(address airswapLight) external override onlyOwner {
        _addresses[AIRSWAP_LIGHT] = airswapLight;
        emit AirswapLightUpdated(airswapLight);
    }

    function getAmmFactory() external view override returns (address) {
        return getAddress(AMM_FACTORY);
    }

    function setAmmFactory(address ammFactory) external override onlyOwner {
        _addresses[AMM_FACTORY] = ammFactory;
        emit AmmFactoryUpdated(ammFactory);
    }

    function getDirectBuyManager() external view override returns (address) {
        return getAddress(DIRECT_BUY_MANAGER);
    }

    function setDirectBuyManager(address directBuyManager)
        external
        override
        onlyOwner
    {
        _addresses[DIRECT_BUY_MANAGER] = directBuyManager;
        emit DirectBuyManagerUpdated(directBuyManager);
    }

    function getWTokenVault() external view override returns (address) {
        return getAddress(WTOKEN_VAULT);
    }

    function setWTokenVault(address wTokenVault) external override onlyOwner {
        _addresses[WTOKEN_VAULT] = wTokenVault;
        emit WTokenVaultUpdated(wTokenVault);
    }

    function getAmmConfig() external view override returns (address) {
        return getAddress(AMM_CONFIG);
    }

    function setAmmConfig(address ammConfig) external override onlyOwner {
        _addresses[AMM_CONFIG] = ammConfig;
        emit AmmConfigUpdated(ammConfig);
    }
}
