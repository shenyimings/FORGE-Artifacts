// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../utils/TrustCaller.sol";
import "../utils/SafeMath.sol";


contract Tree is ERC20, Ownable, TrustCaller {
    using SafeMath for uint256;

    uint256 public transferFeeMultiplyer;
    uint256 public transferFeeDivider;

    address public platformAddress;
    
    constructor(address platformAddress_, uint256 transferFeeMultiplyer_, uint256 transferFeeDivider_) ERC20("Tree", "TREE") {
        setPlatformAddress(platformAddress_);
        setTransferFee(transferFeeMultiplyer_, transferFeeDivider_);
    }

    // By current tokenomic, the Greenhouse is the point to convert LEAF to TREE
    function mint(address account, uint256 amount) external onlyTrustCaller {
        require(account != address(0), "Tree: Minting to the zero address");

        _mint(account, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        uint256 feeAmount = amount.mul(transferFeeMultiplyer).div(transferFeeDivider);
        uint256 amountExcludeFee = amount.sub(feeAmount);

        _transfer(_msgSender(), platformAddress, feeAmount);
        _transfer(_msgSender(), recipient, amountExcludeFee);

        return true;
    }

    // ========== only Owner =============
    
    function setTransferFee(uint256 transferFeeMultiplyer_, uint256 transferFeeDivider_) public onlyOwner {
        transferFeeMultiplyer = transferFeeMultiplyer_;
        transferFeeDivider = transferFeeDivider_;
    }

    function setPlatformAddress(address platformAddress_) public onlyOwner {
        platformAddress = platformAddress_;
    }
} 