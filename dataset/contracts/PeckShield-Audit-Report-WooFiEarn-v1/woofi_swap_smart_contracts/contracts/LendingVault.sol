// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

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
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/utils/EnumerableSet.sol';
import '@openzeppelin/contracts/utils/Pausable.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import './interfaces/ILendingVault.sol';
import './interfaces/IWETH.sol';
import './interfaces/IStrategy.sol';
import './interfaces/IWooAccessManager.sol';

/// @title WOOFi LendingVault.
contract LendingVault is ERC20, Ownable, ReentrancyGuard, Pausable, ILendingVault {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    // *************** //
    // *** STRUCTS *** //
    // *************** //

    struct UserInfo {
        // 在`requestWithdraw()`加, `cancelRequestWithdraw()`和`weeklySettle()`清零
        uint256 requestedShares;
        // 在`weeklySettle()`加, `withdraw()`清零
        uint256 settledAssets;
        // 仅在`deposit()`时触发`_updateCostSharePrice()`来更新
        uint256 costSharePrice;
    }

    struct StrategyCandidate {
        address implementation;
        uint256 proposedTime;
    }

    // ******************************** //
    // *** CONSTANTS AND IMMUTABLES *** //
    // ******************************** //

    address public immutable weth;
    address public immutable override asset;

    uint256 private constant INTEREST_RATE_COEFF = 31536000; // 365 * 24 * 3600
    uint256 public constant MAX_PERCENTAGE = 10000; // 100%

    // ***************** //
    // *** VARIABLES *** //
    // ***************** //

    // 第三方复投策略(如Alpaca)
    address public strategy;
    // 在`instantWithdraw()`时抽取fees并transfer到`treasury`
    address public treasury;
    address public wooAccessManager;

    // `instantWithdraw()`的剩余限额, 每次`instantWithdraw()`都会减少
    // 每日执行`setDailyMaxInstantWithdrawAssets()`(仅)加大限额
    // 每周执行`setWeeklyMaxInstantWithdrawAssets()`重置额度
    uint256 public leftInstantWithdrawAssets;
    // `instantWithdraw()`的最大限额, 用于给前端展示
    // 每日执行`setDailyMaxInstantWithdrawAssets()`(仅)加大上限
    // 每周执行`setWeeklyMaxInstantWithdrawAssets()`更新上限
    uint256 public maxInstantWithdrawAssets;

    // 最大允许Market Maker借用`totalAssets()`的百分比
    uint256 public allowBorrowPercentage = 9000; // 90%
    // `instantWithdraw()`抽取fees的百分比
    uint256 public instantWithdrawFeePercentage = 30; // 0.3%
    // 未来利率百分比, 通过`setInterestRatePercentage()`更新, 更新之前需要`settleInterest()`结算过去的利息
    uint256 public interestRatePercentage; // 由Market Maker调用`setInterestRatePercentage()`更新

    // 总结算金额(这部分不再获得利息收益), 包括未还部分, 在`weeklySettle()`加, `withdraw()`减
    uint256 public totalSettledAssets;
    // Market Maker已还的结算金额, 在`repay()`参数repaySettle为true时表示还debtSettledAssets(联系`totalDebtSettledAssets`),
    // 即在`repay()`处加, 在`withdraw()`减(因为用户取了已经settle的金额)
    uint256 public totalRepaySettledAssets;
    // Market Maker欠的结算金额, 在`weeklySettle()`需要还款时加, `repay`参数repaySettle为true时减,
    // 当`repay()`时还完全部debt(即totalDebtSettledAssets等于0)时, 更新`instantWithdraw()`的每周新限额
    uint256 public totalDebtSettledAssets;
    // Market Maker总借款金额, 在`borrow()`加, `repay()`和`weeklySettle()`需要还款时减
    uint256 public totalBorrowedAssets;
    // 总利息金额(不包括已经结算掉的利率), 仅在`weeklySettle()`加(每周结算完后将没有request的用户利息加上)
    uint256 public totalInterestAssets;
    // 本周利息金额, 在`settleInterest()`加, `weeklySettle()`清零
    uint256 public weeklyInterestAssets;

    // 记录上次执行`settleInterest()`的时间戳
    uint256 public lastSettleInterestTimestamp;
    // 记录上次执行`weeklySettle()`的时间戳
    uint256 public lastWeeklySettleTimestamp;

    uint256 public weeklySettleDiff = 6.5 days; // 561600秒

    uint256 public approvalDelay = 48 hours;

    bool public allowRequestWithdraw = true;

    StrategyCandidate public strategyCandidate;

    EnumerableSet.AddressSet private requestUsers;
    mapping(address => UserInfo) public userInfo;

    // ******************* //
    // *** CONSTRUCTOR *** //
    // ******************* //

    constructor(address _weth, address _asset)
        public
        ERC20(
            string(abi.encodePacked('WOOFi ', ERC20(_asset).name())),
            string(abi.encodePacked('w ', ERC20(_asset).symbol()))
        )
    {
        weth = _weth;
        asset = _asset;
        // solhint-disable-next-line not-rely-on-time
        lastSettleInterestTimestamp = block.timestamp;
        // solhint-disable-next-line not-rely-on-time
        lastWeeklySettleTimestamp = block.timestamp;
    }

    // ***************** //
    // *** MODIFIERS *** //
    // ***************** //

    modifier onlyAdmin() {
        require(
            owner() == msg.sender || IWooAccessManager(wooAccessManager).isVaultAdmin(msg.sender),
            'LendingVault: Not admin'
        );
        _;
    }

    // ************************ //
    // *** PUBLIC FUNCTIONS *** //
    // ************************ //

    /// @inheritdoc ILendingVault
    function totalAssets() public view override returns (uint256 totalManagedAssets) {
        uint256 localAssets_ = localAssets();
        uint256 strategyAssets = IStrategy(strategy).balanceOf();
        uint256 wooPoolAssets = totalBorrowedAssets.add(totalInterestAssets).add(weeklyInterestAssets);

        totalManagedAssets = localAssets_.add(strategyAssets).add(wooPoolAssets);
    }

    /// @inheritdoc ILendingVault
    function localAssets() public view override returns (uint256 assets) {
        assets = IERC20(asset).balanceOf(address(this)).sub(totalRepaySettledAssets);
    }

    /// @inheritdoc ILendingVault
    function getPricePerFullShare() public view override returns (uint256 sharePrice) {
        sharePrice = _convertToAssets(1e18, false);
    }

    /// @inheritdoc ILendingVault
    function convertToShares(uint256 assets) public view override returns (uint256 shares) {
        shares = _convertToShares(assets, false);
    }

    /// @inheritdoc ILendingVault
    function convertToAssets(uint256 shares) public view override returns (uint256 assets) {
        assets = _convertToAssets(shares, false);
    }

    /// @inheritdoc ILendingVault
    function maxDeposit(address) public view override returns (uint256 maxAssets) {
        maxAssets = paused() ? 0 : uint256(-1);
    }

    /// @inheritdoc ILendingVault
    function maxWithdraw(address user) public view override returns (uint256 maxAssets) {
        UserInfo memory userInfo_ = userInfo[user];
        maxAssets = userInfo_.settledAssets;
    }

    /// @inheritdoc ILendingVault
    function maxRequestWithdraw(address user) public view override returns (uint256 maxAssets) {
        maxAssets = _convertToAssets(balanceOf(user), false);
    }

    /// @inheritdoc ILendingVault
    function maxInstantWithdraw(address user) public view override returns (uint256 maxAssets) {
        uint256 assets = _convertToAssets(balanceOf(user), false);
        maxAssets = leftInstantWithdrawAssets > assets ? assets : leftInstantWithdrawAssets;
    }

    /// @inheritdoc ILendingVault
    function isStrategyActive() public view override returns (bool active) {
        active = strategy != address(0) && !IStrategy(strategy).paused();
    }

    // ************************** //
    // *** EXTERNAL FUNCTIONS *** //
    // ************************** //

    /// @inheritdoc ILendingVault
    function deposit(uint256 assets) external payable override nonReentrant whenNotPaused returns (uint256 shares) {
        require((shares = _convertToShares(assets, false)) != 0, 'LendingVault: Zero shares');

        uint256 assetsBefore = localAssets();
        if (asset == weth) {
            require(msg.value == assets, 'LendingVault: msg.value insufficient');
            IWETH(weth).deposit{value: msg.value}();
        } else {
            require(msg.value == 0, 'LendingVault: msg.value invalid');
            TransferHelper.safeTransferFrom(asset, msg.sender, address(this), assets);
        }
        uint256 assetsAfter = localAssets();
        require(assetsAfter.sub(assetsBefore) >= assets, 'LendingVault: assets not enough');

        _updateCostSharePrice(msg.sender, assets, shares);
        _mint(msg.sender, shares);
        _farmAtStrategy();

        emit Deposit(msg.sender, assets, shares);
    }

    /// @inheritdoc ILendingVault
    function withdraw() external override nonReentrant {
        UserInfo storage userInfo_ = userInfo[msg.sender];
        uint256 assets = userInfo_.settledAssets;
        require(totalSettledAssets >= assets, 'LendingVault: Not settle, please wait');
        require(totalRepaySettledAssets >= assets, 'LendingVault: Not repay, please wait');
        userInfo_.settledAssets = 0;
        totalSettledAssets = totalSettledAssets.sub(assets);
        totalRepaySettledAssets = totalRepaySettledAssets.sub(assets);

        if (asset == weth) {
            IWETH(weth).withdraw(assets);
            TransferHelper.safeTransferETH(msg.sender, assets);
        } else {
            TransferHelper.safeTransfer(asset, msg.sender, assets);
        }

        emit Withdraw(msg.sender, assets);
    }

    /// @inheritdoc ILendingVault
    function requestWithdraw(uint256 assets) external override nonReentrant returns (uint256 shares) {
        require(allowRequestWithdraw, 'LendingVault: Not allow yet, please wait');
        require(assets <= maxRequestWithdraw(msg.sender), 'LendingVault: msg.sender assets insufficient');
        require((shares = _convertToShares(assets, true)) != 0, 'LendingVault: Zero shares');

        // 将用户的shares存入Vault, 让Vault暂时保管(不会burn, 在`weeklySettle()`时才会burn)
        TransferHelper.safeTransferFrom(address(this), msg.sender, address(this), shares);

        UserInfo storage userInfo_ = userInfo[msg.sender];
        userInfo_.requestedShares = userInfo_.requestedShares.add(shares);
        requestUsers.add(msg.sender);

        // 此处`assets`仅表示request时存入的shares价值多少assets, 最终得到的assets需在`weeklySettle()`后才准确
        emit RequestWithdraw(msg.sender, assets, shares);
    }

    /// @inheritdoc ILendingVault
    function cancelRequestWithdraw() external override nonReentrant returns (uint256 shares) {
        require(allowRequestWithdraw, 'LendingVault: Not allow yet, please wait');
        UserInfo storage userInfo_ = userInfo[msg.sender];
        require((shares = userInfo_.requestedShares) != 0, 'LendingVault: Zero shares');

        userInfo_.requestedShares = 0;
        requestUsers.remove(msg.sender);

        TransferHelper.safeTransfer(address(this), msg.sender, shares);

        uint256 assets = _convertToAssets(shares, false);
        // `assets` is not the final result, share price will increase until next epoch
        emit CancelRequestWithdraw(msg.sender, assets, shares);
    }

    /// @inheritdoc ILendingVault
    function instantWithdraw(uint256 assets) external override nonReentrant returns (uint256 shares) {
        require(assets <= maxInstantWithdraw(msg.sender), 'LendingVault: msg.sender assets insufficient');
        require((shares = _convertToShares(assets, true)) != 0, 'LendingVault: Zero shares');

        if (isStrategyActive()) {
            IStrategy(strategy).beforeWithdraw();
        }

        _burn(msg.sender, shares);

        _withdrawStrategyIfNeed(assets);
        require(assets <= localAssets(), 'LendingVault: assets exceed');

        leftInstantWithdrawAssets = leftInstantWithdrawAssets.sub(assets);

        uint256 fees;
        if (IWooAccessManager(wooAccessManager).isZeroFeeVault(msg.sender)) {
            fees = 0;
        } else {
            fees = assets.mul(instantWithdrawFeePercentage).div(MAX_PERCENTAGE);
        }

        if (asset == weth) {
            IWETH(weth).withdraw(assets);
            TransferHelper.safeTransferETH(msg.sender, assets.sub(fees));
            if (fees > 0) {
                TransferHelper.safeTransferETH(treasury, fees);
            }
        } else {
            TransferHelper.safeTransfer(asset, msg.sender, assets.sub(fees));
            if (fees > 0) {
                TransferHelper.safeTransfer(asset, treasury, fees);
            }
        }

        emit InstantWithdraw(msg.sender, assets, shares, fees);
    }

    // *********************** //
    // *** ADMIN FUNCTIONS *** //
    // *********************** //

    function settleInterest() public onlyAdmin {
        // solhint-disable-next-line not-rely-on-time
        uint256 currentSettleInterestTimestamp = block.timestamp;
        require(currentSettleInterestTimestamp >= lastSettleInterestTimestamp, 'LendingVault: Timestamp exceed');

        uint256 diff = currentSettleInterestTimestamp.sub(lastSettleInterestTimestamp);
        uint256 rate = diff.mul(1e18).mul(interestRatePercentage).div(INTEREST_RATE_COEFF).div(MAX_PERCENTAGE);
        uint256 interestAssets = totalBorrowedAssets.mul(rate).div(1e18);

        weeklyInterestAssets = weeklyInterestAssets.add(interestAssets);
        lastSettleInterestTimestamp = currentSettleInterestTimestamp;

        emit SettleInterest(msg.sender, diff, rate, interestAssets, weeklyInterestAssets);
    }

    /// @notice 不用程序直接触发, 可以通过`weeklySettle()`和`repay()`顺带触发
    function setWeeklyMaxInstantWithdrawAssets() public onlyAdmin returns (uint256 maxAssets) {
        maxAssets = totalAssets().mul(MAX_PERCENTAGE.sub(allowBorrowPercentage)).div(MAX_PERCENTAGE);
        leftInstantWithdrawAssets = maxAssets;
        maxInstantWithdrawAssets = maxAssets;

        emit SetWeeklyMaxInstantWithdrawAssets(maxAssets);
    }

    function setInterestRatePercentage(uint256 _interestRatePercentage) external onlyAdmin {
        require(_interestRatePercentage <= MAX_PERCENTAGE, 'LendingVault: _interestRatePercentage exceed');
        settleInterest();
        interestRatePercentage = _interestRatePercentage;
    }

    function setWeeklySettleDiff(uint256 _weeklySettleDiff) external onlyAdmin {
        weeklySettleDiff = _weeklySettleDiff;
    }

    /// @notice 程序周一UTC0点触发
    function weeklySettle() external onlyAdmin {
        require(lastWeeklySettleTimestamp.add(weeklySettleDiff) < block.timestamp, 'LendingVault: Not ready to settle');

        if (isStrategyActive()) {
            IStrategy(strategy).beforeWithdraw();
        }
        settleInterest();

        uint256 weeklyBurnShares = 0;
        uint256 weeklySettledAssets = 0;
        uint256 length = requestUsers.length();
        for (uint256 i = 0; i < length; i++) {
            address user = requestUsers.at(0);
            UserInfo storage userInfo_ = userInfo[user];
            uint256 shares = userInfo_.requestedShares;
            weeklyBurnShares = weeklyBurnShares.add(shares);
            uint256 assets = _convertToAssets(shares, false);
            userInfo_.requestedShares = 0;
            userInfo_.settledAssets = userInfo_.settledAssets.add(assets);
            weeklySettledAssets = weeklySettledAssets.add(assets);
            totalSettledAssets = totalSettledAssets.add(assets);
            requestUsers.remove(user);
            emit WeeklySettle(msg.sender, user, assets, shares);
        }
        uint256 totalAssets_ = totalAssets();
        // 将`weeklyInterestAssets`分成两部分, request部分的利息已经在上述for循环里结算给用户(这部分不会再享受到后续利息)
        // 而剩下的部分`leftInterestAssets`将累计到`totalInterestAssets`, 然后清空`weeklyInterestAssets`并burn掉已结算用户的总shares(等于总request的shares)
        uint256 leftInterestAssets = weeklyInterestAssets.mul(totalAssets_.sub(weeklySettledAssets)).div(totalAssets_);
        totalInterestAssets = totalInterestAssets.add(leftInterestAssets);
        weeklyInterestAssets = 0;
        _burn(address(this), weeklyBurnShares);

        totalAssets_ = totalAssets();
        uint256 allowBorrowAssets = totalAssets_.mul(allowBorrowPercentage).div(MAX_PERCENTAGE);

        if (weeklySettledAssets > allowBorrowAssets.sub(totalBorrowedAssets)) {
            uint256 debtSettledAssets = weeklySettledAssets.sub(totalAssets_.sub(totalBorrowedAssets));
            totalBorrowedAssets = totalBorrowedAssets.sub(debtSettledAssets);
            // 需要还款时(有debt)不能执行`setWeeklyMaxInstantWithdrawAssets()`
            totalDebtSettledAssets = totalDebtSettledAssets.add(debtSettledAssets);
        } else {
            // 不需要还款时可以直接执行`setWeeklyMaxInstantWithdrawAssets()`, 因为Vault有足够的金额给用户进行新一周的`instantWithdraw()`
            setWeeklyMaxInstantWithdrawAssets();
        }

        lastWeeklySettleTimestamp = block.timestamp;
    }

    function borrow(uint256 assets) external onlyAdmin {
        if (isStrategyActive()) {
            IStrategy(strategy).beforeWithdraw();
        }

        uint256 allowBorrowAssets = totalAssets().mul(allowBorrowPercentage).div(MAX_PERCENTAGE);
        require(totalBorrowedAssets.add(assets) <= allowBorrowAssets, 'LendingVault: assets exceed');

        _withdrawStrategyIfNeed(assets);
        require(assets <= localAssets(), 'LendingVault: assets exceed');

        settleInterest();
        totalBorrowedAssets = totalBorrowedAssets.add(assets);
        TransferHelper.safeTransfer(asset, msg.sender, assets);

        emit Borrow(assets);
    }

    function repay(uint256 assets, bool repaySettle) external onlyAdmin {
        if (assets > 0) {
            require(
                (!repaySettle && totalBorrowedAssets >= assets) || (repaySettle && totalDebtSettledAssets >= assets),
                'LendingVault: repaySettle error or assets too much'
            );

            uint256 assetsBefore = localAssets();
            TransferHelper.safeTransferFrom(asset, msg.sender, address(this), assets);
            uint256 assetsAfter = localAssets();
            require(assetsAfter.sub(assetsBefore) >= assets, 'LendingVault: assets not enough');

            if (repaySettle) {
                totalRepaySettledAssets = totalRepaySettledAssets.add(assets);
                totalDebtSettledAssets = totalDebtSettledAssets.sub(assets);
                // 还清欠款后需要更新`instantWithdraw()`每周新限额
                if (totalDebtSettledAssets == 0) {
                    setWeeklyMaxInstantWithdrawAssets();
                }
            } else {
                totalBorrowedAssets = totalBorrowedAssets.sub(assets);
                _farmAtStrategy();
            }

            emit Repay(assets, repaySettle);
        }
    }

    function setTreasury(address _treasury) external onlyAdmin {
        require(_treasury != address(0), 'LendingVault: _treasury not set');
        treasury = _treasury;
    }

    function setWooAccessManager(address _wooAccessManager) external onlyAdmin {
        require(_wooAccessManager != address(0), 'LendingVault: _wooAccessManager not set');
        wooAccessManager = _wooAccessManager;
    }

    /// @notice 程序每天UTC0点更新(除了周一UTC0点)
    function setDailyMaxInstantWithdrawAssets() external onlyAdmin returns (uint256 maxAssets) {
        maxAssets = totalAssets().mul(MAX_PERCENTAGE.sub(allowBorrowPercentage)).div(MAX_PERCENTAGE);
        if (maxAssets > maxInstantWithdrawAssets) {
            uint256 increaseAssets = maxAssets.sub(maxInstantWithdrawAssets);
            leftInstantWithdrawAssets = leftInstantWithdrawAssets.add(increaseAssets);
            maxInstantWithdrawAssets = maxAssets;
        }

        emit SetDailyMaxInstantWithdrawAssets(maxInstantWithdrawAssets, leftInstantWithdrawAssets, maxAssets);
    }

    function setAllowBorrowPercentage(uint256 _allowBorrowPercentage) external onlyAdmin {
        require(_allowBorrowPercentage <= MAX_PERCENTAGE, 'LendingVault: _allowBorrowPercentage exceed');
        require(
            totalBorrowedAssets <= localAssets().mul(_allowBorrowPercentage).div(MAX_PERCENTAGE),
            'LendingVault: _allowBorrowPercentage too small'
        );
        allowBorrowPercentage = _allowBorrowPercentage;
    }

    function setInstantWithdrawFeePercentage(uint256 _instantWithdrawFeePercentage) external onlyAdmin {
        require(_instantWithdrawFeePercentage <= MAX_PERCENTAGE, 'LendingVault: _instantWithdrawFeePercentage exceed');
        instantWithdrawFeePercentage = _instantWithdrawFeePercentage;
    }

    function setApprovalDelay(uint256 _approvalDelay) external onlyAdmin {
        approvalDelay = _approvalDelay;
    }

    function setAllowRequestWithdraw(bool _allowRequestWithdraw) external onlyAdmin {
        allowRequestWithdraw = _allowRequestWithdraw;
    }

    function setupStrategy(address _strategy) external onlyAdmin {
        require(_strategy != address(0), 'LendingVault: _strategy not set');
        require(address(strategy) == address(0), 'LendingVault: strategy already set');
        require(address(this) == IStrategy(_strategy).vault(), 'LendingVault: _strategy vault invalid');
        require(asset == IStrategy(_strategy).want(), 'LendingVault: _strategy want invalid');
        strategy = _strategy;

        emit UpgradeStrategy(_strategy);
    }

    function proposeStrat(address _strategy) external onlyAdmin {
        require(address(this) == IStrategy(_strategy).vault(), 'LendingVault: _strategy vault invalid');
        require(asset == IStrategy(_strategy).want(), 'LendingVault: _strategy want invalid');
        // solhint-disable-next-line not-rely-on-time
        strategyCandidate = StrategyCandidate({implementation: _strategy, proposedTime: block.timestamp});

        emit NewStrategyCandidate(_strategy);
    }

    function upgradeStrat() external onlyAdmin {
        require(strategyCandidate.implementation != address(0), 'LendingVault: No candidate');
        // solhint-disable-next-line not-rely-on-time
        require(strategyCandidate.proposedTime.add(approvalDelay) < block.timestamp, 'LendingVault: Time invalid');

        IStrategy(strategy).retireStrat();
        strategy = strategyCandidate.implementation;
        strategyCandidate.implementation = address(0);
        strategyCandidate.proposedTime = 5000000000; // 100+ years to ensure proposedTime check

        _farmAtStrategy();

        emit UpgradeStrategy(strategyCandidate.implementation);
    }

    function inCaseTokensGetStuck(address token) external onlyAdmin {
        require(token != asset, 'LendingVault: token not allow');
        require(token != address(0), 'LendingVault: token not set');
        uint256 tokenBal = IERC20(token).balanceOf(address(this));
        if (tokenBal > 0) {
            TransferHelper.safeTransfer(token, msg.sender, tokenBal);
        }
    }

    function inCaseNativeTokensGetStuck() external onlyAdmin {
        // Vault never needs native tokens to do the yield farming,
        // this native token balance indicates a user's incorrect transfer.
        uint256 nativeBal = address(this).balance;
        if (nativeBal > 0) {
            TransferHelper.safeTransferETH(msg.sender, nativeBal);
        }
    }

    // ************************** //
    // *** INTERNAL FUNCTIONS *** //
    // ************************** //

    function _convertToAssets(uint256 shares, bool roundUp) internal view returns (uint256 assets) {
        uint256 totalSupply_ = totalSupply();
        if (totalSupply_ == 0) {
            assets = shares;
        } else {
            uint256 totalAssets_ = totalAssets();
            assets = shares.mul(totalAssets_).div(totalSupply_);
            if (roundUp && assets.mul(totalSupply_).div(totalAssets_) < shares) {
                assets = assets.add(1);
            }
        }
    }

    function _convertToShares(uint256 assets, bool roundUp) internal view returns (uint256 shares) {
        uint256 totalSupply_ = totalSupply();
        if (totalSupply_ == 0) {
            shares = assets;
        } else {
            uint256 totalAssets_ = totalAssets();
            shares = assets.mul(totalSupply_).div(totalAssets_);
            if (roundUp && shares.mul(totalAssets_).div(totalSupply_) < assets) {
                shares = shares.add(1);
            }
        }
    }

    function _updateCostSharePrice(
        address user,
        uint256 assets,
        uint256 shares
    ) internal {
        uint256 sharesBefore = balanceOf(user);
        UserInfo storage userInfo_ = userInfo[user];
        uint256 costBefore = userInfo_.costSharePrice;

        userInfo_.costSharePrice = (sharesBefore.mul(costBefore).add(assets.mul(1e18))).div(sharesBefore.add(shares));
    }

    function _farmAtStrategy() internal {
        if (isStrategyActive()) {
            uint256 localAssets_ = localAssets();
            TransferHelper.safeTransfer(asset, strategy, localAssets_);
            IStrategy(strategy).deposit();
        }
    }

    function _withdrawStrategyIfNeed(uint256 assets) internal {
        uint256 localAssets_ = localAssets();
        if (localAssets_ < assets) {
            uint256 withdrawAmount = assets.sub(localAssets_);
            require(isStrategyActive(), 'LendingVault: Strategy inactive');
            IStrategy(strategy).withdraw(withdrawAmount);
        }
    }

    // ************************** //
    // *** CALLBACK FUNCTIONS *** //
    // ************************** //

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}
}
