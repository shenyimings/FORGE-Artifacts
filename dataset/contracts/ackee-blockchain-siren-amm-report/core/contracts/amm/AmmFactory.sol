// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol";
import "../proxy/Proxy.sol";
import "../proxy/Proxiable.sol";
import "./IMinterAmm.sol";
import "../series/ISeriesController.sol";
import "../configuration/IAddressesProvider.sol";
import "../token/IERC20Lib.sol";

/// @title AmmFactory
/// @author The Siren Devs
/// @notice Factory contract responsible for AMM creation
contract AmmFactory is OwnableUpgradeable, Proxiable {
    /// @notice Implementation address for the AMM contract - can be upgraded by owner
    address public ammImplementation;

    /// @notice Implementation address for token contracts - can be upgraded by owner
    address public tokenImplementation;

    /// @notice Address of the SeriesController associated with this AmmFactory
    ISeriesController public seriesController;

    /// @notice Address of the AddressesProvider associated with this AmmFactory
    IAddressesProvider public addressesProvider;

    /// @notice Mapping of keccak256(abi.encode(address(_underlyingToken), address(_priceToken), address(collateralToken)))
    /// bytes32 keys to AMM (Automated Market Maker) addresses
    /// @dev used to ensure we cannot create AMM's with the same <underlying>-<price>-<collateral> triplet
    mapping(bytes32 => address) public amms;

    /// @notice Emitted when the owner updates the amm implementation address
    event AmmImplementationUpdated(address newAddress);

    /// @notice Emitted when a new AMM is created and initialized
    event AmmCreated(address amm);

    /// @notice Emitted when the owner updates the token implementation address
    event TokenImplementationUpdated(address newAddress);

    /// @notice Setup the state variables for an AmmFactory
    function initialize(
        address _ammImplementation,
        address _tokenImplementation,
        ISeriesController _seriesController,
        IAddressesProvider _addressesProvider
    ) external {
        __AmmFactory_init(
            _ammImplementation,
            _tokenImplementation,
            _seriesController,
            _addressesProvider
        );
    }

    /**
     * Initialization function that only allows itself to be called once
     */
    function __AmmFactory_init(
        address _ammImplementation,
        address _tokenImplementation,
        ISeriesController _seriesController,
        IAddressesProvider _addressesProvider
    ) internal initializer {
        // Verify addresses
        require(
            _ammImplementation != address(0x0),
            "Invalid _ammImplementation"
        );
        require(
            _tokenImplementation != address(0x0),
            "Invalid _tokenImplementation"
        );
        require(
            address(_seriesController) != address(0x0),
            "Invalid _seriesController"
        );
        require(
            address(_addressesProvider) != address(0x0),
            "Invalid _addressesProvider"
        );

        // Save off implementation address
        ammImplementation = _ammImplementation;
        tokenImplementation = _tokenImplementation;
        seriesController = _seriesController;
        addressesProvider = _addressesProvider;

        // Set up the initialization of the inherited ownable contract
        __Ownable_init();
    }

    /**
     * The owner can update the AMM implementation address that will be used for future AMMs
     */
    function updateAmmImplementation(address newAmmImplementation)
        external
        onlyOwner
    {
        require(
            newAmmImplementation != address(0x0),
            "Invalid newAmmImplementation"
        );

        // Update the address
        ammImplementation = newAmmImplementation;

        // Emit the event
        emit AmmImplementationUpdated(ammImplementation);
    }

    /// @notice The owner can update the token implementation address that will be used for future AMMs
    function updateTokenImplementation(address newTokenImplementation)
        external
        onlyOwner
    {
        require(
            newTokenImplementation != address(0x0),
            "Invalid newTokenImplementation"
        );

        // Update the address
        tokenImplementation = newTokenImplementation;

        // Emit the event
        emit TokenImplementationUpdated(tokenImplementation);
    }

    /// @notice update the logic contract for this proxy contract
    /// @param _newImplementation the address of the new AmmFactory implementation
    /// @dev only the admin address may call this function
    function updateImplementation(address _newImplementation)
        external
        onlyOwner
    {
        require(
            _newImplementation != address(0x0),
            "Invalid _newImplementation"
        );

        _updateCodeAddress(_newImplementation);
    }

    /// @notice Deploy and initializes an AMM
    /// @param _sirenPriceOracle the PriceOracle contract to use for fetching series and settlement prices
    /// @param _underlyingToken The token whose price movements determine the AMM's Series' moneyness
    /// @param _priceToken The token whose units are used for all prices
    /// @param _collateralToken The token used for this AMM's Series' collateral
    /// @param _tradeFeeBasisPoints The fees to charge on option token trades
    function createAmm(
        address _sirenPriceOracle,
        IERC20 _underlyingToken,
        IERC20 _priceToken,
        IERC20 _collateralToken,
        uint16 _tradeFeeBasisPoints
    ) external onlyOwner {
        require(
            address(_sirenPriceOracle) != address(0x0),
            "Invalid _sirenPriceOracle"
        );
        require(
            address(_underlyingToken) != address(0x0),
            "Invalid _underlyingToken"
        );
        require(address(_priceToken) != address(0x0), "Invalid _priceToken");
        require(
            address(_collateralToken) != address(0x0),
            "Invalid _collateralToken"
        );
        require(
            address(_underlyingToken) != address(_priceToken),
            "_underlyingToken cannot equal _priceToken"
        );

        // Verify a amm with this name does not exist
        bytes32 assetPair = keccak256(
            abi.encode(
                address(_underlyingToken),
                address(_priceToken),
                address(_collateralToken)
            )
        );

        require(amms[assetPair] == address(0x0), "AMM name already registered");

        // Create the lpToken and initialize it
        Proxy lpTokenProxy = new Proxy(tokenImplementation);
        ISimpleToken lpToken = ISimpleToken(address(lpTokenProxy));

        // AMM name will be <underlying>-<price>-<collateral>, e.g. WBTC-USDC-WBTC for a WBTC Call AMM
        string memory ammName = string(
            abi.encodePacked(
                IERC20Lib(address(_underlyingToken)).symbol(),
                "-",
                IERC20Lib(address(_priceToken)).symbol(),
                "-",
                IERC20Lib(address(_collateralToken)).symbol()
            )
        );
        string memory lpTokenName = string(abi.encodePacked("LP-", ammName));
        lpToken.initialize(
            lpTokenName,
            lpTokenName,
            IERC20Lib(address(_collateralToken)).decimals()
        );

        // Deploy a new proxy pointing at the AMM impl
        Proxy ammProxy = new Proxy(ammImplementation);
        IMinterAmm newAmm = IMinterAmm(address(ammProxy));

        newAmm.initialize(
            seriesController,
            addressesProvider,
            _underlyingToken,
            _priceToken,
            _collateralToken,
            lpToken,
            _tradeFeeBasisPoints
        );

        IAccessControlUpgradeable(address(lpToken)).grantRole(
            keccak256("MINTER_ROLE"),
            address(newAmm)
        );
        IAccessControlUpgradeable(address(lpToken)).grantRole(
            keccak256("BURNER_ROLE"),
            address(newAmm)
        );

        // Set owner to msg.sender
        OwnableUpgradeable(address(newAmm)).transferOwnership(msg.sender);

        // Save off the new AMM, this way we don't accidentally create an AMM with a duplicate
        // <underlying>-<price>-<collateral> triplet
        amms[assetPair] = address(newAmm);

        // Emit the event
        emit AmmCreated(address(newAmm));
    }
}
