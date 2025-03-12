// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";

import "./interfaces/IFeeSettings.sol";

/**
 * @title FeeSettings
 * @author malteish, cjentzsch
 * @notice The FeeSettings contract is used to manage fees paid to the tokenize.it platfom
 */
contract FeeSettings is
    Ownable2StepUpgradeable,
    ERC165Upgradeable,
    ERC2771ContextUpgradeable,
    IFeeSettingsV2,
    IFeeSettingsV1
{
    /// max token fee is 5%
    uint32 public constant MAX_TOKEN_FEE_NUMERATOR = 1;
    uint32 public constant MAX_TOKEN_FEE_DENOMINATOR = 20;
    /// max crowdinvesting fee is 10%
    uint32 public constant MAX_CONTINUOUS_FUNDRAISING_FEE_NUMERATOR = 1;
    uint32 public constant MAX_CONTINUOUS_FUNDRAISING_FEE_DENOMINATOR = 10;
    /// max private offer fee is 5%
    uint32 public constant MAX_PERSONAL_INVITE_FEE_NUMERATOR = 1;
    uint32 public constant MAX_PERSONAL_INVITE_FEE_DENOMINATOR = 20;

    /// Numerator to calculate fees paid in Token.sol.
    uint32 public defaultTokenFeeNumerator;
    /// Denominator to calculate fees paid in Token.sol.
    uint32 public defaultTokenFeeDenominator;

    /// Numerator to calculate fees paid in Crowdinvesting.sol.
    uint32 public defaultCrowdinvestingFeeNumerator;
    /// Denominator to calculate fees paid in Crowdinvesting.sol.
    uint32 public defaultCrowdinvestingFeeDenominator;

    /// Numerator to calculate fees paid in PrivateOffer.sol.
    uint32 public defaultPrivateOfferFeeNumerator;
    /// Denominator to calculate fees paid in PrivateOffer.sol.
    uint32 public defaultPrivateOfferFeeDenominator;

    /**
     * special fees for specific customers. If a customer has a custom fee, the custom
     * fee is used instead of the default fee.
     * Custom fees can only reduce the fee, not increase it.
     * The key is the customer's token address, e.g. customers are identified by their token.
     * The `time` field is the time up to which the custom fee is valid.
     * Afterwards, standard fees are used.
     */
    mapping(address => Fees) public customFees;

    /// address the token fees have to be paid to
    address private defaultTokenFeeCollector;
    /// address the crowdinvesting fees have to be paid to
    address private defaultCrowdinvestingFeeCollector;
    /// address the private offer fees have to be paid to
    address private defaultPrivateOfferFeeCollector;

    /**
     * if `customTokenFeeCollector[tokenAddress]` is 0x0, the fees must be paid to `defaultTokenFeeCollector`
     * otherwise, the fees must be paid to `customTokenFeeCollector[tokenAddress]`
     */
    mapping(address => address) public customTokenFeeCollector;
    /**
     * if `customCrowdinvestingFeeCollector[tokenAddress]` is 0x0, the fees must be paid to `defaultCrowdinvestingFeeCollector`
     * otherwise, the fees must be paid to `customCrowdinvestingFeeCollector[tokenAddress]`
     */
    mapping(address => address) public customCrowdinvestingFeeCollector;
    /**
     * if `customPrivateOfferFeeCollector[tokenAddress]` is 0x0, the fees must be paid to `defaultPrivateOfferFeeCollector`
     * otherwise, the fees must be paid to `customPrivateOfferFeeCollector[tokenAddress]`
     */
    mapping(address => address) public customPrivateOfferFeeCollector;

    /// new fee settings that can be activated (after a delay in case of fee increase)
    Fees public proposedDefaultFees;

    /// stores who is a manager. Managers can change customFees, but nothing else.
    mapping(address => bool) public managers;

    /**
     * @notice Default fees have been changed
     * @param tokenFeeNumerator a in fraction a/b that defines the fee paid in Token: fee = amount * a / b
     * @param tokenFeeDenominator b in fraction a/b that defines the fee paid in Token: fee = amount * a / b
     * @param crowdinvestingFeeNumerator a in fraction a/b that defines the fee paid in currency for crowdinvesting: fee = amount * a / b
     * @param crowdinvestingFeeDenominator b in fraction a/b that defines the fee paid in currency for crowdinvesting: fee = amount * a / b
     * @param privateOfferFeeNumerator a in fraction a/b that defines the fee paid in currency for private offers: fee = amount * a / b
     * @param privateOfferFeeDenominator b in fraction a/b that defines the fee paid in currency for private offers: fee = amount * a / b
     */
    event SetFee(
        uint32 tokenFeeNumerator,
        uint32 tokenFeeDenominator,
        uint32 crowdinvestingFeeNumerator,
        uint32 crowdinvestingFeeDenominator,
        uint32 privateOfferFeeNumerator,
        uint32 privateOfferFeeDenominator
    );

    /**
     * @notice Default fees have been changed
     * @param tokenFeeNumerator a in fraction a/b that defines the fee paid in Token: fee = amount * a / b
     * @param tokenFeeDenominator b in fraction a/b that defines the fee paid in Token: fee = amount * a / b
     * @param crowdinvestingFeeNumerator a in fraction a/b that defines the fee paid in currency for crowdinvesting: fee = amount * a / b
     * @param crowdinvestingFeeDenominator b in fraction a/b that defines the fee paid in currency for crowdinvesting: fee = amount * a / b
     * @param privateOfferFeeNumerator a in fraction a/b that defines the fee paid in currency for private offers: fee = amount * a / b
     * @param privateOfferFeeDenominator b in fraction a/b that defines the fee paid in currency for private offers: fee = amount * a / b
     * @param time The time when the custom fee expires
     */
    event SetCustomFee(
        address indexed token,
        uint32 tokenFeeNumerator,
        uint32 tokenFeeDenominator,
        uint32 crowdinvestingFeeNumerator,
        uint32 crowdinvestingFeeDenominator,
        uint32 privateOfferFeeNumerator,
        uint32 privateOfferFeeDenominator,
        uint256 time
    );

    /// custom fee settings for the given token have been removed
    event RemoveCustomFee(address indexed token);

    /// token fees for `token` must now be paid to `feeCollector`
    event SetCustomTokenFeeCollector(address indexed token, address indexed feeCollector);
    /// crowdinvesting fees for `token` must now be paid to `feeCollector`
    event SetCustomCrowdinvestingFeeCollector(address indexed token, address indexed feeCollector);
    /// private offer fees for `token` must now be paid to `feeCollector`
    event SetCustomPrivateOfferFeeCollector(address indexed token, address indexed feeCollector);

    /// token fees for `token` must now be paid to the default fee collector
    event RemoveCustomTokenFeeCollector(address indexed token);
    /// crowdinvesting fees for `token` must now be paid to the default fee collector
    event RemoveCustomCrowdinvestingFeeCollector(address indexed token);
    /// private offer fees for `token` must now be paid to the default fee collector
    event RemoveCustomPrivateOfferFeeCollector(address indexed token);

    /**
     * @notice The fee collector has been changed to `newFeeCollector`
     * @param newFeeCollector The new fee collector
     */
    event FeeCollectorsChanged(
        address indexed newFeeCollector,
        address indexed newCrowdinvestingFeeCollector,
        address indexed newPrivateOfferFeeCollector
    );

    /**
     * @notice A fee change has been proposed
     * @param proposal The new fee settings that have been proposed
     */
    event ChangeProposed(Fees proposal);

    /**
     * This constructor deploys a logic contract with no owner, that can be used for cloning.
     * @param _trustedForwarder The trusted forwarder contract to use
     */
    constructor(address _trustedForwarder) ERC2771ContextUpgradeable(_trustedForwarder) {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract with the given fee denominators and fee collector
     * @param _fees The initial fee denominators
     * @param _tokenFeeCollector The initial fee collector
     * @param _crowdinvestingFeeCollector The initial crowdinvesting fee collector
     * @param _privateOfferFeeCollector The initial private offer fee collector
     */
    function initialize(
        address _owner,
        Fees memory _fees,
        address _tokenFeeCollector,
        address _crowdinvestingFeeCollector,
        address _privateOfferFeeCollector
    ) external initializer {
        require(_owner != address(0), "owner can not be zero address");
        managers[_owner] = true;
        _transferOwnership(_owner);

        checkFeeLimits(_fees);
        defaultTokenFeeNumerator = _fees.tokenFeeNumerator;
        defaultTokenFeeDenominator = _fees.tokenFeeDenominator;
        defaultCrowdinvestingFeeNumerator = _fees.crowdinvestingFeeNumerator;
        defaultCrowdinvestingFeeDenominator = _fees.crowdinvestingFeeDenominator;
        defaultPrivateOfferFeeNumerator = _fees.privateOfferFeeNumerator;
        defaultPrivateOfferFeeDenominator = _fees.privateOfferFeeDenominator;

        require(_tokenFeeCollector != address(0), "Fee collector cannot be 0x0");
        defaultTokenFeeCollector = _tokenFeeCollector;

        require(_crowdinvestingFeeCollector != address(0), "Fee collector cannot be 0x0");
        defaultCrowdinvestingFeeCollector = _crowdinvestingFeeCollector;

        require(_privateOfferFeeCollector != address(0), "Fee collector cannot be 0x0");
        defaultPrivateOfferFeeCollector = _privateOfferFeeCollector;
    }

    /**
     * @notice Adds a manager
     * @param _manager The manager to add
     */
    function addManager(address _manager) external onlyOwner {
        managers[_manager] = true;
    }

    /**
     * @notice Removes a manager
     * @param _manager The manager to remove
     */
    function removeManager(address _manager) external onlyOwner {
        delete managers[_manager];
    }

    /**
     * @notice Prepares a fee change. Fee increases are subject to a minimum delay of 12 weeks, while fee reductions can be executed immediately.
     * @dev reducing fees = increasing the denominator
     * @param _fees The new fee denominators
     */
    function planFeeChange(Fees memory _fees) external onlyOwner {
        checkFeeLimits(_fees);

        // if at least one fee increases, enforce minimum delay
        if (
            _isFractionAGreater(
                _fees.tokenFeeNumerator,
                _fees.tokenFeeDenominator,
                defaultTokenFeeNumerator,
                defaultTokenFeeDenominator
            ) ||
            _isFractionAGreater(
                _fees.crowdinvestingFeeNumerator,
                _fees.crowdinvestingFeeDenominator,
                defaultCrowdinvestingFeeNumerator,
                defaultCrowdinvestingFeeDenominator
            ) ||
            _isFractionAGreater(
                _fees.privateOfferFeeNumerator,
                _fees.privateOfferFeeDenominator,
                defaultPrivateOfferFeeNumerator,
                defaultPrivateOfferFeeDenominator
            )
        ) {
            require(
                _fees.validityDate > block.timestamp + 12 weeks,
                "Fee change must be at least 12 weeks in the future"
            );
        }
        proposedDefaultFees = _fees;
        emit ChangeProposed(_fees);
    }

    /**
     * @notice Executes a fee change that has been planned before
     */
    function executeFeeChange() external onlyOwner {
        require(
            block.timestamp >= proposedDefaultFees.validityDate,
            "Fee change must be executed after the change time"
        );
        defaultTokenFeeNumerator = proposedDefaultFees.tokenFeeNumerator;
        defaultTokenFeeDenominator = proposedDefaultFees.tokenFeeDenominator;
        defaultCrowdinvestingFeeNumerator = proposedDefaultFees.crowdinvestingFeeNumerator;
        defaultCrowdinvestingFeeDenominator = proposedDefaultFees.crowdinvestingFeeDenominator;
        defaultPrivateOfferFeeNumerator = proposedDefaultFees.privateOfferFeeNumerator;
        defaultPrivateOfferFeeDenominator = proposedDefaultFees.privateOfferFeeDenominator;
        emit SetFee(
            defaultTokenFeeNumerator,
            defaultTokenFeeDenominator,
            defaultCrowdinvestingFeeNumerator,
            defaultCrowdinvestingFeeDenominator,
            defaultPrivateOfferFeeNumerator,
            defaultPrivateOfferFeeDenominator
        );
        delete proposedDefaultFees;
    }

    /**
     * @notice Sets a new fee collector
     * @param _tokenFeeCollector The new fee collector
     */
    function setFeeCollectors(
        address _tokenFeeCollector,
        address _crowdinvestingFeeCollector,
        address _personalOfferFeeCollector
    ) external onlyOwner {
        require(_tokenFeeCollector != address(0), "Fee collector cannot be 0x0");
        defaultTokenFeeCollector = _tokenFeeCollector;
        require(_crowdinvestingFeeCollector != address(0), "Fee collector cannot be 0x0");
        defaultCrowdinvestingFeeCollector = _crowdinvestingFeeCollector;
        require(_personalOfferFeeCollector != address(0), "Fee collector cannot be 0x0");
        defaultPrivateOfferFeeCollector = _personalOfferFeeCollector;
        emit FeeCollectorsChanged(_tokenFeeCollector, _crowdinvestingFeeCollector, _personalOfferFeeCollector);
    }

    /**
     * Compares two fractions and returns true if the first one is greater than the second one
     * @param aNumerator numerator in fraction aNumerator/aDenominator
     * @param aDenominator denominator in fraction aNumerator/aDenominator
     * @param bNumerator numerator in fraction bNumerator/bDenominator
     * @param bDenominator denominator in fraction bNumerator/bDenominator
     */
    function _isFractionAGreater(
        uint32 aNumerator,
        uint32 aDenominator,
        uint32 bNumerator,
        uint32 bDenominator
    ) internal pure returns (bool) {
        return uint256(aNumerator) * bDenominator > uint256(bNumerator) * aDenominator;
    }

    /**
     * @notice Checks if the given fee settings are valid
     * @param _fees The fees to check
     */
    function checkFeeLimits(Fees memory _fees) internal pure {
        require(
            _fees.tokenFeeDenominator > 0 &&
                _fees.crowdinvestingFeeDenominator > 0 &&
                _fees.privateOfferFeeDenominator > 0,
            "Denominator cannot be 0"
        );
        require(
            !_isFractionAGreater(
                _fees.tokenFeeNumerator,
                _fees.tokenFeeDenominator,
                MAX_TOKEN_FEE_NUMERATOR,
                MAX_TOKEN_FEE_DENOMINATOR
            ),
            "Token fee must be equal or less 5%"
        );
        require(
            !_isFractionAGreater(
                _fees.crowdinvestingFeeNumerator,
                _fees.crowdinvestingFeeDenominator,
                MAX_CONTINUOUS_FUNDRAISING_FEE_NUMERATOR,
                MAX_CONTINUOUS_FUNDRAISING_FEE_DENOMINATOR
            ),
            "Crowdinvesting fee must be equal or less 10%"
        );
        require(
            !_isFractionAGreater(
                _fees.privateOfferFeeNumerator,
                _fees.privateOfferFeeDenominator,
                MAX_PERSONAL_INVITE_FEE_NUMERATOR,
                MAX_PERSONAL_INVITE_FEE_DENOMINATOR
            ),
            "PrivateOffer fee must be equal or less 5%"
        );
    }

    /**
     * @notice Sets a custom fee for a specific token
     * @param _token The token for which the custom fee should be set
     * @param _fees The custom fee
     */
    function setCustomFee(address _token, Fees memory _fees) external onlyManager {
        checkFeeLimits(_fees);
        require(_token != address(0), "Token cannot be 0x0");
        require(_fees.validityDate > block.timestamp, "Custom fee expiry time must be in the future");
        customFees[_token] = _fees;
        emit SetCustomFee(
            _token,
            _fees.tokenFeeNumerator,
            _fees.tokenFeeDenominator,
            _fees.crowdinvestingFeeNumerator,
            _fees.crowdinvestingFeeDenominator,
            _fees.privateOfferFeeNumerator,
            _fees.privateOfferFeeDenominator,
            _fees.validityDate
        );
    }

    /**
     * @notice removes a custom fee entry for a specific token
     * @param _token The token for which the custom fee should be removed
     */
    function removeCustomFee(address _token) external onlyManager {
        delete customFees[_token];
        emit RemoveCustomFee(_token);
    }

    /**
     * set `_feeCollector` as the token fee collector for `_token`
     * @param _token the token for which the fee collector is set
     * @param _feeCollector the address that will receive the token fees
     */
    function setCustomTokenFeeCollector(address _token, address _feeCollector) external onlyManager {
        require(_feeCollector != address(0), "Fee collector cannot be 0x0");
        require(_token != address(0), "Token cannot be 0x0");
        customTokenFeeCollector[_token] = _feeCollector;
        emit SetCustomTokenFeeCollector(_token, _feeCollector);
    }

    /**
     *  set `_feeCollector` as the crowdinvesting fee collector for `_token`
     * @param _token the token for which the fee collector is set
     * @param _feeCollector the address that will receive the crowdinvesting fees
     */
    function setCustomCrowdinvestingFeeCollector(address _token, address _feeCollector) external onlyManager {
        require(_feeCollector != address(0), "Fee collector cannot be 0x0");
        require(_token != address(0), "Token cannot be 0x0");
        customCrowdinvestingFeeCollector[_token] = _feeCollector;
        emit SetCustomCrowdinvestingFeeCollector(_token, _feeCollector);
    }

    /**
     * set `_feeCollector` as the private offer fee collector for `_token`
     * @param _token the token for which the fee collector is set
     * @param _feeCollector the address that will receive the private offer fees
     */
    function setCustomPrivateOfferFeeCollector(address _token, address _feeCollector) external onlyManager {
        require(_feeCollector != address(0), "Fee collector cannot be 0x0");
        require(_token != address(0), "Token cannot be 0x0");
        customPrivateOfferFeeCollector[_token] = _feeCollector;
        emit SetCustomPrivateOfferFeeCollector(_token, _feeCollector);
    }

    /**
     * Reset the token fee collector for `_token` to the default fee collector
     * @param _token the token for which the custom fee collector is removed
     */
    function removeCustomTokenFeeCollector(address _token) external onlyManager {
        delete customTokenFeeCollector[_token];
        emit RemoveCustomTokenFeeCollector(_token);
    }

    /**
     * Reset the crowdinvesting fee collector for `_token` to the default fee collector
     * @param _token the token for which the custom fee collector is removed
     */
    function removeCustomCrowdinvestingFeeCollector(address _token) external onlyManager {
        delete customCrowdinvestingFeeCollector[_token];
        emit RemoveCustomCrowdinvestingFeeCollector(_token);
    }

    /**
     * Reset the private offer fee collector for `_token` to the default fee collector
     * @param _token the token for which the custom fee collector is removed
     */
    function removeCustomPrivateOfferFeeCollector(address _token) external onlyManager {
        delete customPrivateOfferFeeCollector[_token];
        emit RemoveCustomPrivateOfferFeeCollector(_token);
    }

    /**
     * @notice Returns the token fee collector for a given token
     * @param _token The token to return the token fee collector for
     * @return The fee collector
     */
    function tokenFeeCollector(address _token) public view override(IFeeSettingsV2) returns (address) {
        if (customTokenFeeCollector[_token] != address(0)) {
            return customTokenFeeCollector[_token];
        }
        return defaultTokenFeeCollector;
    }

    /**
     * @notice Returns the crowdinvesting fee collector for a given token
     * @param _token The token to return the crowdinvesting fee collector for
     * @return The fee collector
     */
    function crowdinvestingFeeCollector(address _token) public view override(IFeeSettingsV2) returns (address) {
        if (customCrowdinvestingFeeCollector[_token] != address(0)) {
            return customCrowdinvestingFeeCollector[_token];
        }
        return defaultCrowdinvestingFeeCollector;
    }

    /**
     * @notice Returns the private offer fee collector for a given token
     * @param _token The token to return the private offer fee collector for
     * @return The fee collector
     */
    function privateOfferFeeCollector(address _token) public view override(IFeeSettingsV2) returns (address) {
        if (customPrivateOfferFeeCollector[_token] != address(0)) {
            return customPrivateOfferFeeCollector[_token];
        }
        return defaultPrivateOfferFeeCollector;
    }

    /**
     * General linear fee calculation function
     * @param amount how many erc20 tokens are transferred
     * @param numerator fee numerator
     * @param denominator fee denominator
     */
    function _fee(uint256 amount, uint32 numerator, uint32 denominator) internal pure returns (uint256) {
        return (amount * numerator) / denominator;
    }

    function tokenFee(uint256 _tokenAmount, address _token) public view override(IFeeSettingsV2) returns (uint256) {
        uint256 baseFee = _fee(_tokenAmount, defaultTokenFeeNumerator, defaultTokenFeeDenominator);
        if (customFees[_token].validityDate > block.timestamp) {
            uint256 customFee = _fee(
                _tokenAmount,
                customFees[_token].tokenFeeNumerator,
                customFees[_token].tokenFeeDenominator
            );
            if (customFee < baseFee) {
                return customFee;
            }
        }
        return baseFee;
    }

    /**
     * Calculates the fee for a given currency amount in Crowdinvesting (v5) or ContinuousFundraising (v4)
     * @param _currencyAmount how much currency is raised
     * @param _token the token that is sold through the crowdinvesting
     * @return the fee
     */
    function crowdinvestingFee(
        uint256 _currencyAmount,
        address _token
    ) public view override(IFeeSettingsV2) returns (uint256) {
        uint256 baseFee = _fee(_currencyAmount, defaultCrowdinvestingFeeNumerator, defaultCrowdinvestingFeeDenominator);
        if (customFees[_token].validityDate > block.timestamp) {
            uint256 customFee = _fee(
                _currencyAmount,
                customFees[_token].crowdinvestingFeeNumerator,
                customFees[_token].crowdinvestingFeeDenominator
            );
            if (customFee < baseFee) {
                return customFee;
            }
        }
        return baseFee;
    }

    /**
     * Calculates the fee for a given currency amount in PrivateOffer (v5) or PersonalInvite (v4)
     * @param _currencyAmount how much currency is raised
     * @return the fee
     */
    function privateOfferFee(
        uint256 _currencyAmount,
        address _token
    ) public view override(IFeeSettingsV2) returns (uint256) {
        uint256 baseFee = _fee(_currencyAmount, defaultPrivateOfferFeeNumerator, defaultPrivateOfferFeeDenominator);
        if (customFees[_token].validityDate > block.timestamp) {
            uint256 customFee = _fee(
                _currencyAmount,
                customFees[_token].privateOfferFeeNumerator,
                customFees[_token].privateOfferFeeDenominator
            );
            if (customFee < baseFee) {
                return customFee;
            }
        }
        return baseFee;
    }

    /**
     * @dev Specify where the implementation of owner() is located
     * @return The owner of the contract
     */
    function owner() public view override(OwnableUpgradeable, IFeeSettingsV1, IFeeSettingsV2) returns (address) {
        return OwnableUpgradeable.owner();
    }

    modifier onlyManager() {
        require(managers[_msgSender()], "Only managers can call this function");
        _;
    }

    /**
     * @notice This contract implements the ERC165 interface in order to enable other contracts to query which interfaces this contract implements.
     * @dev See https://eips.ethereum.org/EIPS/eip-165
     * @return `true` for supported interfaces, otherwise `false`
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165Upgradeable, IFeeSettingsV1, IFeeSettingsV2) returns (bool) {
        return
            interfaceId == type(IFeeSettingsV1).interfaceId || // we implement IFeeSettingsV1 for backwards compatibility
            interfaceId == type(IFeeSettingsV2).interfaceId || // we implement IFeeSettingsV2
            ERC165Upgradeable.supportsInterface(interfaceId); // default implementation that enables further querying
    }

    /**
     * @notice Returns the default token fee collector
     * @dev this is a compatibility function for IFeeSettingsV1. It enables older token contracts to use the new fee settings contract.
     * @dev as IFeeSettingsV1 only supports a single fee collector, we can not inquire the token address. Therefore, we return the default fee collector.
     * @return The token fee collector
     */
    function feeCollector() external view override(IFeeSettingsV1) returns (address) {
        return defaultTokenFeeCollector;
    }

    /**
     * @notice Returns the fee for a given token amount
     * @dev Custom fees are only applied correctly when this function is called from the token contract itself.
     * To calculate fees when calling from a different address, use `tokenFee(uint256, address)` instead.
     */
    function tokenFee(uint256 _tokenAmount) external view override(IFeeSettingsV1) returns (uint256) {
        return tokenFee(_tokenAmount, _msgSender());
    }

    /**
     * @notice calculate the fee for a given currency amount in Crowdinvesting (formerly ContinuousFundraising)
     * @dev this is a compatibility function for IFeeSettingsV1. It enables older token contracts to use the new fee settings contract.
     * @param _currencyAmount The amount of currency to calculate the fee for
     */
    function continuousFundraisingFee(
        uint256 _currencyAmount
    ) external view override(IFeeSettingsV1) returns (uint256) {
        return crowdinvestingFee(_currencyAmount, address(0));
    }

    /**
     * @notice calculate the fee for a given currency amount in PrivateOffer (formerly PersonalInvite)
     * @dev this is a compatibility function for IFeeSettingsV1. It enables older token contracts to use the new fee settings contract.
     * @param _currencyAmount The amount of currency to calculate the fee for
     */
    function personalInviteFee(uint256 _currencyAmount) external view override(IFeeSettingsV1) returns (uint256) {
        return privateOfferFee(_currencyAmount, address(0));
    }

    /**
     * @dev both Ownable and ERC2771Context have a _msgSender() function, so we need to override and select which one to use.
     */
    function _msgSender() internal view override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (address) {
        return ERC2771ContextUpgradeable._msgSender();
    }

    /**
     * @dev both Ownable and ERC2771Context have a _msgData() function, so we need to override and select which one to use.
     */
    function _msgData() internal view override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (bytes calldata) {
        return ERC2771ContextUpgradeable._msgData();
    }
}
