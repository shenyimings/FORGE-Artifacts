// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import "./../../utils/UpgradeableBase.sol";
import "./../../interfaces/IXToken.sol";
import "./../../interfaces/IMultiLogicProxy.sol";
import "./../../interfaces/ILogicContract.sol";
import "./../../interfaces/IStrategyStatistics.sol";
import "./../../interfaces/IStrategyContract.sol";
import "./LendBorrowLendStrategyHelper.sol";

contract LendBorrowLendStrategy is UpgradeableBase, IStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeCastUpgradeable for uint256;

    address internal constant ZERO_ADDRESS = address(0);
    uint256 internal constant DECIMALS = 18;
    uint256 internal constant BASE = 10**DECIMALS;

    address public logic;
    address public blid;
    address public strategyXToken;
    address public strategyToken;
    address public comptroller;
    address public rewardsToken;

    // Strategy Parameter
    uint8 public circlesCount;
    uint8 public avoidLiquidationFactor;

    uint256 private minStorageAvailable;
    uint256 public borrowRateMin;
    uint256 public borrowRateMax;

    address public multiLogicProxy;
    address public strategyStatistics;

    // RewardsTokenPrice kill switch
    uint256 public rewardsTokenPriceDeviationLimit; // percentage, decimal = 18
    RewardsTokenPriceInfo private rewardsTokenPriceInfo;

    uint256 minimumBLIDPerRewardToken;
    uint256 minRewardsSwapLimit;

    // Swap Information
    SwapInfo internal swapRewardsToBLIDInfo;
    SwapInfo internal swapRewardsToStrategyTokenInfo;
    SwapInfo internal swapStrategyTokenToBLIDInfo;
    SwapInfo internal swapStrategyTokenToSupplyTokenInfo;
    SwapInfo internal swapSupplyTokenToBLIDInfo;

    address public supplyXToken;
    address public supplyToken;

    event SetBLID(address blid);
    event SetCirclesCount(uint8 circlesCount);
    event SetAvoidLiquidationFactor(uint8 avoidLiquidationFactor);
    event SetMinRewardsSwapLimit(uint256 _minRewardsSwapLimit);
    event SetStrategyXToken(address strategyXToken);
    event SetSupplyXToken(address supplyXToken);
    event SetMinStorageAvailable(uint256 minStorageAvailable);
    event SetRebalanceParameter(uint256 borrowRateMin, uint256 borrowRateMax);
    event SetRewardsTokenPriceDeviationLimit(uint256 deviationLimit);
    event SetRewardsTokenPriceInfo(uint256 latestAnser, uint256 timestamp);
    event BuildCircle(address token, uint256 amount, uint256 circlesCount);
    event DestroyCircle(
        address token,
        uint256 circlesCount,
        uint256 destroyAmountLimit
    );
    event DestroyAll(address token, uint256 destroyAmount, uint256 blidAmount);
    event ClaimRewards(uint256 amount);
    event UseToken(address token, uint256 amount);
    event ReleaseToken(address token, uint256 amount);

    function __Strategy_init(address _comptroller, address _logic)
        public
        initializer
    {
        UpgradeableBase.initialize();
        comptroller = _comptroller;
        rewardsToken = ILendingLogic(_logic).rewardToken();
        logic = _logic;

        rewardsTokenPriceDeviationLimit = (1 ether) / uint256(86400); // limit is 100% within 1 day, 50% within 1 day = (1 ether) * 50 / (100 * 86400)
    }

    receive() external payable {}

    modifier onlyMultiLogicProxy() {
        _;
    }

    modifier onlyStrategyPaused() {
        require(_checkStrategyPaused(), "C2");
        _;
    }

    /*** Public Initialize Function ***/

    /**
     * @notice Set blid in contract
     * @param _blid Address of BLID
     */
    function setBLID(address _blid) external onlyOwner {
        if (_blid != ZERO_ADDRESS) {
            blid = _blid;
            emit SetBLID(_blid);
        }
    }

    /**
     * @notice Set MultiLogicProxy, you can call the function once
     * @param _multiLogicProxy Address of Multilogic Contract
     */
    function setMultiLogicProxy(address _multiLogicProxy) external onlyOwner {
        if (_multiLogicProxy != ZERO_ADDRESS) {
            multiLogicProxy = _multiLogicProxy;
        }
    }

    /**
     * @notice Set StrategyStatistics
     * @param _strategyStatistics Address of StrategyStatistics
     */
    function setStrategyStatistics(address _strategyStatistics)
        external
        onlyOwner
    {
        if (_strategyStatistics != ZERO_ADDRESS) {
            strategyStatistics = _strategyStatistics;

            // Save RewardsTokenPriceInfo
            rewardsTokenPriceInfo.latestAnswer = IStrategyStatistics(
                _strategyStatistics
            ).getRewardsTokenPrice(comptroller, rewardsToken);
            rewardsTokenPriceInfo.timestamp = block.timestamp;
        }
    }

    /**
     * @notice Set circlesCount
     * @param _circlesCount Count number
     */
    function setCirclesCount(uint8 _circlesCount) external onlyOwner {
        circlesCount = _circlesCount;

        emit SetCirclesCount(_circlesCount);
    }

    /**
     * @notice Set min Rewards swap limit
     * @param _minRewardsSwapLimit minimum swap amount for rewards token
     */
    function setMinRewardsSwapLimit(uint256 _minRewardsSwapLimit)
        external
        onlyOwner
    {
        minRewardsSwapLimit = _minRewardsSwapLimit;

        emit SetMinRewardsSwapLimit(_minRewardsSwapLimit);
    }

    /**
     * @notice Set minimumBLIDPerRewardToken
     * @param _minimumBLIDPerRewardToken minimum BLID for RewardsToken
     */
    function setMinBLIDPerRewardsToken(uint256 _minimumBLIDPerRewardToken)
        external
        onlyOwner
    {
        minimumBLIDPerRewardToken = _minimumBLIDPerRewardToken;
    }

    /**
     * @notice Set Rewards -> StrategyToken swap information
     * @param swapInfo : addresses of swapRouter and path
     * @param swapPurpose : index of swap purpose
     * 0 : swapRewardsToBLIDInfo
     * 1 : swapRewardsToStrategyTokenInfo
     * 2 : swapStrategyTokenToBLIDInfo
     * 3 : swapStrategyTokenToSupplyTokenInfo
     * 4 : swapSupplyTokenToBLIDInfo
     */
    function setSwapInfo(SwapInfo memory swapInfo, uint8 swapPurpose)
        external
        onlyOwner
    {
        LendBorrowLendStrategyHelper.checkSwapInfo(
            swapInfo,
            swapPurpose,
            supplyToken,
            strategyToken,
            rewardsToken,
            blid
        );

        if (swapPurpose == 0) {
            swapRewardsToBLIDInfo.swapRouters = swapInfo.swapRouters;
            swapRewardsToBLIDInfo.paths = swapInfo.paths;
        } else if (swapPurpose == 1) {
            swapRewardsToStrategyTokenInfo.swapRouters = swapInfo.swapRouters;
            swapRewardsToStrategyTokenInfo.paths = swapInfo.paths;
        } else if (swapPurpose == 2) {
            swapStrategyTokenToBLIDInfo.swapRouters = swapInfo.swapRouters;
            swapStrategyTokenToBLIDInfo.paths = swapInfo.paths;
        } else if (swapPurpose == 3) {
            swapStrategyTokenToSupplyTokenInfo.swapRouters = swapInfo
                .swapRouters;
            swapStrategyTokenToSupplyTokenInfo.paths = swapInfo.paths;
        } else {
            swapSupplyTokenToBLIDInfo.swapRouters = swapInfo.swapRouters;
            swapSupplyTokenToBLIDInfo.paths = swapInfo.paths;
        }
    }

    /**
     * @notice Set avoidLiquidationFactor
     * @param _avoidLiquidationFactor factor value (0-99)
     */
    function setAvoidLiquidationFactor(uint8 _avoidLiquidationFactor)
        external
        onlyOwner
    {
        require(_avoidLiquidationFactor < 100, "C4");

        avoidLiquidationFactor = _avoidLiquidationFactor;
        emit SetAvoidLiquidationFactor(_avoidLiquidationFactor);
    }

    /**
     * @notice Set MinStorageAvailable
     * @param amount amount of min storage available for token using : decimals = token decimals
     */
    function setMinStorageAvailable(uint256 amount) external onlyOwner {
        minStorageAvailable = amount;

        emit SetMinStorageAvailable(amount);
    }

    /**
     * @notice Set RebalanceParameter
     * @param _borrowRateMin borrowRate min : decimals = 18
     * @param _borrowRateMax borrowRate max : deciamls = 18
     */
    function setRebalanceParameter(
        uint256 _borrowRateMin,
        uint256 _borrowRateMax
    ) external onlyOwner {
        require(_borrowRateMin < BASE && _borrowRateMax < BASE, "C4");

        borrowRateMin = _borrowRateMin;
        borrowRateMax = _borrowRateMax;

        emit SetRebalanceParameter(_borrowRateMin, _borrowRateMin);
    }

    /**
     * @notice Set RewardsTokenPriceDeviationLimit
     * @param _rewardsTokenPriceDeviationLimit price Diviation per seccond limit
     */
    function setRewardsTokenPriceDeviationLimit(
        uint256 _rewardsTokenPriceDeviationLimit
    ) external onlyOwner {
        rewardsTokenPriceDeviationLimit = _rewardsTokenPriceDeviationLimit;

        emit SetRewardsTokenPriceDeviationLimit(
            _rewardsTokenPriceDeviationLimit
        );
    }

    /**
     * @notice Force update rewardsTokenPrice
     * @param latestAnswer new latestAnswer
     */
    function setRewardsTokenPrice(uint256 latestAnswer) external onlyOwner {
        rewardsTokenPriceInfo.latestAnswer = latestAnswer;
        rewardsTokenPriceInfo.timestamp = block.timestamp;

        emit SetRewardsTokenPriceInfo(latestAnswer, block.timestamp);
    }

    /*** Public Automation Check view function ***/

    /**
     * @notice Check wheather storageAvailable is bigger enough
     * @return canUseToken true : useToken is possible
     */
    function checkUseToken() public view override returns (bool canUseToken) {
        if (
            IMultiLogicProxy(multiLogicProxy).getTokenAvailable(
                supplyToken,
                logic
            ) < minStorageAvailable
        ) {
            canUseToken = false;
        } else {
            canUseToken = true;
        }
    }

    /**
     * @notice Check whether borrow rate is ok
     * @return canRebalance true : rebalance is possible, borrow rate is abnormal
     */
    function checkRebalance() public view override returns (bool canRebalance) {
        // Get lending status, borrowRate
        (bool isLending, uint256 borrowRate) = LendBorrowLendStrategyHelper
            .getBorrowRate(
                strategyStatistics,
                logic,
                supplyXToken,
                strategyXToken
            );

        // If no lending, can't rebalance
        if (!isLending) return false;

        // Determine rebalance with borrowRate
        if (borrowRate > borrowRateMax || borrowRate < borrowRateMin) {
            canRebalance = true;
        } else {
            canRebalance = false;
        }
    }

    /**
     * @notice Set StrategyXToken
     * Add XToken for circle in Contract and approve token
     * @param _xToken Address of XToken
     */
    function setStrategyXToken(address _xToken)
        external
        onlyOwner
        onlyStrategyPaused
    {
        if (_xToken != ZERO_ADDRESS && strategyXToken != _xToken) {
            strategyXToken = _xToken;
            strategyToken = _registerToken(_xToken, logic);

            emit SetStrategyXToken(_xToken);
        }
    }

    /**
     * @notice Set SupplyXToken
     * Add XToken for supply in Contract and approve token
     * @param _xToken Address of XToken
     */
    function setSupplyXToken(address _xToken)
        external
        onlyOwner
        onlyStrategyPaused
    {
        if (_xToken != ZERO_ADDRESS && supplyXToken != _xToken) {
            supplyXToken = _xToken;
            supplyToken = _registerToken(_xToken, logic);

            emit SetSupplyXToken(_xToken);
        }
    }

    /*** Public Strategy Function ***/

    function useToken() external override {
        address _logic = logic;
        address _supplyXToken = supplyXToken;
        address _strategyXToken = strategyXToken;
        address _supplyToken = supplyToken;

        // Check if storageAvailable is bigger enough
        uint256 availableAmount = IMultiLogicProxy(multiLogicProxy)
            .getTokenAvailable(_supplyToken, _logic);
        if (availableAmount < minStorageAvailable) return;

        // Take token from storage
        ILogic(_logic).takeTokenFromStorage(availableAmount, _supplyToken);

        // If strategy is empty, entermarket again
        if (
            ILendingLogic(_logic).checkEnteredMarket(_supplyXToken) == false ||
            ILendingLogic(_logic).checkEnteredMarket(_strategyXToken) == false
        ) {
            address[] memory tokens = new address[](2);
            tokens[0] = _supplyXToken;
            tokens[1] = _strategyXToken;
            ILendingLogic(_logic).enterMarkets(tokens);
        }

        // Mint
        ILendingLogic(_logic).mint(_supplyXToken, availableAmount);

        emit UseToken(_supplyToken, availableAmount);
    }

    function rebalance() external override {
        address _logic = logic;
        address _strategyXToken = strategyXToken;
        address _supplyXToken = supplyXToken;
        uint8 _circlesCount = circlesCount;

        // Get CollateralFactor
        (
            uint256 collateralFactorStrategy,
            uint256 collateralFactorStrategyApplied
        ) = _getCollateralFactor(_strategyXToken);

        // Get XToken information
        uint256 supplyBorrowLimitUSD;
        uint256 strategyPriceUSD;

        if (_supplyXToken != _strategyXToken) {
            XTokenInfo memory tokenInfo = IStrategyStatistics(
                strategyStatistics
            ).getStrategyXTokenInfo(_supplyXToken, _logic);

            supplyBorrowLimitUSD = tokenInfo.borrowLimitUSD;
        }

        // Call accrueInterest
        ILendingLogic(_logic).accrueInterest(_strategyXToken);
        ILendingLogic(_logic).accrueInterest(_supplyXToken);

        int256 amount;
        (amount, strategyPriceUSD) = LendBorrowLendStrategyHelper
            .getRebalanceAmount(
                RebalanceParam({
                    strategyStatistics: strategyStatistics,
                    logic: _logic,
                    supplyXToken: _supplyXToken,
                    strategyXToken: _strategyXToken,
                    borrowRateMin: borrowRateMin,
                    borrowRateMax: borrowRateMax,
                    circlesCount: _circlesCount,
                    supplyBorrowLimitUSD: supplyBorrowLimitUSD,
                    collateralFactorStrategy: collateralFactorStrategy,
                    collateralFactorStrategyApplied: collateralFactorStrategyApplied
                })
            );

        // Build
        if (amount > 0) {
            createCircles(_strategyXToken, uint256(amount), _circlesCount);

            emit BuildCircle(_strategyXToken, uint256(amount), _circlesCount);
        }

        // Destroy
        if (amount < 0) {
            destructCircles(
                _strategyXToken,
                _circlesCount,
                supplyBorrowLimitUSD,
                collateralFactorStrategyApplied,
                strategyPriceUSD,
                uint256(0 - amount)
            );
            emit DestroyCircle(
                _strategyXToken,
                _circlesCount,
                uint256(0 - amount)
            );
        }
    }

    /**
     * @notice Destroy circle strategy
     * destroy circle and return all tokens to storage
     */
    function destroyAll() external override onlyOwnerAndAdmin {
        address _logic = logic;
        address _rewardsToken = rewardsToken;
        address _supplyXToken = supplyXToken;
        address _strategyXToken = strategyXToken;
        address _supplyToken = supplyToken;
        address _strategyStatistics = strategyStatistics;
        uint256 amountBLID = 0;

        // Destruct circle
        {
            // Get Supply XToken information
            uint256 supplyBorrowLimitUSD;
            uint256 strategyPriceUSD;

            if (_supplyXToken != _strategyXToken) {
                XTokenInfo memory tokenInfo = IStrategyStatistics(
                    strategyStatistics
                ).getStrategyXTokenInfo(_supplyXToken, _logic);

                supplyBorrowLimitUSD = tokenInfo.borrowLimitUSD;

                tokenInfo = IStrategyStatistics(_strategyStatistics)
                    .getStrategyXTokenInfo(_strategyXToken, _logic);

                strategyPriceUSD = tokenInfo.priceUSD;
            }

            // Get Collateral Factor
            (, uint256 collateralFactorStrategyApplied) = _getCollateralFactor(
                _strategyXToken
            );

            destructCircles(
                _strategyXToken,
                circlesCount,
                supplyBorrowLimitUSD,
                collateralFactorStrategyApplied,
                strategyPriceUSD,
                0
            );
        }

        // Claim Rewards token
        ILendingLogic(_logic).claim();

        // Get Rewards amount
        uint256 amountRewardsToken = IERC20MetadataUpgradeable(_rewardsToken)
            .balanceOf(_logic);

        // RewardsToken Price/Amount Kill Switch
        bool rewardsTokenKill = _rewardsPriceKillSwitch(
            _strategyStatistics,
            _rewardsToken,
            amountRewardsToken
        );

        // swap rewardsToken to StrategyToken
        if (rewardsTokenKill == false && amountRewardsToken > 0) {
            _multiSwap(
                _logic,
                amountRewardsToken,
                swapRewardsToStrategyTokenInfo
            );
        }

        // Process With Supply != Strategy
        if (_supplyXToken != _strategyXToken) {
            (uint256 totalSupply, , uint256 borrowAmount) = IStrategyStatistics(
                _strategyStatistics
            ).getStrategyXTokenInfoCompact(_strategyXToken, _logic);

            // StrategyXToken : if totalSupply > 0, redeem it
            if (totalSupply > 0) {
                ILendingLogic(_logic).redeem(
                    _strategyXToken,
                    IERC20MetadataUpgradeable(_strategyXToken).balanceOf(_logic)
                );
            }

            // StrategyXToken : If borrowAmount > 0, repay it
            if (borrowAmount > 0) {
                ILendingLogic(_logic).repayBorrow(
                    _strategyXToken,
                    borrowAmount
                );
            }

            // SupplyXToken : Redeem everything
            ILendingLogic(_logic).redeem(
                _supplyXToken,
                IERC20MetadataUpgradeable(_supplyXToken).balanceOf(_logic)
            );

            // Swap StrategyToken -> SupplyToken
            _multiSwap(
                _logic,
                IERC20MetadataUpgradeable(strategyToken).balanceOf(_logic),
                swapStrategyTokenToSupplyTokenInfo
            );
        }

        // Get strategy amount, current balance of underlying
        uint256 amountStrategy = IMultiLogicProxy(multiLogicProxy)
            .getTokenTaken(_supplyToken, _logic);
        uint256 balanceToken = _supplyToken == ZERO_ADDRESS
            ? address(_logic).balance
            : IERC20MetadataUpgradeable(_supplyToken).balanceOf(_logic);

        // If we have extra, swap SupplyToken to BLID
        if (balanceToken > amountStrategy) {
            _multiSwap(
                _logic,
                balanceToken - amountStrategy,
                swapSupplyTokenToBLIDInfo
            );

            // Add BLID earn to storage
            amountBLID = _addEarnToStorage();
        } else {
            amountStrategy = balanceToken;
        }

        // Return all tokens to strategy
        ILogic(_logic).returnTokenToStorage(amountStrategy, _supplyToken);

        emit DestroyAll(_supplyXToken, amountStrategy, amountBLID);
    }

    /**
     * @notice claim distribution rewards USDT both borrow and lend swap banana token to BLID
     */
    function claimRewards() public override onlyOwnerAndAdmin {
        address _logic = logic;
        address _strategyXToken = strategyXToken;
        address _strategyToken = strategyToken;
        address _rewardsToken = rewardsToken;
        address _strategyStatistics = strategyStatistics;
        uint256 amountRewardsToken;

        // Call accrueInterest
        ILendingLogic(_logic).accrueInterest(_strategyXToken);

        // Claim Rewards token
        ILendingLogic(_logic).claim();

        // Get Rewards amount
        amountRewardsToken = IERC20MetadataUpgradeable(_rewardsToken).balanceOf(
                _logic
            );

        // RewardsToken Price/Amount Kill Switch
        bool rewardsTokenKill = _rewardsPriceKillSwitch(
            _strategyStatistics,
            _rewardsToken,
            amountRewardsToken
        );

        // Get remained amount
        (, int256 diffStrategy) = LendBorrowLendStrategyHelper
            .getDiffAmountForClaim(
                _strategyStatistics,
                _logic,
                multiLogicProxy,
                supplyXToken,
                _strategyXToken,
                supplyToken,
                _strategyToken
            );

        // If we need to replay, swap DF->Strategy and repay it
        if (diffStrategy > 0 && !rewardsTokenKill) {
            // Swap Rewards -> StrategyToken
            if (swapRewardsToStrategyTokenInfo.swapRouters.length == 1) {
                // If 1 swap, SwapTokensForExactTokens
                ILogic(_logic).swap(
                    swapRewardsToStrategyTokenInfo.swapRouters[0],
                    amountRewardsToken,
                    uint256(diffStrategy),
                    swapRewardsToStrategyTokenInfo.paths[0],
                    false,
                    block.timestamp + 300
                );
            } else {
                // If more than 2 swaps, SwapExactTokensForTokens
                _multiSwap(
                    _logic,
                    amountRewardsToken,
                    swapRewardsToStrategyTokenInfo
                );
            }

            // RepayBorrow
            ILendingLogic(_logic).repayBorrow(
                _strategyXToken,
                uint256(diffStrategy)
            );
        }

        // If we need to redeem, redeem
        if (diffStrategy < 0) {
            ILendingLogic(_logic).redeemUnderlying(
                _strategyXToken,
                uint256(0 - diffStrategy)
            );
        }

        // swap Rewards to BLID
        amountRewardsToken = IERC20MetadataUpgradeable(_rewardsToken).balanceOf(
                _logic
            );
        if (amountRewardsToken > 0 && rewardsTokenKill == false) {
            _multiSwap(_logic, amountRewardsToken, swapRewardsToBLIDInfo);
            require(
                (amountRewardsToken * minimumBLIDPerRewardToken) / BASE <=
                    IERC20MetadataUpgradeable(blid).balanceOf(_logic),
                "C5"
            );
        }

        // If we have Strategy Token, swap StrategyToken to BLID
        uint256 balanceStrategyToken = _strategyToken == ZERO_ADDRESS
            ? address(_logic).balance
            : IERC20MetadataUpgradeable(_strategyToken).balanceOf(_logic);
        if (balanceStrategyToken > 0) {
            _multiSwap(
                _logic,
                balanceStrategyToken,
                swapStrategyTokenToBLIDInfo
            );
        }

        // Add BLID earn to storage
        uint256 amountBLID = _addEarnToStorage();

        emit ClaimRewards(amountBLID);
    }

    /**
     * @notice Frees up tokens for the user, but Storage doesn't transfer token for the user,
     * only Storage can this function, after calling this function Storage transfer
     * from Logic to user token.
     * @param amount Amount of token
     * @param token Address of token
     */
    function releaseToken(uint256 amount, address token)
        external
        override
        onlyMultiLogicProxy
    {
        address _supplyXToken = supplyXToken;
        address _strategyXToken = strategyXToken;
        address _logic = logic;
        require(token == supplyToken, "C9");

        // Call accrueInterest
        ILendingLogic(_logic).accrueInterest(_strategyXToken);
        ILendingLogic(_logic).accrueInterest(_supplyXToken);

        // Destruct Circle
        {
            // Get Supply XToken information
            uint256 supplyBorrowLimitUSD;
            uint256 supplyPriceUSD;

            if (_supplyXToken != _strategyXToken) {
                XTokenInfo memory tokenInfo = IStrategyStatistics(
                    strategyStatistics
                ).getStrategyXTokenInfo(_supplyXToken, _logic);

                supplyBorrowLimitUSD = tokenInfo.borrowLimitUSD;
                supplyPriceUSD = tokenInfo.priceUSD;
            }

            // Get destroyAmount
            uint256 destroyAmount;
            uint256 strategyPriceUSD;
            uint256 collateralFactorStrategyApplied;

            {
                // Get CollateralFactor
                uint256 collateralFactorSupply;
                uint256 collateralFactorStrategy;
                (
                    collateralFactorStrategy,
                    collateralFactorStrategyApplied
                ) = _getCollateralFactor(_strategyXToken);

                (collateralFactorSupply, ) = _getCollateralFactor(
                    _supplyXToken
                );

                // Get destroy amount
                (destroyAmount, strategyPriceUSD) = LendBorrowLendStrategyHelper
                    .getDestroyAmountForRelease(
                        strategyStatistics,
                        _logic,
                        amount,
                        _supplyXToken,
                        _strategyXToken,
                        supplyBorrowLimitUSD,
                        supplyPriceUSD,
                        collateralFactorSupply,
                        collateralFactorStrategy
                    );
            }

            // destruct circle
            destructCircles(
                _strategyXToken,
                circlesCount,
                supplyBorrowLimitUSD,
                collateralFactorStrategyApplied,
                strategyPriceUSD,
                destroyAmount
            );
        }

        // Check if redeem is possible
        (int256 diffSupply, ) = LendBorrowLendStrategyHelper
            .getDiffAmountForClaim(
                strategyStatistics,
                _logic,
                multiLogicProxy,
                _supplyXToken,
                _strategyXToken,
                token,
                strategyToken
            );

        if (
            diffSupply >=
            IMultiLogicProxy(multiLogicProxy)
                .getTokenTaken(token, _logic)
                .toInt256() -
                (amount).toInt256()
        ) {
            ILendingLogic(_logic).claim();

            uint256 amountRewardsToken = IERC20MetadataUpgradeable(rewardsToken)
                .balanceOf(_logic);

            bool rewardsTokenKill = _rewardsPriceKillSwitch(
                strategyStatistics,
                rewardsToken,
                amountRewardsToken
            );
            require(!rewardsTokenKill, "C10");

            _multiSwap(
                _logic,
                amountRewardsToken,
                swapRewardsToStrategyTokenInfo
            );

            (, , uint256 borrowAmount) = IStrategyStatistics(strategyStatistics)
                .getStrategyXTokenInfoCompact(_strategyXToken, _logic);

            if (borrowAmount > 0) {
                ILendingLogic(_logic).repayBorrow(
                    _strategyXToken,
                    borrowAmount
                );
            }
        }

        // Redeem for release token
        uint256 balance;
        if (token == ZERO_ADDRESS) {
            balance = address(_logic).balance;
        } else {
            balance = IERC20MetadataUpgradeable(token).balanceOf(_logic);
        }

        if (balance < amount) {
            ILendingLogic(_logic).redeemUnderlying(
                _supplyXToken,
                amount - balance
            );
        }

        // Send ETH
        if (token == ZERO_ADDRESS) {
            ILogic(_logic).returnETHToMultiLogicProxy(amount);
        }

        emit ReleaseToken(token, amount);
    }

    /*** Private Function ***/

    /**
     * @notice creates circle (borrow-lend) of the base token
     * token (of amount) should be mint before start build
     * @param xToken xToken address
     * @param amount amount to build (borrowAmount)
     * @param iterateCount the number circles to
     */
    function createCircles(
        address xToken,
        uint256 amount,
        uint8 iterateCount
    ) private {
        address _logic = logic;
        uint256 _amount = amount;

        // Get collateralFactor, the maximum proportion of borrow/lend
        // apply avoidLiquidationFactor
        (, uint256 collateralFactorApplied) = _getCollateralFactor(xToken);
        require(collateralFactorApplied > 0, "C1");

        if (_amount > 0) {
            for (uint256 i = 0; i < iterateCount; ) {
                ILendingLogic(_logic).borrow(xToken, _amount);
                ILendingLogic(_logic).mint(xToken, _amount);
                _amount = (_amount * collateralFactorApplied) / BASE;

                unchecked {
                    ++i;
                }
            }
        }
    }

    /**
     * @notice unblock all the money
     * @param xToken xToken address
     * @param iterateCount the number circles to : maximum iterates to do, the real number might be less then iterateCount
     * @param supplyBorrowLimitUSD Borrow limit in USD for supply token (deciamls = 18)
     * @param collateralFactorApplied Collateral factor with AvoidLiquidationFactor for strategyToken (decimals = 18)
     * @param priceUSD USD price of strategyToken (decimals = 18 + (18 - token.decimals))
     * @param destroyAmountLimit if > 0, stop destroy if total repay is destroyAmountLimit
     */
    function destructCircles(
        address xToken,
        uint8 iterateCount,
        uint256 supplyBorrowLimitUSD,
        uint256 collateralFactorApplied,
        uint256 priceUSD,
        uint256 destroyAmountLimit
    ) private {
        iterateCount = iterateCount + 3; // additional iteration to repay all borrowed

        address _logic = logic;
        uint256 _destroyAmountLimit = destroyAmountLimit;
        bool matched = supplyXToken == strategyXToken;

        // Check collateralFactor with avoidLiquidationFactor
        require(collateralFactorApplied > 0, "C1");

        for (uint256 i = 0; i < iterateCount; ) {
            uint256 borrowBalance; // balance of borrowed amount
            uint256 supplyBalance; // Total supply

            // Get BorrowBalance, Total Supply
            {
                uint256 xTokenBalance; // balance of xToken

                // get infromation of account
                xTokenBalance = IERC20Upgradeable(xToken).balanceOf(_logic);
                borrowBalance = IXToken(xToken).borrowBalanceCurrent(_logic);

                // calculates of supplied balance, divided by 10^18 to safe digits correctly
                {
                    //conversion rate from iToken to token
                    uint256 exchangeRateMantissa = IXToken(xToken)
                        .exchangeRateStored();
                    supplyBalance =
                        (xTokenBalance * exchangeRateMantissa) /
                        BASE;
                }

                // if nothing to repay
                if (borrowBalance == 0 || xTokenBalance == 1) {
                    // redeem and exit
                    if (xTokenBalance > 0) {
                        ILendingLogic(_logic).redeem(xToken, xTokenBalance);
                    }
                    return;
                }

                // if already redeemed
                if (supplyBalance == 0) {
                    return;
                }
            }

            // calculates how much percents could be borrowed and not to be liquidated, then multiply fo supply balance to calculate the amount
            uint256 withdrawBalance;
            if (matched) {
                withdrawBalance =
                    (supplyBalance * collateralFactorApplied) /
                    BASE -
                    borrowBalance;
            } else {
                withdrawBalance =
                    ((supplyBorrowLimitUSD +
                        (((supplyBalance * collateralFactorApplied) / BASE) *
                            priceUSD) /
                        BASE -
                        (borrowBalance * priceUSD) /
                        BASE) * BASE) /
                    priceUSD;

                // Withdraw balance can't be bigger than supply
                if (withdrawBalance > supplyBalance) {
                    withdrawBalance = supplyBalance;
                }
            }

            // If we have destroylimit, redeem only limit
            if (
                destroyAmountLimit > 0 && withdrawBalance > _destroyAmountLimit
            ) {
                withdrawBalance = _destroyAmountLimit;
            }

            // if redeem tokens
            ILendingLogic(_logic).redeemUnderlying(xToken, withdrawBalance);
            uint256 repayAmount = strategyToken == ZERO_ADDRESS
                ? address(_logic).balance
                : IERC20Upgradeable(strategyToken).balanceOf(_logic);

            // if there is something to repay
            if (repayAmount > 0) {
                // if borrow balance more then we have on account
                if (borrowBalance <= repayAmount) {
                    repayAmount = borrowBalance;
                }
                ILendingLogic(_logic).repayBorrow(xToken, repayAmount);
            }

            // Stop destroy if destroyAmountLimit < sumRepay
            if (destroyAmountLimit > 0) {
                if (_destroyAmountLimit <= repayAmount) break;
                _destroyAmountLimit = _destroyAmountLimit - repayAmount;
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice check if strategy distroy circles
     * @return paused true : strategy is empty, false : strategy has some lending token
     */
    function _checkStrategyPaused() private view returns (bool paused) {
        address _strategyXToken = strategyXToken;
        if (_strategyXToken == ZERO_ADDRESS) return true;

        (uint256 totalSupply, , uint256 borrowAmount) = IStrategyStatistics(
            strategyStatistics
        ).getStrategyXTokenInfoCompact(_strategyXToken, logic);

        if (totalSupply > 0 || borrowAmount > 0) {
            paused = false;
        } else {
            paused = true;
        }
    }

    /**
     * @notice Send all BLID to storage
     * @return amountBLID BLID amount
     */
    function _addEarnToStorage() private returns (uint256 amountBLID) {
        address _logic = logic;
        amountBLID = IERC20Upgradeable(blid).balanceOf(_logic);
        if (amountBLID > 0) {
            ILogic(_logic).addEarnToStorage(amountBLID);
        }
    }

    /**
     * @notice Process RewardsTokenPrice kill switch
     * @param _strategyStatistics : stratgyStatistics
     * @param _rewardsToken : rewardsToken
     * @param _amountRewardsToken : rewardsToken balance
     * @return killSwitch true : DF price should be protected, false : DF price is ok
     */
    function _rewardsPriceKillSwitch(
        address _strategyStatistics,
        address _rewardsToken,
        uint256 _amountRewardsToken
    ) private returns (bool killSwitch) {
        uint256 latestAnswer;
        (latestAnswer, killSwitch) = LendBorrowLendStrategyHelper
            .checkRewardsPriceKillSwitch(
                _strategyStatistics,
                comptroller,
                _rewardsToken,
                _amountRewardsToken,
                rewardsTokenPriceInfo,
                rewardsTokenPriceDeviationLimit,
                minRewardsSwapLimit
            );

        // Keep current status
        rewardsTokenPriceInfo.latestAnswer = latestAnswer;
        rewardsTokenPriceInfo.timestamp = block.timestamp;
    }

    /**
     * @notice Swap tokens base on SwapInfo
     */
    function _multiSwap(
        address _logic,
        uint256 amount,
        SwapInfo memory swapInfo
    ) private {
        for (uint256 i = 0; i < swapInfo.swapRouters.length; ) {
            if (i > 0) {
                amount = swapInfo.paths[i][0] == ZERO_ADDRESS
                    ? address(_logic).balance
                    : IERC20MetadataUpgradeable(swapInfo.paths[i][0]).balanceOf(
                            _logic
                        );
            }

            ILogic(_logic).swap(
                swapInfo.swapRouters[i],
                amount,
                1,
                swapInfo.paths[i],
                true,
                block.timestamp + 300
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Get underlying
     * call Logic.addXTokens
     */
    function _registerToken(address xToken, address _logic)
        private
        returns (address underlying)
    {
        underlying = ILendingLogic(_logic).getUnderlying(xToken);

        // Add token/iToken to Logic
        ILendingLogic(_logic).addXTokens(underlying, xToken);
    }

    /*** Virtual Internal Functions ***/

    /**
     * @notice get CollateralFactor from market
     * Apply avoidLiquidationFactor
     * @param xToken : address of xToken
     * @return collateralFactor decimal = 18
     * @return collateralFactorApplied decimal = 18
     */
    function _getCollateralFactor(address xToken)
        private
        view
        returns (uint256 collateralFactor, uint256 collateralFactorApplied)
    {
        // get collateralFactor from market
        collateralFactor = ILendingLogic(logic).getCollateralFactor(xToken);

        // Apply avoidLiquidationFactor to collateralFactor
        collateralFactorApplied =
            collateralFactor -
            avoidLiquidationFactor *
            10**16;
    }
}
