// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { ERC165Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import { MathUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import { EnumerableSetUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

import { IIndexInit } from "../interfaces/IIndexInit.sol";
import { IIndexLimits } from "../interfaces/IIndexLimits.sol";
import { IIndexOracle } from "../interfaces/IIndexOracle.sol";
import { IIndexStrategy } from "../interfaces/IIndexStrategy.sol";
import { IIndexToken } from "../interfaces/IIndexToken.sol";
import { IFee, PerformanceFeeSuggestion } from "../interfaces/IFee.sol";
import { Constants } from "../libraries/Constants.sol";
import { Errors } from "../libraries/Errors.sol";
import { SwapAdapter } from "../libraries/SwapAdapter.sol";
import { MintingData, MintParams, BurnParams, ManagementParams } from "../Common.sol";
import { IndexStrategyMint } from "../libraries/IndexStrategyMint.sol";
import { IndexStrategyBurn } from "../libraries/IndexStrategyBurn.sol";
import { IndexStrategyManagement } from "../libraries/IndexStrategyManagement.sol";
import { IndexStrategyUtils } from "../libraries/IndexStrategyUtils.sol";
import { IndexStrategyStorage, IndexStrategyStorageLib } from "../libraries/IndexStrategyStorageLib.sol";

/**
 * @title IndexStrategyUpgradeable
 * @dev An abstract contract that implements various interfaces and extends other contracts, providing functionality for managing index strategies.
 */
abstract contract IndexStrategyUpgradeable is
    ERC165Upgradeable,
    ReentrancyGuardUpgradeable,
    ContextUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    IIndexInit,
    IIndexLimits,
    IIndexStrategy,
    IFee
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SwapAdapter for SwapAdapter.Setup;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    address public wNATIVE;

    address[] public whitelistedTokens;
    IIndexToken public indexToken;

    address[] public components;
    mapping(address => uint256) public weights; // A mapping from `component` to its `weight`.
    mapping(address => address[]) public routers; // A mapping from `token` to its list of `routers`.
    mapping(address => SwapAdapter.DEX) public dexs; // A mapping from `router` to its type of `DEX`.
    mapping(address => mapping(address => mapping(address => SwapAdapter.PairData))) // A mapping from `router`, `tokenIn` and `tokenOut` to `PairData`.
        public pairData;

    IIndexOracle public oracle;
    uint256 public equityValuationLimit;

    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    uint256[8] private __gap;

    /**
     * @dev Modifier to allow only whitelisted tokens to access a function.
     * @param token The address of the token to check.
     */
    modifier onlyWhitelistedToken(address token) {
        if (!isTokenWhitelisted(token)) {
            revert Errors.Index_NotWhitelistedToken(token);
        }

        _;
    }

    /**
     * @dev Modifier to check if the equity valuation limit has not been reached.
     */
    modifier whenNotReachedEquityValuationLimit() {
        _;

        if (equityValuation(true, true) > equityValuationLimit) {
            revert Errors.Index_ExceedEquityValuationLimit();
        }
    }

    /**
     * @dev Calculates the equity valuation.
     * @param maximize Boolean value to maximize.
     * @param includeAmmPrice Boolean value to include AMM price.
     * @return The equity valuation as a uint256.
     */
    function equityValuation(bool maximize, bool includeAmmPrice)
        public
        view
        override
        returns (uint256)
    {
        uint256 totalSupply = indexToken.totalSupply();

        if (totalSupply == 0) {
            return 0;
        }

        uint256 amountWNATIVEUnit = _getAmountWNATIVEFromExactIndexView(
            Constants.PRECISION
        );

        uint256 priceWNATIVE = oracle.getPrice(
            wNATIVE,
            maximize,
            includeAmmPrice
        );

        return
            (amountWNATIVEUnit * priceWNATIVE * totalSupply) /
            (Constants.DECIMALS * Constants.PRECISION);
    }

    /**
     * @dev Initializes the IndexStrategyUpgradeable contract.
     * @param initParams The parameters needed for initialization.
     */
    // solhint-disable-next-line
    function __IndexStrategyUpgradeable_init(
        IndexStrategyInitParams calldata initParams
    ) internal onlyInitializing {
        __ERC165_init();
        __ReentrancyGuard_init();
        __Context_init();
        __Ownable_init();
        __Pausable_init();

        wNATIVE = initParams.wNATIVE;

        indexToken = IIndexToken(initParams.indexToken);

        for (uint256 i = 0; i < initParams.components.length; i++) {
            components.push(initParams.components[i].token);

            _setWeight(
                initParams.components[i].token,
                initParams.components[i].weight
            );
        }

        for (uint256 i = 0; i < initParams.swapRoutes.length; i++) {
            addSwapRoute(
                initParams.swapRoutes[i].token,
                initParams.swapRoutes[i].router,
                initParams.swapRoutes[i].dex,
                initParams.swapRoutes[i].pairData
            );
        }

        addWhitelistedTokens(initParams.whitelistedTokens);

        setOracle(initParams.oracle);

        setEquityValuationLimit(initParams.equityValuationLimit);

        setFeeSuggester(initParams.feeSuggester);

        addAddressesToFeeWhitelist(initParams.feeWhitelist);
    }

    function reinitialize(address feeSuggester, address[] calldata feeWhitelist)
        external
        reinitializer(2)
    {
        setFeeSuggester(feeSuggester);
        addAddressesToFeeWhitelist(feeWhitelist);
    }

    /**
     * @dev Pauses the contract, preventing certain functions from being called.
     */
    function pause() external onlyOwner {
        super._pause();
    }

    /**
     * @dev Unpauses the contract, allowing the paused functions to be called.
     */
    function unpause() external onlyOwner {
        super._unpause();
    }

    /**
     * @dev Checks if a particular interface is supported by the contract.
     * @param interfaceId The interface identifier.
     * @return A boolean value indicating whether the interface is supported.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            interfaceId == type(IIndexStrategy).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev It ensures that Ether is only received from wNATIVE and not from any other addresses.
     */
    receive() external payable {
        if (msg.sender != wNATIVE) {
            revert Errors.Index_ReceivedNativeTokenDirectly();
        }
    }

    /**
     * @dev Mints index tokens in exchange for a specified token.
     * @param token The address of the token to be swapped.
     * @param amountTokenMax The maximum amount of the token to be swapped.
     * @param amountIndexMin The minimum amount of index tokens to be minted.
     * @param recipient The address that will receive the minted index tokens.
     * @param affiliateId The id of the affiliate who faciliated the index minting
     * @return amountIndex The amount of index tokens minted.
     * @return amountToken The amount of tokens swapped.
     */
    function mintIndexFromToken(
        address token,
        uint256 amountTokenMax,
        uint256 amountIndexMin,
        address recipient,
        uint64 affiliateId
    )
        external
        nonReentrant
        whenNotPaused
        onlyWhitelistedToken(token)
        whenNotReachedEquityValuationLimit
        returns (uint256 amountIndex, uint256 amountToken)
    {
        (amountIndex, amountToken) = IndexStrategyMint.mintIndexFromToken(
            MintParams(
                token,
                amountTokenMax,
                amountIndexMin,
                recipient,
                _msgSender(),
                wNATIVE,
                components,
                indexToken
            ),
            pairData,
            dexs,
            weights,
            routers
        );

        emit Mint(
            _msgSender(),
            recipient,
            token,
            amountToken,
            amountIndex,
            affiliateId
        );
    }

    /**
     * @dev Mints index tokens by swapping the native asset (such as Ether).
     * @param amountIndexMin The minimum amount of index tokens expected to be minted.
     * @param recipient The address that will receive the minted index tokens.
     * @param affiliateId The id of the affiliate who faciliated the index minting
     * @return amountIndex The actual amount of index tokens minted.
     * @return amountNATIVE The actual amount of the native asset swapped.
     */
    function mintIndexFromNATIVE(
        uint256 amountIndexMin,
        address recipient,
        uint64 affiliateId
    )
        external
        payable
        nonReentrant
        whenNotPaused
        whenNotReachedEquityValuationLimit
        onlyWhitelistedToken(NATIVE)
        returns (uint256 amountIndex, uint256 amountNATIVE)
    {
        (amountIndex, amountNATIVE) = IndexStrategyMint.mintIndexFromNATIVE(
            MintParams(
                NATIVE,
                msg.value,
                amountIndexMin,
                recipient,
                _msgSender(),
                wNATIVE,
                components,
                indexToken
            ),
            pairData,
            dexs,
            weights,
            routers
        );

        emit Mint(
            _msgSender(),
            recipient,
            NATIVE,
            amountNATIVE,
            amountIndex,
            affiliateId
        );
    }

    /**
     * @dev Burns index tokens in exchange for a specified token.
     * @param token The address of the token to be received.
     * @param amountTokenMin The minimum amount of tokens to be received.
     * @param amountIndex The amount of index tokens to be burned.
     * @param recipient The address that will receive the tokens.
     * @return amountToken The amount of tokens received.
     */
    function burnExactIndexForToken(
        address token,
        uint256 amountTokenMin,
        uint256 amountIndex,
        address recipient
    )
        external
        nonReentrant
        whenNotPaused
        onlyWhitelistedToken(token)
        returns (uint256 amountToken)
    {
        amountToken = IndexStrategyBurn.burnExactIndexForToken(
            BurnParams(
                token,
                amountTokenMin,
                amountIndex,
                recipient,
                _msgSender(),
                wNATIVE,
                components,
                indexToken
            ),
            pairData,
            dexs,
            weights,
            routers
        );
        emit Burn(_msgSender(), recipient, token, amountToken, amountIndex);
    }

    /**
     * @dev Burns index tokens in exchange for the native asset (such as Ether).
     * @param amountNATIVEMin The minimum amount of the native asset expected to be received.
     * @param amountIndex The amount of index tokens to be burned.
     * @param recipient The address that will receive the native asset.
     * @return amountNATIVE The actual amount of the native asset received.
     */
    function burnExactIndexForNATIVE(
        uint256 amountNATIVEMin,
        uint256 amountIndex,
        address recipient
    )
        external
        nonReentrant
        whenNotPaused
        onlyWhitelistedToken(NATIVE)
        returns (uint256 amountNATIVE)
    {
        amountNATIVE = IndexStrategyBurn.burnExactIndexForNATIVE(
            BurnParams(
                NATIVE,
                amountNATIVEMin,
                amountIndex,
                recipient,
                _msgSender(),
                wNATIVE,
                components,
                indexToken
            ),
            pairData,
            dexs,
            weights,
            routers
        );

        emit Burn(_msgSender(), recipient, NATIVE, amountNATIVE, amountIndex);
    }

    /**
     * @dev Retrieves the amount of index tokens that will be minted for a specified token.
     * @param token The address of the token to be swapped.
     * @param amountTokenMax The maximum amount of the token to be swapped.
     * @return amountIndex The amount of index tokens that will be minted.
     * @return amountToken The amount of tokens to be swapped.
     */
    function getAmountIndexFromToken(address token, uint256 amountTokenMax)
        external
        onlyWhitelistedToken(token)
        returns (uint256 amountIndex, uint256 amountToken)
    {
        MintingData memory mintingData;

        (amountToken, , mintingData) = IndexStrategyMint
            .getMintingDataFromToken(
                MintParams(
                    token,
                    amountTokenMax,
                    0,
                    address(0),
                    _msgSender(),
                    wNATIVE,
                    components,
                    indexToken
                ),
                pairData,
                dexs,
                weights,
                routers
            );

        amountIndex = mintingData.amountIndex;
    }

    /**
     * @dev Retrieves the amount of index tokens that will be minted in exchange for the native asset (such as Ether).
     * @param amountNATIVEMax The maximum amount of the native asset that can be swapped.
     * @return amountIndex The estimated amount of index tokens that will be minted.
     * @return amountNATIVE The actual amount of the native asset that will be swapped.
     */
    function getAmountIndexFromNATIVE(uint256 amountNATIVEMax)
        external
        returns (uint256 amountIndex, uint256 amountNATIVE)
    {
        MintingData memory mintingData = IndexStrategyMint
            .getMintingDataFromWNATIVE(
                amountNATIVEMax,
                MintParams(
                    wNATIVE,
                    amountNATIVEMax,
                    0,
                    address(0),
                    _msgSender(),
                    wNATIVE,
                    components,
                    indexToken
                ),
                routers,
                pairData,
                dexs,
                weights
            );

        amountIndex = mintingData.amountIndex;
        amountNATIVE = mintingData.amountWNATIVETotal;
    }

    /**
     * @dev Retrieves the amount of tokens that will be received for a specified amount of index tokens.
     * @param token The address of the token to be received.
     * @param amountIndex The amount of index tokens to be burned.
     * @return amountToken The amount of tokens that will be received.
     */
    function getAmountTokenFromExactIndex(address token, uint256 amountIndex)
        external
        onlyWhitelistedToken(token)
        returns (uint256 amountToken)
    {
        uint256 amountWNATIVE = _getAmountWNATIVEFromExactIndex(amountIndex);

        (amountToken, ) = IndexStrategyUtils.getAmountOutMax(
            routers[token],
            amountWNATIVE,
            wNATIVE,
            token,
            dexs,
            pairData
        );
    }

    /**
     * @dev Retrieves the estimated amount of the native asset (such as Ether) that can be received by burning a specified amount of index tokens.
     * @param amountIndex The amount of index tokens to be burned.
     * @return amountNATIVE The estimated amount of the native asset that will be received.
     */
    function getAmountNATIVEFromExactIndex(uint256 amountIndex)
        external
        returns (uint256 amountNATIVE)
    {
        amountNATIVE = _getAmountWNATIVEFromExactIndex(amountIndex);
    }

    /**
     * @dev Rebalances the index strategy by adjusting the weights of the components.
     * @param targetWeights The target weights for each component.
     */
    function rebalance(uint256[] calldata targetWeights) external onlyOwner {
        IndexStrategyManagement.rebalance(
            ManagementParams(wNATIVE, components, indexToken, targetWeights),
            pairData,
            dexs,
            weights,
            routers
        );
    }

    /**
     * @dev Adds a component to the index strategy.
     * @param component The address of the component token.
     */
    function addComponent(address component) external onlyOwner {
        for (uint256 i = 0; i < components.length; i++) {
            if (components[i] == component) {
                revert Errors.Index_ComponentAlreadyExists(component);
            }
        }

        components.push(component);
    }

    /**
     * @dev Adds a swap route for swapping tokens.
     * @param token The address of the token to be swapped.
     * @param router The address of the router contract.
     * @param dex The type of decentralized exchange (DEX) used by the router.
     * @param _pairData The pair data for the router and tokens.
     */
    function addSwapRoute(
        address token,
        address router,
        SwapAdapter.DEX dex,
        SwapAdapter.PairData memory _pairData
    ) public onlyOwner {
        _addRouter(token, router);

        _setDEX(router, dex);

        _setPairData(router, token, wNATIVE, _pairData);
    }

    /**
     * @dev Adds multiple tokens to the whitelist.
     * @param tokens The addresses of the tokens to be added.
     */
    function addWhitelistedTokens(address[] memory tokens) public onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (!isTokenWhitelisted(tokens[i])) {
                whitelistedTokens.push(tokens[i]);
            }
        }
    }

    /**
     * @dev Removes a component from the index strategy.
     * @param component The address of the component token to be removed.
     */
    function removeComponent(address component) external onlyOwner {
        for (uint256 i = 0; i < components.length; i++) {
            if (components[i] == component) {
                if (weights[component] != 0) {
                    revert Errors.Index_ComponentHasNonZeroWeight(component);
                }

                components[i] = components[components.length - 1];
                components.pop();
                break;
            }
        }
    }

    /**
     * @dev Removes a swap route for swapping tokens.
     * @param token The address of the token to be swapped.
     * @param router The address of the router contract to be removed.
     */
    function removeSwapRoute(address token, address router) external onlyOwner {
        _removeRouter(token, router);

        _setPairData(
            router,
            token,
            wNATIVE,
            SwapAdapter.PairData(address(0), abi.encode(0))
        );
    }

    /**
     * @dev Removes multiple tokens from the whitelist.
     * @param tokens The addresses of the tokens to be removed.
     */
    function removeWhitelistedTokens(address[] memory tokens) public onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            for (uint256 j = 0; j < whitelistedTokens.length; j++) {
                if (whitelistedTokens[j] == tokens[i]) {
                    whitelistedTokens[j] = whitelistedTokens[
                        whitelistedTokens.length - 1
                    ];
                    whitelistedTokens.pop();
                    break;
                }
            }
        }
    }

    /**
     * @dev Sets the equity valuation limit for the index strategy.
     * @param _equityValuationLimit The new equity valuation limit.
     */
    function setEquityValuationLimit(uint256 _equityValuationLimit)
        public
        onlyOwner
    {
        equityValuationLimit = _equityValuationLimit;
    }

    /**
     * @dev Sets the oracle contract for the index strategy.
     * @param _oracle The address of the oracle contract.
     */
    function setOracle(address _oracle) public onlyOwner {
        oracle = IIndexOracle(_oracle);
    }

    /**
     * @dev Retrieves the addresses of all components in the index strategy.
     * @return An array of component addresses.
     */
    function allComponents() external view override returns (address[] memory) {
        return components;
    }

    /**
     * @dev Retrieves the addresses of all whitelisted tokens.
     * @return An array of whitelisted token addresses.
     */
    function allWhitelistedTokens() external view returns (address[] memory) {
        return whitelistedTokens;
    }

    /**
     * @dev Checks if a token is whitelisted.
     * @param token The address of the token to check.
     * @return bool Returns true if the token is whitelisted, false otherwise.
     */
    function isTokenWhitelisted(address token) public view returns (bool) {
        for (uint256 i = 0; i < whitelistedTokens.length; i++) {
            if (whitelistedTokens[i] == token) {
                return true;
            }
        }

        return false;
    }

    /**
     * @dev Calculates the amount of wNATIVE received from the exact index amount.
     * @param amountIndex The exact index amount.
     * @return amountWNATIVE The amount of wNATIVE received.
     */
    function _getAmountWNATIVEFromExactIndex(uint256 amountIndex)
        internal
        returns (uint256 amountWNATIVE)
    {
        for (uint256 i = 0; i < components.length; i++) {
            if (weights[components[i]] == 0) {
                continue;
            }

            uint256 amountComponent = (amountIndex * weights[components[i]]) /
                Constants.PRECISION;

            (uint256 amountWNATIVEOut, ) = IndexStrategyUtils.getAmountOutMax(
                routers[components[i]],
                amountComponent,
                components[i],
                wNATIVE,
                dexs,
                pairData
            );

            amountWNATIVE += amountWNATIVEOut;
        }
    }

    /**
     * @dev Calculates the amount of wNATIVE received from the exact index amount.
     * @param amountIndex The exact index amount.
     * @return amountWNATIVE The amount of wNATIVE received.
     */
    function _getAmountWNATIVEFromExactIndexView(uint256 amountIndex)
        internal
        view
        returns (uint256 amountWNATIVE)
    {
        for (uint256 i = 0; i < components.length; i++) {
            if (weights[components[i]] == 0) {
                continue;
            }

            uint256 amountComponent = (amountIndex * weights[components[i]]) /
                Constants.PRECISION;

            (uint256 amountWNATIVEOut, ) = IndexStrategyUtils
                .getAmountOutMaxView(
                    routers[components[i]],
                    amountComponent,
                    components[i],
                    wNATIVE,
                    dexs,
                    pairData
                );

            amountWNATIVE += amountWNATIVEOut;
        }
    }

    /**
     * @dev Sets the weight of a token.
     * @param token The token address.
     * @param weight The weight of the token.
     */
    function _setWeight(address token, uint256 weight) internal {
        weights[token] = weight;
    }

    /**
     * @dev Adds a router for a token.
     * @param token The token address.
     * @param router The router address.
     */
    function _addRouter(address token, address router) internal {
        if (token == address(0)) {
            revert Errors.Index_ZeroAddress();
        }

        for (uint256 i = 0; i < routers[token].length; i++) {
            if (routers[token][i] == router) {
                return;
            }
        }

        routers[token].push(router);
    }

    /**
     * @dev Sets the DEX (Decentralized Exchange) for a router.
     * @param router The router address.
     * @param dex The DEX to set.
     */
    function _setDEX(address router, SwapAdapter.DEX dex) internal {
        if (router == address(0)) {
            revert Errors.Index_ZeroAddress();
        }

        if (dexs[router] != SwapAdapter.DEX.None) {
            return;
        }

        dexs[router] = dex;
    }

    /**
     * @dev Sets the pair data for a router, token0, and token1.
     * @param router The router address.
     * @param token0 The first token address.
     * @param token1 The second token address.
     * @param _pairData The pair data to set.
     */
    function _setPairData(
        address router,
        address token0,
        address token1,
        SwapAdapter.PairData memory _pairData
    ) internal {
        if (token0 == address(0) || token1 == address(0)) {
            revert Errors.Index_ZeroAddress();
        }

        if (pairData[router][token0][token1].pair != address(0)) {
            return;
        }

        pairData[router][token0][token1] = _pairData;
        pairData[router][token1][token0] = _pairData;
    }

    /**
     * @dev Removes a router for a token.
     * @param token The token address.
     * @param router The router address to remove.
     */
    function _removeRouter(address token, address router) internal {
        for (uint256 i = 0; i < routers[token].length; i++) {
            if (routers[token][i] == router) {
                routers[token][i] = routers[token][routers[token].length - 1];
                routers[token].pop();
                break;
            }
        }
    }

    function suggestPerformanceFees(
        PerformanceFeeSuggestion[] calldata performanceFeeSuggestions,
        uint256 seqNum
    ) external {
        // assumptions about the performanceFeeSuggestions
        // 1. no suggestion in the array with tokensToMint == 0
        // 2. no 2 or more suggestions with the same affiliate address
        // 3. the number of our affiliates are low enough to update the strategyStorage.performanceFeeSuggestions
        //    in one transaction

        IndexStrategyStorage storage strategyStorage = IndexStrategyStorageLib
            .getStorage();

        address msgSender = _msgSender();
        if (msgSender != strategyStorage.feeSuggester && msgSender != owner())
            revert IFee.UnauthorizedPerformanceFeeSuggester();
        if (seqNum != strategyStorage.seqNum)
            revert IFee.IncorrectSeqNum(strategyStorage.seqNum);
        if (!areAllAffiliatorAddressesWhitelisted(performanceFeeSuggestions))
            revert IFee.UnauthorizedAffiliateAddress();

        // updating the performanceFeeSuggestions storage variable with the latest suggestions
        delete strategyStorage.performanceFeeSuggestions;
        uint256 performanceFeeSuggestionsLength = performanceFeeSuggestions
            .length;
        for (uint256 i; i < performanceFeeSuggestionsLength; ++i) {
            strategyStorage.performanceFeeSuggestions.push(
                performanceFeeSuggestions[i]
            );
        }
    }

    function getSuggestedPerformanceFee()
        external
        view
        returns (PerformanceFeeSuggestion[] memory performanceFeeSuggestions)
    {
        IndexStrategyStorage storage strategyStorage = IndexStrategyStorageLib
            .getStorage();

        return strategyStorage.performanceFeeSuggestions;
    }

    function approvePerformanceFees() external onlyOwner {
        IndexStrategyStorage storage strategyStorage = IndexStrategyStorageLib
            .getStorage();

        // rechecking if all affiliators are still whitelisted
        if (
            !areAllAffiliatorAddressesWhitelisted(
                strategyStorage.performanceFeeSuggestions
            )
        ) revert IFee.UnauthorizedAffiliateAddress();

        // mint tokens for affiliators
        uint256 indexTokenBalanceBeforeMinting = IERC20Upgradeable(indexToken)
            .totalSupply();
        uint256 performanceFeeSuggestionsLength = strategyStorage
            .performanceFeeSuggestions
            .length;
        for (uint256 i; i < performanceFeeSuggestionsLength; ++i) {
            indexToken.mint(
                strategyStorage.performanceFeeSuggestions[i].affiliateAddress,
                strategyStorage.performanceFeeSuggestions[i].tokenAmountToMint
            );
        }
        uint256 indexTokenBalanceAfterMinting = IERC20Upgradeable(indexToken)
            .totalSupply();

        // change the weight array
        uint256 componentsLength = components.length;
        for (uint256 i; i < componentsLength; ++i) {
            weights[components[i]] =
                (weights[components[i]] * indexTokenBalanceBeforeMinting) /
                indexTokenBalanceAfterMinting;
        }

        // increase seqNum and emit an event
        emit PerformanceFeeApproved(
            ++strategyStorage.seqNum,
            strategyStorage.performanceFeeSuggestions
        );

        // delete the current suggestions
        delete strategyStorage.performanceFeeSuggestions;
    }

    function setFeeSuggester(address newFeeSuggester) public onlyOwner {
        IndexStrategyStorage storage strategyStorage = IndexStrategyStorageLib
            .getStorage();
        strategyStorage.feeSuggester = newFeeSuggester;
    }

    function getFeeSuggester() external view returns (address feeSuggester) {
        IndexStrategyStorage storage strategyStorage = IndexStrategyStorageLib
            .getStorage();
        return strategyStorage.feeSuggester;
    }

    function addAddressesToFeeWhitelist(address[] calldata addressesToAdd)
        public
        onlyOwner
    {
        IndexStrategyStorage storage strategyStorage = IndexStrategyStorageLib
            .getStorage();
        uint256 addressesToAddLength = addressesToAdd.length;
        for (uint256 i; i < addressesToAddLength; ++i) {
            strategyStorage.feeWhitelist.add(addressesToAdd[i]);
        }
    }

    function removeAddressesFromFeeWhitelist(
        address[] calldata addressesToRemove
    ) external onlyOwner {
        IndexStrategyStorage storage strategyStorage = IndexStrategyStorageLib
            .getStorage();
        uint256 addressesToRemoveLength = addressesToRemove.length;
        for (uint256 i; i < addressesToRemoveLength; ++i) {
            strategyStorage.feeWhitelist.remove(addressesToRemove[i]);
        }
    }

    function getAddressesInFeeWhitelist()
        external
        view
        returns (address[] memory feeWhiteListToReturn)
    {
        IndexStrategyStorage storage strategyStorage = IndexStrategyStorageLib
            .getStorage();

        uint256 whitelistLength = strategyStorage.feeWhitelist.length();
        feeWhiteListToReturn = new address[](whitelistLength);
        for (uint256 i; i < whitelistLength; ++i) {
            feeWhiteListToReturn[i] = strategyStorage.feeWhitelist.at(i);
        }
    }

    function getSeqNum() external view returns (uint256) {
        return IndexStrategyStorageLib.getStorage().seqNum;
    }

    function areAllAffiliatorAddressesWhitelisted(
        PerformanceFeeSuggestion[] memory performanceFeeSuggestions
    ) internal view returns (bool) {
        IndexStrategyStorage storage strategyStorage = IndexStrategyStorageLib
            .getStorage();

        uint256 performanceFeeSuggestionsLength = performanceFeeSuggestions
            .length;
        for (uint256 i; i < performanceFeeSuggestionsLength; i++) {
            if (
                !strategyStorage.feeWhitelist.contains(
                    performanceFeeSuggestions[i].affiliateAddress
                )
            ) return false;
        }
        return true;
    }

    function getComponentsLength() public view returns (uint256) {
        return components.length;
    }
}
