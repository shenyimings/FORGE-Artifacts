// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "OpenZeppelin/openzeppelin-contracts@4.4.0/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ILockedToken.sol";
import "./interfaces/IOfferFactory.sol";
import "./interfaces/IOwnable.sol";


contract LockedTokenOffer is ReentrancyGuard {
    bool public hasEnded = false;
    address public immutable factory;
    address public immutable seller;
    address public immutable lockedTokenAddress;
    address public immutable tokenWanted;
    uint256 public immutable amountWanted;
    uint256 public immutable fee; // in bps

    event OfferFilled(address indexed buyer, uint256 lockedTokenAmount, address indexed token, uint256 tokenAmount);
    event OfferCanceled(address indexed seller, uint256 lockedTokenAmount);

    constructor(
        address _seller,
        address _lockedTokenAddress,
        address _tokenWanted,
        uint256 _amountWanted,
        uint256 _fee
    ) {
        factory = msg.sender;
        seller = _seller;
        lockedTokenAddress = _lockedTokenAddress;
        tokenWanted = _tokenWanted;
        amountWanted = _amountWanted;
        fee = _fee;
    }

    // release trapped funds
    function withdrawTokens(address token) external nonReentrant {
        require(msg.sender == IOwnable(factory).owner(), "not owner");
        if (token == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            payable(IOwnable(factory).owner()).transfer(address(this).balance);
        } else {
            uint256 balance = IERC20(token).balanceOf(address(this));
            safeTransfer(token, IOwnable(factory).owner(), balance);
        }
    }

    function fill() external nonReentrant {
        require(hasLockedToken(), "no Locked Token balance");
        require(!hasEnded, "sell has been previously cancelled");
        uint256 balance = ILockedToken(lockedTokenAddress).totalBalanceOf(address(this));
        uint256 txFee = mulDiv(amountWanted, fee, 10_000);

        // cap fee at 25k
        uint256 maxFee = 25_000 * 10**IERC20(tokenWanted).decimals();
        txFee = txFee > maxFee ? maxFee : txFee;

        uint256 amountAfterFee = amountWanted - txFee;
        // collect fee
        _sendFees(txFee);
        // exchange assets
        safeTransferFrom(tokenWanted, msg.sender, seller, amountAfterFee);
        ILockedToken(lockedTokenAddress).transferAll(msg.sender);
        // Normalize to 18 decimals
        IOfferFactory(factory).logTransactionVolume(mulDiv(amountWanted, 1e18, 10**IERC20(tokenWanted).decimals())) ;
        hasEnded = true;
        emit OfferFilled(msg.sender, balance, tokenWanted, amountWanted);
    }

    function cancel() external nonReentrant {
        require(hasLockedToken(), "no Locked Token balance");
        require(msg.sender == seller, "only seller can cancel");
        uint256 balance = ILockedToken(lockedTokenAddress).totalBalanceOf(address(this));
        ILockedToken(lockedTokenAddress).transferAll(seller);
        hasEnded = true;
        emit OfferCanceled(seller, balance);
    }

    function hasLockedToken() public view returns (bool) {
        return ILockedToken(lockedTokenAddress).totalBalanceOf(address(this)) > 0;
    }

    function totalLockedToken() public view returns (uint256) {
        return ILockedToken(lockedTokenAddress).totalBalanceOf(address(this));
    }

    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 z
    ) public pure returns (uint256) {
        return (x * y) / z;
    }

    function _sendFees(uint256 feeAmount) internal {
        uint256 escrowFeeAmount = mulDiv(feeAmount, 1, 2);
        uint256 devFeeAmount = mulDiv(feeAmount, 1, 3);
        uint256 xFoxFeeAmount = feeAmount - escrowFeeAmount - devFeeAmount;

        safeTransferFrom(tokenWanted, msg.sender, IOfferFactory(factory).escrowMultisigFeeAddress(), escrowFeeAmount);
        safeTransferFrom(tokenWanted, msg.sender, IOfferFactory(factory).xFoxAddress(), xFoxFeeAmount);
        safeTransferFrom(tokenWanted, msg.sender, IOfferFactory(factory).devAddress(), devFeeAmount);
    }

    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "safeTransfer: failed");
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "safeTransferFrom: failed");
    }
}
