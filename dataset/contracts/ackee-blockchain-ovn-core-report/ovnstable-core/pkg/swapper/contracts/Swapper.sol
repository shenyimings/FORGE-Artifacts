// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./ISwapPlace.sol";
import "./ISwapper.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Swapper is ISwapper, Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant OPERATOR = keccak256("OPERATOR");

    using SafeERC20Upgradeable for IERC20Upgradeable;

    // ---  fields

    // token's pair to swap place info list
    mapping(address => mapping(address => SwapPlaceInfo[])) public swapPlaceInfos;

    // swap place type to swap place address
    mapping(string => address) public swapPlaces;

    // pool address to swap place type
    mapping(address => string) public poolSwapPlaceTypes;

    // default split parts for common swap request
    uint256 public defaultSplitPartsAmount;

    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        _grantRole(OPERATOR, msg.sender);
    }

    function _authorizeUpgrade(address newImplementation)
    internal
    onlyRole(UPGRADER_ROLE)
    override
    {}

    // ---  modifiers

    modifier onlyOperator() {
        require(hasRole(OPERATOR, msg.sender), "Restricted to operators");
        _;
    }

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Restricted to admins");
        _;
    }

    // --- setters

    function setParams(uint256 _defaultSplitPartsAmount) external {
        defaultSplitPartsAmount = _defaultSplitPartsAmount;
        emit ParamsUpdated(defaultSplitPartsAmount);
    }

    function swapPlaceInfoRegister(
        address token0,
        address token1,
        address pool,
        string calldata swapPlaceType
    ) public onlyOperator {
        require(token0 != address(0), "Zero address not allowed");
        require(token1 != address(0), "Zero address not allowed");
        require(pool != address(0), "Zero address not allowed");

        SwapPlaceInfo[] storage swapPlaceInfoList = swapPlaceInfos[token0][token1];
        if (swapPlaceInfoList.length > 0) {
            for (uint i; i < swapPlaceInfoList.length; i++) {
                require(swapPlaceInfoList[i].pool != pool, "Already in list");
            }
        }

        poolSwapPlaceTypes[pool] = swapPlaceType;
        swapPlaceInfos[token0][token1].push(SwapPlaceInfo(pool, swapPlaceType));
        swapPlaceInfos[token1][token0].push(SwapPlaceInfo(pool, swapPlaceType));

        emit SwapPlaceInfoRegistered(token0, token1, pool, swapPlaceType);
    }

    function swapPlaceInfoLength(address token0, address token1) external view returns (uint256) {
        return swapPlaceInfos[token0][token1].length;
    }

    function swapPlaceInfoRemove(address token0, address token1, address pool) external onlyOperator {
        require(token0 != address(0), "Zero address not allowed");
        require(token1 != address(0), "Zero address not allowed");
        require(pool != address(0), "Zero address not allowed");

        SwapPlaceInfo[] storage swapPlaceInfoList = swapPlaceInfos[token0][token1];
        require(swapPlaceInfoList.length > 0, "Cant remove from empty array");

        uint256 index;
        for (uint i; i < swapPlaceInfoList.length; i++) {
            if (swapPlaceInfoList[i].pool == pool) {
                index = i;
                break;
            }
        }

        swapPlaceInfoList[index] = swapPlaceInfoList[swapPlaceInfoList.length - 1];
        swapPlaceInfoList.pop();

        swapPlaceInfoList = swapPlaceInfos[token1][token0];
        swapPlaceInfoList[index] = swapPlaceInfoList[swapPlaceInfoList.length - 1];
        swapPlaceInfoList.pop();

        emit SwapPlaceInfoRemoved(token0, token1, pool);
    }

    function swapPlaceRegister(string calldata swapPlaceType, address swapPlace) external onlyOperator {
        require(swapPlace != address(0), "Zero address not allowed");
        swapPlaces[swapPlaceType] = swapPlace;
        emit SwapPlaceRegistered(swapPlaceType, swapPlace);
    }

    function swapPlaceRemove(string calldata swapPlaceType) external onlyOperator {
        delete swapPlaces[swapPlaceType];
        emit SwapPlaceRemoved(swapPlaceType);
    }

    // ---  structures

    struct CalcContext {
        address swapPlace;
        address pool;

        uint256 committedIndex;
        uint256 committedIn;
        uint256 committedOut;

        uint256 lastIn;
        uint256 lastOut;
        uint256 lastOutNormalized;
    }


    // ---  logic

    function swapCommon(address tokenIn, address tokenOut, uint256 amountIn) external override returns (uint256) {
        SwapParams memory params = SwapParams(
            tokenIn,
            tokenOut,
            amountIn,
            0,
            defaultSplitPartsAmount
        );
        return swap(params);
    }


    function swap(SwapParams memory params) public override returns (uint256) {
        SwapRoute[] memory swapRoutes = swapPath(params);
        return swapBySwapRoutes(params, swapRoutes);
    }

    function swapExact(SwapParamsExact memory params) external override returns (uint256) {
        string memory swapPlaceType = poolSwapPlaceTypes[params.pool];
        require(bytes(swapPlaceType).length > 0, "Not found swapPlaceType for pool");

        address swapPlace = swapPlaces[swapPlaceType];
        require(swapPlace != address(0x0), "Not found swapPlaceType for pool");

        SwapRoute[] memory swapRoutes = new SwapRoute[](1);
        swapRoutes[0] = SwapRoute(
            params.tokenIn,
            params.tokenOut,
            params.amountIn,
            0,
            swapPlace,
            params.pool
        );
        return swapBySwapRoutes(
            params.tokenIn, params.amountIn,
            params.tokenOut, params.amountOutMin,
            swapRoutes
        );

    }

    function swapBySwapRoutes(SwapParams memory params, SwapRoute[] memory swapRoutes) public override returns (uint256) {
        return swapBySwapRoutes(
            params.tokenIn, params.amountIn,
            params.tokenOut, params.amountOutMin,
            swapRoutes
        );
    }

    function swapBySwapRoutes(
        address tokenIn, uint256 amountIn,
        address tokenOut, uint256 amountOutMin,
        SwapRoute[] memory swapRoutes
    ) public override returns (uint256) {
        IERC20Upgradeable(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        uint256 amountOut;
        for (uint i; i < swapRoutes.length; i++) {
            amountOut += swapRoutes[i].amountOut;
        }
        require(amountOut >= amountOutMin, "amountOut less than needed");

        for (uint i; i < swapRoutes.length; i++) {
            SwapRoute memory swapRoute = swapRoutes[i];
            IERC20Upgradeable(swapRoute.tokenIn).safeTransfer(swapRoute.swapPlace, swapRoute.amountIn);
            ISwapPlace(swapRoute.swapPlace).swap(swapRoute);
        }

        uint256 balanceOut = IERC20(tokenOut).balanceOf(address(this));
        require(
            balanceOut >= amountOutMin,
            "balanceOut lower than amountOutMin"
        );

        IERC20Upgradeable(tokenOut).safeTransfer(msg.sender, balanceOut);
        return balanceOut;
    }

    function getAmountOut(SwapParams memory params) external override view returns (uint256) {
        SwapRoute[] memory swapRoutes = swapPath(params);
        uint256 amountOut;
        for (uint i; i < swapRoutes.length; i++) {
            amountOut += swapRoutes[i].amountOut;
        }
        return amountOut;
    }

    function swapPath(SwapParams memory params) public override view returns (SwapRoute[] memory) {
        SwapPlaceInfo[] storage swapPlaceInfoList = swapPlaceInfos[params.tokenIn][params.tokenOut];
        require(swapPlaceInfoList.length > 0, "Cant find swapPlace by tokens");

        uint256 iterations;
        if (swapPlaceInfoList.length == 1) {
            iterations = 1;
        } else if (params.partsAmount == 0) {
            iterations = swapPlaceInfoList.length;
        } else {
            iterations = params.partsAmount;
        }
        require(params.amountIn >= iterations, "amountIn must be non less than iterations");
        uint256 iterationAmount = params.amountIn / iterations;


        // 1. setup context
        CalcContext[] memory contexts = prepareContext(
            swapPlaceInfoList,
            params,
            iterationAmount
        );

        // 2. find best swaps
        uint256 lastCommittedIndex = calc(
            params,
            iterations,
            iterationAmount,
            contexts
        );

        // 4. recalc amounts if delta exists
        uint256 lostAmountInDelta = params.amountIn - iterationAmount * iterations;
        if (lostAmountInDelta > 0) {
            recalcLastCommittedWithDelta(
                params,
                iterationAmount,
                contexts,
                lastCommittedIndex,
                lostAmountInDelta
            );
        }

        // 5. make swaps list
        SwapRoute[] memory swapRoutes = makeSwapRoutes(
            params,
            contexts
        );

        return swapRoutes;
    }

    function prepareContext(
        SwapPlaceInfo[] storage swapPlaceInfoList,
        SwapParams memory params,
        uint256 iterationAmount
    ) internal view returns (CalcContext[] memory contexts){
        contexts = new CalcContext[](swapPlaceInfoList.length);
        for (uint i; i < swapPlaceInfoList.length; i++) {
            SwapPlaceInfo memory swapPlaceInfo = swapPlaceInfoList[i];
            address swapPlace = swapPlaces[swapPlaceInfo.swapPlaceType];

            uint256 amountOut = ISwapPlace(swapPlace).getAmountOut(
                params.tokenIn,
                params.tokenOut,
                iterationAmount,
                swapPlaceInfoList[i].pool
            );
            contexts[i] = CalcContext(
                swapPlace,
                swapPlaceInfo.pool,
                0, 0, 0,
                iterationAmount,
                amountOut,
                amountOut
            );
        }
    }

    function calc(
        SwapParams memory params,
        uint256 iterations,
        uint256 iterationAmount,
        CalcContext[] memory contexts
    ) internal view returns (uint256){

        uint256 lastCommittedIndex;
        uint256 iterationsDone;
        while (true) {
            // 2. Find best swap and commit
            uint256 committedIndex = findBestSwapAndCommit(contexts);

            iterationsDone++;
            if (iterationsDone >= iterations) {
                lastCommittedIndex = committedIndex;
                break;
            }

            // 3. Recalc next amount out for committed
            uint256 amountIn;
            uint256 multiplayer = contexts[committedIndex].committedIndex + 1;
            if (multiplayer == iterations) {
                amountIn = params.amountIn;
            } else {
                amountIn = iterationAmount * multiplayer;
            }

            uint256 amountOut = ISwapPlace(contexts[committedIndex].swapPlace).getAmountOut(
                params.tokenIn,
                params.tokenOut,
                amountIn,
                contexts[committedIndex].pool
            );

            contexts[committedIndex].lastIn = amountIn;
            contexts[committedIndex].lastOut = amountOut;
            contexts[committedIndex].lastOutNormalized = amountOut / multiplayer;

        }

        return lastCommittedIndex;
    }

    function findBestSwapAndCommit(CalcContext[] memory contexts) internal pure returns (uint256){
        uint256 maxValue = 0;
        uint256 maxValueIndex = 0;
        for (uint256 i; i < contexts.length; i++) {
            uint256 value = contexts[i].lastOutNormalized;
            if (maxValue < value) {
                maxValue = value;
                maxValueIndex = i;
            }
        }

        contexts[maxValueIndex].committedIn = contexts[maxValueIndex].lastIn;
        contexts[maxValueIndex].committedOut = contexts[maxValueIndex].lastOut;
        contexts[maxValueIndex].committedIndex++;

        return maxValueIndex;
    }

    function recalcLastCommittedWithDelta(
        SwapParams memory params,
        uint256 iterationAmount,
        CalcContext[] memory contexts,
        uint256 committedIndex,
        uint256 lostAmountInDelta
    ) internal view {

        uint256 multiplayer = contexts[committedIndex].committedIndex;
        uint256 amountIn = iterationAmount * multiplayer + lostAmountInDelta;

        uint256 amountOut = ISwapPlace(contexts[committedIndex].swapPlace).getAmountOut(
            params.tokenIn,
            params.tokenOut,
            amountIn,
            contexts[committedIndex].pool
        );

        contexts[committedIndex].committedIn = amountIn;
        contexts[committedIndex].committedOut = amountOut;

    }

    function makeSwapRoutes(
        SwapParams memory params,
        CalcContext[] memory contexts
    ) internal pure returns (SwapRoute[] memory swapRoutes){

        uint256 nonZeroSwaps;
        for (uint i; i < contexts.length; i++) {
            CalcContext memory context = contexts[i];
            if (context.committedIndex != 0) {
                nonZeroSwaps++;
            }
        }


        swapRoutes = new SwapRoute[](nonZeroSwaps);
        uint swapRoutesIndex;
        for (uint i; i < contexts.length; i++) {
            CalcContext memory context = contexts[i];
            if (context.committedIndex == 0) {
                continue;
            }
            swapRoutes[swapRoutesIndex] = SwapRoute(
                params.tokenIn,
                params.tokenOut,
                context.committedIn,
                context.committedOut,
                context.swapPlace,
                context.pool
            );
            swapRoutesIndex++;
        }
    }

}
