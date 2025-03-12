// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./interfaces/VBep20Interface.sol";
import "./interfaces/OracleInterface.sol";

contract ResilientOracle is OwnableUpgradeable, PausableUpgradeable, ResilientOracleInterface {
    uint256 public constant INVALID_PRICE = 0;

    BoundValidatorInterface public boundValidator;

    /**
     * @dev oracle role, we have 3 roles at the moment
     * MAIN: The most trustworthy price source
     * PIVOT: Not so trustworthy price source, used as a loose sanity checker
     * FALLBACK: The backup source when main oracle price is invalidated
     */
    enum OracleRole {
        MAIN,
        PIVOT,
        FALLBACK
    }

    struct TokenConfig {
        /// @notice asset address
        address asset;
        /// @notice `oracles` stores the oracles in the order of: [main, pivot, fallback],
        /// it can be indexed with enum OracleRole value
        address[3] oracles;
        /// @notice `enableFlagsForOracles` stores the oracle enable statuses
        /// for each oracle in the same order as `oracles`
        bool[3] enableFlagsForOracles;
    }

    mapping(address => TokenConfig) private tokenConfigs;

    event GlobalEnable(bool indexed isEnable);
    event TokenConfigAdded(
        address indexed asset,
        address indexed mainOracle,
        address indexed pivotOracle,
        address fallbackOracle
    );
    event OracleSet(address indexed asset, address indexed oracle, uint256 indexed role);
    event OracleEnabled(address indexed asset, uint256 indexed role, bool indexed enable);

    modifier notNullAddress(address someone) {
        require(someone != address(0), "can't be zero address");
        _;
    }

    /**
     * @notice Check whether token config exist by checking whether vToken is zero address
     * @dev vToken can't be set to zero, so it's suitable to be used to check
     * @param asset asset address
     */
    modifier checkTokenConfigExistance(address asset) {
        require(tokenConfigs[asset].asset != address(0), "token config must exist");
        _;
    }

    function initialize(BoundValidatorInterface _boundValidator) public initializer {
        require(address(_boundValidator) != address(0), "invaliud bound validator address");
        boundValidator = _boundValidator;

        __Ownable_init();
        __Pausable_init();
    }

    /**
     * @notice Pause protocol
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause protocol
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Get token config by vToken address
     * @param vToken vtoken address
     */
    function getTokenConfig(address vToken) external view returns (TokenConfig memory) {
        address asset = VBep20Interface(vToken).underlying();
        return tokenConfigs[asset];
    }

    /**
     * @notice Get oracle & enabling status by vToken address
     * @param vToken vtoken address
     * @param role oracle role
     */
    function getOracle(address vToken, OracleRole role) public view returns (address oracle, bool enabled) {
        address asset = VBep20Interface(vToken).underlying();
        oracle = tokenConfigs[asset].oracles[uint256(role)];
        enabled = tokenConfigs[asset].enableFlagsForOracles[uint256(role)];
    }

    /**
     * @notice Batch set token configs
     * @param tokenConfigs_ token config array
     */
    function setTokenConfigs(TokenConfig[] memory tokenConfigs_) external onlyOwner {
        require(tokenConfigs_.length != 0, "length can't be 0");
        for (uint256 i = 0; i < tokenConfigs_.length; i++) {
            setTokenConfig(tokenConfigs_[i]);
        }
    }

    /**
     * @notice Set single token configs, vToken MUST HAVE NOT be added before, and main oracle MUST NOT be zero address
     * @param tokenConfig token config struct
     */
    function setTokenConfig(
        TokenConfig memory tokenConfig
    ) public onlyOwner notNullAddress(tokenConfig.asset) notNullAddress(tokenConfig.oracles[uint256(OracleRole.MAIN)]) {
        tokenConfigs[tokenConfig.asset] = tokenConfig;
        emit TokenConfigAdded(
            tokenConfig.asset,
            tokenConfig.oracles[uint256(OracleRole.MAIN)],
            tokenConfig.oracles[uint256(OracleRole.PIVOT)],
            tokenConfig.oracles[uint256(OracleRole.FALLBACK)]
        );
    }

    /**
     * @notice Set oracle of any type for the input vToken, input vToken MUST exist
     * @param asset asset address
     * @param oracle oracle address
     * @param role oracle role
     */
    function setOracle(
        address asset,
        address oracle,
        OracleRole role
    ) external onlyOwner notNullAddress(asset) checkTokenConfigExistance(asset) {
        require(!(oracle == address(0) && role == OracleRole.MAIN), "can't set zero address to main oracle");
        tokenConfigs[asset].oracles[uint256(role)] = oracle;
        emit OracleSet(asset, oracle, uint256(role));
    }

    /**
     * @notice Enable/disable oracle for the input vToken, input vToken MUST exist
     * @param asset asset address
     * @param role oracle role
     * @param enable expected status
     */
    function enableOracle(
        address asset,
        OracleRole role,
        bool enable
    ) external onlyOwner notNullAddress(asset) checkTokenConfigExistance(asset) {
        tokenConfigs[asset].enableFlagsForOracles[uint256(role)] = enable;
        emit OracleEnabled(asset, uint256(role), enable);
    }

    /**
     * @notice Currently it calls the updateTwap
     * @param vToken vToken address
     */
    function updatePrice(address vToken) external override {
        (address pivotOracle, bool pivotOracleEnabled) = getOracle(vToken, OracleRole.PIVOT);
        if (pivotOracle != address(0) && pivotOracleEnabled) {
            //if PIVOT oracle is PythOrcle it will revert so we need to catch the revert
            try TwapInterface(pivotOracle).updateTwap(vToken) returns (uint256 _price) {} catch {}
        }
    }

    /**
     * @notice Get price of underlying asset of the input vToken, check flow:
     * - check the global pausing status
     * - check price from main oracle against pivot oracle
     * - check price from fallback oracle against pivot oracle or main oracle if fails
     * @param vToken vToken address
     * @return price USD price in 18 decimals
     */
    function getUnderlyingPrice(address vToken) external view override returns (uint256) {
        require(!paused(), "resilient oracle is paused");

        uint256 price = _getMainOraclePrice(vToken);
        if (price == INVALID_PRICE) {
            price = _getFallbackOraclePrice(vToken);
        }

        require(price != INVALID_PRICE, "invalid resilient oracle price");
        return price;
    }

    /**
     * @notice This function won't revert when price is 0, because the fallback oracle may come to play later
     * @param vToken vToken address
     * @return price USD price in 18 decimals
     */
    function _getMainOraclePrice(address vToken) internal view returns (uint256) {
        uint256 price = INVALID_PRICE;

        (address mainOracle, bool mainOracleEnabled) = getOracle(vToken, OracleRole.MAIN);
        if (mainOracleEnabled && mainOracle != address(0)) {
            try OracleInterface(mainOracle).getUnderlyingPrice(vToken) returns (uint256 mainOraclePrice) {
                price = mainOraclePrice;

                (address pivotOracle, bool pivotOracleEnabled) = getOracle(vToken, OracleRole.PIVOT);

                if (pivotOracleEnabled && pivotOracle != address(0)) {
                    try OracleInterface(pivotOracle).getUnderlyingPrice(vToken) returns (uint256 pivotPrice) {
                        if (pivotPrice != INVALID_PRICE) {
                            bool isPriceValid = boundValidator.validatePriceWithAnchorPrice(vToken, price, pivotPrice);
                            if (!isPriceValid) {
                                return INVALID_PRICE;
                            }
                        }
                    } catch {}
                }
            } catch {}
        }

        return price;
    }

    /**
     * @notice This function won't revert when price is 0, because the getUnderlyingPrice checks if pirce is > 0
     * @param vToken vToken address
     * @return price USD price in 18 decimals
     */
    function _getFallbackOraclePrice(address vToken) internal view returns (uint256) {
        uint256 price = INVALID_PRICE;
        bool compareWithMain = false;

        (address fallbackOracle, bool fallbackEnabled) = getOracle(vToken, OracleRole.FALLBACK);
        if (fallbackEnabled && fallbackOracle != address(0)) {
            try OracleInterface(fallbackOracle).getUnderlyingPrice(vToken) returns (uint256 fallbackOraclePrice) {
                price = fallbackOraclePrice;

                (address pivotOracle, bool pivotOracleEnabled) = getOracle(vToken, OracleRole.PIVOT);
                if (pivotOracleEnabled && pivotOracle != address(0)) {
                    try OracleInterface(pivotOracle).getUnderlyingPrice(vToken) returns (uint256 pivotPrice) {
                        if (pivotPrice != INVALID_PRICE) {
                            bool isPriceValid = boundValidator.validatePriceWithAnchorPrice(vToken, price, pivotPrice);
                            if (!isPriceValid) {
                                compareWithMain = true;
                            }
                        } else {
                            compareWithMain = true;
                        }
                    } catch {
                        compareWithMain = true;
                    }
                } else {
                    compareWithMain = true;
                }
            } catch {}
        }

        if (compareWithMain) {
            (address mainOracle, bool mainOracleEnabled) = getOracle(vToken, OracleRole.MAIN);
            if (mainOracleEnabled && mainOracle != address(0)) {
                try OracleInterface(mainOracle).getUnderlyingPrice(vToken) returns (uint256 mainOraclePrice) {
                    bool isPriceValid = boundValidator.validatePriceWithAnchorPrice(vToken, price, mainOraclePrice);
                    if (!isPriceValid) {
                        return INVALID_PRICE;
                    } else {
                        price = mainOraclePrice;
                    }
                } catch {
                    price = INVALID_PRICE;
                }
            } else {
                price = INVALID_PRICE;
            }
        }

        return price;
    }
}
