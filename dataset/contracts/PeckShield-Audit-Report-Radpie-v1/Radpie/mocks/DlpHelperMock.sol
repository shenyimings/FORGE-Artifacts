// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../radiant/misc/DustRefunder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../interfaces/IMintableERC20.sol";
import "../radiant/misc/BNum.sol";

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../interfaces/IWETH.sol";

/// @title Balance Pool Helper Contract Mock
contract DlpPoolHelperMock is Initializable, DustRefunder, BNum {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public rdntAddr;
    address public wethAddr;
    address public lpTokenAddr;
    address public mDLP;

    constructor(address _rdntAddr, address _wethAddr, address _lpTokenAddr, address _mDLP) {
        rdntAddr = _rdntAddr;
        wethAddr = _wethAddr;
        lpTokenAddr = _lpTokenAddr;
        mDLP = _mDLP;
    }

    function zapWETH(uint256 amount) public returns (uint256 liquidity) {
        require(msg.sender == mDLP, "!mDLP");
        IWETH(wethAddr).transferFrom(msg.sender, address(this), amount);
        liquidity = joinPool(amount, 0);
        IMintableERC20(lpTokenAddr).mint(msg.sender, liquidity);
        //refundDust(rdntAddr, wethAddr, msg.sender);
    }

    function zapTokens(uint256 _wethAmt, uint256 _rdntAmt) public returns (uint256 liquidity) {
        require(msg.sender == mDLP, "!mDLP");
        IWETH(wethAddr).transferFrom(msg.sender, address(this), _wethAmt);
        IERC20(rdntAddr).safeTransferFrom(msg.sender, address(this), _rdntAmt);

        liquidity = joinPool(_wethAmt, _rdntAmt);
        IMintableERC20(lpTokenAddr).mint(msg.sender, liquidity);
        // refundDust(rdntAddr, wethAddr, msg.sender);
    }

    function joinPool(uint256 _wethAmt, uint256 _rdntAmt) internal view returns (uint256) {
        uint256 lpSupply = IERC20(lpTokenAddr).totalSupply();
        uint256 totalWeth = IERC20(wethAddr).balanceOf(address(this));
        uint256 totalRdnt = IERC20(rdntAddr).balanceOf(address(this));

        uint256 lpAmount;

        if (lpSupply == 0 || totalWeth == 0 || totalRdnt == 0) {
            lpAmount = _wethAmt.mul(4);
        } else if (_wethAmt > 0 && _rdntAmt == 0) {
            lpAmount = _wethAmt.mul(lpSupply).div(totalWeth);
        } else {
            uint256 wethValue = _wethAmt.mul(totalRdnt).div(totalWeth);
            uint256 rdntValue = _rdntAmt.mul(totalWeth).div(totalRdnt);
            lpAmount = wethValue < rdntValue ? wethValue : rdntValue;
        }

        return lpAmount;
    }

    function quoteFromToken(uint256 tokenAmount) public pure returns (uint256 optimalWETHAmount) {
        uint256 rdntPriceInEth = 14648;
        uint256 p1 = rdntPriceInEth.mul(1e10);
        uint256 ethRequiredBeforeWeight = tokenAmount.mul(p1).div(1e18);
        optimalWETHAmount = ethRequiredBeforeWeight.div(4);
    }

    function setmDLP(address _mDLP) external {
        mDLP = _mDLP;
    }
}
