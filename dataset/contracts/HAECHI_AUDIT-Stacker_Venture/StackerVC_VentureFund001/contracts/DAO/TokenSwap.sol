// SPDX-License-Identifier: MIT

pragma solidity ^0.6.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol"; // call ERC20 safely
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../Interfaces/ITokenManager.sol";

contract TokenSwap {
	using SafeERC20 for IERC20;
	using Address for address;
    using SafeMath for uint256;

    address payable public receiver;
    address payable public governance;
    address public buyer;

    address public tokenManager;

    uint256 public rate;
    uint256 public amountIn;
    address public coinIn;

    bool public paused = false;

    // vesting constants
    uint64 public constant start = 1614585600;
    uint64 public constant cliff = 1625122800;
    uint64 public constant vested = 1646121600;
    bool public constant revokable = false;

    constructor(address _tokenManager, address _buyer, uint256 _rate, uint256 _amountIn, address _coinIn) public {
    	governance = msg.sender;
    	receiver = msg.sender;

        tokenManager = _tokenManager;
    	
    	buyer = _buyer;
    	rate = _rate;
    	amountIn = _amountIn;
        coinIn = _coinIn;
    }

    receive() external payable {
    	swap(msg.value);
    }

    function setReceiver(address payable _new) external {
    	require(msg.sender == governance, "SWAP: !governance");
    	require(_new != address(0), "SWAP: receiver == 0x0");

    	receiver = _new;
    }

    function setGovernance(address payable _new) external {
    	require(msg.sender == governance, "SWAP: !governance");
    	require(_new != address(0), "SWAP: governance == 0x0");

    	governance = _new;
    }

    function setTransfer(address _buyer, uint256 _rate, uint256 _amountIn, address _coinIn) external {
        require(msg.sender == governance, "SWAP: !governance");

        buyer = _buyer;
        rate = _rate;
        amountIn = _amountIn;
        coinIn = _coinIn;
    }

    function setPaused(bool _new) external {
    	require(msg.sender == governance, "SWAP: !governance");

    	paused = _new;
    }

    function swap(uint256 _amount) public payable {
    	require(msg.sender == buyer || buyer == address(0), "SWAP: !buyer");
    	require(!paused, "SWAP: paused");

        // receiving ETH...
        if (coinIn == address(0)){
            require(msg.value == _amount, "SWAP: ETH transfer error");
            require(msg.value == amountIn || amountIn == 0, "SWAP: !amountIn for ETH");

            // receiver is trusted address to receive ETH
            receiver.transfer(msg.value);
        }
        else {
            // receiver is trusted address to receive token
            uint256 _before = IERC20(coinIn).balanceOf(receiver);
            IERC20(coinIn).safeTransferFrom(msg.sender, receiver, _amount);
            uint256 _after = IERC20(coinIn).balanceOf(receiver);
            uint256 _total = _after.sub(_before);

            require(_total == _amount, "SWAP: ERC20 transfer error");
            require(_total == amountIn || amountIn == 0, "SWAP: !amountIn for ERC20");
        }

    	
    	uint256 _toSend = _amount.mul(rate).div(1e18);

    	ITokenManager(tokenManager).assignVested(
    		msg.sender,
    		_toSend,
    		start,
    		cliff,
    		vested,
    		revokable
    	);
    }

    function rescue(address _token, uint256 _amount) external {
        require(msg.sender == governance, "SWAP: !governance");

        if (_token != address(0)){
            IERC20(_token).safeTransfer(governance, _amount);
        }
        else { // if _tokenContract is 0x0, then escape ETH
            governance.transfer(_amount);
        }
    }
}