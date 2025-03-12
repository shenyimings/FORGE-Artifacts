// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IPriceOracle.sol";
import "../interfaces/ITreasury.sol";
import "../AddressProvider.sol";

contract MockTreasury is ITreasury {
    using SafeERC20 for IERC20;

    uint8 public purchaseThreshold;

    ITreasury.TreasuryValue private _value;

    function withdraw(
        address token,
        uint256 amount,
        address receiver
    ) external override {
        IERC20(token).safeTransfer(msg.sender, amount);
    }

    function setStableValue(uint256 value) external {
        _value.stable = value;
        _recomputeTotal();
    }

    function setUSDRValue(uint256 value) external {
        _value.usdr = value;
        _recomputeTotal();
    }

    function setRWAValue(uint256 value) external {
        _value.rwa = value;
        _recomputeTotal();
    }

    function setTNGBLValue(uint256 value) external {
        _value.tngbl = value;
        _recomputeTotal();
    }

    function setLiquidityValue(uint256 value) external {
        _value.liquidity = value;
        _recomputeTotal();
    }

    function setTNGBLLiquidityValue(
        uint256 tngbl,
        uint256 underlying,
        uint256 liquidity
    ) external {
        _value.tngblLiquidity = TNGBLLiquidity(tngbl, underlying, liquidity);
        _recomputeTotal();
    }

    function setDebtValue(uint256 value) external {
        _value.debt = value;
        _recomputeTotal();
    }

    function getTreasuryValue()
        external
        view
        returns (ITreasury.TreasuryValue memory)
    {
        return _value;
    }

    function multicall(address[] calldata contracts, bytes[] calldata data)
        external
        returns (bytes[] memory results)
    {}

    function updateTrackerFtnftExt(
        address ftnft,
        uint256 tokenId,
        bool placed
    ) external {}

    function updateTrackerTnftExt(
        address tnft,
        uint256 tokenId,
        bool placed
    ) external {}

    function purchaseReInitialSale(
        IERC20 paymentToken,
        address ftnft,
        uint256 fractTokenId,
        uint256 share,
        uint256 ptAmount
    ) external {}

    function purchaseStableMintedRedeemedThreshold()
        external
        view
        returns (uint8)
    {}

    function purchaseStableMarketcapThreshold() external view returns (uint8) {}

    function _recomputeTotal() private {
        _value.total =
            _value.stable +
            _value.usdr +
            _value.rwa +
            _value.tngbl +
            _value.liquidity +
            _value.tngblLiquidity.liquidity;
    }
}
