/**

-ClickBee ETH Smart Contact

Socials:
Website: https://www.beestoken.com
Twitter: https://twitter.com/ClickBee_
Telegram: t.me/ClickbeeToken

*/

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/Context.sol)

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ClickBeeToken is ERC20, Ownable(msg.sender) {
    // Variables
    uint256 private constant _totalSupply = 100_000_000_000 * 10**18; // 100 billion tokens
    uint256 private _buyFeePercentage = 5;
    uint256 private _sellFeePercentage = 5;
    uint256 private constant _maxFeePercentage = 25;

    constructor() ERC20("ClickBee Token", "BEES") {
        _mint(msg.sender, _totalSupply);
    }

    // Buy and Sell functions with fees
    function _calculateFee(uint256 amount, uint256 feePercentage) internal pure returns (uint256) {
        return (amount * feePercentage) / 100;
    }

    function _transferWithFees(
        address sender,
        address recipient,
        uint256 amount,
        uint256 feePercentage
    ) internal {
        uint256 fee = _calculateFee(amount, feePercentage);
        super._transfer(sender, recipient, amount - fee);
        super._transfer(sender, address(this), fee); // Transfer fee to contract
    }

    function setBuyFeePercentage(uint256 newBuyFeePercentage) external onlyOwner {
        require(newBuyFeePercentage <= _maxFeePercentage, "Buy fee exceeds the maximum allowed percentage");
        _buyFeePercentage = newBuyFeePercentage;
    }

    function setSellFeePercentage(uint256 newSellFeePercentage) external onlyOwner {
        require(newSellFeePercentage <= _maxFeePercentage, "Sell fee exceeds the maximum allowed percentage");
        _sellFeePercentage = newSellFeePercentage;
    }

    function buy() external payable {
        _transferWithFees(owner(), msg.sender, msg.value, _buyFeePercentage);
    }

    function sell(uint256 amount) external {
        _transferWithFees(msg.sender, address(this), amount, _sellFeePercentage);
        payable(msg.sender).transfer(amount);
    }

    // Ownership transfer
    function transferOwnership(address newOwner) public override onlyOwner {
        emit OwnershipTransferred(owner(), newOwner);
        super.transferOwnership(newOwner);
    }

    // No need to remove Blacklist functions if not used

    // No need to override transfer function for blacklist check

    // Fallback function to receive Ether
    receive() external payable {}
}