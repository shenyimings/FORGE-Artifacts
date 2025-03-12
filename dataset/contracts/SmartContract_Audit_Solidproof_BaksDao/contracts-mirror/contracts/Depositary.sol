// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./libraries/AmountNormalization.sol";
import "./libraries/Deposit.sol";
import "./libraries/EnumerableAddressSet.sol";
import "./libraries/FixedPointMath.sol";
import "./libraries/Magister.sol";
import "./libraries/Math.sol";
import "./libraries/Pool.sol";
import "./libraries/SafeERC20.sol";
import {CoreInside, ICore} from "./Core.sol";
import {Governed} from "./Governance.sol";
import {IERC20} from "./interfaces/ERC20.sol";
import {Initializable} from "./libraries/Upgradability.sol";
import {IPriceOracle} from "./interfaces/IPriceOracle.sol";
import "./interfaces/IDepositary.sol";
import "./interfaces/IBank.sol";

/// @dev Генерируется после попытки добавить уже существующего магистра.
/// @param magister Адрес магистра
error BaksDAOMagisterAlreadyWhitelisted(address magister);
/// @dev Генерируется после попытки взаимодействия с удалённым магистром.
/// @param magister Адрес магистра
error BaksDAOMagisterBlacklisted(address magister);
/// @dev Взаимодействие разрешено только вкладчику, либо магистру.
error BaksDAOOnlyDepositorOrMagisterAllowed();
/// @dev Сумма снятия превышает вложенную.
error BaksDAOWithdrawAmountExceedsPrincipal();
/// @dev Сумма депозита с магистром не превышает минимально требуемую.
error BaksDAOBelowMinimumMagisterDepositAmount();
/// @dev Попытка депонировать нулевую сумму.
error BaksDAODepositZeroAmount();

/// @title Контракт для работы с депозитами
/// @author BaksDAO
contract Depositary is CoreInside, Governed, IDepositary, Initializable {
    using AmountNormalization for IERC20;
    using Deposit for Deposit.Data;
    using EnumerableAddressSet for EnumerableAddressSet.Set;
    using FixedPointMath for uint256;
    using Magister for Magister.Data;
    using Pool for Pool.Data;
    using SafeERC20 for IERC20;

    uint256 internal constant ONE = 100e16;

    /// @dev Информация о магистрах.
    mapping(address => Magister.Data) public magisters;
    EnumerableAddressSet.Set internal magistersSet;

    /// @dev Информация о пулах.
    Pool.Data[] public pools;

    /// @dev Массив с информацией о депозитах.
    Deposit.Data[] public deposits;
    /// @dev Идентификаторы депозитов по пулам и кошелькам.
    mapping(uint256 => mapping(address => uint256)) public currentDepositIds;

    /// @dev Генерируется после добавления нового магистра.
    /// @param magister Магистр.
    event MagisterWhitelisted(address indexed magister);
    /// @dev Генерируется после удаления магистра.
    /// @param magister Магистр.
    event MagisterBlacklisted(address indexed magister);

    function initialize(ICore _core) external initializer {
        initializeCoreInside(_core);
        setGovernor(msg.sender);

        // Add guard pool and deposit
        deposits.push(
            Deposit.Data({
                id: 0,
                isActive: false,
                depositor: address(0),
                magister: address(0),
                poolId: 0,
                principal: 0,
                depositorTotalAccruedRewards: 0,
                depositorWithdrawnRewards: 0,
                magisterTotalAccruedRewards: 0,
                magisterWithdrawnRewards: 0,
                createdAt: block.timestamp,
                lastDepositAt: block.timestamp,
                lastInteractionAt: block.timestamp,
                closedAt: block.timestamp
            })
        );

        pools.push(
            Pool.Data({
                id: 0,
                depositToken: IERC20(address(0)),
                priceOracle: IPriceOracle(core.priceOracle()),
                isCompounding: false,
                depositsAmount: 0,
                depositorApr: 0,
                magisterApr: 0,
                depositorBonusApr: 0,
                magisterBonusApr: 0
            })
        );
    }

    /// @dev Депонирование средств в пул.
    /// @param poolId Идентифкатор пула
    /// @param amount Сумма депозита
    function deposit(uint256 poolId, uint256 amount) external {
        deposit(poolId, amount, address(this));
    }

    /// @dev Снятие средств из депозита.
    /// @param depositId Идентифкатор депозита
    /// @param amount Сумма снятия
    function withdraw(uint256 depositId, uint256 amount) external {
        Deposit.Data storage d = deposits[depositId];
        Pool.Data storage p = pools[d.poolId];

        if (!(msg.sender == d.depositor || msg.sender == d.magister)) {
            revert BaksDAOOnlyDepositorOrMagisterAllowed();
        }

        uint256 normalizedAmount = p.depositToken.normalizeAmount(amount);
        accrueRewards(d.id);

        uint256 magisterAmount = Math.min(d.magisterTotalAccruedRewards - d.magisterWithdrawnRewards, normalizedAmount);
        (
            uint256 depositorReward,
            uint256 depositorBonusReward,
            uint256 magisterReward,
            uint256 magisterBonusReward
        ) = splitRewards(d.poolId, d.depositorTotalAccruedRewards - d.depositorWithdrawnRewards, magisterAmount);

        if (msg.sender == d.magister) {
            IERC20(core.baks()).safeTransferFrom(core.exchangeFund(), d.magister, magisterReward);
            if (magisterBonusReward > 0) {
                IERC20(core.voice()).safeTransferFrom(core.exchangeFund(), d.magister, magisterBonusReward);
            }

            d.magisterWithdrawnRewards += magisterAmount;
        } else {
            if (normalizedAmount > d.principal) {
                revert BaksDAOWithdrawAmountExceedsPrincipal();
            }

            uint256 fee;
            if (p.isCompounding) {
                if (block.timestamp < d.lastDepositAt + core.earlyWithdrawalPeriod()) {
                    fee += core.earlyWithdrawalFee();
                }
            }

            if (p.depositToken != IERC20(core.baks()) && p.depositToken != IERC20(core.voice())) {
                p.depositToken.safeTransfer(d.depositor, normalizedAmount);
            }
            IERC20(core.baks()).safeTransferFrom(
                core.exchangeFund(),
                d.depositor,
                p.depositToken == IERC20(core.baks())
                    ? (normalizedAmount + depositorReward).mul(ONE - fee)
                    : depositorReward
            );
            if (depositorBonusReward > 0) {
                IERC20(core.voice()).safeTransferFrom(core.exchangeFund(), d.depositor, depositorBonusReward);
            }

            p.depositsAmount -= normalizedAmount;
            d.principal -= normalizedAmount;
            d.depositorWithdrawnRewards += d.depositorTotalAccruedRewards - d.depositorWithdrawnRewards;
        }

        d.lastInteractionAt = block.timestamp;
        if (d.principal == 0) {
            d.isActive = false;
            d.closedAt = block.timestamp;
            delete currentDepositIds[d.poolId][msg.sender];
        }
    }

    /// @dev Добавить магистра.
    /// @param magister Магистр
    function whitelistMagister(address magister) external onlySuperUser {
        if (magistersSet.contains(magister)) {
            revert BaksDAOMagisterAlreadyWhitelisted(magister);
        }

        if (magistersSet.add(magister)) {
            Magister.Data storage m = magisters[magister];
            m.addr = magister;
            if (m.createdAt == 0) {
                m.createdAt = block.timestamp;
            }
            m.isActive = true;

            emit MagisterWhitelisted(magister);
        }
    }

    /// @dev Удалить магистра.
    /// @param magister Магистр
    function blacklistMagister(address magister) external onlySuperUser {
        if (!magistersSet.contains(magister)) {
            revert BaksDAOMagisterBlacklisted(magister);
        }

        if (magistersSet.remove(magister)) {
            magisters[magister].isActive = false;
            emit MagisterBlacklisted(magister);
        }
    }

    /// @dev Добавить пул.
    /// @param depositToken Депонируемый токен
    /// @param isCompounding Используется ли авто-реинвестирование?
    /// @param depositorApr APR вкладчика
    /// @param magisterApr APR магистра
    /// @param depositorBonusApr Бонусный APR вкладчика
    /// @param magisterBonusApr Бонусный APR магистра
    function addPool(
        IERC20 depositToken,
        bool isCompounding,
        uint256 depositorApr,
        uint256 magisterApr,
        uint256 depositorBonusApr,
        uint256 magisterBonusApr
    ) external onlyGovernor {
        uint256 poolId = pools.length;
        pools.push(
            Pool.Data({
                id: poolId,
                depositToken: depositToken,
                priceOracle: IPriceOracle(core.priceOracle()),
                isCompounding: isCompounding,
                depositsAmount: 0,
                depositorApr: depositorApr,
                magisterApr: magisterApr,
                depositorBonusApr: depositorBonusApr,
                magisterBonusApr: magisterBonusApr
            })
        );
    }

    /// @dev Обновить параметры пула.
    /// @param poolId Идентификатор пула
    /// @param isCompounding Используется ли авто-реинвестирование?
    /// @param depositorApr APR вкладчика
    /// @param magisterApr APR магистра
    /// @param depositorBonusApr Бонусный APR вкладчика
    /// @param magisterBonusApr Бонусный APR магистра
    function updatePool(
        uint256 poolId,
        bool isCompounding,
        uint256 depositorApr,
        uint256 magisterApr,
        uint256 depositorBonusApr,
        uint256 magisterBonusApr
    ) external onlyGovernor {
        Pool.Data storage pool = pools[poolId];
        pool.isCompounding = isCompounding;
        pool.depositorApr = depositorApr;
        pool.magisterApr = magisterApr;
        pool.depositorBonusApr = depositorBonusApr;
        pool.magisterBonusApr = magisterBonusApr;
    }

    /// @dev Получить адреса активных магистров
    function getActiveMagisterAddresses() external view returns (address[] memory activeMagisterAddresses) {
        activeMagisterAddresses = magistersSet.elements;
    }

    /// @dev Получить активных магистров
    function getActiveMagisters() external view returns (Magister.Data[] memory activeMagisters) {
        uint256 length = magistersSet.elements.length;
        activeMagisters = new Magister.Data[](length);

        for (uint256 i = 0; i < length; i++) {
            activeMagisters[i] = magisters[magistersSet.elements[i]];
        }
    }

    /// @dev Получить количество активных пулов
    function getPoolsCount() external view returns (uint256) {
        return pools.length;
    }

    /// @dev Получить активные пулы
    function getPools() external view returns (Pool.Data[] memory) {
        return pools;
    }

    /// @dev Получить идентификаторы депозитов магистра
    function getMagisterDepositIds(address magister) external view returns (uint256[] memory) {
        return magisters[magister].depositIds;
    }

    /// @dev Получить значение LTV по определённому токену для депозитов
    function getTotalValueLocked(IERC20 depositToken) external view returns (uint256 totalValueLocked) {
        for (uint256 i = 0; i < pools.length; i++) {
            if (pools[i].depositToken == depositToken) {
                totalValueLocked += pools[i].getDepositsValue();
            }
        }
    }

    /// @dev Получить общее значение LTV по депозитам
    function getTotalValueLocked() external view returns (uint256 totalValueLocked) {
        for (uint256 i = 0; i < pools.length; i++) {
            totalValueLocked += pools[i].getDepositsValue();
        }
    }

    /// @dev Депонирование средств в пул с магистром.
    /// @param poolId Идентифкатор пула
    /// @param amount Сумма депозита
    /// @param magister Магистр
    function deposit(
        uint256 poolId,
        uint256 amount,
        address magister
    ) public {
        if (magister == msg.sender || !(magister == address(this) || magisters[magister].isActive)) {
            revert BaksDAOMagisterBlacklisted(magister);
        }

        IERC20 baks = IERC20(core.baks());
        IERC20 voice = IERC20(core.voice());

        Pool.Data storage p = pools[poolId];
        p.depositToken.safeTransferFrom(
            msg.sender,
            (p.depositToken == baks || p.depositToken == voice) ? core.exchangeFund() : address(this),
            amount
        );

        uint256 normalizedAmount = p.depositToken.normalizeAmount(amount);
        p.depositsAmount += normalizedAmount;

        if (currentDepositIds[poolId][msg.sender] == 0) {
            if (amount == 0) {
                revert BaksDAODepositZeroAmount();
            }

            uint256 id = deposits.length;
            deposits.push(
                Deposit.Data({
                    id: id,
                    isActive: true,
                    magister: magister,
                    depositor: msg.sender,
                    poolId: poolId,
                    principal: normalizedAmount,
                    depositorTotalAccruedRewards: 0,
                    depositorWithdrawnRewards: 0,
                    magisterTotalAccruedRewards: 0,
                    magisterWithdrawnRewards: 0,
                    createdAt: block.timestamp,
                    lastDepositAt: block.timestamp,
                    lastInteractionAt: block.timestamp,
                    closedAt: 0
                })
            );

            currentDepositIds[poolId][msg.sender] = id;
            if (magister != address(this)) {
                uint256 depositTokenPrice = IPriceOracle(core.priceOracle()).getNormalizedPrice(p.depositToken);
                if (normalizedAmount.mul(depositTokenPrice) < core.minimumMagisterDepositAmount()) {
                    revert BaksDAOBelowMinimumMagisterDepositAmount();
                }

                magisters[magister].depositIds.push(id);
            }
        } else {
            Deposit.Data storage d = deposits[currentDepositIds[poolId][msg.sender]];
            accrueRewards(d.id);

            uint256 r = d.depositorTotalAccruedRewards - d.depositorWithdrawnRewards;
            (uint256 depositorRewards, uint256 depositorBonusRewards, , ) = splitRewards(d.poolId, r, 0);
            baks.safeTransferFrom(core.exchangeFund(), d.depositor, depositorRewards);
            if (depositorBonusRewards > 0) {
                voice.safeTransferFrom(core.exchangeFund(), d.depositor, depositorBonusRewards);
            }

            d.principal += normalizedAmount;
            d.depositorWithdrawnRewards += r;
            d.lastDepositAt = block.timestamp;
            d.lastInteractionAt = block.timestamp;
        }

        if (p.depositToken != baks) {
            IBank(core.bank()).onNewDeposit(p.depositToken, normalizedAmount);
        }
    }

    /// @dev Получить текущее значение начисленных на депозит наград.
    /// @param depositId Идентифкатор депозита
    /// @return depositorRewards Награды вкладчика
    /// @return magisterRewards Награды магистра
    function getRewards(uint256 depositId) public view returns (uint256 depositorRewards, uint256 magisterRewards) {
        Deposit.Data memory d = deposits[depositId];

        (uint256 dr, uint256 mr) = calculateRewards(depositId);
        depositorRewards = dr + d.depositorTotalAccruedRewards - d.depositorWithdrawnRewards;
        magisterRewards = mr + d.magisterTotalAccruedRewards - d.magisterWithdrawnRewards;
    }

    function accrueRewards(uint256 depositId) internal {
        (uint256 depositorRewards, uint256 magisterRewards) = calculateRewards(depositId);

        Deposit.Data storage d = deposits[depositId];
        IERC20 depositToken = pools[d.poolId].depositToken;
        uint256 depositTokenPrice = depositToken == IERC20(core.baks())
            ? ONE
            : IPriceOracle(core.priceOracle()).getNormalizedPrice(depositToken);
        if (d.magister != address(this) && magisters[d.magister].isActive) {
            d.magisterTotalAccruedRewards += magisterRewards;
            magisters[d.magister].totalIncome += magisterRewards.mul(depositTokenPrice);
        }

        d.depositorTotalAccruedRewards += depositorRewards;
        if (magisters[msg.sender].isActive) {
            magisters[msg.sender].totalIncome += depositorRewards.mul(depositTokenPrice);
        }
    }

    function calculateRewards(uint256 depositId)
        internal
        view
        returns (uint256 depositorRewards, uint256 magisterRewards)
    {
        Deposit.Data memory d = deposits[depositId];
        Pool.Data memory p = pools[d.poolId];

        depositorRewards = d.principal.mul(
            p.calculateMultiplier(p.getDepositorApr(), core.workFee(), block.timestamp - d.lastInteractionAt)
        );
        magisterRewards = d.principal.mul(
            p.calculateMultiplier(p.getMagisterApr(), 0, block.timestamp - d.lastInteractionAt)
        );
    }

    function splitRewards(
        uint256 poolId,
        uint256 _depositorRewards,
        uint256 _magisterRewards
    )
        internal
        view
        returns (
            uint256 depositorRewards,
            uint256 depositorBonusRewards,
            uint256 magisterRewards,
            uint256 magisterBonusRewards
        )
    {
        IPriceOracle priceOracle = IPriceOracle(core.priceOracle());

        Pool.Data memory p = pools[poolId];

        uint256 depositorTotalApr = p.getDepositorApr();
        uint256 magisterTotalApr = p.getMagisterApr();
        uint256 depositTokenPrice = p.depositToken == IERC20(core.baks())
            ? ONE
            : priceOracle.getNormalizedPrice(p.depositToken);

        depositorRewards = _depositorRewards.mul(depositTokenPrice);
        magisterRewards = _magisterRewards.mul(depositTokenPrice);

        try priceOracle.getNormalizedPrice(IERC20(core.voice())) returns (uint256 bonusTokenPrice) {
            if (bonusTokenPrice > 0) {
                depositorBonusRewards = depositorRewards.mulDiv(
                    p.depositorBonusApr.mul(bonusTokenPrice),
                    depositorTotalApr
                );
                magisterBonusRewards = magisterRewards.mulDiv(
                    p.magisterBonusApr.mul(bonusTokenPrice),
                    magisterTotalApr
                );

                depositorRewards = depositorRewards.mulDiv(p.depositorApr, depositorTotalApr);
                magisterRewards = magisterRewards.mulDiv(p.magisterApr, magisterTotalApr);
            }
        } catch {}
    }
}
