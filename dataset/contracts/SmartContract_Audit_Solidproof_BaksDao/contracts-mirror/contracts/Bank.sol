// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./interfaces/IBank.sol";
import "./interfaces/IWrappedNativeCurrency.sol";
import "./libraries/AmountNormalization.sol";
import "./libraries/Beneficiary.sol";
import "./libraries/CollateralToken.sol";
import "./libraries/EnumerableAddressSet.sol";
import "./libraries/FixedPointMath.sol";
import "./libraries/Loan.sol";
import "./libraries/Math.sol";
import "./libraries/MintingStage.sol";
import "./libraries/ReentrancyGuard.sol";
import "./libraries/SafeERC20.sol";
import {CoreInside, ICore} from "./Core.sol";
import {Governed} from "./Governance.sol";
import {IDepositary} from "./Depositary.sol";
import {IERC20, IMintableAndBurnableERC20} from "./interfaces/ERC20.sol";
import {Initializable} from "./libraries/Upgradability.sol";

/// @dev Thrown when trying to list collateral token that has zero decimals.
/// @param token The address of the collateral token contract.
error BaksDAOCollateralTokenZeroDecimals(IERC20 token);

/// @dev Thrown when trying to list collateral token that has too large decimals.
/// @param token The address of the collateral token contract.
error BaksDAOCollateralTokenTooLargeDecimals(IERC20 token, uint8 decimals);

/// @dev Thrown when trying to list collateral token that's already listed.
/// @param token The address of the collateral token contract.
error BaksDAOCollateralTokenAlreadyListed(IERC20 token);

/// @dev Thrown when trying to unlist collateral token that's not listed.
/// @param token The address of the collateral token contract.
error BaksDAOCollateralTokenNotListed(IERC20 token);

/// @dev Thrown when interacting with a token that's not allowed as collateral.
/// @param token The address of the collateral token contract.
error BaksDAOTokenNotAllowedAsCollateral(IERC20 token);

/// @dev Thrown when trying to set initial loan-to-value ratio that higher than margin call or liquidation ones.
/// @param token The address of the collateral token contract.
/// @param initialLoanToValueRatio The initial loan-to-value ratio that was tried to set.
error BaksDAOInitialLoanToValueRatioTooHigh(IERC20 token, uint256 initialLoanToValueRatio);

/// @dev Thrown when trying to interact with inactive loan with `id` id.
/// @param id The loan id.
error BaksDAOInactiveLoan(uint256 id);

/// @dev Thrown when trying to liquidate healthy loan with `id` id.
/// @param id The loan id.
error BaksDAOLoanNotSubjectToLiquidation(uint256 id);

/// @dev Thrown when trying to interact with loan with `id` id that is subject to liquidation.
/// @param id The loan id.
error BaksDAOLoanIsSubjectToLiquidation(uint256 id);

/// @dev Thrown when borrowing a zero amount of stablecoin.
error BaksDAOBorrowZeroAmount();

/// @dev Thrown when trying to borrow below minimum principal amount.
error BaksDAOBorrowBelowMinimumPrincipalAmount();

/// @dev Thrown when depositing a zero amount of collateral token.
error BaksDAODepositZeroAmount();

/// @dev Thrown when repaying a zero amount of stablecoin.
error BaksDAORepayZeroAmount();

/// @dev Thrown when there's no need to rebalance the platform.
error BaksDAONoNeedToRebalance();

/// @dev Thrown when trying to rebalance the platform and there is a shortage of funds to burn.
/// @param shortage Shoratge of funds to burn.
error BaksDAOStabilizationFundOutOfFunds(uint256 shortage);

/// @dev Thrown when trying to salvage one of allowed collateral tokens or stablecoin.
/// @param token The address of the token contract.
error BaksDAOTokenNotAllowedToBeSalvaged(IERC20 token);

/// @dev Thrown when trying to deposit native currency collateral to the non-wrapped native currency token loan
/// with `id` id.
/// @param id The loan id.
error BaksDAONativeCurrencyCollateralNotAllowed(uint256 id);

/// @dev Генерируется, если не получилось отправить нативную валюту (ETH, BNB и т. д.).
error BaksDAONativeCurrencyTransferFailed();

/// @dev Генерируется, если контракт не принимает переводы нативной валюты.
error BaksDAOPlainNativeCurrencyTransferNotAllowed();

/// @dev Генерируется при создании займа, если отправлена недостаточная сумма обеспечения.
/// @param minimumRequiredSecurityAmount Минимально требуемый размер суммы обеспечения.
error BaksDAOInsufficientSecurityAmount(uint256 minimumRequiredSecurityAmount);

/// @dev Генерируется, если следующий этап эмиссии BDV ещё не наступил (TVL платформы не достиг порогового значения).
error BaksDAOVoiceNothingToMint();

/// @dev Генерируется после окончания эмиссии BDV.
error BaksDAOVoiceMintingEnded();

/// @dev Генерируется, если отсутствует необходимость в миграции контракта.
error BaksDAONoNeedToMigrate();

/// @title Core smart contract of BaksDAO platform
/// @author BaksDAO
/// @notice You should use this contract to interact with the BaksDAO platform.
/// @notice Only this contract can issue BAKS and BDV tokens.
contract Bank is CoreInside, Governed, IBank, Initializable, ReentrancyGuard {
    using AmountNormalization for IERC20;
    using AmountNormalization for IWrappedNativeCurrency;
    using CollateralToken for CollateralToken.Data;
    using EnumerableAddressSet for EnumerableAddressSet.Set;
    using FixedPointMath for uint256;
    using Loan for Loan.Data;
    using MintingStage for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for IMintableAndBurnableERC20;
    using SafeERC20 for IWrappedNativeCurrency;

    enum Health {
        Ok,
        MarginCall,
        Liquidation
    }

    uint8 internal constant DECIMALS = 18;

    /// @dev Массив с информацией о займах.
    Loan.Data[] public loans;
    /// @dev Идентификаторы займа каждого кошелька.
    mapping(address => uint256[]) public loanIds;

    /// @dev Массив с информацией о залоговых токенах.
    mapping(IERC20 => CollateralToken.Data) public collateralTokens;
    EnumerableAddressSet.Set internal collateralTokensSet;

    /// @dev Номер следующего этапа эмиссии BDV.
    uint256 public nextVoiceMintingStage;

    /// @dev Генерируется после добавления нового залогового токена.
    /// @param token Залоговый токен.
    event CollateralTokenListed(IERC20 indexed token);
    /// @dev Генерируется после удаления залогового токена.
    /// @param token Залоговый токен.
    event CollateralTokenUnlisted(IERC20 indexed token);

    /// @dev Генерируется после изменения начального LTV залогового токена.
    /// @param token Залоговый токен.
    /// @param initialLoanToValueRatio Начальный LTV.
    /// @param newInitialLoanToValueRatio Новый начальный LTV.
    event InitialLoanToValueRatioUpdated(
        IERC20 indexed token,
        uint256 initialLoanToValueRatio,
        uint256 newInitialLoanToValueRatio
    );

    /// @dev Генерируется после создания нового займа.
    /// @param id Идентификатор займа.
    /// @param borrower Заёмщик.
    /// @param token Залоговый токен.
    /// @param principalAmount Сумма займа.
    /// @param collateralAmount Сумма залога.
    /// @param initialLoanToValueRatio Начальный LTV.
    event Borrow(
        uint256 indexed id,
        address indexed borrower,
        IERC20 indexed token,
        uint256 principalAmount,
        uint256 collateralAmount,
        uint256 initialLoanToValueRatio
    );
    /// @dev Генерируется после добавления залога в займ.
    /// @param id Идентификатор займа.
    /// @param collateralAmount Сумма добавленного залога.
    event Deposit(uint256 indexed id, uint256 collateralAmount);
    /// @dev Генерируется после частичного погашения займа.
    /// @param id Идентификатор займа.
    /// @param principalAmount Сумма погашения.
    event Repay(uint256 indexed id, uint256 principalAmount);
    /// @dev Генерируется после полного погашения займа.
    /// @param id Идентификатор займа.
    event Repaid(uint256 indexed id);

    /// @dev Генерируется после ликвидации займа.
    /// @param id Идентификатор займа.
    event Liquidated(uint256 indexed id);

    /// @dev Генерируется после ребалансировки стабилизационного фонда и эмиссии BDV.
    /// @param delta Количество BAKS, которое было сожжено или эмитированно.
    /// @param voiceMinted Количество вновь эмитированных BDV.
    event Rebalance(int256 delta, uint256 voiceMinted);

    modifier tokenAllowedAsCollateral(IERC20 token) {
        if (!collateralTokensSet.contains(address(token))) {
            revert BaksDAOTokenNotAllowedAsCollateral(token);
        }
        _;
    }

    modifier onActiveLoan(uint256 id) {
        if (id >= loans.length || !loans[id].isActive) {
            revert BaksDAOInactiveLoan(id);
        }
        _;
    }

    modifier notOnSubjectToLiquidation(uint256 loanId) {
        if (checkHealth(loanId) == Health.Liquidation) {
            revert BaksDAOLoanIsSubjectToLiquidation(loanId);
        }
        _;
    }

    modifier onSubjectToLiquidation(uint256 loanId) {
        if (checkHealth(loanId) != Health.Liquidation) {
            revert BaksDAOLoanNotSubjectToLiquidation(loanId);
        }
        _;
    }

    receive() external payable {
        if (msg.sender != core.wrappedNativeCurrency()) {
            revert BaksDAOPlainNativeCurrencyTransferNotAllowed();
        }
    }

    function initialize(ICore _core) external initializer {
        initializeReentrancyGuard();
        initializeCoreInside(_core);
        setGovernor(msg.sender);
    }

    /// @notice Increases loan's principal on `collateralToken` collateral token and mints `amount` of stablecoin.
    /// @dev The caller must have allowed this contract to spend a sufficient amount of collateral tokens to cover
    /// initial loan-to-value ratio.
    /// @param collateralToken The address of the collateral token contract.
    /// @param amount The amount of stablecoin to borrow and issue.
    function borrow(IERC20 collateralToken, uint256 amount)
        external
        tokenAllowedAsCollateral(collateralToken)
        returns (Loan.Data memory)
    {
        (
            Loan.Data memory loan,
            uint256 exchangeFee,
            uint256 developmentFee,
            uint256 stabilityFee
        ) = calculateLoanByPrincipalAmount(collateralToken, amount);

        collateralToken.safeTransferFrom(msg.sender, core.operator(), collateralToken.denormalizeAmount(stabilityFee));
        collateralToken.safeTransferFrom(
            msg.sender,
            address(this),
            collateralToken.denormalizeAmount(loan.collateralAmount)
        );

        return _createLoan(loan, exchangeFee, developmentFee);
    }

    /// @notice Increases loan's principal on wrapped native currency token and mints stablecoin.
    function borrowInNativeCurrency(uint256 amount) external payable nonReentrant returns (Loan.Data memory) {
        IWrappedNativeCurrency wrappedNativeCurrency = IWrappedNativeCurrency(core.wrappedNativeCurrency());

        (
            Loan.Data memory loan,
            uint256 exchangeFee,
            uint256 developmentFee,
            uint256 stabilityFee
        ) = calculateLoanByPrincipalAmount(wrappedNativeCurrency, amount);
        loan.isNativeCurrency = true;

        uint256 securityAmount = loan.collateralAmount + stabilityFee;
        if (msg.value < securityAmount) {
            revert BaksDAOInsufficientSecurityAmount(securityAmount);
        }

        wrappedNativeCurrency.deposit{value: securityAmount}();
        wrappedNativeCurrency.safeTransfer(core.operator(), wrappedNativeCurrency.denormalizeAmount(stabilityFee));

        uint256 change;
        unchecked {
            change = msg.value - securityAmount;
        }
        if (change > 0) {
            (bool success, ) = msg.sender.call{value: change}("");
            if (!success) {
                revert BaksDAONativeCurrencyTransferFailed();
            }
        }

        return _createLoan(loan, exchangeFee, developmentFee);
    }

    /// @notice Deposits `amount` of collateral token to loan with `id` id.
    /// @dev The caller must have allowed this contract to spend `amount` of collateral tokens.
    /// @param loanId The loan id.
    /// @param amount The amount of collateral token to deposit.
    function deposit(uint256 loanId, uint256 amount) external onActiveLoan(loanId) notOnSubjectToLiquidation(loanId) {
        loans[loanId].collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        _deposit(loanId, amount);
    }

    /// @notice Deposits wrapped native currency token to loan with `id` id.
    function depositInNativeCurrency(uint256 loanId)
        external
        payable
        nonReentrant
        onActiveLoan(loanId)
        notOnSubjectToLiquidation(loanId)
    {
        IWrappedNativeCurrency wrappedNativeCurrency = IWrappedNativeCurrency(core.wrappedNativeCurrency());
        if (loans[loanId].collateralToken != wrappedNativeCurrency) {
            revert BaksDAONativeCurrencyCollateralNotAllowed(loanId);
        }
        wrappedNativeCurrency.deposit{value: msg.value}();
        _deposit(loanId, msg.value);
    }

    /// @notice Decreases principal of loan with `id` id by `amount` of stablecoin.
    /// @param loanId The loan id.
    /// @param amount The amount of stablecoin to repay.
    function repay(uint256 loanId, uint256 amount)
        external
        nonReentrant
        onActiveLoan(loanId)
        notOnSubjectToLiquidation(loanId)
    {
        if (amount == 0) {
            revert BaksDAORepayZeroAmount();
        }
        Loan.Data storage loan = loans[loanId];
        loan.accrueInterest();

        amount = Math.min(loan.principalAmount + loan.interestAmount, amount);
        uint256 interestPayment;
        uint256 principalPayment;
        if (loan.interestAmount < amount) {
            principalPayment = amount - loan.interestAmount;
            interestPayment = loan.interestAmount;

            loan.principalAmount -= principalPayment;
            loan.interestAmount = 0;
        } else {
            interestPayment = amount;
            loan.interestAmount -= interestPayment;
        }

        IMintableAndBurnableERC20 baks = IMintableAndBurnableERC20(core.baks());

        if (interestPayment > 0) {
            baks.safeTransferFrom(msg.sender, core.developmentFund(), interestPayment);
        }

        if (principalPayment > 0) {
            baks.safeTransferFrom(msg.sender, address(this), principalPayment);
        }

        loan.lastInteractionAt = block.timestamp;
        if (loan.principalAmount > 0) {
            emit Repay(loanId, amount);
        } else {
            uint256 denormalizedCollateralAmount = loan.collateralToken.denormalizeAmount(loan.collateralAmount);
            collateralTokens[loan.collateralToken].collateralAmount -= loan.collateralAmount;

            loan.collateralAmount = 0;

            baks.burn(address(this), amount + loan.stabilizationFee);

            loan.isActive = false;
            emit Repaid(loanId);

            loan.collateralToken.safeTransfer(loan.borrower, denormalizedCollateralAmount);

            /* if (!loan.isNativeCurrency) {
                loan.collateralToken.safeTransfer(loan.borrower, denormalizedCollateralAmount);
            } else {
                IWrappedNativeCurrency(core.wrappedNativeCurrency()).withdraw(denormalizedCollateralAmount);
                (bool success, ) = msg.sender.call{value: denormalizedCollateralAmount}("");
                if (!success) {
                    revert BaksDAONativeCurrencyTransferFailed();
                }
            } */
        }
    }

    /// @dev Ликвидирует займ.
    /// @param loanId Идентификатор займа.
    function liquidate(uint256 loanId) external onActiveLoan(loanId) onSubjectToLiquidation(loanId) {
        Loan.Data storage loan = loans[loanId];

        collateralTokens[loan.collateralToken].collateralAmount -= loan.collateralAmount;
        loan.collateralToken.safeTransfer(
            core.developmentFund(),
            loan.collateralToken.denormalizeAmount(loan.collateralAmount)
        );

        IMintableAndBurnableERC20 baks = IMintableAndBurnableERC20(core.baks());
        uint256 collateralValue = loan.getCollateralValue();
        baks.burn(core.liquidator(), loan.principalAmount);
        baks.burn(address(this), collateralValue - loan.principalAmount);

        loan.isActive = false;
        emit Liquidated(loanId);
    }

    /// @dev Производит ребалансировку стабилизационного фонда.
    function rebalance() external {
        IMintableAndBurnableERC20 baks = IMintableAndBurnableERC20(core.baks());

        uint256 totalValueLocked = getTotalValueLocked();
        uint256 totalSupply = baks.totalSupply();

        int256 delta = int256(totalSupply) - int256(totalValueLocked);
        uint256 absoluteDelta = Math.abs(delta);
        uint256 p = absoluteDelta.div(totalSupply);
        if (p < core.rebalancingThreshold()) {
            revert BaksDAONoNeedToRebalance();
        }

        if (delta > 0) {
            try baks.burn(address(this), absoluteDelta) {} catch {
                uint256 balance = baks.balanceOf(address(this));
                revert BaksDAOStabilizationFundOutOfFunds(absoluteDelta - balance);
            }
        } else {
            baks.mint(address(this), absoluteDelta);
        }

        emit Rebalance(delta, 0);
    }

    /// @dev Производит эмиссию BDV.
    function mintVoice() external {
        uint256[] memory voiceMintingSchedule = core.voiceMintingSchedule();
        uint256 length = voiceMintingSchedule.length;

        if (nextVoiceMintingStage >= length) {
            revert BaksDAOVoiceMintingEnded();
        }

        uint256 totalValueLocked = getTotalValueLocked();
        uint256 voiceToMint;

        for (uint256 i = nextVoiceMintingStage; i < length; i++) {
            (uint256 targetTotalValueLocked, uint256 amount) = voiceMintingSchedule[i].split();

            if (totalValueLocked < targetTotalValueLocked) {
                nextVoiceMintingStage = i;
                break;
            }

            voiceToMint += amount;
        }

        if (voiceToMint == 0) {
            revert BaksDAOVoiceNothingToMint();
        }

        IMintableAndBurnableERC20 voice = IMintableAndBurnableERC20(core.voice());
        voice.mint(address(this), voiceToMint);

        uint256 voiceTotalShares = core.voiceTotalShares();
        uint256[] memory beneficiaries = core.voiceMintingBeneficiaries();
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            (address beneficiary, uint256 share) = Beneficiary.split(beneficiaries[i]);
            voice.safeTransfer(beneficiary, (voiceToMint * share) / voiceTotalShares);
        }

        emit Rebalance(0, voiceToMint);
    }

    function onNewDeposit(IERC20 token, uint256 amount) external onlyDepositary {
        IMintableAndBurnableERC20 baks = IMintableAndBurnableERC20(core.baks());
        if (token == baks) {
            return;
        }

        amount = amount.mul(IPriceOracle(core.priceOracle()).getNormalizedPrice(token));

        baks.mint(address(this), amount.mul(core.depositStabilizationFee()));
        baks.mint(core.exchangeFund(), amount.mul(core.depositExchangeFee()));
        baks.mint(core.developmentFund(), amount.mul(core.depositDevelopmentFee()));
    }

    /// @dev Добавляет новый залоговый токен.
    /// @param token Залоговый токен.
    /// @param initialLoanToValueRatio Начальный LTV.
    function listCollateralToken(IERC20 token, uint256 initialLoanToValueRatio) external onlyGovernor {
        if (collateralTokensSet.contains(address(token))) {
            revert BaksDAOCollateralTokenAlreadyListed(token);
        }

        if (initialLoanToValueRatio >= core.marginCallLoanToValueRatio()) {
            revert BaksDAOInitialLoanToValueRatioTooHigh(token, initialLoanToValueRatio);
        }

        uint8 decimals = token.decimals();
        if (decimals == 0) {
            revert BaksDAOCollateralTokenZeroDecimals(token);
        }
        if (decimals > DECIMALS) {
            revert BaksDAOCollateralTokenTooLargeDecimals(token, decimals);
        }

        if (collateralTokensSet.add(address(token))) {
            collateralTokens[token] = CollateralToken.Data({
                collateralToken: token,
                priceOracle: IPriceOracle(core.priceOracle()),
                stabilityFee: core.stabilityFee(),
                stabilizationFee: core.stabilizationFee(),
                exchangeFee: core.exchangeFee(),
                developmentFee: core.developmentFee(),
                initialLoanToValueRatio: initialLoanToValueRatio,
                marginCallLoanToValueRatio: core.marginCallLoanToValueRatio(),
                liquidationLoanToValueRatio: core.liquidationLoanToValueRatio(),
                collateralAmount: 0
            });

            emit CollateralTokenListed(token);
            emit InitialLoanToValueRatioUpdated(token, 0, initialLoanToValueRatio);
        }
    }

    /// @dev Удаляет залоговый токен.
    /// @param token Залоговый токен.
    function unlistCollateralToken(IERC20 token) external onlyGovernor {
        if (!collateralTokensSet.contains(address(token))) {
            revert BaksDAOCollateralTokenNotListed(token);
        }

        if (collateralTokensSet.remove(address(token))) {
            delete collateralTokens[token];
            emit CollateralTokenUnlisted(token);
        }
    }

    /// @dev Изменяет значение начального LTV для залогового токена.
    /// @param token Залоговый токен.
    /// @param newInitialLoanToValueRatio Новый начальный LTV.
    function setInitialLoanToValueRatio(IERC20 token, uint256 newInitialLoanToValueRatio) external onlyGovernor {
        if (!collateralTokensSet.contains(address(token))) {
            revert BaksDAOCollateralTokenNotListed(token);
        }

        CollateralToken.Data storage collateralToken = collateralTokens[token];
        if (newInitialLoanToValueRatio >= collateralToken.marginCallLoanToValueRatio) {
            revert BaksDAOInitialLoanToValueRatioTooHigh(token, newInitialLoanToValueRatio);
        }

        uint256 initialLoanToValueRatio = collateralToken.initialLoanToValueRatio;
        collateralToken.initialLoanToValueRatio = newInitialLoanToValueRatio;

        emit InitialLoanToValueRatioUpdated(token, initialLoanToValueRatio, newInitialLoanToValueRatio);
    }

    /* function salvage(IERC20 token) external onlyGovernor {
        address tokenAddress = address(token);
        if (tokenAddress == core.baks() || collateralTokensSet.contains(tokenAddress)) {
            revert BaksDAOTokenNotAllowedToBeSalvaged(token);
        }
        token.safeTransfer(core.operator(), token.balanceOf(address(this)));
    } */

    /// @dev Переводит BAKS в фонд обмена.
    /// @param amount Сумма BAKS для перевода.
    function transferBaksToExchangeFund(uint256 amount) external onlySuperUser {
        IERC20(core.baks()).safeTransfer(core.exchangeFund(), amount);
    }

    /// @dev Призводит миграцию BAKS на новый контракт фонда стабилизации.
    function migrate() external onlyGovernor {
        if (core.bank() == address(this)) {
            revert BaksDAONoNeedToMigrate();
        }

        IMintableAndBurnableERC20 baks = IMintableAndBurnableERC20(core.baks());

        uint256 balance = baks.balanceOf(core.bank());
        baks.burn(core.bank(), balance);
        baks.mint(address(this), balance);

        nextVoiceMintingStage = IBank(core.bank()).nextVoiceMintingStage();
    }

    /// @dev Получить займы по адресу заёмщика.
    /// @param borrower Адрес заёмщика.
    function getLoans(address borrower) external view returns (Loan.Data[] memory _loans) {
        uint256 length = loanIds[borrower].length;
        _loans = new Loan.Data[](length);

        for (uint256 i = 0; i < length; i++) {
            _loans[i] = loans[loanIds[borrower][i]];
        }
    }

    /// @dev Получить разрешённые залоговые токены.
    function getAllowedCollateralTokens()
        external
        view
        returns (CollateralToken.Data[] memory allowedCollateralTokens)
    {
        uint256 length = collateralTokensSet.elements.length;
        allowedCollateralTokens = new CollateralToken.Data[](length);

        for (uint256 i = 0; i < length; i++) {
            allowedCollateralTokens[i] = collateralTokens[IERC20(collateralTokensSet.elements[i])];
        }
    }

    /// @dev Рассчитать займ по сумме займа.
    /// @param collateralToken Залоговый токен
    /// @param principalAmount Сумма займа
    /// @return loan Рассчитанный займ
    /// @return exchangeFee Платёж в фонд обмена
    /// @return developmentFee Платёж в фонд развития
    /// @return stabilityFee Платёж за стабильность
    function calculateLoanByPrincipalAmount(IERC20 collateralToken, uint256 principalAmount)
        public
        view
        returns (
            Loan.Data memory loan,
            uint256 exchangeFee,
            uint256 developmentFee,
            uint256 stabilityFee
        )
    {
        return collateralTokens[collateralToken].calculateLoanByPrincipalAmount(principalAmount);
    }

    /// @dev Рассчитать займ по сумме залога.
    /// @param collateralToken Залоговый токен
    /// @param collateralAmount Сумма залога
    /// @return loan Рассчитанный займ
    /// @return exchangeFee Платёж в фонд обмена
    /// @return developmentFee Платёж в фонд развития
    /// @return stabilityFee Платёж за стабильность
    function calculateLoanByCollateralAmount(IERC20 collateralToken, uint256 collateralAmount)
        public
        view
        returns (
            Loan.Data memory loan,
            uint256 exchangeFee,
            uint256 developmentFee,
            uint256 stabilityFee
        )
    {
        return collateralTokens[collateralToken].calculateLoanByCollateralAmount(collateralAmount);
    }

    /// @dev Рассчитать займ по сумме обеспечения.
    /// @param collateralToken Залоговый токен
    /// @param securityAmount Сумма залога
    /// @return loan Рассчитанный займ
    /// @return exchangeFee Платёж в фонд обмена
    /// @return developmentFee Платёж в фонд развития
    /// @return stabilityFee Платёж за стабильность
    function calculateLoanBySecurityAmount(IERC20 collateralToken, uint256 securityAmount)
        public
        view
        returns (
            Loan.Data memory loan,
            uint256 exchangeFee,
            uint256 developmentFee,
            uint256 stabilityFee
        )
    {
        return collateralTokens[collateralToken].calculateLoanBySecurityAmount(securityAmount);
    }

    /// @dev Получить общий текущий TVL платформы.
    /// @return totalValueLocked Текущий TVL платформы
    function getTotalValueLocked() public view returns (uint256 totalValueLocked) {
        for (uint256 i = 0; i < collateralTokensSet.elements.length; i++) {
            totalValueLocked += collateralTokens[IERC20(collateralTokensSet.elements[i])].getCollateralValue();
        }
        totalValueLocked += IDepositary(core.depositary()).getTotalValueLocked();
    }

    /// @dev Получить текущий TVL платформы по токену.
    /// @param token Токен
    /// @return totalValueLocked Текущий TVL платформы по данному токену
    function getTotalValueLocked(IERC20 token) public view returns (uint256 totalValueLocked) {
        totalValueLocked = collateralTokens[token].getCollateralValue();
        totalValueLocked += IDepositary(core.depositary()).getTotalValueLocked(token);
    }

    /// @dev Получить текущее значение LTV займа.
    /// @param loanId Идентификатор займа
    /// @return loanToValueRatio Текущее значение LTV займа
    function getLoanToValueRatio(uint256 loanId) public view returns (uint256 loanToValueRatio) {
        Loan.Data memory loan = loans[loanId];
        loanToValueRatio = loan.calculateLoanToValueRatio();
    }

    /// @dev Получить текущую сумму начисленных на заём процентов.
    /// @param loanId Идентификатор займа
    /// @return accruedInterest Текущую сумму начисленных на заём процентов
    function getLoanAccruedInterest(uint256 loanId) public view returns (uint256 accruedInterest) {
        Loan.Data memory loan = loans[loanId];
        accruedInterest = loan.calculateInterest();
    }

    /// @dev Получить состояние займа.
    /// @param loanId Идентификатор займа
    /// @return health Состояние займа
    function checkHealth(uint256 loanId) public view returns (Health health) {
        uint256 loanToValueRatio = getLoanToValueRatio(loanId);
        health = loanToValueRatio >= core.liquidationLoanToValueRatio()
            ? Health.Liquidation
            : loanToValueRatio >= core.marginCallLoanToValueRatio()
            ? Health.MarginCall
            : Health.Ok;
    }

    function _createLoan(
        Loan.Data memory loan,
        uint256 exchangeFee,
        uint256 developmentFee
    ) internal returns (Loan.Data memory) {
        if (loan.principalAmount == 0) {
            revert BaksDAOBorrowZeroAmount();
        }
        if (loan.principalAmount < core.minimumPrincipalAmount()) {
            revert BaksDAOBorrowBelowMinimumPrincipalAmount();
        }

        IMintableAndBurnableERC20 baks = IMintableAndBurnableERC20(core.baks());
        baks.mint(address(this), loan.stabilizationFee);
        baks.mint(core.exchangeFund(), exchangeFee);
        baks.mint(core.developmentFund(), developmentFee);
        baks.mint(loan.borrower, loan.principalAmount);

        uint256 id = loans.length;
        loan.id = id;
        loan.interest = core.interest();

        loans.push(loan);
        loanIds[loan.borrower].push(id);

        collateralTokens[loan.collateralToken].collateralAmount += loan.collateralAmount;

        emit Borrow(
            id,
            loan.borrower,
            loan.collateralToken,
            loan.principalAmount,
            loan.collateralAmount,
            collateralTokens[loan.collateralToken].initialLoanToValueRatio
        );

        return loan;
    }

    function _deposit(uint256 loanId, uint256 amount) internal {
        if (amount == 0) {
            revert BaksDAODepositZeroAmount();
        }

        Loan.Data storage loan = loans[loanId];
        loan.accrueInterest();

        uint256 normalizedCollateralAmount = loan.collateralToken.normalizeAmount(amount);
        loan.collateralAmount += normalizedCollateralAmount;
        loan.lastInteractionAt = block.timestamp;
        collateralTokens[loan.collateralToken].collateralAmount += normalizedCollateralAmount;

        emit Deposit(loanId, normalizedCollateralAmount);
    }
}
