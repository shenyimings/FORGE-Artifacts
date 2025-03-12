// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/access/IAccessControl.sol';
import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

import './interfaces/IOpenSkyCollateralPriceOracle.sol';
import './interfaces/IOpenSkyNFTDescriptor.sol';
import './interfaces/IOpenSkyLoan.sol';
import './interfaces/IOpenSkyPool.sol';
import './interfaces/IACLManager.sol';
import './libraries/math/MathUtils.sol';
import './libraries/math/PercentageMath.sol';
import './libraries/helpers/Errors.sol';
import './libraries/types/DataTypes.sol';
import './libraries/ReserveLogic.sol';

/**
 * @title OpenSkyPool contract
 * @author OpenSky Labs
 * @notice Main point of interaction with OpenSky protocol's pool
 * - Users can:
 *   # Deposit
 *   # Withdraw
 *   # Borrow
 *   # Repay
 *   # Extend
 **/
contract OpenSkyPool is Context, Pausable, ReentrancyGuard, ERC721Holder, IOpenSkyPool {
    using SafeMath for uint256;
    using PercentageMath for uint256;
    using Counters for Counters.Counter;
    using ReserveLogic for DataTypes.ReserveData;

    // Map of reserves and their data
    mapping(uint256 => DataTypes.ReserveData) public reserves;

    IOpenSkySettings public SETTINGS;
    Counters.Counter private _reserveIdTracker;

    constructor(address SETTINGS_) Pausable() ReentrancyGuard() {
        SETTINGS = IOpenSkySettings(SETTINGS_);
    }

    /**
     * @dev Only pool admin can call functions marked by this modifier.
     **/
    modifier onlyPoolAdmin() {
        IACLManager ACLManager = IACLManager(SETTINGS.ACLManagerAddress());
        require(ACLManager.isPoolAdmin(_msgSender()), Errors.ACL_ONLY_POOL_ADMIN_CAN_CALL);
        _;
    }

    /**
     * @dev Only emergency admin can call functions marked by this modifier.
     **/
    modifier onlyEmergencyAdmin() {
        IACLManager ACLManager = IACLManager(SETTINGS.ACLManagerAddress());
        require(ACLManager.isEmergencyAdmin(_msgSender()), Errors.ACL_ONLY_EMERGENCY_ADMIN_CAN_CALL);
        _;
    }

    /**
     * @dev Only liquidator can call functions marked by this modifier.
     **/
    modifier onlyLiquidator() {
        IACLManager ACLManager = IACLManager(SETTINGS.ACLManagerAddress());
        require(ACLManager.isLiquidator(_msgSender()), Errors.ACL_ONLY_LIQUIDATOR_CAN_CALL);
        _;
    }

    /**
     * @dev functions marked by this modifier can be excuted only when the specific reserve exists.
     **/
    modifier checkReserveExists(uint256 reserveId) {
        require(_exists(reserveId), Errors.RESERVE_DOES_NOT_EXISTS);
        _;
    }

    /**
     * @dev Pause pool for emergency case, can only be called by emergency admin.
     **/
    function pause() external onlyEmergencyAdmin {
        _pause();
    }

    /**
     * @dev Unpause pool for emergency case, can only be called by emergency admin.
     **/
    function unpause() external onlyEmergencyAdmin {
        _unpause();
    }

    /**
     * @dev Check if specific reserve exists.
     **/
    function _exists(uint256 reserveId) internal view returns (bool) {
        return reserves[reserveId].reserveId > 0;
    }

    /// @inheritdoc IOpenSkyPool
    function create(string memory name, string memory symbol) external override onlyPoolAdmin {
        _reserveIdTracker.increment();
        uint256 reserveId = _reserveIdTracker.current();
        address oTokenAddress = IOpenSkyReserveVaultFactory(SETTINGS.vaultFactoryAddress()).create(
            reserveId,
            name,
            symbol
        );
        reserves[reserveId] = DataTypes.ReserveData({
            reserveId: reserveId,
            oTokenAddress: oTokenAddress,
            moneyMarketAddress: SETTINGS.moneyMarketAddress(),
            lastSupplyIndex: uint128(WadRayMath.RAY),
            borrowingInterestPerSecond: 0,
            lastMoneyMarketBalance: 0,
            lastUpdateTimestamp: 0,
            totalBorrows: 0,
            interestModelAddress: SETTINGS.interestRateStrategyAddress(),
            treasuryFactor: SETTINGS.reserveFactor()
        });
        emit Create(reserveId, name, symbol);
    }

    /// @inheritdoc IOpenSkyPool
    function setTreasuryFactor(uint256 reserveId, uint256 factor)
        external
        override
        checkReserveExists(reserveId)
        onlyPoolAdmin
    {
        reserves[reserveId].treasuryFactor = factor;
        emit SetTreasuryFactor(reserveId, factor);
    }

    /// @inheritdoc IOpenSkyPool
    function setInterestModelAddress(uint256 reserveId, address interestModelAddress)
        external
        override
        checkReserveExists(reserveId)
        onlyPoolAdmin
    {
        reserves[reserveId].interestModelAddress = interestModelAddress;
        emit SetInterestModelAddress(reserveId, interestModelAddress);
    }

    /// @inheritdoc IOpenSkyPool
    function deposit(uint256 reserveId, uint256 referralCode)
        public
        payable
        virtual
        override
        whenNotPaused
        nonReentrant
        checkReserveExists(reserveId)
    {
        require(msg.value > 0, Errors.DEPOSIT_AMOUNT_SHOULD_BE_BIGGER_THAN_ZERO);
        reserves[reserveId].deposit(_msgSender(), msg.value);
        emit Deposit(reserveId, _msgSender(), msg.value, referralCode);
    }

    /// @inheritdoc IOpenSkyPool
    function withdraw(uint256 reserveId, uint256 amount)
        public
        virtual
        override
        whenNotPaused
        nonReentrant
        checkReserveExists(reserveId)
    {
        address oTokenAddress = reserves[reserveId].oTokenAddress;
        uint256 userBalance = IOpenSkyOToken(oTokenAddress).balanceOf(msg.sender);

        uint256 amountToWithdraw = amount;
        if (amount == type(uint256).max) {
            amountToWithdraw = userBalance;
        }

        require(amountToWithdraw > 0 && amountToWithdraw <= userBalance, Errors.WITHDRAW_AMOUNT_NOT_ALLOWED);
        require(getAvailableLiquidity(reserveId) >= amountToWithdraw, Errors.WITHDRAW_LIQUIDITY_NOT_SUFFIENCE);

        reserves[reserveId].withdraw(_msgSender(), amountToWithdraw);
        emit Withdraw(reserveId, _msgSender(), amountToWithdraw);
    }

    struct BorrowLocalParams {
        uint256 borrowLimit;
        uint256 availableLiquidity;
        uint256 amountToBorrow;
        uint256 borrowRate;
    }

    /// @inheritdoc IOpenSkyPool
    function borrow(
        uint256 reserveId,
        uint256 amount,
        uint256 duration,
        address nftAddress,
        uint256 tokenId,
        address onBehalfOf
    ) public virtual override whenNotPaused nonReentrant checkReserveExists(reserveId) returns (uint256) {
        require(
            duration >= SETTINGS.minBorrowDuration() && duration <= SETTINGS.maxBorrowDuration(),
            Errors.BORROW_DURATION_NOT_ALLOWED
        );

        BorrowLocalParams memory vars;
        vars.borrowLimit = getBorrowLimitByOracle(reserveId, nftAddress, tokenId);
        vars.availableLiquidity = getAvailableLiquidity(reserveId);

        vars.amountToBorrow = amount;

        if (amount == type(uint256).max) {
            vars.amountToBorrow = (
                vars.borrowLimit < vars.availableLiquidity ? vars.borrowLimit : vars.availableLiquidity
            );
        }

        require(vars.borrowLimit >= vars.amountToBorrow, Errors.BORROW_AMOUNT_EXCEED_BORROW_LIMIT);
        require(vars.availableLiquidity >= vars.amountToBorrow, Errors.RESERVE_LIQUIDITY_INSUFFICIENT);

        IERC721(nftAddress).safeTransferFrom(_msgSender(), SETTINGS.loanAddress(), tokenId);

        vars.borrowRate = reserves[reserveId].getBorrowRate();
        (uint256 loanId, DataTypes.LoanData memory loan) = IOpenSkyLoan(SETTINGS.loanAddress()).mint(
            reserveId,
            onBehalfOf,
            nftAddress,
            tokenId,
            vars.amountToBorrow,
            duration,
            vars.borrowRate
        );
        reserves[reserveId].borrow(loan);

        emit Borrow(
            reserveId,
            _msgSender(),
            onBehalfOf,
            nftAddress,
            tokenId,
            vars.amountToBorrow,
            duration,
            vars.borrowRate,
            loan.borrowOverdueTime,
            loanId
        );

        return loanId;
    }

    /// @inheritdoc IOpenSkyPool
    function repay(uint256 loanId) public payable virtual override whenNotPaused nonReentrant {
        address onBehalfOf = IERC721(SETTINGS.loanAddress()).ownerOf(loanId);

        IOpenSkyLoan loanNFT = IOpenSkyLoan(SETTINGS.loanAddress());
        DataTypes.LoanData memory loanData = loanNFT.getLoanData(loanId);

        require(
            loanData.status == DataTypes.LoanStatus.BORROWING ||
                loanData.status == DataTypes.LoanStatus.EXTENDABLE ||
                loanData.status == DataTypes.LoanStatus.OVERDUE,
            Errors.REPAY_STATUS_ERROR
        );

        uint256 penalty = loanNFT.getPenalty(loanId);
        uint256 borrowBalance = loanNFT.getBorrowBalance(loanId);
        uint256 repayAmount = borrowBalance.add(penalty);
        require(msg.value >= repayAmount, Errors.REPAY_AMOUNT_NOT_ENOUGH);

        uint256 reserveId = loanData.reserveId;
        require(_exists(reserveId), Errors.RESERVE_DOES_NOT_EXISTS);

        reserves[reserveId].repay(loanData, repayAmount, borrowBalance);

        loanNFT.end(loanId, onBehalfOf, _msgSender());

        address nftReceiver = SETTINGS.punkGatewayAddress() == _msgSender() ? _msgSender() : onBehalfOf;
        IERC721(loanData.nftAddress).safeTransferFrom(address(loanNFT), nftReceiver, loanData.tokenId);

        if (msg.value > repayAmount) _safeTransferETH(_msgSender(), msg.value - repayAmount);

        emit Repay(reserveId, _msgSender(), onBehalfOf, loanId, repayAmount, penalty);
    }

    struct ExtendLocalParams {
        uint256 reserveId;
        uint256 borrowInterestOfOldLoan;
        uint256 needInETH;
        uint256 needOutETH;
        uint256 penalty;
        uint256 borrowLimit;
        uint256 availableLiquidity;
        uint256 amountToExtend;
        DataTypes.LoanStatus oldLoanStatus;
    }

    /// @inheritdoc IOpenSkyPool
    function extend(
        uint256 oldLoanId,
        uint256 amount,
        uint256 duration
    ) external payable override whenNotPaused nonReentrant {
        require(
            duration >= SETTINGS.minBorrowDuration() && duration <= SETTINGS.maxBorrowDuration(),
            Errors.BORROW_DURATION_NOT_ALLOWED
        );

        IOpenSkyLoan loanNFT = IOpenSkyLoan(SETTINGS.loanAddress());
        require(loanNFT.ownerOf(oldLoanId) == _msgSender(), Errors.LOAN_CALLER_IS_NOT_OWNER);

        ExtendLocalParams memory vars = ExtendLocalParams({
            reserveId: 0,
            borrowInterestOfOldLoan: 0,
            needInETH: 0,
            needOutETH: 0,
            penalty: 0,
            borrowLimit: 0,
            availableLiquidity: 0,
            amountToExtend: 0,
            oldLoanStatus: DataTypes.LoanStatus.BORROWING
        });

        vars.oldLoanStatus = loanNFT.getStatus(oldLoanId);
        require(
            vars.oldLoanStatus == DataTypes.LoanStatus.EXTENDABLE || vars.oldLoanStatus == DataTypes.LoanStatus.OVERDUE,
            Errors.EXTEND_STATUS_ERROR
        );

        DataTypes.LoanData memory oldLoan = loanNFT.getLoanData(oldLoanId);
        vars.reserveId = oldLoan.reserveId;
        vars.borrowLimit = getBorrowLimitByOracle(oldLoan.reserveId, oldLoan.nftAddress, oldLoan.tokenId);

        vars.amountToExtend = amount;
        if (amount == type(uint256).max) {
            vars.amountToExtend = vars.borrowLimit; // no need to check availableLiquidity here
        }

        require(vars.borrowLimit >= vars.amountToExtend, Errors.BORROW_AMOUNT_EXCEED_BORROW_LIMIT);

        // check msg.value
        vars.borrowInterestOfOldLoan = loanNFT.getBorrowInterest(oldLoanId);
        vars.penalty = loanNFT.getPenalty(oldLoanId);
        if (oldLoan.amount <= vars.amountToExtend) {
            uint256 extendAmount = vars.amountToExtend.sub(oldLoan.amount);
            if (extendAmount < vars.borrowInterestOfOldLoan + vars.penalty) {
                vars.needInETH = vars.borrowInterestOfOldLoan.add(vars.penalty).sub(extendAmount);
            } else {
                vars.needOutETH = extendAmount.sub(vars.borrowInterestOfOldLoan).sub(vars.penalty);
            }
        } else {
            //vars.needInETH = oldLoan.amount - vars.amountToExtend + vars.borrowInterestOfOldLoan + vars.penalty;
            vars.needInETH = oldLoan.amount.sub(vars.amountToExtend).add(vars.borrowInterestOfOldLoan + vars.penalty);
        }
        require(msg.value >= vars.needInETH, Errors.EXTEND_MSG_VALUE_ERROR);

        //check availableLiquidity
        if (vars.needOutETH > 0) {
            vars.availableLiquidity = getAvailableLiquidity(oldLoan.reserveId);
            require(vars.availableLiquidity >= vars.needOutETH, Errors.RESERVE_LIQUIDITY_INSUFFICIENT);
        }

        // end old loan
        loanNFT.end(oldLoanId, _msgSender(), _msgSender());

        // create new loan
        (uint256 loanId, DataTypes.LoanData memory newLoan) = loanNFT.mint(
            vars.reserveId,
            _msgSender(),
            oldLoan.nftAddress,
            oldLoan.tokenId,
            vars.amountToExtend,
            duration,
            reserves[vars.reserveId].getBorrowRate()
        );

        // update reserve state
        reserves[vars.reserveId].extend(
            oldLoan,
            newLoan,
            vars.borrowInterestOfOldLoan,
            vars.needInETH,
            vars.needOutETH,
            vars.penalty
        );

        if (msg.value > vars.needInETH) _safeTransferETH(_msgSender(), msg.value - vars.needInETH);

        emit Extend(vars.reserveId, _msgSender(), oldLoanId, loanId);
    }

    /// @inheritdoc IOpenSkyPool
    function startLiquidation(uint256 loanId) external override whenNotPaused onlyLiquidator {
        IOpenSkyLoan loanNFT = IOpenSkyLoan(SETTINGS.loanAddress());
        DataTypes.LoanData memory loanData = loanNFT.getLoanData(loanId);
        require(loanData.status == DataTypes.LoanStatus.LIQUIDATABLE, Errors.START_LIQUIDATION_STATUS_ERROR);

        reserves[loanData.reserveId].startLiquidation(loanData);

        IERC721(loanData.nftAddress).safeTransferFrom(address(loanNFT), _msgSender(), loanData.tokenId);
        loanNFT.startLiquidation(loanId);

        emit StartLiquidation(loanData.reserveId, loanId, loanData.nftAddress, loanData.tokenId, _msgSender());
    }

    /// @inheritdoc IOpenSkyPool
    function endLiquidation(uint256 loanId) external payable override whenNotPaused onlyLiquidator {
        IOpenSkyLoan loanNFT = IOpenSkyLoan(SETTINGS.loanAddress());
        DataTypes.LoanData memory loanData = loanNFT.getLoanData(loanId);
        require(loanData.status == DataTypes.LoanStatus.LIQUIDATING, Errors.END_LIQUIDATION_STATUS_ERROR);

        // repay money
        uint256 borrowBalance = loanNFT.getBorrowBalance(loanId);
        uint256 inEthAmount = msg.value;
        require(inEthAmount >= borrowBalance, Errors.END_LIQUIDATION_AMOUNT_ERROR);

        reserves[loanData.reserveId].endLiquidation(inEthAmount, borrowBalance);

        loanNFT.endLiquidation(loanId);

        emit EndLiquidation(
            loanData.reserveId,
            loanId,
            loanData.nftAddress,
            loanData.tokenId,
            _msgSender(),
            inEthAmount,
            borrowBalance
        );
    }

    /// @inheritdoc IOpenSkyPool
    function getReserveData(uint256 reserveId)
        public
        view
        override
        checkReserveExists(reserveId)
        returns (DataTypes.ReserveData memory)
    {
        return reserves[reserveId];
    }

    /// @inheritdoc IOpenSkyPool
    function getReserveNormalizedIncome(uint256 reserveId)
        public
        view
        override
        checkReserveExists(reserveId)
        returns (uint256)
    {
        return reserves[reserveId].getNormalizedIncome();
    }

    /// @inheritdoc IOpenSkyPool
    function getAvailableLiquidity(uint256 reserveId)
        public
        view
        override
        checkReserveExists(reserveId)
        returns (uint256)
    {
        return reserves[reserveId].getMoneyMarketBalance();
    }

    /// @inheritdoc IOpenSkyPool
    function getBorrowLimitByOracle(
        uint256 reserveId,
        address nftAddress,
        uint256 tokenId
    ) public view virtual override returns (uint256) {
        return
            IOpenSkyCollateralPriceOracle(SETTINGS.nftPriceOracleAddress())
                .getPrice(reserveId, nftAddress, tokenId)
                .percentMul(SETTINGS.getWhitelistDetail(nftAddress).LTV);
    }

    /// @inheritdoc IOpenSkyPool
    function getSupplyBalance(uint256 reserveId, address account)
        external
        view
        override
        checkReserveExists(reserveId)
        returns (uint256)
    {
        return IOpenSkyOToken(reserves[reserveId].oTokenAddress).balanceOf(account);
    }

    /// @inheritdoc IOpenSkyPool
    function getTotalBorrowBalance(uint256 reserveId) public view override returns (uint256) {
        return reserves[reserveId].getTotalBorrowBalance();
    }

    /// @inheritdoc IOpenSkyPool
    function getBorrowRate(uint256 reserveId) public view override returns (uint256) {
        return reserves[reserveId].getBorrowRate();
    }

    /// @inheritdoc IOpenSkyPool
    function getTVL(uint256 reserveId) public view override checkReserveExists(reserveId) returns (uint256) {
        return reserves[reserveId].getTVL();
    }

    function _safeTransferETH(address recipient, uint256 amount) internal {
        (bool success, ) = recipient.call{value: amount}('');
        require(success, Errors.ETH_TRANSFER_FAILED);
    }

    receive() external payable {
        revert(Errors.RECEIVE_NOT_ALLOWED);
    }

    fallback() external payable {
        revert(Errors.FALLBACK_NOT_ALLOWED);
    }
}
