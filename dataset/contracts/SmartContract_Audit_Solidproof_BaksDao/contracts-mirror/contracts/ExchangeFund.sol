// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./libraries/AmountNormalization.sol";
import "./libraries/EnumerableAddressSet.sol";
import "./libraries/FixedPointMath.sol";
import "./libraries/Math.sol";
import "./libraries/SafeERC20.sol";
import {CoreInside, ICore} from "./Core.sol";
import {Governed} from "./Governance.sol";
import {IERC20} from "./interfaces/ERC20.sol";
import {Initializable} from "./libraries/Upgradability.sol";
import {IPriceOracle} from "./interfaces/IPriceOracle.sol";
import {IUniswapV2Factory, IUniswapV2Router, IUniswapV2Pair} from "./interfaces/UniswapV2.sol";

/// @dev Thrown when trying to list depositable token that has zero decimals.
/// @param token The address of the token contract.
error ExchangeFundDepositableTokenZeroDecimals(IERC20 token);

/// @dev Thrown when trying to list depositable token that has too large decimals.
/// @param token The address of the token contract.
error ExchangeFundDepositableTokenTooLargeDecimals(IERC20 token, uint8 decimals);

/// @dev Thrown when trying to list depositable token that's already listed.
/// @param token The address of the token contract.
error ExchangeFundDepositableTokenAlreadyListed(IERC20 token);

/// @dev Thrown when trying to unlist depositable token that's not listed.
/// @param token The address of the token contract.
error ExchangeFundDepositableTokenNotListed(IERC20 token);

/// @dev Thrown when interacting with a token that's not allowed to be deposited.
/// @param token The address of the token contract.
error ExchangeFundTokenNotAllowedToBeDeposited(IERC20 token);

/// @dev Thrown when interacting with a token that's not allowed to be withdrawn.
/// @param token The address of the token contract.
error ExchangeFundTokenNotAllowedToBeWithdrawn(IERC20 token);

/// @dev Thrown when trying to salvage one of depositable tokens or BAKS.
/// @param token The address of the token contract.
error ExchangeFundTokenNotAllowedToBeSalvaged(IERC20 token);

/// @dev Генерируется при нехватке депонированных средств суперпользователя.
error ExchangeFundInsufficientDeposits();

/// @dev Генерируется при нехватке LP-токенов суперпользователя.
error ExchangeFundInsufficientLiquidity();

/// @dev Генерируется при попытке обмена одинаковых токенов.
error ExchangeFundSameTokenSwap(IERC20 token);

/// @dev Thrown when trying to swap token that's not allowed to be swapped.
/// @param token The address of the token contract.
error ExchangeFundTokenNotAllowedToBeSwapped(IERC20 token);

/// @dev Thrown when there's no need to service the `token`/BAKS pair cause the difference between target and
/// pair price does not exceed servicing threshold.
/// @param token The address of the token contract.
error ExchangeFundNoNeedToService(IERC20 token);

error ExchangeFundTokenNotApproved();

/// @title Фонд обмена
/// @author BaksDAO
contract ExchangeFund is CoreInside, Governed, Initializable {
    using AmountNormalization for IERC20;
    using EnumerableAddressSet for EnumerableAddressSet.Set;
    using FixedPointMath for uint256;
    using SafeERC20 for IERC20;

    uint256 internal constant ONE = 100e16;
    uint8 internal constant DECIMALS = 18;

    /// @dev Допустимое проскальзывание при обмене
    uint256 public slippageTolerance;
    /// @dev Дедлайн обмена
    uint256 public swapDeadline;

    /// @dev Суммы вложенных средств по суперпользователю и пулу.
    mapping(address => mapping(IERC20 => uint256)) public deposits;
    /// @dev Суммы LP-токенов по суперпользователю и пулу.
    mapping(address => mapping(IERC20 => uint256)) public liquidity;

    /// @dev Информация о депонируемых токенах.
    mapping(IERC20 => bool) public depositableTokens;
    EnumerableAddressSet.Set internal depositableTokensSet;

    /// @dev Генерируется после добавления нового депонируемого токена.
    /// @param token Депонируемый токен.
    /// @param pair Адрес пары.
    event DepositableTokenListed(IERC20 indexed token, IUniswapV2Pair pair);
    /// @dev Генерируется после удаления депонируемого токена.
    /// @param token Депонируемый токен.
    event DepositableTokenUnlisted(IERC20 indexed token);

    /// @dev Генерируется после обновления значения допустимого проскальзывания.
    event SlippageToleranceUpdated(uint256 slippageTolerance, uint256 newSlippageTolerance);
    /// @dev Генерируется после обновления значения дедлайна.
    event SwapDeadlineUpdated(uint256 swapDeadline, uint256 newSwapDeadline);

    /// @dev Генерируется после депонирования средств в фонд обмена.
    /// @param account Адрес вкладчика.
    /// @param token Адрес депонируемого токена.
    /// @param amount Сумма депозита.
    event Deposit(address indexed account, IERC20 indexed token, uint256 amount);
    /// @dev Генерируется после произведённого обмена.
    event Swap(address indexed account, IERC20 indexed tokenA, IERC20 indexed tokenB, uint256 amountA, uint256 amountB);
    /// @dev Генерируется после добавления ликвидности из фонда обмена.
    event Invest(address indexed account, IERC20 indexed token, uint256 amount);
    /// @dev Генерируется после вывода ликвидности в фонд обмена.
    event Divest(address indexed account, IERC20 indexed token, uint256 amount);
    /// @dev Генерируется после вывода средств из фонда обмена.
    event Withdrawal(address indexed account, IERC20 indexed token, uint256 amount);
    /// @dev Генерируется после выравнивания курса / добавления ликвидности.
    event Service(address indexed account, IERC20 indexed token);

    modifier tokenAllowedToBeDeposited(IERC20 token) {
        if (!depositableTokensSet.contains(address(token))) {
            revert ExchangeFundTokenNotAllowedToBeDeposited(token);
        }
        _;
    }

    modifier tokenAllowedToBeSwapped(IERC20 token) {
        if (token != IERC20(core.baks()) && !depositableTokensSet.contains(address(token))) {
            revert ExchangeFundTokenNotAllowedToBeSwapped(token);
        }
        _;
    }

    function initialize(ICore _core) external initializer {
        initializeCoreInside(_core);
        setGovernor(msg.sender);

        slippageTolerance = 5e15; // 0.5 %
        swapDeadline = 20 minutes;

        IERC20 baks = IERC20(core.baks());
        IERC20 voice = IERC20(core.voice());

        if (!baks.approve(core.uniswapV2Router(), type(uint256).max)) {
            revert ExchangeFundTokenNotApproved();
        }
        if (!baks.approve(core.depositary(), type(uint256).max)) {
            revert ExchangeFundTokenNotApproved();
        }

        if (!voice.approve(core.uniswapV2Router(), type(uint256).max)) {
            revert ExchangeFundTokenNotApproved();
        }
        if (!voice.approve(core.depositary(), type(uint256).max)) {
            revert ExchangeFundTokenNotApproved();
        }
    }

    /// @dev Депонировать средства в фонд обмена.
    function deposit(IERC20 token, uint256 amount) external tokenAllowedToBeDeposited(token) onlySuperUser {
        token.safeTransferFrom(msg.sender, address(this), amount);

        uint256 normalizedAmount = token.normalizeAmount(amount);
        deposits[msg.sender][token] += normalizedAmount;

        emit Deposit(msg.sender, token, normalizedAmount);
    }

    /// @dev Произвести обмен.
    /// @param tokenA Адрес токена А
    /// @param tokenB Адреса токена B
    /// @param amount Сумма обмена
    /// @param useWrappedNativeCurrencyAsIntermediateToken Использовать WBNB/WETH как промежуточный токен обмена.
    function swap(
        IERC20 tokenA,
        IERC20 tokenB,
        uint256 amount,
        bool useWrappedNativeCurrencyAsIntermediateToken
    ) external tokenAllowedToBeSwapped(tokenA) tokenAllowedToBeSwapped(tokenB) onlySuperUser {
        uint256 normalizedAmount = tokenA.normalizeAmount(amount);
        if (normalizedAmount > deposits[msg.sender][tokenA]) {
            revert ExchangeFundInsufficientDeposits();
        }

        if (tokenA == tokenB) {
            revert ExchangeFundSameTokenSwap(tokenA);
        }

        IERC20[] memory path = new IERC20[](useWrappedNativeCurrencyAsIntermediateToken ? 3 : 2);
        path[0] = tokenA;
        path[1] = useWrappedNativeCurrencyAsIntermediateToken ? IERC20(core.wrappedNativeCurrency()) : tokenB;
        if (useWrappedNativeCurrencyAsIntermediateToken) {
            path[2] = tokenB;
        }

        IUniswapV2Router uniswapV2Router = IUniswapV2Router(core.uniswapV2Router());
        uint256[] memory amounts = uniswapV2Router.getAmountsOut(amount, path);
        uint256 normalizedAmountOut = tokenB.normalizeAmount(amounts[amounts.length - 1]);

        amounts = uniswapV2Router.swapExactTokensForTokens(
            amount,
            tokenB.denormalizeAmount(normalizedAmountOut.mul(ONE - slippageTolerance)),
            path,
            address(this),
            block.timestamp + swapDeadline
        );

        uint256 normalizedTokenAAmount = tokenA.normalizeAmount(amounts[0]);
        uint256 normalizedTokenBAmount = tokenB.normalizeAmount(amounts[amounts.length - 1]);

        deposits[msg.sender][tokenA] -= normalizedTokenAAmount;
        deposits[msg.sender][tokenB] += normalizedTokenBAmount;

        emit Swap(msg.sender, tokenA, tokenB, normalizedTokenAAmount, normalizedTokenBAmount);
    }

    /// @dev Добавить ликвидность из фонда обмена.
    function invest(IERC20 token, uint256 amount) external onlySuperUser {
        uint256 normalizedAmount = token.normalizeAmount(amount);
        if (normalizedAmount > deposits[msg.sender][token]) {
            revert ExchangeFundInsufficientDeposits();
        }

        uint256 tokenValue = quote(token, amount);
        (, uint256 amountSent, uint256 liquidityMinted) = IUniswapV2Router(core.uniswapV2Router()).addLiquidity(
            IERC20(core.baks()),
            token,
            tokenValue,
            amount,
            tokenValue.mul(ONE - slippageTolerance),
            token.denormalizeAmount(normalizedAmount.mul(ONE - slippageTolerance)),
            address(this),
            block.timestamp + swapDeadline
        );

        deposits[msg.sender][token] -= token.normalizeAmount(amountSent);
        liquidity[msg.sender][token] += liquidityMinted;

        emit Invest(msg.sender, token, normalizedAmount);
    }

    /// @dev Вывести ликвидность в фонд обмена.
    function divest(IERC20 token, uint256 amount) external onlySuperUser {
        if (amount > liquidity[msg.sender][token]) {
            revert ExchangeFundInsufficientLiquidity();
        }

        (, uint256 amountReceived) = IUniswapV2Router(core.uniswapV2Router()).removeLiquidity(
            IERC20(core.baks()),
            token,
            amount,
            0,
            0,
            address(this),
            block.timestamp + swapDeadline
        );

        deposits[msg.sender][token] += token.normalizeAmount(amountReceived);
        liquidity[msg.sender][token] -= amount;

        emit Divest(msg.sender, token, amount);
    }

    /// @dev Вывести средства из фонда обмена.
    function withdraw(IERC20 token, uint256 amount) external onlySuperUser {
        if (token == IERC20(core.baks())) {
            revert ExchangeFundTokenNotAllowedToBeWithdrawn(token);
        }

        uint256 normalizedAmount = token.normalizeAmount(amount);
        if (normalizedAmount > deposits[msg.sender][token]) {
            revert ExchangeFundInsufficientDeposits();
        }

        deposits[msg.sender][token] -= normalizedAmount;
        token.safeTransfer(msg.sender, amount);

        emit Withdrawal(msg.sender, token, normalizedAmount);
    }

    /// @dev Добавить новый депонируемый токен.
    function listDepositableToken(IERC20 token) external onlyGovernor {
        if (depositableTokensSet.contains(address(token))) {
            revert ExchangeFundDepositableTokenAlreadyListed(token);
        }

        uint8 decimals = token.decimals();
        if (decimals == 0) {
            revert ExchangeFundDepositableTokenZeroDecimals(token);
        }
        if (decimals > DECIMALS) {
            revert ExchangeFundDepositableTokenTooLargeDecimals(token, decimals);
        }

        if (depositableTokensSet.add(address(token))) {
            IERC20 baks = IERC20(core.baks());
            IUniswapV2Router uniswapV2Router = IUniswapV2Router(core.uniswapV2Router());

            token.approve(address(uniswapV2Router), type(uint256).max);

            IUniswapV2Factory uniswapV2Factory = uniswapV2Router.factory();
            IUniswapV2Pair uniswapV2Pair = uniswapV2Factory.getPair(baks, token);
            if (address(uniswapV2Pair) == address(0)) {
                uniswapV2Pair = uniswapV2Factory.createPair(baks, token);
            }
            uniswapV2Pair.approve(address(uniswapV2Router), type(uint256).max);

            depositableTokens[token] = true;
            emit DepositableTokenListed(token, uniswapV2Pair);
        }
    }

    /// @dev Удалить депонируемый токен.
    function unlistDepositableToken(IERC20 token) external onlyGovernor {
        if (!depositableTokensSet.contains(address(token))) {
            revert ExchangeFundDepositableTokenNotListed(token);
        }

        if (depositableTokensSet.remove(address(token))) {
            IUniswapV2Router uniswapV2Router = IUniswapV2Router(core.uniswapV2Router());

            token.approve(address(uniswapV2Router), 0);

            IUniswapV2Factory uniswapV2Factory = uniswapV2Router.factory();
            IUniswapV2Pair uniswapV2Pair = uniswapV2Factory.getPair(IERC20(core.baks()), token);
            if (address(uniswapV2Pair) != address(0)) {
                uniswapV2Pair.approve(address(uniswapV2Router), 0);
            }

            delete depositableTokens[token];
            emit DepositableTokenUnlisted(token);
        }
    }

    /// @dev Установить допустимое проскальзывание.
    function setSlippageTolerance(uint256 newSlippageTolerance) external onlyGovernor {
        emit SlippageToleranceUpdated(slippageTolerance, newSlippageTolerance);
        slippageTolerance = newSlippageTolerance;
    }

    /// @dev Установить дедлайн обмена.
    function setSwapDeadline(uint256 newSwapDeadline) external onlyGovernor {
        emit SwapDeadlineUpdated(swapDeadline, newSwapDeadline);
        swapDeadline = newSwapDeadline;
    }

    function salvage(IERC20 token) external onlyGovernor {
        address tokenAddress = address(token);
        if (token == IERC20(core.baks()) || depositableTokensSet.contains(tokenAddress)) {
            revert ExchangeFundTokenNotAllowedToBeSalvaged(token);
        }
        token.safeTransfer(core.operator(), token.balanceOf(address(this)));
    }

    /// @dev Привести курс к рыночному / добавить ликвидность до минимального порогового уровня.
    function service(IERC20 token) external {
        (uint256 baksReserve, uint256 tokenReserve) = getReserves(token);
        tokenReserve = token.normalizeAmount(tokenReserve);

        bool isService;

        uint256 targetPrice = IPriceOracle(core.priceOracle()).getNormalizedPrice(token);
        uint256 price = baksReserve.div(tokenReserve);
        int256 delta = int256(price.div(targetPrice)) - int256(ONE);
        if (Math.abs(delta) >= core.servicingThreshold()) {
            int256 amountOut;
            IERC20[] memory path = new IERC20[](2);
            if (price > targetPrice) {
                amountOut = int256(Math.fpsqrt(baksReserve.mul(tokenReserve).mul(targetPrice))) - int256(baksReserve);
                path[0] = token;
                path[1] = IERC20(core.baks());
            } else {
                amountOut = int256(Math.fpsqrt(baksReserve.mulDiv(tokenReserve, targetPrice))) - int256(tokenReserve);
                path[0] = IERC20(core.baks());
                path[1] = token;
            }

            // NOTE: using this instead of `swapExactTokensForTokens` to shift responsibility for calculating fees to
            // *swap itself.
            IUniswapV2Router(core.uniswapV2Router()).swapTokensForExactTokens(
                Math.abs(amountOut),
                type(uint256).max,
                path,
                address(this),
                block.timestamp + swapDeadline
            );

            isService = true;
        }

        if (!(isService || topUpLiquidity(token))) {
            revert ExchangeFundNoNeedToService(token);
        }

        emit Service(msg.sender, token);
    }

    /// @dev Перевести BAKS в фонд стабилизации.
    function transferBaksToBank(uint256 amount) external onlySuperUser {
        IERC20(core.baks()).safeTransfer(core.bank(), amount);
    }

    /// @dev Получить депонируемые токены.
    function getDepositableTokens() external view returns (IERC20[] memory tokens) {
        uint256 length = depositableTokensSet.elements.length;
        tokens = new IERC20[](length);

        for (uint256 i = 0; i < length; i++) {
            tokens[i] = IERC20(depositableTokensSet.elements[i]);
        }
    }

    /// @dev Рассчитать сумму обмена токена на BAKS.
    function quote(IERC20 token, uint256 amount) public view returns (uint256 baksAmount) {
        IERC20 baks = IERC20(core.baks());
        IUniswapV2Router uniswapV2Router = IUniswapV2Router(core.uniswapV2Router());

        IUniswapV2Pair uniswapV2Pair = uniswapV2Router.factory().getPair(baks, token);

        (uint256 reserveA, uint256 reserveB, ) = uniswapV2Pair.getReserves();
        if (reserveA == 0 || reserveB == 0) {
            baksAmount = token.normalizeAmount(amount).mul(IPriceOracle(core.priceOracle()).getNormalizedPrice(token));
            return baksAmount;
        }

        baksAmount = address(baks) < address(token)
            ? uniswapV2Router.quote(amount, reserveB, reserveA)
            : uniswapV2Router.quote(amount, reserveA, reserveB);
    }

    function topUpLiquidity(IERC20 token) internal returns (bool isTopUpped) {
        (uint256 baksReserve, uint256 tokenReserve) = getReserves(token);
        tokenReserve = token.normalizeAmount(tokenReserve);

        uint256 minimumLiquidity = core.minimumLiquidity();
        if (baksReserve < minimumLiquidity) {
            uint256 amountADesired = minimumLiquidity - baksReserve;
            uint256 amountBDesired = token.denormalizeAmount(amountADesired.div(baksReserve.div(tokenReserve)));
            IUniswapV2Router(core.uniswapV2Router()).addLiquidity(
                IERC20(core.baks()),
                token,
                amountADesired,
                amountBDesired,
                amountADesired.mul(ONE - slippageTolerance),
                token.denormalizeAmount(amountBDesired.mul(ONE - slippageTolerance)),
                address(this),
                block.timestamp + swapDeadline
            );

            isTopUpped = true;
        }
    }

    function getReserves(IERC20 token) internal view returns (uint256 baksReserve, uint256 tokenReserve) {
        IERC20 baks = IERC20(core.baks());
        IUniswapV2Pair uniswapV2Pair = IUniswapV2Router(core.uniswapV2Router()).factory().getPair(baks, token);

        (uint256 reserveA, uint256 reserveB, ) = uniswapV2Pair.getReserves();
        if (address(baks) < address(token)) {
            baksReserve = reserveA;
            tokenReserve = reserveB;
        } else {
            tokenReserve = reserveA;
            baksReserve = reserveB;
        }
    }
}
