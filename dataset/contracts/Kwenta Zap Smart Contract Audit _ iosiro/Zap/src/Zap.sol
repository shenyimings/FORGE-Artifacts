// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import {IERC20} from "./interfaces/IERC20.sol";
import {ISpotMarketProxy} from "./interfaces/ISpotMarketProxy.sol";
import {ZapErrors} from "./ZapErrors.sol";
import {ZapEvents} from "./ZapEvents.sol";

/// @title Zap contract for wrapping/unwrapping $USDC into $sUSD
/// via Synthetix v3 Andromeda Spot Market
/// @author JaredBorders (jaredborders@pm.me)
abstract contract Zap is ZapErrors, ZapEvents {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice keccak256 hash of expected name of $sUSDC synth
    /// @dev pre-computed to save gas during deployment:
    /// keccak256(abi.encodePacked("Synthetic USD Coin Spot Market"))
    bytes32 internal constant _HASHED_SUSDC_NAME =
        0xdb59c31a60f6ecfcb2e666ed077a3791b5c753b5a5e8dc5120f29367b94bbb22;

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice $USDC token contract address
    IERC20 internal immutable _USDC;

    /// @notice $sUSD token/synth contract address
    IERC20 internal immutable _SUSD;

    /// @notice $sUSDC token/synth contract address
    IERC20 internal immutable _SUSDC;

    /// @notice Synthetix v3 Spot Market ID for $sUSDC
    uint128 internal immutable _SUSDC_SPOT_MARKET_ID;

    /// @notice Synthetix v3 Spot Market Proxy contract address
    ISpotMarketProxy internal immutable _SPOT_MARKET_PROXY;

    /// @notice used to adjust $USDC decimals
    uint256 internal immutable _DECIMALS_FACTOR;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Zap constructor
    /// @dev will revert if any of the addresses are zero
    /// @dev will revert if the Synthetix v3 Spot Market ID for
    /// $sUSDC is incorrect
    /// @param _usdc $USDC token contract address
    /// @param _susd $sUSD token contract address
    /// @param _spotMarketProxy Synthetix v3 Spot Market Proxy
    /// contract address
    /// @param _sUSDCId Synthetix v3 Spot Market ID for $sUSDC
    constructor(
        address _usdc,
        address _susd,
        address _spotMarketProxy,
        uint128 _sUSDCId
    ) {
        if (_usdc == address(0)) revert USDCZeroAddress();
        if (_susd == address(0)) revert SUSDZeroAddress();
        if (_spotMarketProxy == address(0)) revert SpotMarketZeroAddress();

        _USDC = IERC20(_usdc);
        _SUSD = IERC20(_susd);
        _SPOT_MARKET_PROXY = ISpotMarketProxy(_spotMarketProxy);

        _DECIMALS_FACTOR = 10 ** (18 - IERC20(_usdc).decimals());

        if (
            keccak256(abi.encodePacked(_SPOT_MARKET_PROXY.name(_sUSDCId)))
                != _HASHED_SUSDC_NAME
        ) revert InvalidIdSUSDC(_sUSDCId);

        // id of $sUSDC is verified to be correct via the above
        // name comparison check
        _SUSDC_SPOT_MARKET_ID = _sUSDCId;
        _SUSDC = IERC20(_SPOT_MARKET_PROXY.getSynth(_sUSDCId));
    }

    /*//////////////////////////////////////////////////////////////
                                 ZAP IN
    //////////////////////////////////////////////////////////////*/

    /// @notice wrap $USDC into $sUSD
    /// @dev call will result in $sUSD minted to this contract
    /// @dev override this function to include additional logic
    /// @dev wrapping $USDC requires sufficient Zap
    /// contract $USDC allowance and results in a
    /// 1:1 ratio in terms of value
    /// @dev assumes zero fees when
    /// wrapping/unwrapping/selling/buying
    /// @param _amount is the amount of $USDC to wrap
    function _zapIn(uint256 _amount)
        internal
        virtual
        returns (uint256 adjustedAmount)
    {
        // transfer $USDC to the Zap contract
        if (!_USDC.transferFrom(msg.sender, address(this), _amount)) {
            revert TransferFailed(
                address(_USDC), msg.sender, address(this), _amount
            );
        }

        // allocate $USDC allowance to the Spot Market Proxy
        if (!_USDC.approve(address(_SPOT_MARKET_PROXY), _amount)) {
            revert ApprovalFailed(
                address(_USDC),
                address(this),
                address(_SPOT_MARKET_PROXY),
                _amount
            );
        }

        /// @notice $USDC may use non-standard decimals
        /// @dev adjustedAmount is the amount of $sUSDC
        /// expected to receive from wrapping
        /// @dev Synthetix synths use 18 decimals
        /// @custom:example if $USDC has 6 decimals,
        /// and $sUSD and $sUSDC have 18 decimals,
        /// then, 1e12 $sUSD/$sUSDC = 1 $USDC
        adjustedAmount = _amount * _DECIMALS_FACTOR;

        /// @notice wrap $USDC into $sUSDC
        /// @dev call will result in $sUSDC minted/transferred
        /// to the Zap contract
        _SPOT_MARKET_PROXY.wrap({
            marketId: _SUSDC_SPOT_MARKET_ID,
            wrapAmount: _amount,
            minAmountReceived: adjustedAmount
        });

        // allocate $sUSDC allowance to the Spot Market Proxy
        if (!_SUSDC.approve(address(_SPOT_MARKET_PROXY), adjustedAmount)) {
            revert ApprovalFailed(
                address(_SUSDC),
                address(this),
                address(_SPOT_MARKET_PROXY),
                adjustedAmount
            );
        }

        /// @notice sell $sUSDC for $sUSD
        /// @dev call will result in $sUSD minted/transferred
        /// to the Zap contract
        _SPOT_MARKET_PROXY.sell({
            marketId: _SUSDC_SPOT_MARKET_ID,
            synthAmount: adjustedAmount,
            minUsdAmount: adjustedAmount,
            referrer: address(0)
        });

        emit ZappedIn({amountWrapped: _amount, amountMinted: adjustedAmount});
    }

    /*//////////////////////////////////////////////////////////////
                                ZAP OUT
    //////////////////////////////////////////////////////////////*/

    /// @notice unwrap $USDC from $sUSD
    /// @dev call will result in $USDC transferred to this contract
    /// @dev override this function to include additional logic
    /// @dev unwrapping may result in a loss of precision:
    /// unwrapping (1e12 + n) $sUSDC results in 1 $USDC
    /// when n is a number less than 1e12; n $sUSDC is lost
    /// @param _amount is the amount of $sUSD to sell
    /// for $sUSDC and then unwrap
    function _zapOut(uint256 _amount)
        internal
        virtual
        returns (uint256 adjustedAmount)
    {
        /// @notice prior to unwrapping, ensure that there
        /// is enough $sUSDC to unwrap
        /// @custom:example if $USDC has 6 decimals, and
        /// $sUSDC has greater than 6 decimals,
        /// then it is possible that the amount of
        /// $sUSDC to unwrap is less than 1 $USDC;
        /// this contract will prevent such cases
        /// @dev if $USDC has 6 decimals, and $sUSDC has 18 decimals,
        /// precision may be lost
        if (_amount < _DECIMALS_FACTOR) {
            revert InsufficientAmount(_amount);
        }

        // allocate $sUSD allowance to the Spot Market Proxy
        if (!_SUSD.approve(address(_SPOT_MARKET_PROXY), _amount)) {
            revert ApprovalFailed(
                address(_SUSD),
                address(this),
                address(_SPOT_MARKET_PROXY),
                _amount
            );
        }

        /// @notice buy $sUSDC with $sUSD
        /// @dev call will result in $sUSDC minted/transferred
        /// to the Zap contract
        _SPOT_MARKET_PROXY.buy({
            marketId: _SUSDC_SPOT_MARKET_ID,
            usdAmount: _amount,
            minAmountReceived: _amount,
            referrer: address(0)
        });

        // allocate $sUSDC allowance to the Spot Market Proxy
        if (!_SUSDC.approve(address(_SPOT_MARKET_PROXY), _amount)) {
            revert ApprovalFailed(
                address(_SUSDC),
                address(this),
                address(_SPOT_MARKET_PROXY),
                _amount
            );
        }

        /// @notice $USDC might use non-standard decimals
        /// @dev adjustedAmount is the amount of $USDC
        /// expected to receive from unwrapping
        /// @custom:example if $USDC has 6 decimals,
        /// and $sUSD and $sUSDC have 18 decimals,
        /// then, 1e12 $sUSD/$sUSDC = 1 $USDC
        adjustedAmount = _amount / _DECIMALS_FACTOR;

        /// @notice unwrap $USDC via burning $sUSDC
        /// @dev call will result in $USDC minted/transferred
        /// to the Zap contract
        _SPOT_MARKET_PROXY.unwrap({
            marketId: _SUSDC_SPOT_MARKET_ID,
            unwrapAmount: _amount,
            minAmountReceived: adjustedAmount
        });

        emit ZappedOut({amountBurned: _amount, amountUnwrapped: adjustedAmount});
    }
}
