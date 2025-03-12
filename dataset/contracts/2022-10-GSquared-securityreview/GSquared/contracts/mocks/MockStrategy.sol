// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.10;

import "../interfaces/IStrategy.sol";
import "../interfaces/IGVault.sol";
import {ERC20} from "../solmate/src/tokens/ERC20.sol";

library TestStratErrors {
    error NotOwner(); // 0x30cd7471
    error NotVault(); // 0x62df0545
    error NotKeeper(); // 0xf512b278
}

contract MockStrategy {
    /*//////////////////////////////////////////////////////////////
                        CONSTANTS & IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant PERCENTAGE_DECIMAL_FACTOR = 1E4;
    uint256 internal constant DEFAULT_DECIMALS_FACTOR = 1E18;

    IGVault public immutable vault;
    ERC20 public immutable asset;

    uint256 internal constant MAX_REPORT_DELAY = 604800;
    uint256 internal constant MIN_REPORT_DELAY = 172800;

    address public owner; // contract owner
    mapping(address => bool) public keepers;

    bool public emergencyMode;
    bool public stop;

    bool noLoss = false;
    bool tooMuchGain = false;
    bool tooMuchLoss = false;

    /*//////////////////////////////////////////////////////////////
                    STORAGE VARIABLES & TYPES
    //////////////////////////////////////////////////////////////*/

    // Strategy harvest thresholds
    uint256 internal debtThreshold = 20_000 * DEFAULT_DECIMALS_FACTOR;
    uint256 internal profitThreshold = 20_000 * DEFAULT_DECIMALS_FACTOR;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    event NewKeeper(address indexed keeper);
    event RevokedKeeper(address indexed keeper);
    event LogNewHarvestThresholds(
        uint256 debtThreshold,
        uint256 profitThreshold
    );
    event LogNewStopLoss(address newStopLoss);
    event LogNewBaseSlippage(uint256 baseSlippage);

    event Harvested(
        uint256 profit,
        uint256 loss,
        uint256 debtRepayment,
        uint256 excessDebt
    );

    event EmergencyModeSet(bool mode);
    event LogAdditionalRewards(address[] rewardTokens);

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _vault) {
        IGVault _v = IGVault(_vault);
        owner = msg.sender;
        keepers[msg.sender] = true;
        vault = _v;
        ERC20 _asset = _v.asset();
        asset = _asset;
        _asset.approve(_vault, type(uint256).max); // Max approve asset for Vault to save gas
    }

    /*//////////////////////////////////////////////////////////////
                           SETTERS
    //////////////////////////////////////////////////////////////*/

    function setKeeper(address _keeper) external {
        keepers[_keeper] = true;

        emit NewKeeper(_keeper);
    }

    function revokeKeeper(address _keeper) external {
        keepers[_keeper] = false;

        emit RevokedKeeper(_keeper);
    }

    /*//////////////////////////////////////////////////////////////
                           STRATEGY ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Get strategies current assets
    function estimatedTotalAssets() external view returns (uint256) {
        return _estimatedTotalAssets(false);
    }

    function _estimatedTotalAssets(bool _rewards)
        private
        view
        returns (uint256)
    {
        return asset.balanceOf(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                           CORE LOGIC
    //////////////////////////////////////////////////////////////*/

    function withdraw(uint256 _amount)
        external
        returns (uint256 withdrawnAssets, uint256 loss)
    {
        if (msg.sender != address(vault)) revert TestStratErrors.NotVault();
        uint256 assets = _estimatedTotalAssets(false);
        uint256 debt = vault.getStrategyDebt();
        if (_amount > assets) {
            withdrawnAssets = assets;
            if (!noLoss) {
                loss = _amount - assets;
            }
        } else {
            if (debt > assets) {
                if (!noLoss) {
                    loss = debt - assets;
                    if (loss > _amount) loss = _amount;
                }
            }
            if (!noLoss) {
                withdrawnAssets = _amount - loss;
            } else {
                if (_amount > assets) {
                    withdrawnAssets = assets;
                } else {
                    withdrawnAssets = _amount;
                }
            }
        }

        asset.transfer(msg.sender, withdrawnAssets);
        return (withdrawnAssets, loss);
    }

    function realisePnl(uint256 _excessDebt, uint256 _debtRatio)
        internal
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 profit = 0;
        uint256 loss = 0;
        uint256 debtRepayment = 0;

        uint256 debt = vault.getStrategyDebt();

        uint256 assets = _estimatedTotalAssets(true);
        uint256 balance = asset.balanceOf(address(this));

        // During testing, send this contract some tokens to simulate "Rewards"
        if (assets > _excessDebt) {
            debtRepayment = _excessDebt;
            assets -= _excessDebt;
        } else {
            debtRepayment = assets;
            assets = 0;
        }
        debt -= debtRepayment;

        if (assets > debt) {
            profit = assets - debt;
        } else {
            loss = debt - assets;
        }
        if (tooMuchGain) {
            profit = profit * 5;
        }
        if (tooMuchLoss) {
            loss = debt * 2;
        }
        return (profit, loss, debtRepayment, balance);
    }

    function divest(uint256 _debt, bool _slippage) internal returns (uint256) {}

    function divestAll(bool _slippage) internal returns (uint256) {}

    function invest(uint256 _credit) internal returns (uint256) {}

    function runHarvest() external {
        if (!keepers[msg.sender]) revert TestStratErrors.NotKeeper();
        (uint256 excessDebt, uint256 debtRatio) = vault.excessDebt(
            address(this)
        );
        uint256 profit;
        uint256 loss;
        uint256 debtRepayment;

        uint256 balance;
        bool emergency;

        // separate logic for emergency mode which needs implementation
        if (emergencyMode) {
            divestAll(false);
            emergency = true;
            debtRepayment = asset.balanceOf(address(this));
            uint256 debt = vault.getStrategyDebt();
            if (debt > debtRepayment) loss = debt - debtRepayment;
            else profit = debtRepayment - debt;
        } else {
            (profit, loss, debtRepayment, balance) = realisePnl(
                excessDebt,
                debtRatio
            );
        }
        uint256 credit = vault.report(profit, loss, debtRepayment, emergency);

        // invest any free funds in the strategy
        if (balance + credit > debtRepayment) {
            invest(balance + credit - debtRepayment);
        }

        emit Harvested(profit, loss, debtRepayment, excessDebt);
    }

    function stopLoss() external returns (bool) {}

    /*//////////////////////////////////////////////////////////////
                           TRIGGERS
    //////////////////////////////////////////////////////////////*/

    function canHarvest() external view returns (bool) {
        (bool active, uint256 totalDebt, uint256 lastReport) = vault
            .getStrategyData();

        if (!active) return false;
        if (stop) return false;

        uint256 timeSinceLastHarvest = block.timestamp - lastReport;
        if (timeSinceLastHarvest > MAX_REPORT_DELAY) return true;

        uint256 assets = _estimatedTotalAssets(true);
        uint256 debt = totalDebt;
        (uint256 excessDebt, ) = vault.excessDebt(address(this));
        uint256 profit;
        if (assets > debt) {
            profit = assets - debt;
        } else {
            excessDebt += debt - assets;
        }
        profit += vault.creditAvailable();
        if (excessDebt > debtThreshold) return true;
        if (profit > profitThreshold && timeSinceLastHarvest > MIN_REPORT_DELAY)
            return true;

        return false;
    }

    function canStopLoss() external view returns (bool) {}

    /*//////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS 
    //////////////////////////////////////////////////////////////*/

    function _takeFunds(uint256 amount) public {
        asset.transfer(msg.sender, amount);
    }

    function setTooMuchGain() external {
        tooMuchGain = true;
    }

    function setTooMuchLoss() external {
        tooMuchLoss = true;
    }

    function setNoLossStrategy() external {
        noLoss = true;
    }
}
