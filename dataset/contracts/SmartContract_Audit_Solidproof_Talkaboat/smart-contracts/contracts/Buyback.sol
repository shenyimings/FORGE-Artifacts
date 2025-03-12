// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./libraries/TransferHelper.sol";
import "./interfaces/IMasterEntertainer.sol";
import "./chains/kardiachain/AboatToken.sol";

contract Buyback is Ownable {
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    /* =====================================================================================================================
                                                        Variables
    ===================================================================================================================== */
    IERC20 public rewardToken; //WKAI
    AboatToken public paymentToken; //ABOAT
    uint256 public pricePerToken;   //How much ABOAT PER KAI

    /* =====================================================================================================================
                                                        Events
    ===================================================================================================================== */
    
    event Bought(address indexed buyer, uint256 indexed amount);
    
    constructor(IERC20 _rewardToken, AboatToken _paymentToken, uint256 _price) {
        require(_price > 0, "ABOAT::error: Price has to be higher than zero");
        rewardToken = _rewardToken;
        paymentToken = _paymentToken;
        pricePerToken = _price;
    }

    receive() external payable {}

    function getRemainingBalance() public view returns(uint256) {
        bool isRewardTokenEthToken = address(rewardToken) == address(0);
        if(isRewardTokenEthToken) {
            return address(this).balance;
        } else {
            return IERC20(rewardToken).balanceOf(address(this));
        }
    }

    function getRewardAmountFromPayment(uint256 amount) public view returns(uint256) {
        return amount.mul(pricePerToken).div(1e18);
    }
    
    /* =====================================================================================================================
                                                        Owner
    ===================================================================================================================== */



    function claimRemainingBalance() public onlyOwner {
        bool isRewardTokenEthToken = address(rewardToken) == address(0);
        if(isRewardTokenEthToken) {
            TransferHelper.safeTransferETH(owner(), getRemainingBalance());
        } else {
            TransferHelper.safeTransfer(address(rewardToken), owner(), getRemainingBalance());
        }
    }
    
    /* =====================================================================================================================
                                                        Investors
    ===================================================================================================================== */
    
    function buy(uint256 amount) public payable {
        bool isPaymentTokenEthToken = address(paymentToken) == address(0);
        bool isRewardTokenEthToken = address(rewardToken) == address(0);
        require(!isPaymentTokenEthToken || msg.value == amount, "ABOAT::buy: Sent value doesn't meet the given amount");
        uint256 amountBought = getRewardAmountFromPayment(amount);
        require(getRemainingBalance().sub(amountBought) > 0, "ABOAT::buy: Amount would exceed the remaining balance");
        //Payment Token (ABOAT) is sent to sc owner
        if(!isPaymentTokenEthToken) {
            require(IERC20(paymentToken).balanceOf(msg.sender) > amount, "ABOAT::buy: User has not enough token for transfer");
            IERC20(paymentToken).safeTransferFrom(address(msg.sender), owner(), amount);
        } else {
            TransferHelper.safeTransferETH(owner(), amount);
        }
        //Reward Token (KAI) is sent to buyer
        if(isRewardTokenEthToken) {
            TransferHelper.safeTransferETH(msg.sender, amountBought);
        } else {
            TransferHelper.safeTransfer(address(rewardToken), msg.sender, amountBought);
        }
        emit Bought(msg.sender, amount);
    }
}