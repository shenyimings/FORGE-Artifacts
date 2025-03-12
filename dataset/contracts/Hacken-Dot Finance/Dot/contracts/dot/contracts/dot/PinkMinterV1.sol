// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/*
*
* MIT License
* ===========
*
* Copyright (c) 2021 DotFinance
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
*/

import "../library/pancakeswap/BEP20.sol";
import "../library/pancakeswap/SafeBEP20.sol";
import "../library/pancakeswap/SafeMath.sol";

import "../interfaces/IPinkMinterV1.sol";
import "../interfaces/IStakingRewards.sol";
import "../interfaces/IPriceCalculator.sol";

import "../zap/ZapBSC.sol";
import "../library/SafeToken.sol";

contract PinkMinterV1 is IPinkMinterV1, OwnableUpgradeable {
    using SafeMath for uint;
    using SafeBEP20 for IBEP20;

    /* ========== CONSTANTS ============= */

    address public constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address private constant DEAD = 0x000000000000000000000000000000000000dEaD;

    uint public constant FEE_MAX = 10000;

    /* ========== STATE VARIABLES ========== */

    address public pinkChef;
    address public pinkToken;
    address public pinkPool;
    address public deployer;
    address public treasury;
    address public timelock;
    IPriceCalculator public priceCalculator;
    mapping(address => bool) private _minters;

    uint public PERFORMANCE_FEE;
    uint public override WITHDRAWAL_FEE_FREE_PERIOD;
    uint public override WITHDRAWAL_FEE;

    uint public override pinkPerProfitBNB;

    /* ========== MODIFIERS ========== */

    modifier onlyMinter {
        require(isMinter(msg.sender) == true, "PinkMinterV1: caller is not the minter");
        _;
    }

    modifier onlyPinkChef {
        require(msg.sender == pinkChef, "PinkMinterV1: caller not the pink chef");
        _;
    }

    receive() external payable {}

    /* ========== INITIALIZER ========== */

    function initialize(
        address _token,
        address _pool,
        address _deployer,
        address _timelock,
        address _priceCalculator,
        address payable _treasury
    )
        external
        initializer
    {
        require(_token != address(0), "token must be set");
        pinkToken = _token;
        require(_pool != address(0), "pool must be set");
        pinkPool = _pool;
        require(_deployer != address(0), "deployer must be set");
        deployer = _deployer;
        require(_timelock != address(0), "timelock must be set");
        timelock = _timelock;
        require(_treasury != address(0), "treasury must be set");
        treasury = _treasury;
        require(_priceCalculator != address(0), "priceCalculator must be set");
        priceCalculator = IPriceCalculator(_priceCalculator);
        WITHDRAWAL_FEE_FREE_PERIOD = 3 days;
        WITHDRAWAL_FEE = 50;
        PERFORMANCE_FEE = 3000;

        pinkPerProfitBNB = 6500e18;

        IBEP20(pinkToken).approve(pinkPool, type(uint).max);

        __Ownable_init();
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function transferPinkOwner(address _owner) external onlyOwner {
        Ownable(pinkToken).transferOwnership(_owner);
    }

    function setWithdrawalFee(uint _fee) external onlyOwner {
        require(_fee < 500, "wrong fee");
        // less 5%
        WITHDRAWAL_FEE = _fee;
    }

    function setPerformanceFee(uint _fee) external onlyOwner {
        require(_fee < 5000, "wrong fee");
        PERFORMANCE_FEE = _fee;
    }

    function setWithdrawalFeeFreePeriod(uint _period) external onlyOwner {
        WITHDRAWAL_FEE_FREE_PERIOD = _period;
    }

    function setMinter(address minter, bool canMint) external override onlyOwner {
        if (canMint) {
            _minters[minter] = canMint;
        } else {
            delete _minters[minter];
        }
    }

    function setPinkPerProfitBNB(uint _ratio) external onlyOwner {
        pinkPerProfitBNB = _ratio;
    }
    
    function setPinkPool(address _pinkPool) external onlyOwner {
        require(_pinkPool != address(0), 'PinkMinterV1: invalid pinkPool address');
        pinkPool = _pinkPool;
        IBEP20(pinkToken).approve(pinkPool, type(uint).max);
    }

    function setPinkChef(address _pinkChef) external onlyOwner {
        require(pinkChef == address(0), "PinkMinterV1: setPinkChef only once");
        pinkChef = _pinkChef;
    }

    /* ========== VIEWS ========== */

    function isMinter(address account) public view override returns (bool) {
        if (IBEP20(pinkToken).getOwner() != address(this)) {
            return false;
        }
        return _minters[account];
    }

    function amountPinkToMint(uint bnbProfit) public view override returns (uint) {
        return bnbProfit.mul(pinkPerProfitBNB).div(1e18);
    }

    function withdrawalFee(uint amount, uint depositedAt) external view override returns (uint) {
        if (depositedAt.add(WITHDRAWAL_FEE_FREE_PERIOD) > block.timestamp) {
            return amount.mul(WITHDRAWAL_FEE).div(FEE_MAX);
        }
        return 0;
    }

    function performanceFee(uint profit) external view override returns (uint) {
        return profit.mul(PERFORMANCE_FEE).div(FEE_MAX);
    }

    function mintFor(address asset, uint _withdrawalFee, uint _performanceFee, address to, uint) external payable override onlyMinter {
        uint feeSum = _performanceFee.add(_withdrawalFee);
        _transferAsset(asset, feeSum);

        if (asset == pinkToken) {
            IBEP20(pinkToken).safeTransfer(DEAD, feeSum);
            return;
        }

        if (asset == address(0)) { // means BNB
            SafeToken.safeTransferETH(treasury, feeSum);
        } else {
            IBEP20(asset).safeTransfer(treasury, feeSum);
        }

        (uint contribution, ) = priceCalculator.valueOfAsset(asset, _performanceFee);
        uint mintPink = amountPinkToMint(contribution);
        if (mintPink == 0) return;
        _mint(mintPink, to);
    }

    /* ========== PinkChef FUNCTIONS ========== */

    function mint(uint amount) external override onlyPinkChef {
        if (amount == 0) return;
        _mint(amount, address(this));
    }

    function safePinkTransfer(address _to, uint _amount) external override onlyPinkChef {
        if (_amount == 0) return;

        uint bal = IBEP20(pinkToken).balanceOf(address(this));
        if (_amount <= bal) {
            IBEP20(pinkToken).safeTransfer(_to, _amount);
        } else {
            IBEP20(pinkToken).safeTransfer(_to, bal);
        }
    }

    // @dev should be called when determining mint in governance. Pink is transferred to the timelock contract.
    function mintGov(uint amount) external override onlyOwner {
        if (amount == 0) return;
        _mint(amount, timelock);
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function _transferAsset(address asset, uint amount) private {
        if (asset == address(0)) {
            // case) transferred BNB
            require(msg.value >= amount);
        } else {
            IBEP20(asset).safeTransferFrom(msg.sender, address(this), amount);
        }
    }

    function _mint(uint amount, address to) private {
        BEP20 tokenPINK = BEP20(pinkToken);

        tokenPINK.mint(amount);
        if (to != address(this)) {
            tokenPINK.transfer(to, amount);
        }

        uint pinkForDev = amount.mul(15).div(100);
        tokenPINK.mint(pinkForDev);
        IStakingRewards(pinkPool).stakeTo(pinkForDev, deployer);
    }
}
