// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/pools/ILpToken.sol";
import "../interfaces/ICurveHandler.sol";
import "../interfaces/ICurveRegistryCache.sol";
import "../interfaces/vendor/IWETH.sol";
import "../interfaces/vendor/ICurvePoolV1.sol";
import "../interfaces/vendor/ICurvePoolV0.sol";
import "../interfaces/vendor/ICurvePoolV2.sol";
import "../interfaces/vendor/ICurvePoolV1Eth.sol";
import "../interfaces/vendor/ICurvePoolV2Eth.sol";
import "../interfaces/IController.sol";

/// @notice This contract acts as a wrapper for depositing and removing liquidity to and from Curve pools.
/// Please be aware of the following:
/// - This contract accepts WETH and unwraps it for Curve pool deposits
/// - This contract should only be used through delegate calls for deposits and withdrawals
/// - Slippage from deposits and withdrawals is handled in the ConicPool (do not use handler elsewhere)
contract CurveHandler is ICurveHandler {
    using SafeERC20 for IERC20;

    address internal constant _ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    IWETH internal constant _WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    // Normal calls to `exchange` functions will read various state variables, resulting in
    // gas fees that are always in the double-digit thousand gas.
    // On the other hand, a reentrant call will only read a single warm variable (100 gas)
    // and call a contract already touched, so it will use vastly less than 5k gas.
    // In practice, reentrant calls appear to use ~1.5k gas while non-reentrant
    // calls use ~60k gas.
    // We are better off setting this value a little too high compared to the ~1.5k estimate
    // to make sure that we always prevent reentrant calls.
    uint256 internal constant LOCK_GAS_THRESHOLD = 5_000;

    // Recent factory pools are deployed using a minimal proxy pattern pointing to
    // 1. `0x847ee1227a9900b73aeeb3a47fac92c52fd54ed9`
    // 2. `0x94b4dfd9ba5865cc931195c99a2db42f3fc5d45b`
    // The exact bytecodes are:
    // 1. `0x363d3d373d3d3d363d73847ee1227a9900b73aeeb3a47fac92c52fd54ed95af43d82803e903d91602b57fd5bf3`
    // 2. `0x363d3d373d3d3d363d7394b4dfd9ba5865cc931195c99a2db42f3fc5d45b5af43d82803e903d91602b57fd5bf3`
    // that yield the following hashes, against which we can compare the result of `EXTCODEHASH` to
    // check whether it is from this factory or not.
    // This check is very local, so we do not include it in the `CurveRegistryCache`.
    // Note that other pools may have `price_oracle` that do not check for reentrancy, so we cannot
    // rely on this check for any pool with the `price_oracle` function.
    // We only include the hash codes of pools created through factories, because
    // the bytecode is otherwise slightly different for each pool
    // Since this is only a optimization for gas purposes, we choose to make this constant,
    // even if that means that we might miss this optimization for new factories deployed later.
    bytes32 internal constant ETH_FACTORY_POOL_CODE_HASH_1 =
        0x9e28a09452d2354fc4e15e3244dde27cbc4d52f12a10b91f2ca755b672bfa9be;
    bytes32 internal constant ETH_FACTORY_POOL_CODE_HASH_2 =
        0x3429b8decaf6b79a2721e434f60c3c47b9961fdba16eb6ac6c50d3690ac25276;

    IController internal immutable controller;

    constructor(address controller_) {
        controller = IController(controller_);
    }

    /// @notice Deposits single sided liquidity into a Curve pool
    /// @dev This supports both v1 and v2 (crypto) pools.
    /// @param _curvePool Curve pool to deposit into
    /// @param _token Asset to deposit
    /// @param _amount Amount of asset to deposit
    function deposit(address _curvePool, address _token, uint256 _amount) public override {
        ICurveRegistryCache registry_ = controller.curveRegistryCache();
        bool isETH = _isETH(_curvePool, _token);
        if (!registry_.hasCoinDirectly(_curvePool, isETH ? _ETH_ADDRESS : _token)) {
            address intermediate = registry_.basePool(_curvePool);
            require(intermediate != address(0), "CurveHandler: intermediate not found");
            address lpToken = registry_.lpToken(intermediate);
            uint256 balanceBefore = ILpToken(lpToken).balanceOf(address(this));
            _addLiquidity(intermediate, _amount, _token);
            _token = lpToken;
            _amount = ILpToken(_token).balanceOf(address(this)) - balanceBefore;
        }
        _addLiquidity(_curvePool, _amount, _token);
    }

    /// @notice Withdraws single sided liquidity from a Curve pool
    /// @param _curvePool Curve pool to withdraw from
    /// @param _token Underlying asset to withdraw
    /// @param _amount Amount of Curve LP tokens to withdraw
    function withdraw(address _curvePool, address _token, uint256 _amount) external override {
        ICurveRegistryCache registry_ = controller.curveRegistryCache();
        bool isETH = _isETH(_curvePool, _token);
        if (!registry_.hasCoinDirectly(_curvePool, isETH ? _ETH_ADDRESS : _token)) {
            address intermediate = registry_.basePool(_curvePool);
            require(intermediate != address(0), "CurveHandler: intermediate not found");
            address lpToken = registry_.lpToken(intermediate);
            uint256 balanceBefore = ILpToken(lpToken).balanceOf(address(this));
            _removeLiquidity(_curvePool, _amount, lpToken);
            _curvePool = intermediate;
            _amount = ILpToken(lpToken).balanceOf(address(this)) - balanceBefore;
        }

        _removeLiquidity(_curvePool, _amount, _token);
    }

    function isReentrantCall(address _curvePool) public override returns (bool) {
        // In this version, curve pools have a price oracle that has a reentrancy lock
        // so this call will only succeed if we are not in a reentrant call
        // This is cheaper than trying to do an exchange
        bytes32 codeHash = _curvePool.codehash;
        if (codeHash == ETH_FACTORY_POOL_CODE_HASH_1 || codeHash == ETH_FACTORY_POOL_CODE_HASH_2) {
            try ICurvePoolV2Eth(_curvePool).price_oracle() {
                return false;
            } catch {
                return true;
            }
        }

        uint256 interfaceVersion_ = controller.curveRegistryCache().interfaceVersion(_curvePool);
        bool ethIndexFirst_ = _isEthIndexFirst(_curvePool);

        // If we don't have any other way to check for reentrancy, we try to do a swap
        // with 0 amount, which can behave in 3 ways depending on the state and the pool:
        // 1. If it succeeds, there was definitely no lock in place, so the call is not reentrant
        // 2. If it fails, it can fail in 2 ways:
        //   a. It fails because some pools do not allow to swap 0 amount. This also means that the call is non-reentrant
        //   b. It fails because there is a reentrancy lock in place, which means that the call is reentrant
        // Checking for case 1 is trivial. For case 2a vs 2b, we check the amount of gas consumed by the call.
        // Some more details about the values are given in the comments of `LOCK_GAS_THRESHOLD`
        uint256 gasUsed;
        uint256 currentGasLeft = gasleft();
        if (interfaceVersion_ == 2) {
            try
                ICurvePoolV2Eth(_curvePool).exchange(
                    ethIndexFirst_ ? uint256(0) : uint256(1),
                    ethIndexFirst_ ? uint256(1) : uint256(0),
                    uint256(0),
                    uint256(0)
                )
            {
                return false;
            } catch {
                gasUsed = currentGasLeft - gasleft();
            }
        } else {
            try
                ICurvePoolV1Eth(_curvePool).exchange(
                    ethIndexFirst_ ? int128(0) : int128(1),
                    ethIndexFirst_ ? int128(1) : int128(0),
                    uint256(0),
                    uint256(0)
                )
            {
                return false;
            } catch {
                gasUsed = currentGasLeft - gasleft();
            }
        }

        return gasUsed < LOCK_GAS_THRESHOLD;
    }

    /// @notice Validates if a given Curve pool is currently in reentrancy
    /// @dev Reverts if it is in reentrancy
    /// @param _curvePool Curve pool to validate
    function reentrancyCheck(address _curvePool) external override {
        require(!isReentrantCall(_curvePool), "CurveHandler: reentrant call");
    }

    function _removeLiquidity(
        address _curvePool,
        uint256 _amount, // Curve LP token amount
        address _token // underlying asset to withdraw
    ) internal {
        bool isETH = _isETH(_curvePool, _token);
        int128 index = controller.curveRegistryCache().coinIndex(
            _curvePool,
            isETH ? _ETH_ADDRESS : _token
        );

        uint256 balanceBeforeWithdraw = address(this).balance;

        uint256 interfaceVersion_ = controller.curveRegistryCache().interfaceVersion(_curvePool);
        if (interfaceVersion_ == 0) {
            _version_0_remove_liquidity_one_coin(_curvePool, _amount, index);
        } else if (interfaceVersion_ == 1) {
            ICurvePoolV1(_curvePool).remove_liquidity_one_coin(_amount, index, 0);
        } else if (interfaceVersion_ == 2) {
            ICurvePoolV2(_curvePool).remove_liquidity_one_coin(
                _amount,
                uint256(uint128(index)),
                0,
                isETH,
                address(this)
            );
        } else {
            revert("CurveHandler: unsupported interface version");
        }

        if (isETH) {
            uint256 balanceIncrease = address(this).balance - balanceBeforeWithdraw;
            _wrapWETH(balanceIncrease);
        }
    }

    /// Version 0 pools don't have a `remove_liquidity_one_coin` function.
    /// So we work around this by calling `removing_liquidity`
    /// and then swapping all the coins to the target
    function _version_0_remove_liquidity_one_coin(
        address _curvePool,
        uint256 _amount,
        int128 _index
    ) internal {
        ICurveRegistryCache registry_ = controller.curveRegistryCache();
        uint256 coins = registry_.nCoins(_curvePool);
        if (coins == 2) {
            uint256[2] memory min_amounts;
            ICurvePoolV0(_curvePool).remove_liquidity(_amount, min_amounts);
        } else if (coins == 3) {
            uint256[3] memory min_amounts;
            ICurvePoolV0(_curvePool).remove_liquidity(_amount, min_amounts);
        } else if (coins == 4) {
            uint256[4] memory min_amounts;
            ICurvePoolV0(_curvePool).remove_liquidity(_amount, min_amounts);
        } else if (coins == 5) {
            uint256[5] memory min_amounts;
            ICurvePoolV0(_curvePool).remove_liquidity(_amount, min_amounts);
        } else if (coins == 6) {
            uint256[6] memory min_amounts;
            ICurvePoolV0(_curvePool).remove_liquidity(_amount, min_amounts);
        } else if (coins == 7) {
            uint256[7] memory min_amounts;
            ICurvePoolV0(_curvePool).remove_liquidity(_amount, min_amounts);
        } else if (coins == 8) {
            uint256[8] memory min_amounts;
            ICurvePoolV0(_curvePool).remove_liquidity(_amount, min_amounts);
        } else {
            revert("CurveHandler: unsupported coins");
        }

        for (uint256 i = 0; i < coins; i++) {
            if (i == uint256(int256(_index))) continue;
            address[] memory coins_ = registry_.coins(_curvePool);
            address coin_ = coins_[i];
            uint256 balance_ = IERC20(coin_).balanceOf(address(this));
            if (balance_ == 0) continue;
            IERC20(coin_).safeApprove(_curvePool, balance_);
            ICurvePoolV0(_curvePool).exchange(int128(int256(i)), _index, balance_, 0);
        }
    }

    function _wrapWETH(uint256 amount) internal {
        _WETH.deposit{value: amount}();
    }

    function _unwrapWETH(uint256 amount) internal {
        _WETH.withdraw(amount);
    }

    function _addLiquidity(
        address _curvePool,
        uint256 _amount, // amount of asset to deposit
        address _token // asset to deposit
    ) internal {
        bool isETH = _isETH(_curvePool, _token);
        if (!isETH) {
            IERC20(_token).safeIncreaseAllowance(_curvePool, _amount);
        }

        ICurveRegistryCache registry_ = controller.curveRegistryCache();
        uint256 index = uint128(registry_.coinIndex(_curvePool, isETH ? _ETH_ADDRESS : _token));
        uint256 coins = registry_.nCoins(_curvePool);
        if (coins == 2) {
            uint256[2] memory amounts;
            amounts[index] = _amount;
            if (isETH) {
                _unwrapWETH(_amount);
                ICurvePoolV1Eth(_curvePool).add_liquidity{value: _amount}(amounts, 0);
            } else {
                ICurvePoolV1(_curvePool).add_liquidity(amounts, 0);
            }
        } else if (coins == 3) {
            uint256[3] memory amounts;
            amounts[index] = _amount;
            if (isETH) {
                _unwrapWETH(_amount);
                ICurvePoolV1Eth(_curvePool).add_liquidity{value: _amount}(amounts, 0);
            } else {
                ICurvePoolV1(_curvePool).add_liquidity(amounts, 0);
            }
        } else if (coins == 4) {
            uint256[4] memory amounts;
            amounts[index] = _amount;
            if (isETH) {
                _unwrapWETH(_amount);
                ICurvePoolV1Eth(_curvePool).add_liquidity{value: _amount}(amounts, 0);
            } else {
                ICurvePoolV1(_curvePool).add_liquidity(amounts, 0);
            }
        } else if (coins == 5) {
            uint256[5] memory amounts;
            amounts[index] = _amount;
            if (isETH) {
                _unwrapWETH(_amount);
                ICurvePoolV1Eth(_curvePool).add_liquidity{value: _amount}(amounts, 0);
            } else {
                ICurvePoolV1(_curvePool).add_liquidity(amounts, 0);
            }
        } else if (coins == 6) {
            uint256[6] memory amounts;
            amounts[index] = _amount;
            if (isETH) {
                _unwrapWETH(_amount);
                ICurvePoolV1Eth(_curvePool).add_liquidity{value: _amount}(amounts, 0);
            } else {
                ICurvePoolV1(_curvePool).add_liquidity(amounts, 0);
            }
        } else if (coins == 7) {
            uint256[7] memory amounts;
            amounts[index] = _amount;
            if (isETH) {
                _unwrapWETH(_amount);
                ICurvePoolV1Eth(_curvePool).add_liquidity{value: _amount}(amounts, 0);
            } else {
                ICurvePoolV1(_curvePool).add_liquidity(amounts, 0);
            }
        } else if (coins == 8) {
            uint256[8] memory amounts;
            amounts[index] = _amount;
            if (isETH) {
                _unwrapWETH(_amount);
                ICurvePoolV1Eth(_curvePool).add_liquidity{value: _amount}(amounts, 0);
            } else {
                ICurvePoolV1(_curvePool).add_liquidity(amounts, 0);
            }
        } else {
            revert("invalid number of coins for curve pool");
        }
    }

    function _isETH(address pool, address token) internal view returns (bool) {
        return
            token == address(_WETH) &&
            controller.curveRegistryCache().hasCoinDirectly(pool, _ETH_ADDRESS);
    }

    function _isETH(address pool) internal view returns (bool) {
        return controller.curveRegistryCache().hasCoinDirectly(pool, _ETH_ADDRESS);
    }

    function _isEthIndexFirst(address pool) internal view returns (bool) {
        return controller.curveRegistryCache().coinIndex(pool, address(_WETH)) == int128(0);
    }
}
