// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IUsdPlusToken.sol";

contract MockExchange {

    IUsdPlusToken public usdPlus;
    IERC20 public usdc;

    uint256 public buyFee;
    uint256 public buyFeeDenominator; // ~ 100 %

    uint256 public redeemFee;
    uint256 public redeemFeeDenominator; // ~ 100 %


    constructor(address _usdPlus, address _usdc) {
        usdPlus = IUsdPlusToken(_usdPlus);
        usdc = IERC20(_usdc);

        buyFee = 40;
        buyFeeDenominator = 100000; // ~ 100 %

        redeemFee = 40;
        redeemFeeDenominator = 100000; // ~ 100 %
    }

    /**
     * @param _addrTok Token to withdraw
     * @param _amount Amount of USD+ tokens to burn
     * @return Amount of minted to caller tokens
     */
    function buy(address _addrTok, uint256 _amount) external returns (uint256) {
        require(_addrTok == address(usdc), "Only USDC tokens currently available for buy");

        uint256 currentBalance = IERC20(_addrTok).balanceOf(msg.sender);
        require(currentBalance >= _amount, "Not enough tokens to buy");

        IERC20(_addrTok).transferFrom(msg.sender, address(this), _amount);

        uint256 buyFeeAmount = (_amount * buyFee) / buyFeeDenominator;
        uint256 buyAmount = _amount - buyFeeAmount;

        usdPlus.mint(msg.sender, buyAmount);

        return buyAmount;
    }

    /**
     * @param _addrTok Token to withdraw
     * @param _amount Amount of USD+ tokens to burn
     * @return Amount of unstacked and transferred to caller tokens
     */
    function redeem(address _addrTok, uint256 _amount) external returns (uint256) {
        require(_addrTok == address(usdc), "Only USDC tokens currently available for redeem");

        uint256 redeemFeeAmount = (_amount * redeemFee) / redeemFeeDenominator;
        uint256 redeemAmount = _amount - redeemFeeAmount;

        usdPlus.burn(msg.sender, _amount);

        uint256 currentBalance = IERC20(_addrTok).balanceOf(address(this));
        require(currentBalance >= redeemAmount, "Not enough for transfer redeemAmount");

        IERC20(_addrTok).transfer(msg.sender, redeemAmount);

        return redeemAmount;
    }

    function setLiquidityIndex(uint256 _liquidityIndex) external {
        usdPlus.setLiquidityIndex(_liquidityIndex);
    }

}
