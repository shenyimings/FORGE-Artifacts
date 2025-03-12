// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IMintableERC20 is IERC20 {
    function mint(address _to, uint256 _amount) external;
}

// Wrapped Safe that can be traded without any fee
// TOEDIT: Name and Symbol
contract WMMP is ERC20('Wrapped MMP', 'wMMP'), Ownable {
    IERC20 public immutable safeToken;
    IMintableERC20 public immutable feeToken;
    address public devAddr;
    
    // TOEDIT: Fee
    uint256 public safeFeeRate = 100;
    uint256 public wrapFeeRate = 0;
    uint256 public unwrapFeeRate = 1;
    
    // TOEDIT: Set decimal place here
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
    
    constructor(
        IERC20 _safeToken,
        IMintableERC20 _feeToken
    ) {
        safeToken = _safeToken;
        feeToken = _feeToken;
        devAddr = msg.sender;
    }

    event SetSafeFeeRate(address indexed setter, uint256 oldRate, uint256 newRate);
    function setSafeFeeRate(uint256 _safeFeeRate) public onlyOwner {
        // Prevent too greedy
        require(_safeFeeRate <= 200, "Too greedy");
        emit SetSafeFeeRate(msg.sender, safeFeeRate, _safeFeeRate);
        safeFeeRate = _safeFeeRate;
    }
    
    event SetWrapFeeRate(address indexed setter, uint256 oldRate, uint256 newRate);
    function setWrapFeeRate(uint256 _wrapFeeRate) public onlyOwner {
        // Prevent too greedy
        require(_wrapFeeRate <= 200, "Too greedy");
        emit SetWrapFeeRate(msg.sender, wrapFeeRate, _wrapFeeRate);
        wrapFeeRate = _wrapFeeRate;
    }

    event SetUnwrapFeeRate(address indexed setter, uint256 oldRate, uint256 newRate);
    function setUnwrapFeeRate(uint256 _unwrapFeeRate) public onlyOwner {
        // Prevent too greedy
        require(_unwrapFeeRate <= 200, "Too greedy");
        emit SetUnwrapFeeRate(msg.sender, unwrapFeeRate, _unwrapFeeRate);
        unwrapFeeRate = _unwrapFeeRate;
    }
    
    event SetDev(address indexed setter, address indexed oldDev, address indexed newDev);
    function setDev(address _devAddr) public {
        require(msg.sender == devAddr || msg.sender == owner(), "Only Dev");
        emit SetDev(msg.sender, devAddr, _devAddr);
        devAddr = _devAddr;
    }
    
    event DistributeReward(address indexed setter, uint256 amount, uint256 totalReward);
    function distributeReward(uint256 amount) public {
        uint256 totalReward = amount * safeFeeRate / 1000;
        feeToken.mint(msg.sender, totalReward);
        emit DistributeReward(msg.sender, amount, totalReward);
    }
    
    event Wrap(address indexed wrapper, uint256 amount, uint256 wrapFee, uint256 totalReceived);
    function wrap(uint256 amount) public returns (uint256 totalReceived) {
        uint256 balanceBefore = safeToken.balanceOf(address(this));
        uint256 wrapRatio = getWrapRatio();
        safeToken.transferFrom(msg.sender, address(this), amount);
        
        uint256 safeBalance = safeToken.balanceOf(address(this));
        
        totalReceived = safeBalance - balanceBefore;
        totalReceived = totalReceived * 1e9 / wrapRatio;
        uint256 wrapFee = totalReceived * wrapFeeRate / 1000;
        
        totalReceived -= wrapFee;
        
        distributeReward(amount);
        
        _mint(msg.sender, totalReceived);
        _mint(devAddr, wrapFee);
        
        emit Wrap(msg.sender, amount, wrapFee, totalReceived);
    }
    
    event Unwrap(address indexed wrapper, uint256 amount, uint256 unwrapFee, uint256 outputAmount);
    function unwrap(uint256 amount) public {
        uint256 unwrapFee = amount * unwrapFeeRate / 1000;
        uint256 outputAmount = getWrapRatio() * (amount - unwrapFee) / 1e9;

        _burn(msg.sender, amount);
        _mint(devAddr, unwrapFee);
        
        safeToken.transfer(msg.sender, outputAmount);
        
        emit Unwrap(msg.sender, amount, unwrapFee, outputAmount);
    }
    
    function getWrapRatio() public view returns (uint256 ratio) {
        if (totalSupply() == 0) return 1e9;
        
        uint256 safeBalance = safeToken.balanceOf(address(this));
        return safeBalance * 1e9 / totalSupply();
    }
}
