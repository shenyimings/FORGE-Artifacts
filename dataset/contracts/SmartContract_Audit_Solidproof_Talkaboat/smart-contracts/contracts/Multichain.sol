// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./libraries/TransferHelper.sol";

contract Multichain is Ownable, ReentrancyGuard{
    using Address for address;
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _swapIds;
    IERC20 _token;

    struct Transfer {
        uint16 ChainId;
        uint256 Amount;
        address User;
        uint256 Timestamp;
        uint256 RefSwapId;
    }

    mapping(uint256 => Transfer) incomingTransfers;
    mapping(uint16 => mapping(uint256 => Transfer)) outgoingTransfers; //chain => ref swap id => transfer data

    event InitChainTransfer(uint16 targetChain, uint256 amount, address user);
    event CompleteChainTransfer(uint16 originalChain, uint256 amount, address user, uint256 originalSwapId);
 
    constructor(IERC20 token) {
        _token = token;
    }

    function transferIn(uint256 amount, uint16 chainId) public nonReentrant returns (uint256) {
        TransferHelper.safeTransferFrom(address(_token), msg.sender, address(this), amount);
        uint256 swapId = _swapIds.current();
        _swapIds.increment();
        Transfer memory transfer = Transfer(chainId, amount, msg.sender, block.timestamp, swapId);
        incomingTransfers[swapId] = transfer;
        emit InitChainTransfer(chainId, amount, msg.sender);
        return swapId;
    }

    function transferOut(uint256 amount, uint16 chainId, uint256 originalSwapId, address user) public onlyOwner {
        require(outgoingTransfers[chainId][originalSwapId].RefSwapId != originalSwapId, "ABOAT::ERROR: Swap is already completed!");
        Transfer memory transfer = Transfer(chainId, amount, user, block.timestamp, originalSwapId);
        outgoingTransfers[chainId][originalSwapId] = transfer;
        TransferHelper.safeTransfer(address(_token), user, amount);
        emit CompleteChainTransfer(chainId, amount, user, originalSwapId);
    }
    
}