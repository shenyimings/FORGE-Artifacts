// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { TokenPreTimelock } from "./TokenPreTimelock.sol";
import { TokenPreVesting } from "./TokenPreVesting.sol";

/**
 * @title TokenPreSale Contract
 */

contract TokenPreSale is Ownable {
    using SafeMath for uint256;

    IERC20 public token; // the token being sold

    uint256 public coinsSold;

    event Sold(address buyer, uint256 amount);

    uint256 public exchangePriceUSDT = 120000000000000000;
    uint256 public exchangePriceBUSD = 120000000000000000;
    uint256 public duration = 18 * 30 days;
    uint256 public cliff = 3 * 30 days;
    uint256 public minBuyAmountUSDT = 1000000000000000000;
    uint256 public maxBuyAmountUSDT = 10000000000000000000000;
    uint256 public minBuyAmountBUSD = 1000000000000000000;
    uint256 public maxBuyAmountBUSD = 10000000000000000000000;
    TokenPreVesting public vesting;
    TokenPreTimelock public timelock;

    uint256 public availableAtTGE = 200; // percentage basis points

    enum SaleStatus {
        Pause,
        Start
    }

    SaleStatus public saleStatus;
    address public immutable USDT;
    address public immutable BUSD;

    constructor(
        IERC20 _token,
        address _usdt,
        address _busd
    ) {
        token = _token;
        USDT = _usdt;
        BUSD = _busd;
        vesting = new TokenPreVesting(address(token));
        timelock = new TokenPreTimelock(address(token));
    }

    modifier onSale() {
        require(saleStatus == SaleStatus.Start, "TokenPreSale: Sale not started");
        _;
    }

    function setExchangePriceUSDT(uint256 _usdtPrice) external onlyOwner {
        exchangePriceUSDT = _usdtPrice;
    }

    function setExchangePriceBUSD(uint256 _busdPrice) external onlyOwner {
        exchangePriceBUSD = _busdPrice;
    }

    function setDuration(uint256 _duration) external onlyOwner {
        duration = _duration;
    }

    function setCliff(uint256 _cliff) external onlyOwner {
        cliff = _cliff;
    }

    function setTimeStamp(uint256 _timePeriodInSeconds) external onlyOwner {
        vesting.setTimestamp(_timePeriodInSeconds);
        timelock.setTimestamp(_timePeriodInSeconds);
    }

    function setSaleStatus(SaleStatus _saleStatus) external onlyOwner {
        saleStatus = _saleStatus;
    }

    function setAvailableAtTGE(uint256 _availableAtTGE) external onlyOwner {
        availableAtTGE = _availableAtTGE;
    }

    function transferAccidentallyLockedTokensInTimeLock(IERC20 _token, uint256 _amount) external onlyOwner {
        timelock.transferAccidentallyLockedTokens(_token, _amount);
        _token.transfer(owner(), _amount);
    }

    function setBuyAmountRangeBUSD(uint256 _min, uint256 _max) external onlyOwner {
        minBuyAmountBUSD = _min;
        maxBuyAmountBUSD = _max;
    }

    function setBuyAmountRangeUSDT(uint256 _min, uint256 _max) external onlyOwner {
        minBuyAmountUSDT = _min;
        maxBuyAmountUSDT = _max;
    }

    function buyTokensUsingBUSD(uint256 _busdAmount) external onSale {
        uint256 _balanceBefore = IERC20(BUSD).balanceOf(address(this));
        require(IERC20(BUSD).transferFrom(msg.sender, address(this), _busdAmount), "TokenPreSale: BUSD -> this");
        uint256 _balanceAfter = IERC20(BUSD).balanceOf(address(this));
        uint256 _actualBUSDAmount = _balanceAfter.sub(_balanceBefore);
        require(
            _actualBUSDAmount >= minBuyAmountBUSD && _actualBUSDAmount <= maxBuyAmountBUSD,
            "TokenPreSale: BUSD out of range"
        );
        uint256 _numberOfTokens = computeTokensForBUSD(_actualBUSDAmount);
        require(
            token.allowance(owner(), address(this)) >= _numberOfTokens,
            "TokenPreSale: insufficient token approval"
        );
        emit Sold(msg.sender, _numberOfTokens);
        coinsSold += _numberOfTokens;
        uint256 _nonVestedTokenAmount = _numberOfTokens.mul(availableAtTGE).div(10000);
        uint256 _vestedTokenAmount = _numberOfTokens.sub(_nonVestedTokenAmount);
        // send some pct of tokens to buyer right away
        if (_nonVestedTokenAmount > 0) {
            require(
                token.transferFrom(owner(), address(timelock), _nonVestedTokenAmount),
                "TokenPreSale: token -> tokenpretimelock"
            );
            timelock.depositTokens(msg.sender, _nonVestedTokenAmount);
        } // vest rest of the tokens
        require(
            token.transferFrom(owner(), address(vesting), _vestedTokenAmount),
            "TokenPreSale: token -> tokenprevesting"
        );
        vesting.createVestingSchedule(msg.sender, cliff, duration, 1, false, _vestedTokenAmount, availableAtTGE);
    }

    function buyTokensUsingUSDT(uint256 _usdtAmount) external onSale {
        uint256 _balanceBefore = IERC20(USDT).balanceOf(address(this));
        require(IERC20(USDT).transferFrom(msg.sender, address(this), _usdtAmount), "TokenPreSale: USDT -> this");
        uint256 _balanceAfter = IERC20(USDT).balanceOf(address(this));
        uint256 _actualUSDTAmount = _balanceAfter.sub(_balanceBefore);
        require(
            _actualUSDTAmount >= minBuyAmountUSDT && _actualUSDTAmount <= maxBuyAmountUSDT,
            "TokenPreSale: USDT out of range"
        );
        uint256 _numberOfTokens = computeTokensForUSDT(_actualUSDTAmount);
        require(
            token.allowance(owner(), address(this)) >= _numberOfTokens,
            "TokenPreSale: insufficient token approval"
        );
        emit Sold(msg.sender, _numberOfTokens);
        coinsSold += _numberOfTokens;
        uint256 _nonVestedTokenAmount = _numberOfTokens.mul(availableAtTGE).div(10000);
        uint256 _vestedTokenAmount = _numberOfTokens.sub(_nonVestedTokenAmount);
        // send some pct of tokens to buyer right away
        if (_nonVestedTokenAmount > 0) {
            require(
                token.transferFrom(owner(), address(timelock), _nonVestedTokenAmount),
                "TokenPreSale: token -> tokenpretimelock"
            );
            timelock.depositTokens(msg.sender, _nonVestedTokenAmount);
        } // vest rest of the tokens
        require(
            token.transferFrom(owner(), address(vesting), _vestedTokenAmount),
            "TokenPreSale: token -> tokenprevesting"
        );

        vesting.createVestingSchedule(msg.sender, cliff, duration, 1, false, _vestedTokenAmount, availableAtTGE);
    }

    function computeTokensForBUSD(uint256 _busdAmount) public view returns (uint256) {
        uint256 _tokenDecimals = ERC20(address(token)).decimals();
        return (_busdAmount * 10**_tokenDecimals) / exchangePriceBUSD;
    }

    function computeTokensForUSDT(uint256 _usdtAmount) public view returns (uint256) {
        uint256 _tokenDecimals = ERC20(address(token)).decimals();
        return (_usdtAmount * 10**_tokenDecimals) / exchangePriceUSDT;
    }

    function withdrawBUSD() public onlyOwner {
        uint256 _busdBalance = IERC20(BUSD).balanceOf(address(this));
        if (_busdBalance > 0) {
            IERC20(BUSD).transfer(owner(), _busdBalance);
        }
    }

    function withdrawUSDT() public onlyOwner {
        uint256 _usdtBalance = IERC20(USDT).balanceOf(address(this));
        if (_usdtBalance > 0) {
            IERC20(USDT).transfer(owner(), _usdtBalance);
        }
    }

    function withdrawFromVesting(uint256 _amount) public onlyOwner {
        vesting.withdraw(_amount);
        token.transfer(owner(), _amount);
    }

    function transferAccidentallyLockedTokensFromTimelock(IERC20 _token, uint256 amount) public onlyOwner {
        timelock.transferAccidentallyLockedTokens(_token, amount);
        _token.transfer(owner(), _token.balanceOf(address(this)));
    }

    function revoke(bytes32 vestingScheduleId) external onlyOwner {
        vesting.revoke(vestingScheduleId);
    }

    function endSale() external onlyOwner {
        // Send unsold tokens to owner.
        saleStatus = SaleStatus.Pause;
        uint256 _withdrawableAmount = vesting.getWithdrawableAmount();
        if (_withdrawableAmount > 0) {
            withdrawFromVesting(vesting.getWithdrawableAmount());
        }
        withdrawBUSD();
        withdrawUSDT();
    }
}
