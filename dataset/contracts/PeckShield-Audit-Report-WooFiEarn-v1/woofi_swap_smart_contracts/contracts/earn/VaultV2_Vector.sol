// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import '../interfaces/IStrategy.sol';
import '../interfaces/IWETH.sol';
import '../interfaces/IWooAccessManager.sol';
import '../interfaces/IVault.sol';

/*

░██╗░░░░░░░██╗░█████╗░░█████╗░░░░░░░███████╗██╗
░██║░░██╗░░██║██╔══██╗██╔══██╗░░░░░░██╔════╝██║
░╚██╗████╗██╔╝██║░░██║██║░░██║█████╗█████╗░░██║
░░████╔═████║░██║░░██║██║░░██║╚════╝██╔══╝░░██║
░░╚██╔╝░╚██╔╝░╚█████╔╝╚█████╔╝░░░░░░██║░░░░░██║
░░░╚═╝░░░╚═╝░░░╚════╝░░╚════╝░░░░░░░╚═╝░░░░░╚═╝

*
* MIT License
* ===========
*
* Copyright (c) 2020 WooTrade
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
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
contract WOOFiVaultV2Vector is IVault, ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct StratCandidate {
        address implementation;
        uint256 proposedTime;
    }

    /* ----- State Variables ----- */

    address public immutable override want;

    IWooAccessManager public immutable accessManager;

    IStrategy public strategy;
    StratCandidate public stratCandidate;

    uint256 public approvalDelay = 48 hours;
    uint256 public earnThreshold = 3000;

    mapping(address => uint256) public costSharePrice;

    event NewStratCandidate(address indexed implementation);
    event UpgradeStrat(address indexed implementation);

    /* ----- Constant Variables ----- */

    // WBNB: https://bscscan.com/token/0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c
    // WAVAX: https://snowtrace.io/address/0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7
    address public immutable weth;

    constructor(
        address _weth,
        address _want,
        address _accessManager
    )
        public
        ERC20(
            string(abi.encodePacked('WOOFi Earn ', ERC20(_want).name())),
            string(abi.encodePacked('we', ERC20(_want).symbol()))
        )
    {
        require(_weth != address(0), 'WOOFiVaultV2: weth_ZERO_ADDR');
        require(_want != address(0), 'WOOFiVaultV2: want_ZERO_ADDR');
        require(_accessManager != address(0), 'WOOFiVaultV2: accessManager_ZERO_ADDR');

        weth = _weth;
        want = _want;
        accessManager = IWooAccessManager(_accessManager);
    }

    modifier onlyAdmin() {
        require(owner() == msg.sender || accessManager.isVaultAdmin(msg.sender), 'WOOFiVaultV2: NOT_ADMIN');
        _;
    }

    /* ----- External Functions ----- */

    function deposit(uint256 amount) public payable override nonReentrant {
        require(amount > 0, 'WOOFiVaultV2: amount_CAN_NOT_BE_ZERO');

        if (want == weth) {
            require(msg.value == amount, 'WOOFiVaultV2: msg.value_INSUFFICIENT');
        } else {
            require(msg.value == 0, 'WOOFiVaultV2: msg.value_INVALID');
        }

        if (address(strategy) != address(0)) {
            require(!strategy.paused(), 'WOOFiVaultV2: strat_paused');
            strategy.beforeDeposit();
        }

        uint256 balanceBefore = balance();
        if (want == weth) {
            IWETH(weth).deposit{value: msg.value}();
        } else {
            TransferHelper.safeTransferFrom(want, msg.sender, address(this), amount);
        }
        uint256 balanceAfter = balance();
        require(amount <= balanceAfter.sub(balanceBefore), 'WOOFiVaultV2: amount_NOT_ENOUGH');

        uint256 shares = totalSupply() == 0 ? amount : amount.mul(totalSupply()).div(balanceBefore);
        uint256 sharesBefore = balanceOf(msg.sender);
        uint256 costBefore = costSharePrice[msg.sender];
        uint256 costAfter = (sharesBefore.mul(costBefore).add(amount.mul(1e18))).div(sharesBefore.add(shares));
        costSharePrice[msg.sender] = costAfter;

        _mint(msg.sender, shares);

        if (amount >= earnThreshold * (10**uint256(ERC20(want).decimals()))) {
            earn();
        }
    }

    function withdraw(uint256 shares) public override nonReentrant {
        require(shares > 0, 'WOOFiVaultV2: shares_ZERO');
        require(shares <= balanceOf(msg.sender), 'WOOFiVaultV2: shares_NOT_ENOUGH');

        if (address(strategy) != address(0)) {
            strategy.beforeWithdraw();
        }

        uint256 withdrawAmount = shares.mul(balance()).div(totalSupply());
        _burn(msg.sender, shares);

        uint256 balanceBefore = IERC20(want).balanceOf(address(this));
        if (balanceBefore < withdrawAmount) {
            uint256 balanceToWithdraw = withdrawAmount.sub(balanceBefore);
            require(_isStratActive(), 'WOOFiVaultV2: STRAT_INACTIVE');
            strategy.withdraw(balanceToWithdraw);
            uint256 balanceAfter = IERC20(want).balanceOf(address(this));
            if (withdrawAmount > balanceAfter) {
                // NOTE: in case a small amount not counted in, due to the decimal precision.
                withdrawAmount = balanceAfter;
            }
        }

        if (want == weth) {
            IWETH(weth).withdraw(withdrawAmount);
            TransferHelper.safeTransferETH(msg.sender, withdrawAmount);
        } else {
            TransferHelper.safeTransfer(want, msg.sender, withdrawAmount);
        }
    }

    function earn() public override {
        if (_isStratActive()) {
            uint256 balanceAvail = available();
            TransferHelper.safeTransfer(want, address(strategy), balanceAvail);
            strategy.deposit();
        }
    }

    function available() public view override returns (uint256) {
        return IERC20(want).balanceOf(address(this));
    }

    function balance() public view override returns (uint256) {
        return address(strategy) != address(0) ? available().add(strategy.balanceOf()) : available();
    }

    function getPricePerFullShare() public view override returns (uint256) {
        return totalSupply() == 0 ? 1e18 : balance().mul(1e18).div(totalSupply());
    }

    function _isStratActive() internal view returns (bool) {
        return address(strategy) != address(0) && !strategy.paused();
    }

    /* ----- Admin Functions ----- */

    function setupStrat(address _strat) public onlyAdmin {
        require(_strat != address(0), 'WOOFiVaultV2: STRAT_ZERO_ADDR');
        require(address(strategy) == address(0), 'WOOFiVaultV2: STRAT_ALREADY_SET');
        require(address(this) == IStrategy(_strat).vault(), 'WOOFiVaultV2: STRAT_VAULT_INVALID');
        require(want == IStrategy(_strat).want(), 'WOOFiVaultV2: STRAT_WANT_INVALID');
        strategy = IStrategy(_strat);

        emit UpgradeStrat(_strat);
    }

    function proposeStrat(address _implementation) public onlyAdmin {
        require(address(this) == IStrategy(_implementation).vault(), 'WOOFiVaultV2: STRAT_VAULT_INVALID');
        require(want == IStrategy(_implementation).want(), 'WOOFiVaultV2: STRAT_WANT_INVALID');
        stratCandidate = StratCandidate({implementation: _implementation, proposedTime: block.timestamp});

        emit NewStratCandidate(_implementation);
    }

    function upgradeStrat() public onlyAdmin {
        require(stratCandidate.implementation != address(0), 'WOOFiVaultV2: NO_CANDIDATE');
        require(stratCandidate.proposedTime.add(approvalDelay) < block.timestamp, 'WOOFiVaultV2: TIME_INVALID');

        emit UpgradeStrat(stratCandidate.implementation);

        strategy.retireStrat();
        strategy = IStrategy(stratCandidate.implementation);
        stratCandidate.implementation = address(0);
        stratCandidate.proposedTime = 5000000000; // 100+ years to ensure proposedTime check

        earn();
    }

    function setApprovalDelay(uint256 _approvalDelay) external onlyAdmin {
        require(_approvalDelay > 0, 'WOOFiVaultV2: approvalDelay_ZERO');
        approvalDelay = _approvalDelay;
    }

    function setEarnThreshold(uint256 _earnThreshold) external onlyAdmin {
        earnThreshold = _earnThreshold;
    }

    function inCaseTokensGetStuck(address stuckToken) external onlyAdmin {
        require(stuckToken != want, 'WOOFiVaultV2: stuckToken_NOT_WANT');
        require(stuckToken != address(0), 'WOOFiVaultV2: stuckToken_ZERO_ADDR');
        uint256 amount = IERC20(stuckToken).balanceOf(address(this));
        if (amount > 0) {
            TransferHelper.safeTransfer(stuckToken, msg.sender, amount);
        }
    }

    function inCaseNativeTokensGetStuck() external onlyAdmin {
        // NOTE: vault never needs native tokens to do the yield farming;
        // This native token balance indicates a user's incorrect transfer.
        if (address(this).balance > 0) {
            TransferHelper.safeTransferETH(msg.sender, address(this).balance);
        }
    }

    receive() external payable {}
}
