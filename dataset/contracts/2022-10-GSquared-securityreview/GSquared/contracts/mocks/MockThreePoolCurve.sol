// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.10;

import "../interfaces/ICurve3Pool.sol";
import "./Mock3CRV.sol";
import "./MockERC20.sol";
import "../solmate/src/utils/SafeTransferLib.sol";

contract MockThreePoolCurve is ICurve3Pool {
    using SafeTransferLib for MockERC20;
    MockERC20 public dai;
    MockERC20 public usdc;
    MockERC20 public usdt;

    MockERC20[3] public tokens = [dai, usdc, usdt];

    Mock3CRV public threeCrv;

    function setThreeCrv(address _threeCrv) external {
        threeCrv = Mock3CRV(_threeCrv);
    }

    function get_virtual_price() external pure override returns (uint256) {
        return 1e18;
    }

    /// @dev assuming that 3crv:Any stable is always 1:1
    function add_liquidity(
        uint256[3] calldata _deposit_amounts,
        uint256 _min_mint_amount
    ) external {
        uint256 balances;
        for (uint256 i = 0; i < _deposit_amounts.length; i++) {
            tokens[i].safeTransferFrom(
                msg.sender,
                address(this),
                _deposit_amounts[i]
            );
            balances += _deposit_amounts[i];
        }
        threeCrv.mint(msg.sender, balances);
    }

    /// @dev assuming that 3crv:Any stable is always 1:1
    function remove_liquidity_one_coin(
        uint256 _token_amount,
        int128 i,
        uint256 min_amount
    ) external {
        threeCrv.burn(msg.sender, _token_amount);
        if (i == 0) {
            dai.safeTransferFrom(address(this), msg.sender, _token_amount);
        } else if (i == 1) {
            usdc.safeTransferFrom(address(this), msg.sender, _token_amount);
        } else if (i == 2) {
            usdt.safeTransferFrom(address(this), msg.sender, _token_amount);
        }
    }
}
