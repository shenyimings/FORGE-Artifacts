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

contract VaultErc20 is IVault, ERC20, Ownable, ReentrancyGuard {
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

    mapping(address => uint256) public costSharePrice;

    event NewStratCandidate(address indexed implementation);
    event UpgradeStrat(address indexed implementation);

    constructor(address initWant, address initAccessManager)
        public
        ERC20(
            string(abi.encodePacked('WOOFi Earn ', ERC20(initWant).name())),
            string(abi.encodePacked('we', ERC20(initWant).symbol()))
        )
    {
        require(initWant != address(0), 'Vault: initWant_ZERO_ADDR');
        require(initAccessManager != address(0), 'Vault: initAccessManager_ZERO_ADDR');

        want = initWant;
        accessManager = IWooAccessManager(initAccessManager);
    }

    modifier onlyAdmin() {
        require(owner() == _msgSender() || accessManager.isVaultAdmin(msg.sender), 'Vault: NOT_ADMIN');
        _;
    }

    /* ----- External Functions ----- */

    function deposit(uint256 amount) public payable override nonReentrant {
        require(amount > 0, 'Vault: amount_CAN_NOT_BE_ZERO');

        // STEP 0: strategy's routing work before deposit.
        if (address(strategy) != address(0)) {
            require(!strategy.paused(), 'Vault: strat_paused');
            strategy.beforeDeposit();
        }

        // STEP 1: check the deposit amount
        uint256 balanceBefore = balance();
        TransferHelper.safeTransferFrom(want, msg.sender, address(this), amount);
        uint256 balanceAfter = balance();
        require(amount <= balanceAfter.sub(balanceBefore), 'Vault: amount_NOT_ENOUGH');

        // STEP 2: issues the shares and update the cost basis
        uint256 shares = totalSupply() == 0 ? amount : amount.mul(totalSupply()).div(balanceBefore);
        uint256 sharesBefore = balanceOf(msg.sender);
        uint256 costBefore = costSharePrice[msg.sender];
        uint256 costAfter = (sharesBefore.mul(costBefore).add(amount.mul(1e18))).div(sharesBefore.add(shares));
        costSharePrice[msg.sender] = costAfter;
        _mint(msg.sender, shares);

        // STEP 3
        earn();
    }

    function withdraw(uint256 shares) public override nonReentrant {
        require(shares > 0, 'Vault: shares_ZERO');
        require(shares <= balanceOf(msg.sender), 'Vault: shares_NOT_ENOUGH');

        // STEP 0: burn the user's shares to start the withdrawal process.
        uint256 withdrawAmount = shares.mul(balance()).div(totalSupply());
        _burn(msg.sender, shares);

        // STEP 1: withdraw the token from strategy if needed
        uint256 balanceBefore = IERC20(want).balanceOf(address(this));
        if (balanceBefore < withdrawAmount) {
            uint256 balanceToWithdraw = withdrawAmount.sub(balanceBefore);
            require(_isStratActive(), 'Vault: STRAT_INACTIVE');
            strategy.withdraw(balanceToWithdraw);
            uint256 balanceAfter = IERC20(want).balanceOf(address(this));
            require(balanceAfter.sub(balanceBefore) > 0, 'Vault: Strat_WITHDRAW_ERROR');
            if (withdrawAmount > balanceAfter) {
                // NOTE: Tiny diff is accepted due to the decimal precision.
                withdrawAmount = balanceAfter;
            }
        }

        // STEP 3
        TransferHelper.safeTransfer(want, msg.sender, withdrawAmount);
    }

    function earn() public override {
        if (_isStratActive()) {
            uint256 balanceAvail = available();
            if (balanceAvail > 0) {
                TransferHelper.safeTransfer(want, address(strategy), balanceAvail);
                strategy.deposit();
            }
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
        require(_strat != address(0), 'Vault: STRAT_ZERO_ADDR');
        require(address(strategy) == address(0), 'Vault: STRAT_ALREADY_SET');
        require(address(this) == IStrategy(_strat).vault(), 'Vault: STRAT_VAULT_INVALID');
        require(want == IStrategy(_strat).want(), 'Vault: STRAT_WANT_INVALID');
        strategy = IStrategy(_strat);

        emit UpgradeStrat(_strat);
    }

    function proposeStrat(address _implementation) public onlyAdmin {
        require(address(this) == IStrategy(_implementation).vault(), 'Vault: STRAT_VAULT_INVALID');
        require(want == IStrategy(_implementation).want(), 'Vault: STRAT_WANT_INVALID');
        stratCandidate = StratCandidate({implementation: _implementation, proposedTime: block.timestamp});

        emit NewStratCandidate(_implementation);
    }

    function upgradeStrat() public onlyAdmin {
        require(stratCandidate.implementation != address(0), 'Vault: NO_CANDIDATE');
        require(stratCandidate.proposedTime.add(approvalDelay) < block.timestamp, 'Vault: TIME_INVALID');

        emit UpgradeStrat(stratCandidate.implementation);

        strategy.retireStrat();
        strategy = IStrategy(stratCandidate.implementation);
        stratCandidate.implementation = address(0);
        stratCandidate.proposedTime = 5000000000; // 100+ years to ensure proposedTime check

        earn();
    }

    function setApprovalDelay(uint256 newApprovalDelay) external onlyAdmin {
        require(newApprovalDelay > 0, 'Vault: newApprovalDelay_ZERO');
        approvalDelay = newApprovalDelay;
    }

    function inCaseTokensGetStuck(address stuckToken) external onlyAdmin {
        // NOTE: vault never allowed to access users' `want` token
        require(stuckToken != want, 'Vault: stuckToken_NOT_WANT');
        require(stuckToken != address(0), 'Vault: stuckToken_ZERO_ADDR');
        uint256 amount = IERC20(stuckToken).balanceOf(address(this));
        if (amount > 0) {
            TransferHelper.safeTransfer(stuckToken, msg.sender, amount);
        }
    }
}
