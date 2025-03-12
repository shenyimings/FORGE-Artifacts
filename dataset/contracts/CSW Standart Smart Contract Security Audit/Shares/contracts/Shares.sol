// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Shares is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public token;
    uint public percent = 5;

    uint public startBlock;
    uint public circleTime = 74000;

    mapping (uint => uint) public sharesPrice;

    constructor(IERC20 _token, uint _startBlock) {
        token = _token;
        startBlock = _startBlock;
    }

    function currentCircle() public view returns (uint) {
        if (startBlock > block.number) {
            return 0;
        }
        return (block.number - startBlock) / circleTime;
    }
    
    function blocksLeft() public view returns (uint) {
        if (startBlock > block.number) {
            return 0;
        }
        return circleTime - ((block.number - startBlock) % circleTime);
    }
    
    
    function currentPrice() public view returns (uint) {
        uint current = currentCircle();
        if (sharesPrice[current] == 0) {
            return token.balanceOf(address(this)) * percent / 100;
        } else {
            return sharesPrice[current];
        }
    }
    
    function sendTo(address to, uint amount) external onlyTrusted {
        updatePrice();
        
        token.safeTransfer(to, sharesPrice[currentCircle()] * amount / 1e18);
    }

    function updatePrice() public onlyTrusted {
        uint current = currentCircle();
        if (sharesPrice[current] == 0) {
            sharesPrice[current] = token.balanceOf(address(this)) * percent / 100;
            percent += 1;
        }
    }

    function addMoneyAndRecalculate(uint amount) external onlyTrusted {
        token.safeTransferFrom(address(msg.sender), address(this), amount);
        sharesPrice[currentCircle()] = token.balanceOf(address(this)) * percent / 100;
    }

    function setPercent(uint _percent) external onlyOwner {
        percent = _percent;
    }
    
    function withdraw() public onlyOwner {
        token.safeTransfer(msg.sender, token.balanceOf(address(this)));
    }
    

    mapping(address=>bool) private _isTrusted;
    modifier onlyTrusted {
        require(_isTrusted[msg.sender] || msg.sender == owner(), "not trusted");
        _;
    }

    function addTrusted(address user) public onlyOwner {
        _isTrusted[user] = true;
    }

    function removeTrusted(address user) public onlyOwner {
        _isTrusted[user] = false;
    }
}
