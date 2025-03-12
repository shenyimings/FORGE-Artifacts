// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

// dependencies
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";

// contracts
import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";
import { Executor } from "src/executors/Executor.sol";
import { PancakeV3VaultOracle } from "src/oracles/PancakeV3VaultOracle.sol";

// interfaces
import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { ICommonV3Pool } from "src/interfaces/ICommonV3Pool.sol";
import { IBank } from "src/interfaces/IBank.sol";

// libraries
import { LibTickMath } from "src/libraries/LibTickMath.sol";
import { MAX_BPS } from "src/libraries/Constants.sol";

contract PCSV3StableExecutor is Executor {
  using SafeTransferLib for ERC20;

  error PCSV3StableExecutor_NotPool();
  error PCSV3StableExecutor_BelowRepurchaseThreshold();
  error PCSV3StableExecutor_RepurchaseExceedDebt();
  error PCSV3StableExecutor_TooLittleReceived();

  event LogOnDeposit(address indexed _vaultToken, address indexed _worker, uint256 _amountIn0, uint256 _amountIn1);
  event LogOnWithdraw(
    address indexed _vaultToken,
    address indexed _worker,
    uint256 _sharesToWithdraw,
    uint256 _totalShares,
    uint256 _amount0Withdraw,
    uint256 _amount1Withdraw,
    uint256 _amount0AfterRepay,
    uint256 _amount1AfterRepay
  );
  event LogOnUpdate(address indexed _vaultToken, address indexed _worker);
  event LogSweepToWorker(address _token, uint256 _amount);
  event LogIncreasePosition(
    address indexed _vaultToken, address indexed _worker, uint256 _amountIn0, uint256 _amountIn1
  );
  event LogOpenPosition(
    address indexed _vaultToken,
    address indexed _worker,
    int24 _tickLower,
    int24 _tickUpper,
    uint256 _amountIn0,
    uint256 _amountIn1
  );
  event LogDecreasePosition(address indexed _vaultToken, address indexed _worker, uint128 _liquidity);
  event LogClosePosition(address indexed _vaultToken, address indexed _worker);
  event LogTransferFromWorker(address indexed _vaultToken, address indexed _worker, uint256 _amount);
  event LogBorrow(address indexed _vaultToken, address _token, uint256 _amount);
  event LogRepay(address indexed _vaultToken, address _token, uint256 _amount);
  event LogRepurchase(address indexed _vaultToken, address _borrowToken, uint256 _borrowAmount, uint256 _repayAmount);
  event LogSetRepurchaseThreshold(uint160 _token0Threshold, uint160 _token1Threshold);
  event LogSetRepurchaseSlippage(uint16 _repurchaseSlippageBps);
  event LogSetVaultOracle(address _vaultOracle);

  // threshold is in sqrtPriceX96
  // only allow repurchase when stables depegged to threshold
  uint160 public token0RepurchaseThresholdX96;
  uint160 public token1RepurchaseThresholdX96;
  PancakeV3VaultOracle public vaultOracle;
  uint16 public repurchaseSlippageBps;

  function initialize(
    address _vaultManager,
    address _bank,
    uint160 _token0RepurchaseThreshold,
    uint160 _token1RepurchaseThreshold,
    address _vaultOracle,
    uint16 _repurchaseSlippageBps
  ) external initializer {
    if (_repurchaseSlippageBps > MAX_BPS) {
      revert Executor_InvalidParams();
    }
    // Sanity check
    PancakeV3VaultOracle(_vaultOracle).maxPriceAge();
    AutomatedVaultManager(_vaultManager).vaultTokenImplementation();
    if (_vaultManager != IBank(_bank).vaultManager()) {
      revert Executor_InvalidParams();
    }

    __Ownable2Step_init();

    vaultManager = _vaultManager;
    bank = IBank(_bank);
    token0RepurchaseThresholdX96 = _token0RepurchaseThreshold;
    token1RepurchaseThresholdX96 = _token1RepurchaseThreshold;
    vaultOracle = PancakeV3VaultOracle(_vaultOracle);
    repurchaseSlippageBps = _repurchaseSlippageBps;
  }

  function onDeposit(address _worker, address _vaultToken)
    external
    override
    onlyVaultManager
    returns (bytes memory _result)
  {
    ERC20 _token0 = PancakeV3Worker(_worker).token0();
    ERC20 _token1 = PancakeV3Worker(_worker).token1();
    uint256 _amountIn0 = _token0.balanceOf(address(this));
    uint256 _amountIn1 = _token1.balanceOf(address(this));

    if (_amountIn0 != 0) {
      _token0.safeTransfer(_worker, _amountIn0);
    }
    if (_amountIn1 != 0) {
      _token1.safeTransfer(_worker, _amountIn1);
    }

    emit LogOnDeposit(_vaultToken, _worker, _amountIn0, _amountIn1);

    return abi.encode(_amountIn0, _amountIn1);
  }

  /// @notice Decrease liquidity, transfer undeployed funds from worker and repay debt
  function onWithdraw(address _worker, address _vaultToken, uint256 _sharesToWithdraw)
    external
    override
    onlyVaultManager
    onlyOutOfExecutionScope
    returns (AutomatedVaultManager.TokenAmount[] memory _results)
  {
    uint256 _totalShares = ERC20(_vaultToken).totalSupply();
    ERC20 _token0 = PancakeV3Worker(_worker).token0();
    ERC20 _token1 = PancakeV3Worker(_worker).token1();

    // Withdraw from nft liquidity (if applicable) and undeployed funds
    uint256 _amount0Withdraw;
    uint256 _amount1Withdraw;
    {
      _amount0Withdraw = _token0.balanceOf(_worker) * _sharesToWithdraw / _totalShares;
      _amount1Withdraw = _token1.balanceOf(_worker) * _sharesToWithdraw / _totalShares;
      {
        uint256 _tokenId = PancakeV3Worker(_worker).nftTokenId();
        if (_tokenId != 0) {
          (,,,,,,, uint128 _liquidity,,,,) = PancakeV3Worker(_worker).nftPositionManager().positions(_tokenId);
          if (_liquidity != 0) {
            (uint256 _amount0Decreased, uint256 _amount1Decreased) =
              PancakeV3Worker(_worker).decreasePosition(uint128(_liquidity * _sharesToWithdraw / _totalShares));
            // Tokens still with worker after `decreasePosition` so we need to add to withdrawal
            _amount0Withdraw += _amount0Decreased;
            _amount1Withdraw += _amount1Decreased;
          }
        }
      }
      // Withdraw undeployed funds and decreased liquidity if any
      if (_amount0Withdraw != 0) {
        PancakeV3Worker(_worker).transferToExecutor(address(_token0), _amount0Withdraw);
      }
      if (_amount1Withdraw != 0) {
        PancakeV3Worker(_worker).transferToExecutor(address(_token1), _amount1Withdraw);
      }
    }

    // Repay with amount withdrawn, swap other token to repay token if not enough
    // NOTE: can't repay if vault has no equity (position value + undeployed funds < debt value)
    // due to amount withdrawn is not enough to repay and will revert
    _repayOnWithdraw(_worker, _vaultToken, _sharesToWithdraw, _totalShares, _amount0Withdraw, _token0, _token1);
    _repayOnWithdraw(_worker, _vaultToken, _sharesToWithdraw, _totalShares, _amount1Withdraw, _token1, _token0);

    // What is left after repayment belongs to user
    uint256 _amount0AfterRepay = _token0.balanceOf(address(this));
    if (_amount0AfterRepay != 0) {
      _token0.safeTransfer(msg.sender, _amount0AfterRepay);
    }
    uint256 _amount1AfterRepay = _token1.balanceOf(address(this));
    if (_amount1AfterRepay != 0) {
      _token1.safeTransfer(msg.sender, _amount1AfterRepay);
    }

    emit LogOnWithdraw(
      _vaultToken,
      _worker,
      _sharesToWithdraw,
      _totalShares,
      _amount0Withdraw,
      _amount1Withdraw,
      _amount0AfterRepay,
      _amount1AfterRepay
    );

    _results = new AutomatedVaultManager.TokenAmount[](2);
    _results[0] = AutomatedVaultManager.TokenAmount({ token: address(_token0), amount: _amount0AfterRepay });
    _results[1] = AutomatedVaultManager.TokenAmount({ token: address(_token1), amount: _amount1AfterRepay });
    return _results;
  }

  function _repayOnWithdraw(
    address _worker,
    address _vaultToken,
    uint256 _sharesToWithdraw,
    uint256 _totalShares,
    uint256 _repayTokenBalance,
    ERC20 _repayToken,
    ERC20 _otherToken
  ) internal {
    uint256 _repayAmount;
    (, uint256 _debtAmount) = bank.getVaultDebt(_vaultToken, address(_repayToken));
    _repayAmount = _debtAmount * _sharesToWithdraw / _totalShares;
    // Early return if no repay
    if (_repayAmount == 0) return;

    // Swap if not enough to repay
    if (_repayAmount > _repayTokenBalance) {
      uint256 _diffAmount = _repayAmount - _repayTokenBalance;
      bool _zeroForOne = address(_otherToken) < address(_repayToken);

      ICommonV3Pool _pool = PancakeV3Worker(_worker).pool();
      _pool.swap(
        address(this),
        _zeroForOne,
        -int256(_diffAmount), // negative = exact output
        _zeroForOne ? LibTickMath.MIN_SQRT_RATIO + 1 : LibTickMath.MAX_SQRT_RATIO - 1, // no price limit
        abi.encode(_pool.token0(), _pool.token1(), _pool.fee())
      );
    }

    _repay(_vaultToken, address(_repayToken), _repayAmount);
  }

  function onUpdate(address _worker, address _vaultToken)
    external
    override
    onlyVaultManager
    returns (bytes memory _result)
  {
    bank.accrueInterest(_vaultToken);
    PancakeV3Worker(_worker).harvest();
    emit LogOnUpdate(_vaultToken, _worker);
  }

  function sweepToWorker() external override onlyVaultManager {
    address _worker = _getCurrentWorker();
    ICommonV3Pool _pool = PancakeV3Worker(_worker).pool();
    _sweepTo(ERC20(_pool.token0()), _worker);
    _sweepTo(ERC20(_pool.token1()), _worker);
  }

  function _sweepTo(ERC20 _token, address _to) internal {
    uint256 _balance = _token.balanceOf(address(this));
    if (_balance != 0) {
      _token.safeTransfer(_to, _balance);
      emit LogSweepToWorker(address(_token), _balance);
    }
  }

  /// @notice Increase existing position liquidity using worker's undeployed funds.
  /// Worker will revert if it doesn't have position.
  function increasePosition(uint256 _amountIn0, uint256 _amountIn1) external onlyVaultManager {
    address _worker = _getCurrentWorker();
    PancakeV3Worker(_worker).increasePosition(_amountIn0, _amountIn1);
    emit LogIncreasePosition(_getCurrentVaultToken(), _worker, _amountIn0, _amountIn1);
  }

  /// @notice Open new position (zap, add liquidity and deposit nft to masterchef) for worker
  /// using worker's undeployed funds. Worker will revert if position already exist.
  /// Can't open position for pool that doesn't have CAKE reward in masterChef.
  function openPosition(int24 _tickLower, int24 _tickUpper, uint256 _amountIn0, uint256 _amountIn1)
    external
    onlyVaultManager
  {
    address _worker = _getCurrentWorker();
    PancakeV3Worker(_worker).openPosition(_tickLower, _tickUpper, _amountIn0, _amountIn1);
    emit LogOpenPosition(_getCurrentVaultToken(), _worker, _tickLower, _tickUpper, _amountIn0, _amountIn1);
  }

  function decreasePosition(uint128 _liquidity) external onlyVaultManager {
    address _worker = _getCurrentWorker();
    PancakeV3Worker(_worker).decreasePosition(_liquidity);
    emit LogDecreasePosition(_getCurrentVaultToken(), _worker, _liquidity);
  }

  function closePosition() external onlyVaultManager {
    address _worker = _getCurrentWorker();
    PancakeV3Worker(_worker).closePosition();
    emit LogClosePosition(_getCurrentVaultToken(), _worker);
  }

  function transferFromWorker(address _token, uint256 _amount) external onlyVaultManager {
    address _worker = _getCurrentWorker();
    PancakeV3Worker(_worker).transferToExecutor(_token, _amount);
    emit LogTransferFromWorker(_getCurrentVaultToken(), _worker, _amount);
  }

  /// @notice Borrow token from Bank. Borrowed funds will be sent directly to worker.
  function borrow(address _token, uint256 _amount) external onlyVaultManager {
    address _vaultToken = _getCurrentVaultToken();
    bank.borrowOnBehalfOf(_vaultToken, _token, _amount);
    ERC20(_token).safeTransfer(_getCurrentWorker(), _amount);
    emit LogBorrow(_vaultToken, _token, _amount);
  }

  /// @notice Repay token back to Bank
  function repay(address _token, uint256 _amount) external onlyVaultManager {
    address _vaultToken = _getCurrentVaultToken();
    _repay(_vaultToken, _token, _amount);
  }

  function _repay(address _vaultToken, address _token, uint256 _amount) internal returns (uint256 _actualRepayAmount) {
    ERC20(_token).safeApprove(address(bank), _amount);

    _actualRepayAmount = bank.repayOnBehalfOf(_vaultToken, _token, _amount);

    ERC20(_token).safeApprove(address(bank), 0);

    emit LogRepay(_vaultToken, _token, _actualRepayAmount);
  }

  /// @notice Adjust vault exposure by borrowing a token, swap to another and repay.
  function repurchase(address _borrowToken, uint256 _borrowAmount) external onlyVaultManager {
    // Example
    // token0 = USDT, token1 = BUSD
    // BUSD depegged to 0.9
    // repurchase (borrow USDT, swap for BUSD and repay)
    // after repurchase there cannot be any USDT left aka. repay <= debt

    // Check
    // Only allow to repurchase token0 or 1 when price is depegged above threshold
    // to prevent price manipulation
    address _vaultToken = _getCurrentVaultToken();
    ICommonV3Pool _pool = PancakeV3Worker(_getCurrentWorker()).pool();
    ERC20 _token0 = ERC20(_pool.token0());
    ERC20 _token1 = ERC20(_pool.token1());
    bool _zeroForOne;
    address _repayToken;
    if (_borrowToken == address(_token0)) {
      (uint160 _sqrtPriceX96,,,,,,) = _pool.slot0();
      if (_sqrtPriceX96 < token0RepurchaseThresholdX96) {
        revert PCSV3StableExecutor_BelowRepurchaseThreshold();
      }
      _zeroForOne = true;
      _repayToken = address(_token1);
    } else if (_borrowToken == address(_token1)) {
      (uint160 _sqrtPriceX96,,,,,,) = _pool.slot0();
      if (_sqrtPriceX96 > token1RepurchaseThresholdX96) {
        revert PCSV3StableExecutor_BelowRepurchaseThreshold();
      }
      _zeroForOne = false;
      _repayToken = address(_token0);
    } else {
      revert Executor_InvalidParams();
    }

    IBank _bank = bank;
    // Borrow
    _bank.borrowOnBehalfOf(_vaultToken, _borrowToken, _borrowAmount);

    // Swap
    (int256 _amount0, int256 _amount1) = _pool.swap(
      address(this),
      _zeroForOne,
      int256(_borrowAmount), // positive = exact input
      _zeroForOne ? LibTickMath.MIN_SQRT_RATIO + 1 : LibTickMath.MAX_SQRT_RATIO - 1, // no price limit
      abi.encode(address(_token0), address(_token1), _pool.fee())
    );
    uint256 _swapAmountOut = uint256(_zeroForOne ? -_amount1 : -_amount0);

    // Check slippage
    {
      {
        uint256 _expectedAmountOut;
        if (_zeroForOne) {
          _expectedAmountOut = _borrowAmount * vaultOracle.getTokenPrice(address(_token0)) * (10 ** _token1.decimals())
            / (vaultOracle.getTokenPrice(address(_token1)) * (10 ** _token0.decimals()));
        } else {
          _expectedAmountOut = _borrowAmount * vaultOracle.getTokenPrice(address(_token1)) * (10 ** _token0.decimals())
            / (vaultOracle.getTokenPrice(address(_token0)) * (10 ** _token1.decimals()));
        }
        if (_swapAmountOut * MAX_BPS < _expectedAmountOut * (MAX_BPS - repurchaseSlippageBps)) {
          revert PCSV3StableExecutor_TooLittleReceived();
        }
      }
    }

    // Prevent repurchase exceed debt
    (, uint256 _debt) = _bank.getVaultDebt(_vaultToken, _repayToken);
    if (_swapAmountOut > _debt) {
      revert PCSV3StableExecutor_RepurchaseExceedDebt();
    }

    // Repay
    uint256 _actualRepayAmount = _repay(_vaultToken, _repayToken, _swapAmountOut);

    emit LogRepurchase(_vaultToken, _borrowToken, _borrowAmount, _actualRepayAmount);
  }

  function pancakeV3SwapCallback(int256 _amount0Delta, int256 _amount1Delta, bytes calldata _data) external {
    (address _token0, address _token1, uint24 _fee) = abi.decode(_data, (address, address, uint24));
    address _pool = address(
      uint160(
        uint256(
          keccak256(
            abi.encodePacked(
              hex"ff",
              0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9,
              keccak256(abi.encode(_token0, _token1, _fee)),
              bytes32(0x6ce8eb472fa82df5469c6ab6d485f17c3ad13c8cd7af59b3d4a8026c5ce0f7e2)
            )
          )
        )
      )
    );
    if (msg.sender == _pool) {
      if (_amount0Delta > 0) {
        ERC20(_token0).safeTransfer(msg.sender, uint256(_amount0Delta));
      } else {
        ERC20(_token1).safeTransfer(msg.sender, uint256(_amount1Delta));
      }
    } else {
      revert PCSV3StableExecutor_NotPool();
    }
  }

  function setRepurchaseThreshold(uint160 _token0ThresholdX96, uint160 _token1ThresholdX96) external onlyOwner {
    if (_token0ThresholdX96 < _token1ThresholdX96) {
      revert Executor_InvalidParams();
    }
    token0RepurchaseThresholdX96 = _token0ThresholdX96;
    token1RepurchaseThresholdX96 = _token1ThresholdX96;
    emit LogSetRepurchaseThreshold(_token0ThresholdX96, _token1ThresholdX96);
  }

  function setRepurchaseSlippageBps(uint16 _repurchaseSlippageBps) external onlyOwner {
    if (_repurchaseSlippageBps > MAX_BPS) {
      revert Executor_InvalidParams();
    }
    repurchaseSlippageBps = _repurchaseSlippageBps;
    emit LogSetRepurchaseSlippage(_repurchaseSlippageBps);
  }

  function setVaultOracle(address _vaultOracle) external onlyOwner {
    PancakeV3VaultOracle(_vaultOracle).maxPriceAge();
    vaultOracle = PancakeV3VaultOracle(_vaultOracle);
    emit LogSetVaultOracle(_vaultOracle);
  }
}
