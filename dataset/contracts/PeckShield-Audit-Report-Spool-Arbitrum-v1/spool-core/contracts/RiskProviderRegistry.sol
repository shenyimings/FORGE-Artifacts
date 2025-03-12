// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "./interfaces/IRiskProviderRegistry.sol";
import "./shared/SpoolOwnable.sol";

import "./interfaces/IFeeHandler.sol";

/**
 * @dev Implementation of the {IRiskProviderRegistry} interface.
 *
 * @notice
 * This implementation acts as a simple registry contract permitting a
 * designated party (the owner) to toggle the validity of providers within
 * it.
 *
 * In turn, these providers are able to set a risk score for the strategies
 * they want that needs to be in the range [-10.0, 10.0].
 */
contract RiskProviderRegistry is IRiskProviderRegistry, SpoolOwnable {
    /* ========== CONSTANTS ========== */

    /// @notice Maximum strategy risk score
    /// @dev Risk score has 1 decimal accuracy, so value 100 represents 10.0
    uint8 public constant MAX_RISK_SCORE = 100;

    /* ========== STATE VARIABLES ========== */

    /// @notice fee handler contracts, to manage the risk provider fees
    IFeeHandler public immutable feeHandler;

    /// @notice Association of a risk provider to a strategy and finally to a risk score [0, 100]
    mapping(address => mapping(address => uint8)) private _risk;

    /// @notice Status of a risk provider
    mapping(address => bool) private _provider;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @notice Initialize contract, set spool owner
     *
     * @param _feeHandler to manage the risk provider fees
     * @param _spoolOwner the spool owner contract
     */
    constructor(
        IFeeHandler _feeHandler,
        ISpoolOwner _spoolOwner
    )
        SpoolOwnable(_spoolOwner)
    {
        require(address(_feeHandler) != address(0), "RiskProviderRegistry::constructor: Fee Handler address cannot be 0");
        feeHandler = _feeHandler;
    }

    /* ========== VIEWS ========== */

    /**
     * @notice Returns whether or not a particular address is a risk provider.
     *
     * @param provider provider address to check
     *
     * @return boolean indicating entry in _provider
     */
    function isProvider(address provider) public view override returns (bool) {
        return _provider[provider];
    }

    /**
     * @notice Returns the risk scores of strateg(s) as defined by
     * the provided risk provider.
     *
     * @param riskProvider risk provider to get risk scores for 
     * @param strategies list of strategies that the risk provider has set risks for
     *
     * @return risk scores
     */
    function getRisks(address riskProvider, address[] memory strategies)
        external
        view
        override
        returns (uint8[] memory)
    {
        uint8[] memory riskScores = new uint8[](strategies.length);
        for (uint256 i = 0; i < strategies.length; i++) {
            riskScores[i] = _risk[riskProvider][strategies[i]];
        }

        return riskScores;
    }

    /**
     * @notice Returns the risk score of a particular strategy as defined by
     * the provided risk provider.
     *
     * @param riskProvider risk provider to get risk scores for 
     * @param strategy strategy that the risk provider has set risk for
     *
     * @return risk score
     */
    function getRisk(address riskProvider, address strategy)
        external
        view
        override
        returns (uint8)
    {
        return _risk[riskProvider][strategy];
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice Allows the risk score of multiple strategies to be set.
     *
     * @dev
     * Requirements:
     * - the caller must be a risk provider
     * - input arrays must have the same length
     *
     * @param strategies list of strategies to set risk scores for
     * @param riskScores list of risk scores to set on each strategy
     */
    function setRisks(address[] memory strategies, uint8[] memory riskScores) external {
        require(
            isProvider(msg.sender),
            "RiskProviderRegistry::setRisks: Insufficient Privileges"
        );

        require(
            strategies.length == riskScores.length,
            "RiskProviderRegistry::setRisks: Strategies and risk scores lengths don't match"
        );    

        for (uint i = 0; i < strategies.length; i++) {
            _setRisk(strategies[i], riskScores[i]);
        }
    }

    /**
     * @notice Allows the risk score of a strategy to be set.
     *
     * @dev
     * Requirements:
     * - the caller must be a valid risk provider
     *
     * @param strategy strategy to set risk score for
     * @param riskScore risk score to set on the strategy
     */
    function setRisk(address strategy, uint8 riskScore) external {
        require(
            isProvider(msg.sender),
            "RiskProviderRegistry::setRisk: Insufficient Privileges"
        );

        _setRisk(strategy, riskScore);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /**
     * @notice Allows the inclusion of a new provider to the registry.
     *
     * @dev
     * Emits a {ProviderAdded} event indicating the newly added provider.
     *
     * Requirements:
     * - the caller must be the owner of the contract
     * - the provider must not already exist in the registry
     *
     * @param provider provider to add
     * @param fee fee to go to provider
     */
    function addProvider(address provider, uint16 fee) external onlyOwner {
        require(
            !_provider[provider],
            "RiskProviderRegistry::addProvider: Provider already exists"
        );

        _provider[provider] = true;
        feeHandler.setRiskProviderFee(provider, fee);

        emit ProviderAdded(provider);
    }

    /**
     * @notice Allows the removal of an existing provider to the registry.
     *
     * @dev
     * Emits a {ProviderRemoved} event indicating the address of the removed provider.
     * provider fee is also set to 0.
     *
     * Requirements:
     *
     * - the caller must be the owner of the contract
     * - the provider must already exist in the registry
     *
     * @param provider provider to remove
     */
    function removeProvider(address provider) external onlyOwner {
        require(
            _provider[provider],
            "RiskProviderRegistry::removeProvider: Provider does not exist"
        );

        _provider[provider] = false;
        feeHandler.setRiskProviderFee(provider, 0);

        emit ProviderRemoved(provider);
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    /**
     * @notice Allows the risk score of a strategy to be set (internal)
     *
     * @dev
     * Emits a {RiskAssessed} event indicating the assessor of the score and the
     * newly set risk score of the strategy
     *
     * Requirements:
     *
     * - the risk score must be less than 100
     *
     * @param strategy strategy to set risk score for
     * @param riskScore risk score to set on the strategy
     */
    function _setRisk(address strategy, uint8 riskScore) private {
        require(riskScore <= MAX_RISK_SCORE, "RiskProviderRegistry::_setRisk: Risk score too big");

        _risk[msg.sender][strategy] = riskScore;

        emit RiskAssessed(msg.sender, strategy, riskScore);
    }
}
