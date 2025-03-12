//SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "../PancakeSwap/IPancakeV2Factory.sol";
import "../PancakeSwap/IPancakeV2Pair.sol";
import "../PancakeSwap/IPancakeV2Router01.sol";
import "../PancakeSwap/IPancakeV2Router02.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../4RX/IFourRXToken.sol";

contract ICOContract is Ownable {
    using SafeMath for uint;

    uint public constant MIN_PURCHASE = 1 * (10**8); // Minimum purchase 1 coin

    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    address public constant USDT_ADDRESS = 0x07de306FF27a2B630B1141956844eB1552B956B5; // Kovan

    uint public constant USDT_DECIMAL = 6;

    IFourRXToken fourRXToken;
    IPancakeV2Router02 public pancakeV2Router;
    address public pancakeV2Pair;

    constructor (address _fourRXToken, address _pairAddress) public {
        require(_fourRXToken != address(0), 'ICOContract: Token address cannot be 0');
        require(_pairAddress != address(0), 'ICOContract: Pair address cannot be 0');
        fourRXToken = IFourRXToken(_fourRXToken);

        // IPancakeV2Router02 _pancakeV2Router = IPancakeV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D); // Mainnet
        IPancakeV2Router02 _pancakeV2Router = IPancakeV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D); // kovan

        // Create a uniswap pair for fourRXToken
        pancakeV2Pair = _pairAddress;

        // set the rest of the contract variables
        pancakeV2Router = _pancakeV2Router;
    }

    function addLiquidityAndBurn(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        fourRXToken.approve(address(pancakeV2Router), tokenAmount);

        IPancakeV2Pair _token = IPancakeV2Pair(pancakeV2Pair);
        uint256 balanceBefore = _token.balanceOf(address(this));

        // add the liquidity
        pancakeV2Router.addLiquidityETH{value: ethAmount}(
            address(fourRXToken),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );

        uint256 balanceAfter = _token.balanceOf(address(this));
        _token.transfer(BURN_ADDRESS, balanceAfter.sub(balanceBefore).div(2)); // burn 50%

    }

    function getUSDTFromETH(uint ethAmount) internal view returns (uint) {
        IPancakeV2Factory pcsFactory = IPancakeV2Factory(pancakeV2Router.factory());
        IPancakeV2Pair usdtETHPair = IPancakeV2Pair(pcsFactory.getPair(pancakeV2Router.WETH(), USDT_ADDRESS));

        (uint112 reserve0, uint112 reserve1,) = usdtETHPair.getReserves();

        return pancakeV2Router.getAmountOut(ethAmount, uint(reserve1), uint(reserve0));
    }

    function get4rxAmountFromETH(uint ethAmount) internal view returns (uint) {
        IPancakeV2Pair tokenPair = IPancakeV2Pair(pancakeV2Pair);
        (uint112 reserve0, uint112 reserve1,) = tokenPair.getReserves();

        return pancakeV2Router.getAmountOut(ethAmount, uint(reserve1), uint(reserve0));
    }

    function purchase() external payable {
        require(msg.value > 0, 'ICO: Purchase value should be greater then 0');
        require(fourRXToken.priceValidTill() >= block.number, 'ICO: Price is not up to date in token');

        uint price = fourRXToken.latestPrice().div(1e8);
        uint usdtValue = getUSDTFromETH(msg.value).mul(10**(18 - USDT_DECIMAL)); // convert received BNB/ETH to USDT equivalent + add 12 zeros to make sure price is matched upto decimal places

        uint coinAmount = usdtValue.div(price);

        uint coinAmountForLp = get4rxAmountFromETH(msg.value);

        require(coinAmount >= MIN_PURCHASE, 'ICO: Min 1 token can be purchased');
        require(fourRXToken.balanceOf(address(this)) >= coinAmount.add(coinAmountForLp), 'ICO: Not enough tokens balance to me'); // need to send 100% amount for liquidity too

        fourRXToken.transfer(msg.sender, coinAmount); // send coins to user
        addLiquidityAndBurn(coinAmountForLp, msg.value); // add 100% liquidity to pool
    }

    function recoverTokens(address _tokenAddress, address payable recipient) onlyOwner external {
        if (_tokenAddress == address(0)) {
            recipient.transfer(address(this).balance);
        } else {
            IERC20 token = IERC20(_tokenAddress);
            token.transfer(recipient, token.balanceOf(address(this)));
        }
    }

    receive() external payable {}
}
